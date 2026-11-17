import { AppError } from '../lib/errors.js';
import type { FetchLike } from './types.js';

export async function fetchJson<T>(
  fetchImpl: FetchLike,
  url: string,
  init: RequestInit = {},
  timeoutMs = 15_000,
): Promise<T> {
  let response: Response;
  try {
    response = await fetchImpl(url, {
      ...init,
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    throw new AppError(
      502,
      'platform_unreachable',
      `Площадка не ответила: ${String(error).slice(0, 180)}`,
    );
  }
  const text = await response.text();
  let body: unknown = text;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    // Keep raw text for a readable error.
  }
  if (!response.ok) {
    const message =
      typeof body === 'object' && body !== null
        ? String(
            (body as Record<string, unknown>)['error_description'] ??
              (body as Record<string, unknown>)['message'] ??
              (body as Record<string, unknown>)['error'] ??
              text,
          )
        : text;
    throw new AppError(
      response.status === 401 || response.status === 403 ? 401 : 502,
      'platform_api_error',
      `API площадки вернул ошибку ${response.status}: ${message.slice(0, 300)}`,
    );
  }
  return body as T;
}

export function query(params: Record<string, string | number | boolean>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    search.set(key, String(value));
  }
  return search.toString();
}
