import { sql } from 'drizzle-orm';

import { db } from '../db/index.js';
import { records } from '../db/schema.js';

export interface GeneratedRecord {
  collection: string;
  entityId: string;
  payload: Record<string, unknown>;
  entityUpdatedAt?: Date;
}

/**
 * Writes server-generated records in chunks. The `WHERE payload IS DISTINCT
 * FROM excluded.payload` clause prevents a pull cursor from moving when a
 * platform returns the same data again, which keeps clients from downloading
 * unchanged rows.
 */
export async function writeGeneratedRecords(
  userId: string,
  entries: GeneratedRecord[],
): Promise<void> {
  for (let index = 0; index < entries.length; index += 100) {
    const chunk = entries.slice(index, index + 100);
    if (chunk.length === 0) continue;
    await db
      .insert(records)
      .values(
        chunk.map((entry) => ({
          userId,
          collection: entry.collection,
          entityId: entry.entityId,
          payload: entry.payload,
          entityUpdatedAt: entry.entityUpdatedAt ?? new Date(),
          updatedAt: new Date(),
          deletedAt: null,
          version: 1,
        })),
      )
      .onConflictDoUpdate({
        target: [records.userId, records.collection, records.entityId],
        set: {
          payload: sql`excluded.payload`,
          entityUpdatedAt: sql`excluded.entity_updated_at`,
          updatedAt: new Date(),
          deletedAt: null,
          version: sql`${records.version} + 1`,
        },
        setWhere: sql`${records.payload} IS DISTINCT FROM excluded.payload`,
      });
  }
}
