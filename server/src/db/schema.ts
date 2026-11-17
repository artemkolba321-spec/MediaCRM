import {
  index,
  integer,
  jsonb,
  pgTable,
  primaryKey,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

/**
 * Users are owned by this backend. Password hashes use scrypt with a random
 * per-user salt; plaintext passwords are never stored or logged.
 */
export const users = pgTable(
  'users',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    email: varchar('email', { length: 320 }).notNull(),
    passwordHash: text('password_hash').notNull(),
    displayName: varchar('display_name', { length: 120 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [uniqueIndex('users_email_unique').on(table.email)],
);

/**
 * Refresh tokens are stored as SHA-256 hashes. Rotation happens on every
 * refresh; a stolen old token cannot be reused.
 */
export const sessions = pgTable(
  'sessions',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tokenHash: varchar('token_hash', { length: 64 }).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    uniqueIndex('sessions_token_hash_unique').on(table.tokenHash),
    index('sessions_user_idx').on(table.userId),
    index('sessions_expiry_idx').on(table.expiresAt),
  ],
);

export const passwordResetTokens = pgTable(
  'password_reset_tokens',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    tokenHash: varchar('token_hash', { length: 64 }).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    usedAt: timestamp('used_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    uniqueIndex('password_reset_token_unique').on(table.tokenHash),
    index('password_reset_user_idx').on(table.userId),
  ],
);

/**
 * One row per authenticated push request. The primary key makes retries
 * idempotent: a repeated request never applies the same changes twice.
 */
export const syncRequests = pgTable(
  'sync_requests',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    requestId: varchar('request_id', { length: 64 }).notNull(),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.requestId] }),
    index('sync_requests_created_idx').on(table.createdAt),
  ],
);

/**
 * The offline-first document store. Every local collection is persisted as a
 * JSONB document. This keeps the schema stable while the client evolves,
 * supports one ordered incremental pull query for all collections, and avoids
 * 20+ round trips per sync.
 *
 * - entity_updated_at is the client's logical timestamp (last-write-wins).
 * - updated_at is the server receipt time and is used for pull cursors, so a
 *   skewed device clock cannot make records invisible to other devices.
 * - deleted_at is a tombstone; payload is retained so a delete can be undone
 *   and so operators can audit what was removed.
 */
export const records = pgTable(
  'records',
  {
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    collection: varchar('collection', { length: 40 }).notNull(),
    entityId: varchar('entity_id', { length: 64 }).notNull(),
    payload: jsonb('payload')
      .$type<Record<string, unknown>>()
      .notNull()
      .default({}),
    entityUpdatedAt: timestamp('entity_updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .notNull()
      .defaultNow(),
    deletedAt: timestamp('deleted_at', { withTimezone: true }),
    version: integer('version').notNull().default(1),
  },
  (table) => [
    primaryKey({ columns: [table.userId, table.collection, table.entityId] }),
    index('records_pull_idx').on(
      table.userId,
      table.updatedAt,
      table.collection,
      table.entityId,
    ),
    index('records_collection_idx').on(
      table.userId,
      table.collection,
      table.updatedAt,
    ),
  ],
);

/**
 * Platform OAuth/API credentials never reach the Flutter client. Tokens are
 * encrypted with AES-256-GCM using CREDENTIALS_KEY before insertion.
 */
export const platformConnections = pgTable(
  'platform_connections',
  {
    id: uuid('id').defaultRandom().primaryKey(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    channelId: varchar('channel_id', { length: 64 }).notNull(),
    platform: varchar('platform', { length: 20 }).notNull(),
    authMethod: varchar('auth_method', { length: 20 }).notNull(),
    credentialCiphertext: text('credential_ciphertext').notNull(),
    credentialIv: varchar('credential_iv', { length: 32 }).notNull(),
    credentialTag: varchar('credential_tag', { length: 32 }).notNull(),
    metadata: jsonb('metadata')
      .$type<Record<string, unknown>>()
      .notNull()
      .default({}),
    expiresAt: timestamp('expires_at', { withTimezone: true }),
    createdAt: timestamp('created_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
    updatedAt: timestamp('updated_at', { withTimezone: true })
      .defaultNow()
      .notNull(),
  },
  (table) => [
    uniqueIndex('platform_connections_user_channel_unique').on(
      table.userId,
      table.channelId,
    ),
    index('platform_connections_user_idx').on(table.userId),
  ],
);

export type UserRow = typeof users.$inferSelect;
export type RecordRow = typeof records.$inferSelect;
export type PlatformConnectionRow = typeof platformConnections.$inferSelect;
