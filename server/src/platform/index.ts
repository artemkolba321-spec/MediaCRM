import { AppError } from '../lib/errors.js';
import { isoDate, stableUuid } from '../lib/records.js';
import { syncGitHub, verifyGitHub } from './github.js';
import { syncTelegram, verifyTelegram } from './telegram.js';
import type {
  ChannelPatch,
  FetchLike,
  PlatformContext,
  PlatformName,
  PlatformSyncResult,
  VerifiedConnection,
} from './types.js';
import { syncVk, verifyVk } from './vk.js';
import { syncYouTube, verifyYouTube } from './youtube.js';
import type { GeneratedRecord } from './store.js';

export function isPlatformName(value: string): value is PlatformName {
  return ['youtube', 'telegram', 'vk', 'github'].includes(value);
}

export async function verifyConnection(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<VerifiedConnection> {
  switch (context.platform) {
    case 'youtube':
      return verifyYouTube(context, fetchImpl);
    case 'telegram':
      return verifyTelegram(context, fetchImpl);
    case 'vk':
      return verifyVk(context, fetchImpl);
    case 'github':
      return verifyGitHub(context, fetchImpl);
  }
}

export async function syncPlatform(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<PlatformSyncResult> {
  switch (context.platform) {
    case 'youtube':
      return syncYouTube(context, fetchImpl);
    case 'telegram':
      return syncTelegram(context, fetchImpl);
    case 'vk':
      return syncVk(context, fetchImpl);
    case 'github':
      return syncGitHub(context, fetchImpl);
  }
}

export function buildGeneratedRecords(
  context: PlatformContext,
  result: PlatformSyncResult,
  now = new Date(),
): GeneratedRecord[] {
  const recordsOut: GeneratedRecord[] = [];
  const today = isoDate(now);
  const stableTimestamp = (date: string) => `${date}T00:00:00.000Z`;

  for (const metric of result.metrics) {
    if (!Number.isFinite(metric.value)) continue;
    const id = stableUuid(
      `snapshot|${context.channelId}|${metric.metric}|${metric.date}|api`,
    );
    recordsOut.push({
      collection: 'snapshots',
      entityId: id,
      payload: {
        id,
        user_id: context.userId,
        channel_id: context.channelId,
        platform: context.platform,
        metric: metric.metric,
        value: metric.value,
        date: metric.date,
        source: 'api',
        reliability: 'verified',
        recorded_at: stableTimestamp(metric.date),
      },
      entityUpdatedAt: now,
    });
  }

  for (const publication of result.publications) {
    const id = stableUuid(
      `publication|${context.channelId}|${publication.platformPostId}`,
    );
    const createdAt = publication.publishedAt;
    recordsOut.push({
      collection: 'publications',
      entityId: id,
      payload: {
        id,
        user_id: context.userId,
        platform: context.platform,
        channel_id: context.channelId,
        platform_post_id: publication.platformPostId,
        title: publication.title,
        content: publication.content ?? null,
        image_url: publication.imageUrl ?? null,
        url: publication.url ?? null,
        type: publication.type,
        published_at: publication.publishedAt,
        created_at: createdAt,
        updated_at: createdAt,
      },
      entityUpdatedAt: now,
    });

    if (publication.stats) {
      const statsId = stableUuid(`publication_stats|${id}|${today}`);
      recordsOut.push({
        collection: 'publication_stats',
        entityId: statsId,
        payload: {
          id: statsId,
          user_id: context.userId,
          publication_id: id,
          views: publication.stats.views ?? 0,
          likes: publication.stats.likes ?? 0,
          comments: publication.stats.comments ?? 0,
          shares: publication.stats.shares ?? 0,
          reach: publication.stats.reach ?? null,
          impressions: publication.stats.impressions ?? null,
          source: 'api',
          recorded_at: stableTimestamp(today),
        },
        entityUpdatedAt: now,
      });
    }
  }

  return recordsOut;
}

export function normalizeChannelPatch(
  channel: ChannelPatch,
): Record<string, unknown> {
  return {
    platform_id: channel.platformId ?? null,
    name: channel.name ?? null,
    description: channel.description ?? null,
    avatar_url: channel.avatarUrl ?? null,
    subscriber_count: channel.subscriberCount ?? null,
  };
}

export function assertAutomaticPlatform(platform: string): PlatformName {
  if (platform === 'boosty') {
    throw new AppError(
      400,
      'manual_only',
      'У Boosty нет публичного API. Используйте ручной импорт данных.',
    );
  }
  if (!isPlatformName(platform)) {
    throw new AppError(400, 'unknown_platform', `Неизвестная площадка: ${platform}`);
  }
  return platform;
}

export type { PlatformContext, PlatformSyncResult, GeneratedRecord };
