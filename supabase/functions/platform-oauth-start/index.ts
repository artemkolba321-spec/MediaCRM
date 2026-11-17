// Supabase Edge Function: platform-oauth-start
// Initiates OAuth 2.0 flow for a platform and returns the auth URL.
// Client secrets are stored as Edge Function env vars and never exposed to the client.

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
    const { channel_id, user_id, platform } = await req.json();
    if (!channel_id || !platform) {
      return new Response(
        JSON.stringify({ ok: false, message: "channel_id and platform are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Safe logging: log channel_id and platform, NEVER log JWT or secrets
    console.log(`[oauth-start] channel_id=${channel_id} user_id=${user_id} platform=${platform}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    // Try to find the existing channel
    let channel = null;
    try {
      const { data: found } = await supabase
        .from("platform_channels")
        .select("user_id")
        .eq("id", channel_id)
        .single();
      channel = found;
    } catch {
      // Query error — continue to auto-create
    }

    if (!channel) {
      // Channel record is missing (deleted manually, propagation delay, etc.).
      // Auto-create it so the OAuth flow can complete and tokens will be saved.
      // The Flutter app already generated the channel UUID and saved it locally;
      // we just need the cloud record to exist for the callback to work.
      console.log(
        `[oauth-start] Channel not found, auto-creating: id=${channel_id} platform=${platform}`
      );

      const { data: created, error: createError } = await supabase
        .from("platform_channels")
        .insert({
          id: channel_id,
          user_id: user_id,
          platform: platform,
          name: `Новый ${platform === "youtube" ? "YouTube" : platform === "vk" ? "VK" : platform === "github" ? "GitHub" : platform} канал`,
          status: "disconnected",
          has_credentials: false,
          auth_method: "none",
          auto_sync: true,
        })
        .select("user_id")
        .single();

      if (createError || !created) {
        console.error(
          `[oauth-start] Failed to auto-create channel: id=${channel_id} ` +
            `error=${createError?.code ?? createError?.message ?? "unknown"}`
        );
        return new Response(
          JSON.stringify({
            ok: false,
            message: "Не удалось создать запись площадки. Повторите попытку.",
          }),
          { status: 500, headers: { "Content-Type": "application/json" } }
        );
      }

      channel = created;
      console.log(`[oauth-start] Channel auto-created: user_id=${channel.user_id}`);
    } else {
      console.log(`[oauth-start] Channel found: user_id=${channel.user_id}`);
    }

    let authUrl = "";

    switch (platform) {
      case "youtube":
        authUrl = await startYouTubeOAuth(channel_id);
        break;
      case "vk":
        authUrl = startVKOAuth(channel_id);
        break;
      case "github":
        authUrl = startGitHubOAuth(channel_id);
        break;
      default:
        return new Response(
          JSON.stringify({ ok: false, message: `OAuth not supported for: ${platform}` }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
    }

    return new Response(
      JSON.stringify({ ok: true, auth_url: authUrl }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("OAuth start error:", error);
    return new Response(
      JSON.stringify({ ok: false, message: error.message || "Unknown error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

async function startYouTubeOAuth(channelId: string): Promise<string> {
  if (!GOOGLE_CLIENT_ID) {
    throw new Error("Google OAuth not configured. Set GOOGLE_CLIENT_ID env var.");
  }
  const state = `${channelId}:${Date.now()}`;
  const params = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: `${SUPABASE_URL}/functions/v1/platform-oauth-callback`,
    response_type: "code",
    scope: "https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/yt-analytics.readonly",
    access_type: "offline",
    prompt: "consent",
    state,
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

function startVKOAuth(channelId: string): string {
  if (!VK_CLIENT_ID) {
    throw new Error("VK OAuth not configured. Set VK_CLIENT_ID env var.");
  }
  const state = `${channelId}:${Date.now()}`;
  const params = new URLSearchParams({
    client_id: VK_CLIENT_ID,
    redirect_uri: `${SUPABASE_URL}/functions/v1/platform-oauth-callback`,
    response_type: "code",
    state,
    v: "5.131",
  });
  return `https://oauth.vk.com/authorize?${params.toString()}`;
}

function startGitHubOAuth(channelId: string): string {
  if (!GITHUB_CLIENT_ID) {
    throw new Error("GitHub OAuth not configured. Set GITHUB_CLIENT_ID env var.");
  }
  const state = `${channelId}:${Date.now()}`;
  const params = new URLSearchParams({
    client_id: GITHUB_CLIENT_ID,
    redirect_uri: `${SUPABASE_URL}/functions/v1/platform-oauth-callback`,
    state,
    scope: "read:user repo",
  });
  return `https://github.com/login/oauth/authorize?${params.toString()}`;
}
