import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

import { env } from '../config.js';
import { serviceUnavailable } from '../lib/errors.js';

let cachedKey: Buffer | null | undefined;

function credentialKey(): Buffer {
  if (cachedKey !== undefined) {
    if (cachedKey === null) {
      throw serviceUnavailable(
        'CREDENTIALS_KEY не настроен. Задайте 32-байтный ключ в окружении сервера.',
      );
    }
    return cachedKey;
  }
  const raw = env.CREDENTIALS_KEY.trim();
  if (!raw) {
    cachedKey = null;
    throw serviceUnavailable(
      'CREDENTIALS_KEY не настроен. Задайте 32-байтный ключ в окружении сервера.',
    );
  }
  let key: Buffer;
  if (/^[0-9a-fA-F]{64}$/.test(raw)) {
    key = Buffer.from(raw, 'hex');
  } else {
    key = Buffer.from(raw, 'base64');
    if (key.length !== 32) key = Buffer.from(raw, 'base64url');
  }
  if (key.length !== 32) {
    cachedKey = null;
    throw serviceUnavailable(
      'CREDENTIALS_KEY должен быть 32 байта в base64, base64url или hex.',
    );
  }
  cachedKey = key;
  return key;
}

export interface EncryptedValue {
  ciphertext: string;
  iv: string;
  tag: string;
}

export function encryptCredential(value: unknown): EncryptedValue {
  const key = credentialKey();
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const plaintext = Buffer.from(JSON.stringify(value), 'utf8');
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return {
    ciphertext: ciphertext.toString('base64'),
    iv: iv.toString('base64url'),
    tag: cipher.getAuthTag().toString('base64url'),
  };
}

export function decryptCredential<T = Record<string, unknown>>(
  value: EncryptedValue,
): T {
  const key = credentialKey();
  const decipher = createDecipheriv(
    'aes-256-gcm',
    key,
    Buffer.from(value.iv, 'base64url'),
  );
  decipher.setAuthTag(Buffer.from(value.tag, 'base64url'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(value.ciphertext, 'base64')),
    decipher.final(),
  ]);
  return JSON.parse(plaintext.toString('utf8')) as T;
}
