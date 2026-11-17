// Supabase Edge Function: platform-oauth-callback
// Handles OAuth callback from platforms and exchanges the code for tokens.
// Tokens are stored in oauth_tokens table (secure) and platform_channels
// is updated with basic channel info (platform_id, name, has_credentials).

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID") ?? "";
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "";
const VK_CLIENT_ID = Deno.env.get("VK_CLIENT_ID") ?? "";
const VK_CLIENT_SECRET = Deno.env.get("VK_CLIENT_SECRET") ?? "";
const GITHUB_CLIENT_ID = Deno.env.get("GITHUB_CLIENT_ID") ?? "";
const GITHUB_CLIENT_SECRET = Deno.env.get("GITHUB_CLIENT_SECRET") ?? "";
const APP_REDIRECT = Deno.env.get("APP_REDIRECT_URL") ?? "mediacrm://oauth-callback";

serve(async (req) => {
  try {
    // ── Parse code + state from GET query params or POST JSON body ──────────
    let code: string | null = null;
    let state: string | null = null;
    let error: string | null = null;

    if (req.method === "GET") {
      const url = new URL(req.url);
      code = url.searchParams.get("code");
      state = url.searchParams.get("state");
      error = url.searchParams.get("error");
    } else {
      const body = await req.json();
      code = body?.code ?? null;
      state = body?.state ?? null;
      error = body?.error ?? null;
    }

    // ── Handle OAuth errors from the provider ──────────────────────────────
    if (error) {
      const desc = new URLSearchParams({ status: "error", message: error });
      const redirectUrl = `${APP_REDIRECT}?${desc}`;
      return Response.redirect(redirectUrl, 302);
    }

    if (!code || !state) {
      return Response.redirect(
        `${APP_REDIRECT}?status=error&message=${encodeURIComponent("code and state are required")}`,
        302,
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    // ── Validate state: channel_id:timestamp ───────────────────────────────
    const colonIndex = state.lastIndexOf(":");
    if (colonIndex < 1) {
      return Response.redirect(
        `${APP_REDIRECT}?status=error&message=${encodeURIComponent("Invalid state parameter")}`,
        302,
      );
    }

    const channelId = state.slice(0, colonIndex);
    const stateTimestamp = parseInt(state.slice(colonIndex + 1), 10);

    // Guard against expired / reused state (tolerance: 24 hours)
    const now = Date.now();
    if (isNaN(stateTimestamp) || (now - stateTimestamp) > 24 * 60 * 60 * 1000) {
      return Response.redirect(
        `${APP_REDIRECT}?status=error&message=${encodeURIComponent("State expired or invalid")}`,
        302,
      );
    }

    // ── Get channel info to know which platform ────────────────────────────
    const { data: channel, error: channelError } = await supabase
      .from("platform_channels")
      .select("platform, user_id")
      .eq("id", channelId)
      .single();

    if (channelError || !channel) {
      const errMsg =
        "Запись площадки не найдена. Это могло произойти, если запись " +
        "была удалена во время OAuth-сессии. OAuth-сессия безопасна: " +
        "токены не сохранены.";
      return Response.redirect(
        `${APP_REDIRECT}?status=error&message=${encodeURIComponent(errMsg)}`,
        302,
      );
    }

    let token: string = "";
    let refreshToken: string | null = null;
    let expiresAt: string | null = null;
    let platformId: string = "";
    let channelName: string | null = null;
    let channelAvatar: string | null = null;

    switch (channel.platform) {
      case "youtube": {
        const ytResult = await exchangeYouTubeToken(code);
        token = ytResult.accessToken;
        refreshToken = ytResult.refreshToken ?? null;
        expiresAt = ytResult.expiresAt ?? null;
        platformId = await getYouTubeChannelId(token);
        channelName = await getYouTubeChannelName(token);
        channelAvatar = await getYouTubeChannelAvatar(token);
        break;
      }
      case "vk": {
        const vkResult = await exchangeVKToken(code);
        token = vkResult.accessToken;
        platformId = vkResult.userId.toString();
        channelName = vkResult.userName ?? null;
        channelAvatar = vkResult.userPhoto ?? null;
        break;
      }
      case "github": {
        const ghResult = await exchangeGitHubToken(code);
        token = ghResult.accessToken;
        platformId = ghResult.login;
        channelName = ghResult.displayName ?? ghResult.login;
        channelAvatar = ghResult.avatarUrl ?? null;
        break;
      }
      default:
        return Response.redirect(
          `${APP_REDIRECT}?status=error&message=${encodeURIComponent(`OAuth callback not supported for: ${channel.platform}`)}`,
          302,
        );
    }

    // ── Update channel with basic info (tokens go to oauth_tokens table) ────
    const channelUpdateData: Record<string, unknown> = {
      platform_id: platformId,
      name: channelName ?? (channelName === null ? (channel as any).name ?? "" : ""),
      avatar_url: channelAvatar ?? undefined,
      has_credentials: true,
      status: "connected",
      auth_method: "oauth",
      error: null,
      last_sync_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    // Remove undefined values
    for (const key of Object.keys(channelUpdateData)) {
      if (channelUpdateData[key] === undefined) {
        delete channelUpdateData[key];
      }
    }

    await supabase
      .from("platform_channels")
      .update(channelUpdateData)
      .eq("id", channelId);

    // ── Store OAuth tokens in secure table (not visible to client) ─────────
    const tokenData: Record<string, unknown> = {
      channel_id: channelId,
      user_id: channel.user_id,
      platform: channel.platform,
      access_token: token,
      updated_at: new Date().toISOString(),
    };

    if (refreshToken) {
      tokenData.refresh_token = refreshToken;
    }
    if (expiresAt) {
      tokenData.oauth_expires_at = expiresAt;
    }

    await supabase
      .from("oauth_tokens")
      .upsert(tokenData, { onConflict: "channel_id" });

    // ── Redirect back to app on success ────────────────────────────────────
    const redirectUrl = `${APP_REDIRECT}?status=success&channel_id=${encodeURIComponent(channelId)}`;
    return Response.redirect(redirectUrl, 302);
  } catch (error) {
    console.error("OAuth callback error:", error);
    const errMsg = (error as Error).message || "Unknown error";
    const redirectUrl = `${APP_REDIRECT}?status=error&message=${encodeURIComponent(errMsg)}`;
    return Response.redirect(redirectUrl, 302);
  }
});

// ── Token exchange helpers ────────────────────────────────────────────────────

async function exchangeYouTubeToken(code: string): Promise<{
  accessToken: string;
  refreshToken?: string | null;
  expiresAt?: string | null;
}> {
  const redirectUri = `${SUPABASE_URL}/functions/v1/platform-oauth-callback`;

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      redirect_uri: redirectUri,
      grant_type: "authorization_code",
    }),
  });

  const data = await resp.json();

  if (!data.access_token) {
    const errMsg = data.error_description || data.error || "Failed to exchange YouTube token";
    throw new Error(errMsg);
  }

  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token ?? undefined,
    expiresAt: data.expires_in
      ? new Date(Date.now() + data.expires_in * 1000).toISOString()
      : undefined,
  };
}

async function getYouTubeChannelId(accessToken: string): Promise<string> {
  const resp = await fetch(
    "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true",
    {
      headers: { Authorization: `Bearer ${accessToken}` },
    }
  );
  const data = await resp.json();
  if (data.items && data.items.length > 0) {
    return data.items[0].id;
  }
  throw new Error("Could not find YouTube channel");
}

async function getYouTubeChannelName(accessToken: string): Promise<string | null> {
  try {
    const resp = await fetch(
      "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true",
      {
        headers: { Authorization: `Bearer ${accessToken}` },
      }
    );
    const data = await resp.json();
    if (data.items && data.items.length > 0) {
      return data.items[0].snippet?.title ?? null;
    }
  } catch (e) {
    console.warn("Failed to fetch YouTube channel name:", e);
  }
  return null;
}

async function getYouTubeChannelAvatar(accessToken: string): Promise<string | null> {
  try {
    const resp = await fetch(
      "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true",
      {
        headers: { Authorization: `Bearer ${accessToken}` },
      }
    );
    const data = await resp.json();
    if (data.items && data.items.length > 0) {
      return data.items[0].snippet?.thumbnails?.high?.url ??
             data.items[0].snippet?.thumbnails?.default?.url ??
             null;
    }
  } catch (e) {
    console.warn("Failed to fetch YouTube channel avatar:", e);
  }
  return null;
}

async function exchangeVKToken(code: string): Promise<{
  accessToken: string;
  userId: number;
  userName?: string | null;
  userPhoto?: string | null;
}> {
  const redirectUri = `${SUPABASE_URL}/functions/v1/platform-oauth-callback`;

  const resp = await fetch("https://oauth.vk.com/access_token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: VK_CLIENT_ID,
      client_secret: VK_CLIENT_SECRET,
      redirect_uri: redirectUri,
      code,
      grant_type: "authorization_code",
    }),
  });
  const data = await resp.json();
  if (!data.access_token) {
    throw new Error("Failed to exchange VK token");
  }

  // Fetch user info for display name and photo
  let userName: string | null = null;
  let userPhoto: string | null = null;
  try {
    const userResp = await fetch(
      `https://api.vk.com/method/users.get?user_ids=${data.user_id}&v=5.131&fields=photo_200`
    );
    const userData = await userResp.json();
    if (userData.response && userData.response.length > 0) {
      const user = userData.response[0];
      userName = user.first_name + (user.last_name ? ` ${user.last_name}` : "");
      userPhoto = user.photo_200 ?? null;
    }
  } catch (e) {
    console.warn("Failed to fetch VK user info:", e);
  }

  return { accessToken: data.access_token, userId: data.user_id, userName, userPhoto };
}

async function exchangeGitHubToken(code: string): Promise<{
  accessToken: string;
  login: string;
  displayName?: string | null;
  avatarUrl?: string | null;
}> {
  const redirectUri = `${SUPABASE_URL}/functions/v1/platform-oauth-callback`;

  const resp = await fetch("https://github.com/login/oauth/access_token", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      client_id: GITHUB_CLIENT_ID,
      client_secret: GITHUB_CLIENT_SECRET,
      code,
      redirect_uri: redirectUri,
    }),
  });
  const data = await resp.json();
  if (!data.access_token) {
    throw new Error("Failed to exchange GitHub token");
  }
  const userResp = await fetch("https://api.github.com/user", {
    headers: { Authorization: `Bearer ${data.access_token}` },
  });
  const userData = await userResp.json();
  return {
    accessToken: data.access_token,
    login: userData.login,
    displayName: userData.name ?? null,
    avatarUrl: userData.avatar_url ?? null,
  };
}
