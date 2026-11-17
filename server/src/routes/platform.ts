import { and, eq } from 'drizzle-orm';
import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';

import { decryptCredential, encryptCredential } from '../auth/crypto.js';
import { requireAuth } from '../auth/middleware.js';
import { signOAuthState, verifyOAuthState } from '../auth/tokens.js';
import { env } from '../config.js';
import { db } from '../db/index.js';
import { platformConnections } from '../db/schema.js';
import { AppError, badRequest } from '../lib/errors.js';
import { ENTITY_ID_RE, isPlainObject } from '../lib/records.js';
import {
  assertAutomaticPlatform,
  buildGeneratedRecords,
  isPlatformName,
  syncPlatform,
  verifyConnection,
} from '../platform/index.js';
import { fetchJson } from '../platform/http.js';
import { writeGeneratedRecords } from '../platform/store.js';
import type { PlatformContext, PlatformName } from '../platform/types.js';

const platformSchema = z.enum(['youtube', 'telegram', 'vk', 'github', 'boosty']);

const connectSchema = z.object({
  channel_id: z.string().max(64),
  platform: platformSchema,
  credential: z.string().min(1).max(4096),
  auth_method: z.string().max(20).default('accessToken'),
  extra: z.record(z.string(), z.unknown()).default({}),
});

const channelSchema = z.object({
  channel_id: z.string().max(64),
});

const oauthStartSchema = z.object({
  channel_id: z.string().max(64),
  platform: platformSchema,
});

const syncSchema = z.object({
  channel_id: z.string().max(64),
  platform: platformSchema.optional(),
  last_sync_at: z.string().max(40).optional(),
});

function validateChannelId(channelId: string): void {
  if (!ENTITY_ID_RE.test(channelId)) {
    throw badRequest('Некорректный channel_id');
  }
}

function oauthRedirectUri(): string {
  return `${env.PUBLIC_API_URL.replace(/\/$/, '')}/v1/platform/oauth/callback`;
}

async function loadConnection(userId: string, channelId: string) {
  const rows = await db
    .select()
    .from(platformConnections)
    .where(
      and(
        eq(platformConnections.userId, userId),
        eq(platformConnections.channelId, channelId),
      ),
    )
    .limit(1);
  return rows[0] ?? null;
}

async function saveConnection(options: {
  userId: string;
  channelId: string;
  platform: PlatformName;
  authMethod: string;
  credential: Record<string, unknown>;
  metadata: Record<string, unknown>;
  expiresAt?: Date | null;
}): Promise<void> {
  const encrypted = encryptCredential(options.credential);
  await db
    .insert(platformConnections)
    .values({
      userId: options.userId,
      channelId: options.channelId,
      platform: options.platform,
      authMethod: options.authMethod,
      credentialCiphertext: encrypted.ciphertext,
      credentialIv: encrypted.iv,
      credentialTag: encrypted.tag,
      metadata: options.metadata,
      expiresAt: options.expiresAt ?? null,
      updatedAt: new Date(),
    })
    .onConflictDoUpdate({
      target: [
        platformConnections.userId,
        platformConnections.channelId,
      ],
      set: {
        platform: options.platform,
        authMethod: options.authMethod,
        credentialCiphertext: encrypted.ciphertext,
        credentialIv: encrypted.iv,
        credentialTag: encrypted.tag,
        metadata: options.metadata,
        expiresAt: options.expiresAt ?? null,
        updatedAt: new Date(),
      },
    });
}

function expiresAtOf(credential: Record<string, unknown>): Date | null {
  const raw = credential['expires_at'];
  if (typeof raw === 'string') {
    const time = Date.parse(raw);
    return Number.isFinite(time) ? new Date(time) : null;
  }
  return null;
}

function htmlPage(title: string, message: string): string {
  return [
    '<!doctype html><html lang="ru"><head><meta charset="utf-8">',
    `<title>${title}</title></head><body>`,
    `<h1>${title}</h1><p>${message}</p>`,
    '</body></html>',
  ].join('');
}

async function oauthCallback(
  request: FastifyRequest,
  reply: FastifyReply,
) {
  const query = z
    .object({
      code: z.string().max(2048).optional(),
      state: z.string().max(2048).optional(),
      error: z.string().max(200).optional(),
      error_description: z.string().max(500).optional(),
    })
    .parse(request.query ?? {});
  if (query.error) {
    reply
      .code(400)
      .type('text/html')
      .send(
        htmlPage(
          'Не удалось подключить',
          query.error_description ?? query.error,
        ),
      );
    return;
  }
  if (!query.code || !query.state) {
    reply
      .code(400)
      .type('text/html')
      .send(htmlPage('Не удалось подключить', 'OAuth-код не получен.'));
    return;
  }
  const state = verifyOAuthState(query.state);
  try {
    if (state.platform === 'youtube') {
      if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) {
        throw new AppError(503, 'oauth_not_configured', 'Google OAuth не настроен');
      }
      const token = await fetchJson<{
        access_token?: string;
        refresh_token?: string;
        expires_in?: number;
        scope?: string;
      }>(fetch, 'https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          client_id: env.GOOGLE_CLIENT_ID,
          client_secret: env.GOOGLE_CLIENT_SECRET,
          code: query.code,
          grant_type: 'authorization_code',
          redirect_uri: oauthRedirectUri(),
        }),
      });
      if (!token.access_token) {
        throw new AppError(502, 'oauth_failed', 'Google не вернул access token');
      }
      const credential: Record<string, unknown> = {
        access_token: token.access_token,
        refresh_token: token.refresh_token,
        expires_at: new Date(
          Date.now() + (token.expires_in ?? 3600) * 1000,
        ).toISOString(),
        scope: token.scope,
      };
      const channels = await fetchJson<{
        items?: Array<{
          id: string;
          snippet?: {
            title?: string;
            description?: string;
            thumbnails?: Record<string, { url?: string }>;
          };
          statistics?: { subscriberCount?: string };
        }>;
      }>(
        fetch,
        'https://www.googleapis.com/youtube/v3/channels?part=snippet,statistics&mine=true',
        { headers: { authorization: `Bearer ${token.access_token}` } },
      );
      const channel = channels.items?.[0];
      if (!channel) {
        throw new AppError(
          404,
          'channel_not_found',
          'У токена нет доступа ни к одному YouTube-каналу',
        );
      }
      await saveConnection({
        userId: state.sub,
        channelId: state.cid,
        platform: 'youtube',
        authMethod: 'oauth',
        credential,
        metadata: {
          platform_id: channel.id,
          name: channel.snippet?.title,
          avatar_url:
            channel.snippet?.thumbnails?.['high']?.url ??
            channel.snippet?.thumbnails?.['default']?.url,
          subscriber_count: Number(channel.statistics?.subscriberCount ?? 0),
        },
        expiresAt: expiresAtOf(credential),
      });
    } else if (state.platform === 'github') {
      if (!env.GITHUB_CLIENT_ID || !env.GITHUB_CLIENT_SECRET) {
        throw new AppError(503, 'oauth_not_configured', 'GitHub OAuth не настроен');
      }
      const token = await fetchJson<{ access_token?: string }>(
        fetch,
        'https://github.com/login/oauth/access_token',
        {
          method: 'POST',
          headers: { accept: 'application/json' },
          body: new URLSearchParams({
            client_id: env.GITHUB_CLIENT_ID,
            client_secret: env.GITHUB_CLIENT_SECRET,
            code: query.code,
            redirect_uri: oauthRedirectUri(),
          }),
        },
      );
      if (!token.access_token) {
        throw new AppError(502, 'oauth_failed', 'GitHub не вернул access token');
      }
      const user = await fetchJson<{
        login?: string;
        name?: string;
        bio?: string;
        avatar_url?: string;
        followers?: number;
      }>(fetch, 'https://api.github.com/user', {
        headers: {
          authorization: `Bearer ${token.access_token}`,
          accept: 'application/vnd.github+json',
          'user-agent': 'MediaCRM/2.0',
        },
      });
      const credential = { token: token.access_token };
      await saveConnection({
        userId: state.sub,
        channelId: state.cid,
        platform: 'github',
        authMethod: 'oauth',
        credential,
        metadata: {
          login: user.login,
          platform_id: user.login,
          name: user.name ?? user.login,
          avatar_url: user.avatar_url,
          subscriber_count: user.followers ?? 0,
        },
      });
    } else {
      throw new AppError(400, 'unsupported_oauth', 'OAuth не поддерживается');
    }
    reply
      .type('text/html')
      .send(
        htmlPage(
          'Готово',
          'Доступ сохранён на сервере. Вернитесь в MediaCRM и запустите синхронизацию.',
        ),
      );
  } catch (error) {
    const message =
      error instanceof AppError ? error.message : 'Внутренняя ошибка сервера';
    request.log.error(
      { error: String(error), userId: state.sub },
      'oauth callback failed',
    );
    reply
      .code(error instanceof AppError ? error.statusCode : 500)
      .type('text/html')
      .send(htmlPage('Не удалось подключить', message));
  }
}

export async function registerPlatformRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/v1/platform/connect',
    { preHandler: requireAuth },
    async (request) => {
      const body = connectSchema.parse(request.body ?? {});
      validateChannelId(body.channel_id);
      const platform = assertAutomaticPlatform(body.platform);
      const extra = isPlainObject(body.extra) ? body.extra : {};
      const credential: Record<string, unknown> =
        platform === 'youtube'
          ? { access_token: body.credential }
          : { token: body.credential };
      const metadata: Record<string, unknown> = {};
      if (platform === 'telegram') {
        if (extra['chat_id'] !== undefined) metadata['chat_id'] = extra['chat_id'];
      }
      if (platform === 'vk') {
        if (extra['group_id'] !== undefined) metadata['group_id'] = extra['group_id'];
      }
      if (platform === 'github') {
        if (extra['login'] !== undefined) metadata['login'] = extra['login'];
      }
      if (extra['platform_id'] !== undefined) {
        metadata['platform_id'] = extra['platform_id'];
      }
      const context: PlatformContext = {
        userId: request.userId,
        channelId: body.channel_id,
        platform,
        credential,
        metadata,
        platformId:
          typeof extra['platform_id'] === 'string'
            ? extra['platform_id']
            : undefined,
      };
      const verified = await verifyConnection(context);
      const finalCredential = verified.credentialUpdate ?? credential;
      await saveConnection({
        userId: request.userId,
        channelId: body.channel_id,
        platform,
        authMethod: body.auth_method,
        credential: finalCredential,
        metadata: { ...metadata, ...verified.metadata },
        expiresAt: expiresAtOf(finalCredential),
      });
      return {
        ok: true,
        account: {
          platform,
          name: verified.channel.name,
          platform_id: verified.channel.platformId,
          subscriber_count: verified.channel.subscriberCount,
          avatar_url: verified.channel.avatarUrl,
        },
      };
    },
  );

  app.post(
    '/v1/platform/disconnect',
    { preHandler: requireAuth },
    async (request) => {
      const body = channelSchema.parse(request.body ?? {});
      validateChannelId(body.channel_id);
      await db
        .delete(platformConnections)
        .where(
          and(
            eq(platformConnections.userId, request.userId),
            eq(platformConnections.channelId, body.channel_id),
          ),
        );
      return { ok: true };
    },
  );

  app.post(
    '/v1/platform/oauth/start',
    { preHandler: requireAuth },
    async (request) => {
      const body = oauthStartSchema.parse(request.body ?? {});
      validateChannelId(body.channel_id);
      const platform = assertAutomaticPlatform(body.platform);
      if (platform !== 'youtube' && platform !== 'github') {
        throw badRequest(
          'OAuth доступен для YouTube и GitHub. Для Telegram и VK используйте токен.',
        );
      }
      const state = signOAuthState(request.userId, body.channel_id, platform);
      const redirect = encodeURIComponent(oauthRedirectUri());
      let authUrl: string;
      if (platform === 'youtube') {
        if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) {
          throw new AppError(
            503,
            'oauth_not_configured',
            'На сервере не настроены GOOGLE_CLIENT_ID/GOOGLE_CLIENT_SECRET',
          );
        }
        authUrl =
          'https://accounts.google.com/o/oauth2/v2/auth?' +
          new URLSearchParams({
            client_id: env.GOOGLE_CLIENT_ID,
            redirect_uri: oauthRedirectUri(),
            response_type: 'code',
            scope:
              'https://www.googleapis.com/auth/youtube.readonly ' +
              'https://www.googleapis.com/auth/yt-analytics.readonly',
            access_type: 'offline',
            prompt: 'consent',
            include_granted_scopes: 'true',
            state,
          }).toString();
      } else {
        if (!env.GITHUB_CLIENT_ID || !env.GITHUB_CLIENT_SECRET) {
          throw new AppError(
            503,
            'oauth_not_configured',
            'На сервере не настроены GITHUB_CLIENT_ID/GITHUB_CLIENT_SECRET',
          );
        }
        authUrl =
          'https://github.com/login/oauth/authorize?' +
          new URLSearchParams({
            client_id: env.GITHUB_CLIENT_ID,
            redirect_uri: oauthRedirectUri(),
            scope: 'read:user',
            state,
          }).toString();
      }
      return { auth_url: authUrl, redirect_uri: redirect };
    },
  );

  app.get('/v1/platform/oauth/callback', oauthCallback);

  app.post(
    '/v1/platform/sync',
    {
      preHandler: requireAuth,
      config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    },
    async (request) => {
      const body = syncSchema.parse(request.body ?? {});
      validateChannelId(body.channel_id);
      const connection = await loadConnection(request.userId, body.channel_id);
      if (!connection) {
        throw new AppError(
          404,
          'connection_not_found',
          'Канал не подключён на сервере. Сохраните токен доступа заново.',
        );
      }
      if (!isPlatformName(connection.platform)) {
        throw new AppError(400, 'unknown_platform', 'Неизвестная площадка');
      }
      const credential = decryptCredential<Record<string, unknown>>({
        ciphertext: connection.credentialCiphertext,
        iv: connection.credentialIv,
        tag: connection.credentialTag,
      });
      if (
        body.platform !== undefined &&
        body.platform !== connection.platform
      ) {
        throw badRequest('Площадка канала не совпадает с сохранённым подключением');
      }
      const context: PlatformContext = {
        userId: request.userId,
        channelId: body.channel_id,
        platform: connection.platform,
        credential,
        metadata: connection.metadata,
        platformId:
          typeof connection.metadata['platform_id'] === 'string'
            ? connection.metadata['platform_id']
            : undefined,
        lastSyncAt: body.last_sync_at,
      };
      const result = await syncPlatform(context);
      const generated = buildGeneratedRecords(context, result);
      await writeGeneratedRecords(request.userId, generated);
      if (result.credentialUpdate) {
        const updated = result.credentialUpdate;
        await saveConnection({
          userId: request.userId,
          channelId: body.channel_id,
          platform: connection.platform,
          authMethod: connection.authMethod,
          credential: updated,
          metadata: {
            ...connection.metadata,
            platform_id:
              result.channel.platformId ?? connection.metadata['platform_id'],
            name: result.channel.name ?? connection.metadata['name'],
            avatar_url:
              result.channel.avatarUrl ?? connection.metadata['avatar_url'],
          },
          expiresAt: expiresAtOf(updated),
        });
      }
      return {
        ok: true,
        message: [result.message, ...result.warnings].join(' '),
        metrics_written: generated.filter((r) => r.collection === 'snapshots')
          .length,
        publications_written: generated.filter(
          (r) => r.collection === 'publications',
        ).length,
        warnings: result.warnings,
        channel_patch: {
          platform_id: result.channel.platformId ?? null,
          name: result.channel.name ?? null,
          description: result.channel.description ?? null,
          avatar_url: result.channel.avatarUrl ?? null,
          subscriber_count: result.channel.subscriberCount ?? null,
        },
      };
    },
  );
}
