export type PlatformName = 'youtube' | 'telegram' | 'vk' | 'github';

export interface PlatformContext {
  userId: string;
  channelId: string;
  platform: PlatformName;
  credential: Record<string, unknown>;
  metadata: Record<string, unknown>;
  platformId?: string;
  lastSyncAt?: string;
}

export interface MetricRow {
  metric: string;
  value: number;
  date: string;
}

export interface PublicationRow {
  platformPostId: string;
  title: string;
  content?: string;
  imageUrl?: string;
  url?: string;
  type: 'video' | 'post' | 'article' | 'release' | 'stream' | 'other';
  publishedAt: string;
  stats?: {
    views?: number;
    likes?: number;
    comments?: number;
    shares?: number;
    reach?: number;
    impressions?: number;
  };
}

export interface ChannelPatch {
  platformId?: string;
  name?: string;
  avatarUrl?: string;
  subscriberCount?: number;
  description?: string;
}

export interface PlatformSyncResult {
  metrics: MetricRow[];
  publications: PublicationRow[];
  channel: ChannelPatch;
  message: string;
  warnings: string[];
  credentialUpdate?: Record<string, unknown>;
}

export interface VerifiedConnection {
  metadata: Record<string, unknown>;
  channel: ChannelPatch;
  credentialUpdate?: Record<string, unknown>;
}

export type FetchLike = typeof fetch;
