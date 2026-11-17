import { AppError } from '../lib/errors.js';
import { isoDate } from '../lib/records.js';
import { fetchJson, query } from './http.js';
import type {
  FetchLike,
  PlatformContext,
  PlatformSyncResult,
  VerifiedConnection,
} from './types.js';

const API = 'https://api.telegram.org';

interface TelegramChat {
  id: number | string;
  title?: string;
  username?: string;
  description?: string;
  type?: string;
}

function tokenOf(context: PlatformContext): string {
  const token = context.credential['token'] ?? context.credential['bot_token'];
  if (typeof token !== 'string' || token.length < 20) {
    throw new AppError(400, 'invalid_credential', 'Не указан токен бота Telegram');
  }
  return token;
}

function chatIdOf(context: PlatformContext): string {
  const chatId =
    context.metadata['chat_id'] ??
    context.credential['chat_id'] ??
    context.platformId;
  if (chatId === undefined || chatId === null || String(chatId).trim() === '') {
    throw new AppError(
      400,
      'chat_id_required',
      'Для Telegram укажите chat_id канала (например, -1001234567890).',
    );
  }
  return String(chatId).trim();
}

async function call<T>(
  token: string,
  method: string,
  params: Record<string, string | number>,
  fetchImpl: FetchLike,
): Promise<T> {
  const response = await fetchJson<{
    ok?: boolean;
    result?: T;
    description?: string;
  }>(fetchImpl, `${API}/bot${token}/${method}?${query(params)}`);
  if (!response.ok || response.result === undefined) {
    throw new AppError(
      502,
      'telegram_error',
      `Telegram Bot API: ${response.description ?? 'неизвестная ошибка'}`,
    );
  }
  return response.result;
}

export async function verifyTelegram(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<VerifiedConnection> {
  const token = tokenOf(context);
  const chatId = chatIdOf(context);
  const chat = await call<TelegramChat>(
    token,
    'getChat',
    { chat_id: chatId },
    fetchImpl,
  );
  let members: number | undefined;
  try {
    members = await call<number>(
      token,
      'getChatMemberCount',
      { chat_id: chatId },
      fetchImpl,
    );
  } catch {
    // Some private channels do not expose the member count to non-admin bots.
  }
  return {
    metadata: {
      chat_id: chatId,
      platform_id: String(chat.id),
      name: chat.title ?? 'Telegram',
      description: chat.description,
      username: chat.username,
    },
    channel: {
      platformId: String(chat.id),
      name: chat.title,
      description: chat.description,
      subscriberCount: members,
    },
  };
}

export async function syncTelegram(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<PlatformSyncResult> {
  const token = tokenOf(context);
  const chatId = chatIdOf(context);
  const chat = await call<TelegramChat>(
    token,
    'getChat',
    { chat_id: chatId },
    fetchImpl,
  );
  const warnings: string[] = [];
  let members = 0;
  try {
    members = await call<number>(
      token,
      'getChatMemberCount',
      { chat_id: chatId },
      fetchImpl,
    );
  } catch {
    warnings.push(
      'Bot API не отдал число участников: добавьте бота администратором канала.',
    );
  }
  const metrics: PlatformSyncResult['metrics'] = members
    ? [{ metric: 'followers', value: members, date: isoDate(new Date()) }]
    : [];
  if (metrics.length === 0) {
    warnings.push(
      'Исторические метрики недоступны: Telegram Bot API не предоставляет ' +
        'историю подписчиков и просмотры постов.',
    );
  }
  return {
    metrics,
    publications: [],
    channel: {
      platformId: String(chat.id),
      name: chat.title,
      description: chat.description,
      subscriberCount: members || undefined,
    },
    message: `Telegram: ${members ? `${members} участников` : 'данные ограничены'}.`,
    warnings,
  };
}
