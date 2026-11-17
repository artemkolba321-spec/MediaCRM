import { sql } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { requireAuth } from '../auth/middleware.js';
import { env } from '../config.js';
import { rawRows, runMaintenanceIfDue } from '../db/index.js';
import { badRequest } from '../lib/errors.js';
import { decodeCursor, encodeCursor, type PullCursor } from '../lib/cursor.js';
import {
  ENTITY_ID_RE,
  MAX_PAYLOAD_BYTES,
  isPlainObject,
  isValidCollection,
} from '../lib/records.js';

const changeSchema = z.object({
  collection: z.string().max(40),
  entity_id: z.string().max(64),
  operation: z.enum(['upsert', 'delete']),
  payload: z.record(z.string(), z.unknown()).optional(),
  updated_at: z.string().max(40).optional(),
});

const pushSchema = z.object({
  request_id: z.string().min(8).max(64),
  changes: z.array(changeSchema).min(1).max(env.MAX_PUSH_BATCH),
});

interface PushChange {
  collection: string;
  entity_id: string;
  operation: 'upsert' | 'delete';
  payload: Record<string, unknown> | null;
  entity_updated_at: string;
}

function normalizeChange(
  raw: z.infer<typeof changeSchema>,
  userId: string,
): PushChange {
  if (!isValidCollection(raw.collection)) {
    throw badRequest(`Неизвестная коллекция: ${raw.collection}`);
  }
  if (!ENTITY_ID_RE.test(raw.entity_id)) {
    throw badRequest('Некорректный идентификатор записи');
  }
  const payload = raw.payload === undefined ? null : raw.payload;
  if (payload !== null) {
    if (!isPlainObject(payload)) {
      throw badRequest('payload должен быть объектом');
    }
    const encoded = JSON.stringify(payload);
    if (Buffer.byteLength(encoded, 'utf8') > MAX_PAYLOAD_BYTES) {
      throw badRequest('Запись превышает допустимый размер 64 КБ');
    }
    const owner = payload['user_id'];
    if (owner !== undefined && owner !== userId) {
      throw badRequest('Запись принадлежит другому пользователю');
    }
    if (raw.collection !== 'currency_rates') {
      payload['user_id'] = userId;
    } else if (
      payload['code'] !== undefined &&
      payload['code'] !== raw.entity_id
    ) {
      throw badRequest('Код валюты не совпадает с идентификатором');
    } else {
      payload['code'] = raw.entity_id;
    }
  }

  // Clamp client clocks so a device set far in the future cannot permanently
  // win last-write-wins conflicts.
  const parsed = raw.updated_at ? Date.parse(raw.updated_at) : Number.NaN;
  const maxAllowed = Date.now() + 5 * 60_000;
  const timestamp = Number.isFinite(parsed)
    ? new Date(Math.min(Math.max(parsed, Date.parse('2000-01-01')), maxAllowed))
    : new Date();

  return {
    collection: raw.collection,
    entity_id: raw.entity_id,
    operation: raw.operation,
    payload,
    entity_updated_at: timestamp.toISOString(),
  };
}

function dedupe(changes: PushChange[]): PushChange[] {
  const byKey = new Map<string, PushChange>();
  for (const change of changes) {
    const key = `${change.collection}\u0000${change.entity_id}`;
    // A delete followed by an upsert in the same batch is represented by the
    // last operation. The client queue already coalesces this way.
    byKey.set(key, change);
  }
  return [...byKey.values()];
}

export async function registerSyncRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/v1/sync/push',
    {
      preHandler: requireAuth,
      config: { rateLimit: { max: 120, timeWindow: '1 minute' } },
    },
    async (request) => {
      const body = pushSchema.parse(request.body ?? {});
      const changes = dedupe(
        body.changes.map((change) => normalizeChange(change, request.userId)),
      );
      if (changes.length === 0) {
        return { ok: true, received: 0, applied: 0, duplicate: false };
      }

      // One statement: idempotency check, insert/upsert, and counters. Neon
      // HTTP executes it as a single transaction and a single network request.
      const rows = await rawRows<{
        applied_request: number;
        applied_count: number;
        received_count: number;
      }>(sql`
        WITH req AS (
          INSERT INTO sync_requests (user_id, request_id)
          VALUES (${request.userId}::uuid, ${body.request_id})
          ON CONFLICT (user_id, request_id) DO NOTHING
          RETURNING 1 AS inserted
        ),
        src AS (
          SELECT c.*
          FROM req,
               jsonb_to_recordset(${JSON.stringify(changes)}::jsonb) AS c(
                 collection text,
                 entity_id text,
                 operation text,
                 payload jsonb,
                 entity_updated_at timestamptz
               )
        ),
        applied AS (
          INSERT INTO records (
            user_id, collection, entity_id, payload,
            entity_updated_at, updated_at, deleted_at, version
          )
          SELECT
            ${request.userId}::uuid,
            s.collection,
            s.entity_id,
            COALESCE(s.payload, '{}'::jsonb),
            COALESCE(s.entity_updated_at, now()),
            now(),
            CASE WHEN s.operation = 'delete' THEN now() ELSE NULL END,
            1
          FROM src s
          ON CONFLICT (user_id, collection, entity_id) DO UPDATE SET
            payload = CASE
              WHEN EXCLUDED.deleted_at IS NOT NULL THEN records.payload
              ELSE EXCLUDED.payload
            END,
            deleted_at = EXCLUDED.deleted_at,
            entity_updated_at = EXCLUDED.entity_updated_at,
            updated_at = now(),
            version = records.version + 1
          WHERE records.entity_updated_at <= EXCLUDED.entity_updated_at
          RETURNING records.entity_id
        )
        SELECT
          (SELECT count(*)::int FROM req) AS applied_request,
          (SELECT count(*)::int FROM applied) AS applied_count,
          (SELECT count(*)::int FROM src) AS received_count
      `);

      const result = rows[0] ?? {
        applied_request: 0,
        applied_count: 0,
        received_count: 0,
      };
      void runMaintenanceIfDue().catch((error) => {
        request.log.warn({ error: String(error) }, 'sync maintenance failed');
      });
      return {
        ok: true,
        received: result.received_count,
        applied: result.applied_count,
        duplicate: result.applied_request === 0,
        request_id: body.request_id,
      };
    },
  );

  app.get('/v1/sync/pull', { preHandler: requireAuth }, async (request) => {
    const query = z
      .object({
        cursor: z.string().max(500).optional(),
        limit: z.coerce.number().int().positive().max(env.MAX_PULL_LIMIT).optional(),
      })
      .parse(request.query ?? {});

    let cursor: PullCursor;
    try {
      cursor = decodeCursor(query.cursor);
    } catch {
      throw badRequest('Некорректный курсор синхронизации');
    }
    const limit = query.limit ?? 200;

    const rows = await rawRows<{
      collection: string;
      entity_id: string;
      payload: Record<string, unknown>;
      deleted_at: Date | string | null;
      updated_at: Date | string;
    }>(sql`
      SELECT collection, entity_id, payload, deleted_at, updated_at
      FROM records
      WHERE user_id = ${request.userId}::uuid
        AND (updated_at, collection, entity_id) >
            (${cursor.updatedAt}::timestamptz, ${cursor.collection}, ${cursor.entityId})
      ORDER BY updated_at, collection, entity_id
      LIMIT ${limit}
    `);

    const records = rows.map((row) => ({
      collection: row.collection,
      entity_id: row.entity_id,
      data: row.payload,
      deleted: row.deleted_at !== null,
      updated_at:
        row.updated_at instanceof Date
          ? row.updated_at.toISOString()
          : new Date(row.updated_at).toISOString(),
    }));
    const last = rows[rows.length - 1];
    return {
      records,
      has_more: rows.length === limit,
      next_cursor: last
        ? encodeCursor({
            updatedAt:
              last.updated_at instanceof Date
                ? last.updated_at.toISOString()
                : new Date(last.updated_at).toISOString(),
            collection: last.collection,
            entityId: last.entity_id,
          })
        : query.cursor ?? null,
      limit,
    };
  });
}
