const EPOCH = '1970-01-01T00:00:00.000Z';

export interface PullCursor {
  updatedAt: string;
  collection: string;
  entityId: string;
}

export function initialCursor(): PullCursor {
  return { updatedAt: EPOCH, collection: '', entityId: '' };
}

export function encodeCursor(cursor: PullCursor): string {
  return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
}

export function decodeCursor(raw: string | undefined): PullCursor {
  if (!raw) return initialCursor();
  let parsed: unknown;
  try {
    parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
  } catch {
    throw new Error('invalid cursor');
  }
  if (
    typeof parsed !== 'object' ||
    parsed === null ||
    typeof (parsed as PullCursor).updatedAt !== 'string' ||
    Number.isNaN(Date.parse((parsed as PullCursor).updatedAt)) ||
    typeof (parsed as PullCursor).collection !== 'string' ||
    typeof (parsed as PullCursor).entityId !== 'string'
  ) {
    throw new Error('invalid cursor');
  }
  return parsed as PullCursor;
}
