import { AppError } from '../lib/errors.js';
import { isoDate, safeInt } from '../lib/records.js';
import { fetchJson } from './http.js';
import type {
  FetchLike,
  PlatformContext,
  PlatformSyncResult,
  VerifiedConnection,
} from './types.js';

const API = 'https://api.github.com';

interface GithubUser {
  login?: string;
  name?: string;
  bio?: string;
  avatar_url?: string;
  followers?: number;
  public_repos?: number;
}

interface GithubRepo {
  stargazers_count?: number;
  forks_count?: number;
}

function tokenOf(context: PlatformContext): string {
  const token = context.credential['token'] ?? context.credential['access_token'];
  if (typeof token !== 'string' || token.length < 10) {
    throw new AppError(400, 'invalid_credential', 'Не указан GitHub token');
  }
  return token;
}

function loginOf(context: PlatformContext): string | null {
  const raw =
    context.metadata['login'] ??
    context.platformId ??
    context.credential['login'];
  if (typeof raw === 'string' && raw.trim()) return raw.trim();
  const url = context.metadata['url'] ?? context.credential['url'];
  if (typeof url === 'string') {
    const match = url.match(/github\.com\/([^/?#]+)/i);
    if (match) return match[1]!;
  }
  return null;
}

function headers(token: string): Record<string, string> {
  return {
    authorization: `Bearer ${token}`,
    accept: 'application/vnd.github+json',
    'x-github-api-version': '2022-11-28',
    'user-agent': 'MediaCRM/2.0',
  };
}

async function githubGet<T>(
  path: string,
  token: string,
  fetchImpl: FetchLike,
): Promise<T> {
  return fetchJson<T>(fetchImpl, `${API}${path}`, {
    headers: headers(token),
  });
}

async function loadAccount(
  context: PlatformContext,
  token: string,
  fetchImpl: FetchLike,
): Promise<GithubUser> {
  const login = loginOf(context);
  if (!login) {
    return githubGet<GithubUser>('/user', token, fetchImpl);
  }
  try {
    return await githubGet<GithubUser>(
      `/users/${encodeURIComponent(login)}`,
      token,
      fetchImpl,
    );
  } catch {
    return githubGet<GithubUser>(
      `/orgs/${encodeURIComponent(login)}`,
      token,
      fetchImpl,
    );
  }
}

function accountPatch(user: GithubUser) {
  return {
    platformId: user.login,
    name: user.name ?? user.login,
    description: user.bio,
    avatarUrl: user.avatar_url,
    subscriberCount: user.followers,
  };
}

export async function verifyGitHub(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<VerifiedConnection> {
  const token = tokenOf(context);
  const user = await loadAccount(context, token, fetchImpl);
  if (!user.login) {
    throw new AppError(502, 'github_error', 'GitHub не вернул логин аккаунта');
  }
  return {
    metadata: {
      login: user.login,
      platform_id: user.login,
      name: user.name ?? user.login,
      avatar_url: user.avatar_url,
    },
    channel: accountPatch(user),
  };
}

export async function syncGitHub(
  context: PlatformContext,
  fetchImpl: FetchLike = fetch,
): Promise<PlatformSyncResult> {
  const token = tokenOf(context);
  const user = await loadAccount(context, token, fetchImpl);
  if (!user.login) {
    throw new AppError(502, 'github_error', 'GitHub не вернул логин аккаунта');
  }
  const warnings: string[] = [];
  const today = isoDate(new Date());
  const metrics: PlatformSyncResult['metrics'] = [
    { metric: 'followers', value: safeInt(user.followers), date: today },
    { metric: 'posts', value: safeInt(user.public_repos), date: today },
  ];

  // One request returns up to 100 repositories. Stars and forks are summed;
  // if the account has more than 100 repos the response is explicitly marked
  // as partial instead of pretending it is complete.
  let stars = 0;
  let forks = 0;
  try {
    const repos = await githubGet<GithubRepo[]>(
      `/users/${encodeURIComponent(user.login)}/repos?per_page=100&sort=updated&type=owner`,
      token,
      fetchImpl,
    );
    for (const repo of repos) {
      stars += safeInt(repo.stargazers_count);
      forks += safeInt(repo.forks_count);
    }
    metrics.push({ metric: 'stars', value: stars, date: today });
    metrics.push({ metric: 'forks', value: forks, date: today });
    if (repos.length === 100) {
      warnings.push(
        'GitHub отдал первые 100 репозиториев; звёзды и форки могут быть ' +
          'неполными. Полная сумма потребует пагинации.',
      );
    }
  } catch (error) {
    warnings.push(
      `Репозитории GitHub не загружены: ${String(error).slice(0, 160)}`,
    );
  }

  return {
    metrics,
    publications: [],
    channel: accountPatch(user),
    message:
      `GitHub: ${safeInt(user.followers)} подписчиков, ` +
      `${safeInt(user.public_repos)} публичных репозиториев.`,
    warnings,
  };
}
