import { AppError } from '../lib/errors.js';
import { isoDate, safeInt, safeNumber } from '../lib/records.js';
import { fetchJson } from './http.js';
import type {
  FetchLike,
  PlatformContext,
  PlatformSyncResult,
  PublicationRow,
  VerifiedConnection,
} from './types.js';

const API = 'https://api.vk.com/method';
const VERSION = '5.199';

interface VkErrorResponse {
  error?: { error_code?: number; error_msg?: string };
}

interface VkGroup {
  id: number;
  name?: string;
  screen_name?: string;
  description?: string;
  members_count?: number;
  photo_200?: string;
}

interface VkStatsRow {
  period?: number;
  visitors?: { total?: number } | number;
  reach?: { total?: number } | number;
  views?: { total?: number } | number;
}

interface VkWallPost {
  id: number;
  owner_id: number;
  date?: number;
  text?: string;
  likes?: { count?: number };
  comments?: { count?: number };
  reposts?: { count?: number };
  views?: { count?: number };
  attachments?: Array<{
    type?: string;
    photo?: { sizes?: Array<{ url?: string; width?: number }> };
  }>;
}

function tokenOf(context: PlatformContext): string {
  const token =
    context.credential['token'] ?? context.credential['access_token'];
  if (typeof token !== 'string' || token.length < 10) {
    throw new AppError(400, 'invalid_credential', 'Не указан access token VK');
  }
  return token;
}

function groupIdOf(context: PlatformContext): string {
  const raw =
    context.metadata['group_id'] ??
    context.credential['group_id'] ??
    context.platformId;
  const cleaned = String(raw ?? '')
    .trim()
    .replace(/^-/, '')
    .replace(/^club/, '');
  if (!/^\d+$/.test(cleaned)) {
    throw new AppError(
      400,
      'group_id_required',
      'Для VK укажите числовой group_id сообщества.',
    );
  }
  return cleaned;
}

async function vkCall<T>(
  method: string,
  params: Record<string, string | number>,
  token: string,
  fetchImpl: FetchLike,
): Promise<T> {
  const search = new URLSearchParams({
    ...Object.fromEntries(
      Object.entries(params).map(([key, value]) => [key, String(value)]),
    ),
    access_token: token,
    v: VERSION,
  });
  const body = await fetchJson<T & VkErrorResponse>(
    fetchImpl,
    `${API}/${method}?${search.toString()}`,
  );
  if (body.error) {
    throw new AppError(
      502,
      'vk_error',
      `VK API: ${body.error.error_msg ?? 'неизвестная ошибка'} ` +
        `(${body.error.error_code ?? '?'})`,
    );
  }
  return body as T;
}

function groupPatch(group: VkGroup) {
  return {
    platformId: String(group.id),
    name: group.name,
    description: group.description,
    avatarUrl: group.photo_200,
    subscriberCount: group.members_count,
  };
}

export async function verifyVk(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<VerifiedConnection> {
  const token = tokenOf(context);
  const groupId = groupIdOf(context);
  const response = await vkCall<{ response?: VkGroup[] }>(
    'groups.getById',
    { group_id: groupId, fields: 'members_count,description,photo_200' },
    token,
    fetchImpl,
  );
  const group = response.response?.[0];
  if (!group) {
    throw new AppError(404, 'group_not_found', 'Сообщество VK не найдено');
  }
  return {
    metadata: {
      group_id: String(group.id),
      platform_id: String(group.id),
      name: group.name,
      screen_name: group.screen_name,
    },
    channel: groupPatch(group),
  };
}

export async function syncVk(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<PlatformSyncResult> {
  const token = tokenOf(context);
  const groupId = groupIdOf(context);
  const warnings: string[] = [];
  const metrics: PlatformSyncResult['metrics'] = [];

  const groupResponse = await vkCall<{ response?: VkGroup[] }>(
    'groups.getById',
    { group_id: groupId, fields: 'members_count,description,photo_200' },
    token,
    fetchImpl,
  );
  const group = groupResponse.response?.[0];
  if (!group) {
    throw new AppError(404, 'group_not_found', 'Сообщество VK не найдено');
  }
  const today = isoDate(new Date());
  if (group.members_count !== undefined) {
    metrics.push({ metric: 'followers', value: group.members_count, date: today });
  }

  try {
    const stats = await vkCall<{ response?: VkStatsRow[] }>(
      'stats.get',
      { group_id: groupId, interval: 'day', intervals_count: 30 },
      token,
      fetchImpl,
    );
    for (const row of stats.response ?? []) {
      if (!row.period) continue;
      const date = isoDate(new Date(row.period * 1000));
      const views =
        typeof row.views === 'number' ? row.views : row.views?.total;
      const reach =
        typeof row.reach === 'number' ? row.reach : row.reach?.total;
      if (views !== undefined) {
        metrics.push({ metric: 'views', value: safeInt(views), date });
      }
      if (reach !== undefined) {
        metrics.push({ metric: 'reach', value: safeInt(reach), date });
      }
    }
  } catch (error) {
    warnings.push(
      `Статистика VK недоступна (нужен токен администратора с правами stats): ` +
        String(error).slice(0, 160),
    );
  }

  let publications: PublicationRow[] = [];
  try {
    const wall = await vkCall<{ response?: { items?: VkWallPost[] } }>(
      'wall.get',
      { owner_id: `-${groupId}`, count: 10, filter: 'owner' },
      token,
      fetchImpl,
    );
    publications = (wall.response?.items ?? []).map((post) => {
      const photo = post.attachments?.find((item) => item.type === 'photo');
      const sizes = photo?.photo?.sizes ?? [];
      const image = [...sizes].sort(
        (left, right) => safeNumber(right.width) - safeNumber(left.width),
      )[0]?.url;
      const text = post.text?.trim() ?? '';
      return {
        platformPostId: `${post.owner_id}_${post.id}`,
        title: text ? text.split('\n')[0]!.slice(0, 120) : 'Пост VK',
        content: text || undefined,
        imageUrl: image,
        url: `https://vk.com/wall${post.owner_id}_${post.id}`,
        type: 'post' as const,
        publishedAt: post.date
          ? new Date(post.date * 1000).toISOString()
          : new Date().toISOString(),
        stats: {
          views: safeInt(post.views?.count),
          likes: safeInt(post.likes?.count),
          comments: safeInt(post.comments?.count),
          shares: safeInt(post.reposts?.count),
        },
      };
    });
  } catch (error) {
    warnings.push(
      `Публикации VK не загружены: ${String(error).slice(0, 160)}`,
    );
  }

  return {
    metrics,
    publications,
    channel: groupPatch(group),
    message: `VK: ${metrics.length} метрик, ${publications.length} публикаций.`,
    warnings,
  };
}
