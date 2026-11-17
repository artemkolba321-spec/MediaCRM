import { randomBytes, randomUUID } from 'node:crypto';

import { and, eq, gt, isNull } from 'drizzle-orm';
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import { db } from '../db/index.js';
import { passwordResetTokens, sessions, users } from '../db/schema.js';
import { badRequest, conflict, unauthorized } from '../lib/errors.js';
import { requireAuth } from '../auth/middleware.js';
import { hashPassword, verifyPassword } from '../auth/password.js';
import {
  createRefreshToken,
  hashRefreshToken,
  refreshTokenExpiry,
  signAccessToken,
} from '../auth/tokens.js';
import { sendPasswordResetEmail } from '../auth/email.js';

const emailSchema = z
  .string()
  .trim()
  .toLowerCase()
  .email('Некорректный email')
  .max(320);

const passwordSchema = z
  .string()
  .min(8, 'Пароль должен содержать минимум 8 символов')
  .max(128, 'Пароль слишком длинный');

const registerSchema = z.object({
  email: emailSchema,
  password: passwordSchema,
  display_name: z.string().trim().min(1).max(120).default('Моя медиасеть'),
});

const loginSchema = z.object({
  email: emailSchema,
  password: z.string().min(1).max(128),
});

const refreshSchema = z.object({
  refresh_token: z.string().min(20).max(200),
});

const resetRequestSchema = z.object({ email: emailSchema });

const resetConfirmSchema = z.object({
  token: z.string().min(20).max(200),
  password: passwordSchema,
});

const changePasswordSchema = z.object({
  current_password: z.string().min(1).max(128),
  new_password: passwordSchema,
});

const profileSchema = z.object({
  display_name: z.string().trim().min(1).max(120),
});

function publicUser(row: {
  id: string;
  email: string;
  displayName: string;
}) {
  return {
    id: row.id,
    email: row.email,
    display_name: row.displayName,
  };
}

async function issueRefreshToken(userId: string): Promise<string> {
  const token = createRefreshToken();
  await db.insert(sessions).values({
    userId,
    tokenHash: hashRefreshToken(token),
    expiresAt: refreshTokenExpiry(),
  });
  return token;
}

function authResponse(
  user: { id: string; email: string; displayName: string },
  refreshToken: string,
) {
  return {
    user: publicUser(user),
    access_token: signAccessToken(user.id, user.email),
    refresh_token: refreshToken,
    expires_in: 15 * 60,
  };
}

function isUniqueViolation(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: string }).code === '23505'
  );
}

export async function registerAuthRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/v1/auth/register',
    {
      config: { rateLimit: { max: 5, timeWindow: '10 minutes' } },
    },
    async (request, reply) => {
      const body = registerSchema.parse(request.body ?? {});
      const existing = await db
        .select({ id: users.id })
        .from(users)
        .where(eq(users.email, body.email))
        .limit(1);
      if (existing.length > 0) {
        throw conflict('Пользователь с таким email уже зарегистрирован');
      }
      const passwordHash = await hashPassword(body.password);
      let user: {
        id: string;
        email: string;
        displayName: string;
        passwordHash: string;
      };
      try {
        const inserted = await db
          .insert(users)
          .values({
            id: randomUUID(),
            email: body.email,
            passwordHash,
            displayName: body.display_name,
          })
          .returning();
        user = inserted[0]!;
      } catch (error) {
        if (isUniqueViolation(error)) {
          throw conflict('Пользователь с таким email уже зарегистрирован');
        }
        throw error;
      }
      const refreshToken = await issueRefreshToken(user.id);
      reply.code(201);
      return authResponse(user, refreshToken);
    },
  );

  app.post(
    '/v1/auth/login',
    {
      config: { rateLimit: { max: 10, timeWindow: '1 minute' } },
    },
    async (request) => {
      const body = loginSchema.parse(request.body ?? {});
      const rows = await db
        .select()
        .from(users)
        .where(eq(users.email, body.email))
        .limit(1);
      const user = rows[0];
      // Always run the hash comparison to keep the response timing similar for
      // unknown emails and wrong passwords.
      const valid = user
        ? await verifyPassword(body.password, user.passwordHash)
        : await verifyPassword(body.password, 'scrypt$16384$8$1$AAAA$AAAA');
      if (!user || !valid) {
        throw unauthorized('Неверный email или пароль');
      }
      const refreshToken = await issueRefreshToken(user.id);
      return authResponse(user, refreshToken);
    },
  );

  app.post(
    '/v1/auth/refresh',
    {
      config: { rateLimit: { max: 30, timeWindow: '1 minute' } },
    },
    async (request) => {
      const body = refreshSchema.parse(request.body ?? {});
      const tokenHash = hashRefreshToken(body.refresh_token);
      const rows = await db
        .select({ session: sessions, user: users })
        .from(sessions)
        .innerJoin(users, eq(sessions.userId, users.id))
        .where(eq(sessions.tokenHash, tokenHash))
        .limit(1);
      const row = rows[0];
      if (!row) throw unauthorized('Сессия не найдена. Войдите снова.');
      if (row.session.revokedAt) {
        // A revoked refresh token was reused: revoke every session of the
        // account as a precaution.
        await db
          .update(sessions)
          .set({ revokedAt: new Date() })
          .where(and(eq(sessions.userId, row.user.id), isNull(sessions.revokedAt)));
        throw unauthorized('Сессия отозвана. Войдите снова.');
      }
      if (row.session.expiresAt.getTime() <= Date.now()) {
        throw unauthorized('Сессия истекла. Войдите снова.');
      }
      const newRefresh = createRefreshToken();
      await db.batch([
        db
          .update(sessions)
          .set({ revokedAt: new Date() })
          .where(eq(sessions.id, row.session.id)),
        db.insert(sessions).values({
          userId: row.user.id,
          tokenHash: hashRefreshToken(newRefresh),
          expiresAt: refreshTokenExpiry(),
        }),
      ]);
      return authResponse(row.user, newRefresh);
    },
  );

  app.post('/v1/auth/logout', async (request, reply) => {
    const body = refreshSchema.parse(request.body ?? {});
    await db
      .update(sessions)
      .set({ revokedAt: new Date() })
      .where(
        and(
          eq(sessions.tokenHash, hashRefreshToken(body.refresh_token)),
          isNull(sessions.revokedAt),
        ),
      );
    reply.code(204);
    return null;
  });

  app.get('/v1/auth/me', { preHandler: requireAuth }, async (request) => {
    const rows = await db
      .select()
      .from(users)
      .where(eq(users.id, request.userId))
      .limit(1);
    const user = rows[0];
    if (!user) throw unauthorized('Пользователь не найден');
    return { user: publicUser(user) };
  });

  app.patch(
    '/v1/auth/me',
    { preHandler: requireAuth },
    async (request) => {
      const body = profileSchema.parse(request.body ?? {});
      const rows = await db
        .update(users)
        .set({ displayName: body.display_name, updatedAt: new Date() })
        .where(eq(users.id, request.userId))
        .returning();
      const user = rows[0];
      if (!user) throw unauthorized('Пользователь не найден');
      return { user: publicUser(user) };
    },
  );

  app.post(
    '/v1/auth/password/reset-request',
    {
      config: { rateLimit: { max: 3, timeWindow: '15 minutes' } },
    },
    async (request, reply) => {
      const body = resetRequestSchema.parse(request.body ?? {});
      const rows = await db
        .select({ id: users.id, email: users.email })
        .from(users)
        .where(eq(users.email, body.email))
        .limit(1);
      const user = rows[0];
      let delivery: 'email' | 'manual' | 'none' = 'none';
      let devToken: string | undefined;
      if (user) {
        const token = randomBytes(32).toString('base64url');
        await db.insert(passwordResetTokens).values({
          userId: user.id,
          tokenHash: hashRefreshToken(token),
          expiresAt: new Date(Date.now() + 30 * 60_000),
        });
        const sent = await sendPasswordResetEmail(user.email, token).catch(
          (error: unknown) => {
            request.log.error(
              { error: String(error) },
              'password reset email failed',
            );
            return false;
          },
        );
        if (sent) {
          delivery = 'email';
        } else if (process.env.NODE_ENV !== 'production') {
          delivery = 'manual';
          devToken = token;
        }
      }
      reply.code(202);
      return {
        ok: true,
        message:
          'Если аккаунт существует, инструкция по восстановлению отправлена.',
        delivery,
        // Only present in development when SMTP is not configured.
        ...(devToken ? { dev_reset_token: devToken } : {}),
      };
    },
  );

  app.post(
    '/v1/auth/password/reset',
    {
      config: { rateLimit: { max: 10, timeWindow: '15 minutes' } },
    },
    async (request) => {
      const body = resetConfirmSchema.parse(request.body ?? {});
      const tokenHash = hashRefreshToken(body.token);
      const rows = await db
        .select({ token: passwordResetTokens, user: users })
        .from(passwordResetTokens)
        .innerJoin(users, eq(passwordResetTokens.userId, users.id))
        .where(
          and(
            eq(passwordResetTokens.tokenHash, tokenHash),
            isNull(passwordResetTokens.usedAt),
            gt(passwordResetTokens.expiresAt, new Date()),
          ),
        )
        .limit(1);
      const row = rows[0];
      if (!row) {
        throw badRequest('Ссылка восстановления недействительна или истекла');
      }
      const passwordHash = await hashPassword(body.password);
      await db.batch([
        db
          .update(users)
          .set({ passwordHash, updatedAt: new Date() })
          .where(eq(users.id, row.user.id)),
        db
          .update(passwordResetTokens)
          .set({ usedAt: new Date() })
          .where(eq(passwordResetTokens.id, row.token.id)),
        db
          .update(sessions)
          .set({ revokedAt: new Date() })
          .where(and(eq(sessions.userId, row.user.id), isNull(sessions.revokedAt))),
      ]);
      return { ok: true, message: 'Пароль изменён. Войдите с новым паролем.' };
    },
  );

  app.post(
    '/v1/auth/password/change',
    { preHandler: requireAuth },
    async (request) => {
      const body = changePasswordSchema.parse(request.body ?? {});
      const rows = await db
        .select()
        .from(users)
        .where(eq(users.id, request.userId))
        .limit(1);
      const user = rows[0];
      if (!user) throw unauthorized('Пользователь не найден');
      const valid = await verifyPassword(
        body.current_password,
        user.passwordHash,
      );
      if (!valid) throw badRequest('Текущий пароль неверен');
      if (body.current_password === body.new_password) {
        throw badRequest('Новый пароль должен отличаться от текущего');
      }
      const passwordHash = await hashPassword(body.new_password);
      await db.batch([
        db
          .update(users)
          .set({ passwordHash, updatedAt: new Date() })
          .where(eq(users.id, user.id)),
        db
          .update(sessions)
          .set({ revokedAt: new Date() })
          .where(and(eq(sessions.userId, user.id), isNull(sessions.revokedAt))),
      ]);
      return {
        ok: true,
        message: 'Пароль изменён. Все сессии завершены, войдите снова.',
      };
    },
  );
}

