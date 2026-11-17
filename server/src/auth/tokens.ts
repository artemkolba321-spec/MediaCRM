import { createHash, randomBytes, timingSafeEqual } from 'node:crypto';
import jwt from 'jsonwebtoken';

import { env } from '../config.js';
import { unauthorized } from '../lib/errors.js';

const ISSUER = 'mediacrm';
const ALGORITHM = 'HS256' as const;

export interface AccessPayload {
  sub: string;
  email: string;
  typ: 'access';
}

export interface OAuthStatePayload {
  sub: string;
  cid: string;
  platform: string;
  typ: 'oauth';
  nonce: string;
}

export function signAccessToken(userId: string, email: string): string {
  return jwt.sign(
    { sub: userId, email, typ: 'access' },
    env.JWT_SECRET,
    {
      algorithm: ALGORITHM,
      issuer: ISSUER,
      expiresIn: `${env.ACCESS_TOKEN_TTL_MINUTES}m`,
    },
  );
}

export function verifyAccessToken(token: string): AccessPayload {
  try {
    const payload = jwt.verify(token, env.JWT_SECRET, {
      algorithms: [ALGORITHM],
      issuer: ISSUER,
    });
    if (
      typeof payload !== 'object' ||
      payload === null ||
      payload.typ !== 'access' ||
      typeof payload.sub !== 'string' ||
      typeof payload.email !== 'string'
    ) {
      throw unauthorized('Некорректный токен');
    }
    return {
      sub: payload.sub,
      email: payload.email,
      typ: 'access',
    };
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw unauthorized('Сессия истекла. Войдите снова.');
    }
    throw unauthorized('Некорректный токен');
  }
}

export function signOAuthState(
  userId: string,
  channelId: string,
  platform: string,
): string {
  return jwt.sign(
    {
      sub: userId,
      cid: channelId,
      platform,
      typ: 'oauth',
      nonce: randomBytes(12).toString('base64url'),
    },
    env.JWT_SECRET,
    {
      algorithm: ALGORITHM,
      issuer: ISSUER,
      expiresIn: '10m',
    },
  );
}

export function verifyOAuthState(state: string): OAuthStatePayload {
  try {
    const payload = jwt.verify(state, env.JWT_SECRET, {
      algorithms: [ALGORITHM],
      issuer: ISSUER,
    });
    if (
      typeof payload !== 'object' ||
      payload === null ||
      payload.typ !== 'oauth' ||
      typeof payload.sub !== 'string' ||
      typeof payload.cid !== 'string' ||
      typeof payload.platform !== 'string'
    ) {
      throw unauthorized('Некорректный OAuth state');
    }
    return {
      sub: payload.sub,
      cid: payload.cid,
      platform: payload.platform,
      typ: 'oauth',
      nonce: String(payload.nonce ?? ''),
    };
  } catch {
    throw unauthorized('OAuth state истёк. Начните подключение снова.');
  }
}

export function createRefreshToken(): string {
  return randomBytes(48).toString('base64url');
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function refreshTokenExpiry(): Date {
  return new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 86_400_000);
}

export function safeEqualHex(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  return timingSafeEqual(Buffer.from(left), Buffer.from(right));
}
