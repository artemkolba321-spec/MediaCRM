import { env } from '../config.js';
import { AppError } from '../lib/errors.js';
import { daysAgo, isoDate, safeInt } from '../lib/records.js';
import { fetchJson, query } from './http.js';
import type {
  FetchLike,
  PlatformContext,
  PlatformSyncResult,
  VerifiedConnection,
} from './types.js';

const DATA_API = 'https://www.googleapis.com/youtube/v3';
const ANALYTICS_API = 'https://youtubeanalytics.googleapis.com/v2/reports';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

interface GoogleCredential {
  access_token?: string;
  token?: string;
  refresh_token?: string;
  expires_at?: string;
  scope?: string;
}

interface YouTubeChannelItem {
  id: string;
  snippet?: {
    title?: string;
    description?: string;
    thumbnails?: Record<string, { url?: string }>;
  };
  statistics?: {
    subscriberCount?: string;
    viewCount?: string;
    videoCount?: string;
  };
  contentDetails?: {
    relatedPlaylists?: { uploads?: string };
  };
}

interface ChannelListResponse {
  items?: YouTubeChannelItem[];
}

interface AnalyticsResponse {
  columnHeaders?: Array<{ name?: string }>;
  rows?: Array<Array<string | number>>;
}

function credentialOf(context: PlatformContext): GoogleCredential {
  return context.credential as GoogleCredential;
}

function expiresSoon(value: unknown): boolean {
  if (typeof value !== 'string' || !value) return false;
  const time = Date.parse(value);
  return Number.isFinite(time) && time <= Date.now() + 90_000;
}

async function freshCredential(
  context: PlatformContext,
  fetchImpl: FetchLike,
): Promise<{ credential: GoogleCredential; update?: GoogleCredential }> {
  const credential = credentialOf(context);
  const access = credential.access_token ?? credential.token;
  if (access && !expiresSoon(credential.expires_at)) {
    return { credential };
  }
  if (!credential.refresh_token) {
    if (access && (!credential.expires_at || !expiresSoon(credential.expires_at))) {
      return { credential };
    }
    throw new AppError(
      401,
      'oauth_expired',
      'OAuth-токен YouTube истёк. Подключите канал заново.',
    );
  }
  if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) {
    throw new AppError(
      503,
      'oauth_not_configured',
      'На сервере не настроены GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET.',
    );
  }
  const body = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    client_secret: env.GOOGLE_CLIENT_SECRET,
    refresh_token: credential.refresh_token,
    grant_type: 'refresh_token',
  });
  const refreshed = await fetchJson<{
    access_token?: string;
    expires_in?: number;
    refresh_token?: string;
    scope?: string;
  }>(fetchImpl, TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!refreshed.access_token) {
    throw new AppError(502, 'oauth_refresh_failed', 'Google не вернул access token');
  }
  const update: GoogleCredential = {
    ...credential,
    access_token: refreshed.access_token,
    expires_at: new Date(
      Date.now() + safeInt(refreshed.expires_in, 3600) * 1000,
    ).toISOString(),
    refresh_token: refreshed.refresh_token ?? credential.refresh_token,
    scope: refreshed.scope ?? credential.scope,
  };
  return { credential: update, update };
}

async function loadChannel(
  context: PlatformContext,
  credential: GoogleCredential,
  fetchImpl: FetchLike,
): Promise<YouTubeChannelItem> {
  const access = credential.access_token ?? credential.token;
  const params: Record<string, string> = {
    part: 'snippet,statistics,contentDetails',
  };
  if (context.platformId) {
    params['id'] = context.platformId;
  } else if (context.metadata['platform_id']) {
    params['id'] = String(context.metadata['platform_id']);
  } else {
    params['mine'] = 'true';
  }
  const response = await fetchJson<ChannelListResponse>(
    fetchImpl,
    `${DATA_API}/channels?${query(params)}`,
    { headers: { authorization: `Bearer ${access}` } },
  );
  const item = response.items?.[0];
  if (!item) {
    throw new AppError(
      404,
      'channel_not_found',
      'YouTube-канал не найден или у токена нет доступа к нему.',
    );
  }
  return item;
}

function channelPatch(item: YouTubeChannelItem) {
  return {
    platformId: item.id,
    name: item.snippet?.title,
    description: item.snippet?.description,
    avatarUrl:
      item.snippet?.thumbnails?.['high']?.url ??
      item.snippet?.thumbnails?.['default']?.url,
    subscriberCount: safeInt(item.statistics?.subscriberCount),
  };
}

async function loadPublications(
  context: PlatformContext,
  item: YouTubeChannelItem,
  credential: GoogleCredential,
  fetchImpl: FetchLike,
): Promise<PlatformSyncResult['publications']> {
  const uploads = item.contentDetails?.relatedPlaylists?.uploads;
  if (!uploads) return [];
  const access = credential.access_token ?? credential.token;
  const playlist = await fetchJson<{
    items?: Array<{
      contentDetails?: { videoId?: string };
    }>;
  }>(
    fetchImpl,
    `${DATA_API}/playlistItems?${query({
      part: 'contentDetails',
      playlistId: uploads,
      maxResults: 10,
    })}`,
    { headers: { authorization: `Bearer ${access}` } },
  );
  const ids = (playlist.items ?? [])
    .map((row) => row.contentDetails?.videoId)
    .filter((id): id is string => Boolean(id));
  if (ids.length === 0) return [];
  const videos = await fetchJson<{
    items?: Array<{
      id: string;
      snippet?: {
        title?: string;
        description?: string;
        publishedAt?: string;
        thumbnails?: Record<string, { url?: string }>;
      };
      statistics?: {
        viewCount?: string;
        likeCount?: string;
        commentCount?: string;
      };
    }>;
  }>(
    fetchImpl,
    `${DATA_API}/videos?${query({
      part: 'snippet,statistics',
      id: ids.join(','),
    })}`,
    { headers: { authorization: `Bearer ${access}` } },
  );
  return (videos.items ?? []).map((video) => ({
    platformPostId: video.id,
    title: video.snippet?.title ?? 'Без названия',
    content: video.snippet?.description,
    imageUrl:
      video.snippet?.thumbnails?.['high']?.url ??
      video.snippet?.thumbnails?.['default']?.url,
    url: `https://www.youtube.com/watch?v=${video.id}`,
    type: 'video' as const,
    publishedAt:
      video.snippet?.publishedAt ?? new Date().toISOString(),
    stats: {
      views: safeInt(video.statistics?.viewCount),
      likes: safeInt(video.statistics?.likeCount),
      comments: safeInt(video.statistics?.commentCount),
    },
  }));
}

export async function verifyYouTube(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<VerifiedConnection> {
  const fresh = await freshCredential(context, fetchImpl);
  const item = await loadChannel(context, fresh.credential, fetchImpl);
  return {
    metadata: {
      platform_id: item.id,
      name: item.snippet?.title ?? 'YouTube',
      avatar_url: channelPatch(item).avatarUrl,
    },
    channel: channelPatch(item),
    credentialUpdate: fresh.update ? { ...fresh.update } : undefined,
  };
}

export async function syncYouTube(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<PlatformSyncResult> {
  const fresh = await freshCredential(context, fetchImpl);
  const credential = fresh.credential;
  const item = await loadChannel(context, credential, fetchImpl);
  const today = isoDate(new Date());
  const metrics: PlatformSyncResult['metrics'] = [
    {
      metric: 'followers',
      value: safeInt(item.statistics?.subscriberCount),
      date: today,
    },
  ];
  const warnings: string[] = [];
  const access = credential.access_token ?? credential.token;

  try {
    const end = daysAgo(2);
    const start = daysAgo(29);
    const analytics = await fetchJson<AnalyticsResponse>(
      fetchImpl,
      `${ANALYTICS_API}?${query({
        ids: 'channel==MINE',
        startDate: isoDate(start),
        endDate: isoDate(end),
        metrics:
          'views,likes,comments,shares,subscribersGained,subscribersLost',
        dimensions: 'day',
        sort: 'day',
      })}`,
      { headers: { authorization: `Bearer ${access}` } },
    );
    const names =
      analytics.columnHeaders?.map((header) =>
        String(header.name ?? '').toLowerCase(),
      ) ?? [];
    const index = (name: string) => names.indexOf(name);
    for (const row of analytics.rows ?? []) {
      const date = String(row[index('day')] ?? '');
      if (!date) continue;
      const values: Array<[string, number]> = [
        ['views', safeInt(row[index('views')])],
        ['likes', safeInt(row[index('likes')])],
        ['comments', safeInt(row[index('comments')])],
        ['shares', safeInt(row[index('shares')])],
        ['followers_gained', safeInt(row[index('subscribersgained')])],
        ['followers_lost', safeInt(row[index('subscriberslost')])],
      ];
      for (const [metric, value] of values) {
        metrics.push({ metric, value, date });
      }
    }
    if (!analytics.rows || analytics.rows.length === 0) {
      warnings.push(
        'YouTube Analytics не вернул строк за последние 28 дней. ' +
          'Исторические метрики не создаются.',
      );
    }
  } catch (error) {
    const text = String(error);
    if (text.includes('403') || text.includes('401')) {
      warnings.push(
        'YouTube Analytics недоступен для этого токена (нет scope ' +
          'yt-analytics.readonly или прав владельца). Записаны только ' +
          'подписчики и публикации из Data API.',
      );
    } else {
      throw error;
    }
  }

  const publications = await loadPublications(
    context,
    item,
    credential,
    fetchImpl,
  ).catch((error) => {
    warnings.push(`Публикации YouTube не загружены: ${String(error).slice(0, 180)}`);
    return [];
  });

  return {
    metrics,
    publications,
    channel: channelPatch(item),
    message: `YouTube: ${metrics.length} метрик, ${publications.length} публикаций.`,
    warnings,
    credentialUpdate: fresh.update ? { ...fresh.update } : undefined,
  };
}
