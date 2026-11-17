import { neon } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';
import { sql } from 'drizzle-orm';

import { env } from '../config.js';
import * as schema from './schema.js';

/**
 * Neon's HTTP driver is used instead of a persistent TCP pool. Each query is a
 * short HTTPS request, connections are managed by Neon, and the process never
 * holds an idle database connection. This is the lowest-overhead option for a
 * small API and works with Neon's pooled connection string.
 */
const client = neon(env.DATABASE_URL);

export const db = drizzle({ client, schema });

export type Database = typeof db;

/** Drizzle's neon-http execute result exposes rows at runtime. */
export async function rawRows<T>(
  query: Parameters<typeof db.execute>[0],
): Promise<T[]> {
  const result = (await db.execute(query)) as unknown as { rows?: T[] };
  return result.rows ?? [];
}

/**
 * Housekeeping is deliberately not a background timer. It runs at most once
 * per day, triggered by a push request, and deletes only expired auth rows and
 * old idempotency keys. User data is never deleted.
 */
let lastMaintenanceAt = 0;

export async function runMaintenanceIfDue(): Promise<void> {
  const now = Date.now();
  if (lastMaintenanceAt > 0 && now - lastMaintenanceAt < 86_400_000) return;
  lastMaintenanceAt = now;
  await db.execute(sql`
    DELETE FROM sessions
    WHERE expires_at < now() - interval '7 days'
  `);
  await db.execute(sql`
    DELETE FROM password_reset_tokens
    WHERE created_at < now() - interval '2 days'
  `);
  await db.execute(sql`
    DELETE FROM sync_requests
    WHERE created_at < now() - interval '7 days'
  `);
}
