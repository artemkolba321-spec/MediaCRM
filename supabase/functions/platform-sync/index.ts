// Supabase Edge Function: platform-sync
// Collects metrics from connected platforms and writes them to analytics_snapshots
// and publications tables. Tokens are stored securely in platform_channels.platform_token
// and accessed only on the server.

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_CLIENT_ID = Deno.env.get("GOOGLE_CLIENT_ID") ?? "";
const GOOGLE_CLIENT_SECRET = Deno.env.get("GOOGLE_CLIENT_SECRET") ?? "";
const YOUTUBE_API_KEY = Deno.env.get("YOUTUBE_API_KEY") ?? "";
const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const VK_APP_ID = Deno.env.get("VK_APP_ID") ?? "";
const VK_SECRET = Deno.env.get("VK_SECRET") ?? "";
const VK_ACCESS_TOKEN = Deno.env.get("VK_ACCESS_TOKEN") ?? "";
const GITHUB_TOKEN = Deno.env.get("GITHUB_TOKEN") ?? "";

serve(async (req) => {
  try {
    const { channel_id } = await req.json();
    if (!channel_id) {
      return new Response(
        JSON.stringify({ ok: false, message: "channel_id is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Initialize Supabase client with service role
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    // Get channel info (include auth_method to distinguish OAuth vs manual)
    const { data: channel, error: channelError } = await supabase
      .from("platform_channels")
      .select("*, auth_method")
      .eq("id", channel_id)
      .single();

    if (channelError || !channel) {
      return new Response(
        JSON.stringify({ ok: false, message: "Channel not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    const platform = channel.platform;
    const authMethod = channel.auth_method ?? "none";
    const userId = channel.user_id;
    let metricsWritten = 0;
    let publicationsWritten = 0;
    let syncError: string | null = null;

    switch (platform) {
      case "youtube":
        const ytResult = await syncYouTube(channel, supabase);
        metricsWritten = ytResult.metrics;
        publicationsWritten = ytResult.publications;
        syncError = ytResult.error ?? null;
        break;
      case "telegram":
        const tgResult = await syncTelegram(channel, supabase);
        metricsWritten = tgResult.metrics;
        publicationsWritten = tgResult.publications;
        break;
      case "vk":
        const vkResult = await syncVK(channel, supabase);
        metricsWritten = vkResult.metrics;
        publicationsWritten = vkResult.publications;
        break;
      case "github":
        const ghResult = await syncGitHub(channel, supabase);
        metricsWritten = ghResult.metrics;
        publicationsWritten = ghResult.publications;
        break;
      case "boosty":
        return new Response(
          JSON.stringify({
            ok: true,
            message: "Boosty: manual import only, no API available",
            metrics: 0,
            publications: 0,
          }),
          { status: 200, headers: { "Content-Type": "application/json" } }
        );
      default:
        return new Response(
          JSON.stringify({ ok: false, message: `Unsupported platform: ${platform}` }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
    }

    // Update last_sync_at — reflect actual sync result, don't mask errors
    const syncUpdate: Record<string, unknown> = {
      last_sync_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    // If no metrics were written and there was an error, record it
    if (metricsWritten === 0 && syncError) {
      syncUpdate.status = "error";
      syncUpdate.error = syncError;
    } else {
      syncUpdate.status = "connected";
      syncUpdate.error = null;
    }

    await supabase
      .from("platform_channels")
      .update(syncUpdate)
      .eq("id", channel_id);

    return new Response(
      JSON.stringify({
        ok: metricsWritten > 0 || syncError === null,
        message: syncError
          ? `Синхронизация: ${syncError}`
          : metricsWritten > 0
          ? "Синхронизация завершена"
          : "Нет данных для обновления",
        metrics_written: metricsWritten,
        publications_written: publicationsWritten,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Sync error:", error);
    return new Response(
      JSON.stringify({
        ok: false,
        message: error.message || "Unknown error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

// ---------------------------------------------------------------------------
// YouTube sync
// ---------------------------------------------------------------------------
async function syncYouTube(channel: any, supabase: any) {
  let metrics = 0;
  let publications = 0;
  let error: string | null = null;

  const authMethod = channel.auth_method ?? "none";
  const platformId = channel.platform_id;

  // OAuth channels: read access_token from oauth_tokens table (secure).
  // Manual channels: read api_key from platform_channels.
  let accessToken: string | null = null;
  let refreshToken: string | null = null;
  if (authMethod === "oauth") {
    const { data: tokenRow } = await supabase
      .from("oauth_tokens")
      .select("access_token, refresh_token, oauth_expires_at")
      .eq("channel_id", channel.id)
      .maybeSingle();
    accessToken = tokenRow?.access_token ?? null;
    refreshToken = tokenRow?.refresh_token ?? null;

    // Refresh expired access token using refresh_token
    if (accessToken && refreshToken) {
      const expiresAt = tokenRow?.oauth_expires_at
        ? new Date(tokenRow.oauth_expires_at)
        : null;
      if (expiresAt && expiresAt.getTime() < Date.now() - 60_000) {
        const refreshed = await refreshYouTubeToken(refreshToken);
        if (refreshed) {
          accessToken = refreshed.accessToken;
          if (refreshed.refreshToken) refreshToken = refreshed.refreshToken;
          if (refreshed.expiresAt) {
            await supabase
              .from("oauth_tokens")
              .update({
                access_token: refreshed.accessToken,
                refresh_token: refreshed.refreshToken,
                oauth_expires_at: refreshed.expiresAt,
                updated_at: new Date().toISOString(),
              })
              .eq("channel_id", channel.id);
          }
        }
      }
    }
  }
  const apiKey = YOUTUBE_API_KEY || channel.api_key;

  // Need either OAuth token or API key + platform_id
  if (!platformId) {
    error = "platform_id не найден";
    return { metrics: 0, publications: 0, error };
  }

  if (!apiKey && !accessToken) {
    error = "Нет API ключа или OAuth токена";
    return { metrics: 0, publications: 0, error };
  }

  try {
    // ── YouTube Data API: channel stats ──────────────────────────────
    const statsParams = new URLSearchParams({
      part: "snippet,statistics,contentDetails",
      id: platformId,
    });
    if (apiKey) statsParams.set("key", apiKey);
    const statsUrl = `https://www.googleapis.com/youtube/v3/channels?${statsParams.toString()}`;

    const statsHeaders: Record<string, string> = {};
    if (accessToken) {
      statsHeaders["Authorization"] = `Bearer ${accessToken}`;
    }

    const statsResp = await fetch(statsUrl, { headers: statsHeaders });
    const statsData = await statsResp.json();

    if (statsData.items && statsData.items.length > 0) {
      const item = statsData.items[0];
      const now = new Date().toISOString();

      // Save subscriber count snapshot
      const subscribers = parseInt(item.statistics?.subscriberCount || "0");
      await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "followers", subscribers, now);
      metrics++;

      // Save view count snapshot
      const totalViews = parseInt(item.statistics?.viewCount || "0");
      await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "total_views", totalViews, now);
      metrics++;

      // Save video count
      const videoCount = parseInt(item.statistics?.videoCount || "0");
      await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "videos", videoCount, now);
      metrics++;

      // Fetch recent videos (publications)
      const contentId = item.contentDetails?.relatedPlaylists?.uploads;
      if (contentId) {
        const videosUrl = `https://www.googleapis.com/youtube/v3/playlistItems?part=snippet&playlistId=${contentId}&maxResults=20${apiKey ? `&key=${apiKey}` : ""}`;
        const videosResp = await fetch(videosUrl);
        const videosData = await videosResp.json();

        if (videosData.items) {
          for (const videoItem of videosData.items) {
            const videoId = videoItem.snippet.resourceId?.videoId;
            if (!videoId) continue;

            // Check if already exists
            const { data: existing } = await supabase
              .from("publications")
              .select("id")
              .eq("user_id", channel.user_id)
              .eq("platform_post_id", videoId)
              .single();

            if (!existing) {
              const publishedAt = videoItem.snippet.publishedAt;
              const title = videoItem.snippet.title;
              const thumb = videoItem.snippet.thumbnails?.high?.url || videoItem.snippet.thumbnails?.default?.url;

              await supabase.from("publications").insert({
                user_id: channel.user_id,
                platform: "youtube",
                channel_id: channel.id,
                platform_post_id: videoId,
                title: title,
                content: videoItem.snippet.description,
                image_url: thumb,
                url: `https://www.youtube.com/watch?v=${videoId}`,
                published_at: publishedAt,
              });
              publications++;
            }
          }
        }
      }
    } else if (statsData.error) {
      error = `YouTube API error: ${statsData.error.message}`;
      console.error("YouTube Data API error:", statsData.error);
    }

    // ── YouTube Analytics API: real metrics ──────────────────────────
    if (accessToken) {
      try {
        const analyticsResult = await syncYouTubeAnalytics(channel, supabase, accessToken);
        metrics += analyticsResult.metrics;
      } catch (analyticsError) {
        // Analytics is optional — log but don't fail the whole sync
        console.warn("YouTube Analytics sync failed (optional):", (analyticsError as Error).message);
      }
    }
  } catch (err) {
    console.error("YouTube sync error:", err);
    if (!error) {
      error = (err as Error).message || "Unknown YouTube sync error";
    }
  }

  return { metrics, publications, error };
}

// ---------------------------------------------------------------------------
// YouTube Analytics API (requires OAuth access token)
// ---------------------------------------------------------------------------
async function syncYouTubeAnalytics(
  channel: any,
  supabase: any,
  accessToken: string,
) {
  let metrics = 0;
  const channelId = channel.platform_id;
  const now = new Date();
  const yesterday = new Date(now);
  yesterday.setDate(yesterday.getDate() - 1);
  const startDate = new Date(now);
  startDate.setDate(startDate.getDate() - 7); // Last 7 days

  const params = new URLSearchParams({
    ids: "channel==" + channelId,
    startDate: startDate.toISOString().split("T")[0],
    endDate: yesterday.toISOString().split("T")[0],
    metrics: "views,subscribersGained,subscribersLost,estimatedMinutesWatched,averageViewDuration,averageViewPercentage,likes,dislikes,comments",
    dimensions: "day",
    access_token: accessToken,
  });

  const url = `https://youtubeanalytics.googleapis.com/v2/reports?${params.toString()}`;
  const resp = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!resp.ok) {
    const errData = await resp.json().catch(() => ({}));
    throw new Error(
      `YouTube Analytics API ${resp.status}: ${errData.error?.message || resp.statusText}`,
    );
  }

  const data = await resp.json();

  if (data.rows && data.rows.length > 0) {
    // Aggregate daily metrics into totals
    let totalViews = 0;
    let totalSubscribersGained = 0;
    let totalSubscribersLost = 0;
    let totalLikes = 0;

    for (const row of data.rows) {
      // row[0] = day (dimension), row[1] = views, row[2] = subscribersGained, etc.
      totalViews += parseInt(row[1] || "0");
      totalSubscribersGained += parseInt(row[2] || "0");
      totalSubscribersLost += parseInt(row[3] || "0");
      if (row[8]) totalLikes += parseInt(row[8] || "0");
    }

    const netSubscribers = totalSubscribersGained - totalSubscribersLost;
    const dateStr = now.toISOString();

    await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "total_views_7d", totalViews, dateStr);
    metrics++;

    await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "subscribers_gained_7d", totalSubscribersGained, dateStr);
    metrics++;

    await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "subscribers_lost_7d", totalSubscribersLost, dateStr);
    metrics++;

    await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "net_subscribers_7d", netSubscribers, dateStr);
    metrics++;

    await saveSnapshot(supabase, channel.user_id, channel.id, "youtube", "likes_7d", totalLikes, dateStr);
    metrics++;

    console.log(
      `YouTube Analytics: views=${totalViews}, netSubscribers=${netSubscribers}, likes=${totalLikes}`,
    );
  }

  return { metrics };
}

// ---------------------------------------------------------------------------
// Telegram sync
// ---------------------------------------------------------------------------
async function syncTelegram(channel: any, supabase: any) {
  let metrics = 0;
  let publications = 0;
  const botToken = TELEGRAM_BOT_TOKEN || channel.api_key;
  const channelUsername = channel.platform_id;

  if (!botToken || !channelUsername) {
    return { metrics: 0, publications: 0 };
  }

  try {
    // Fetch channel info via Bot API
    const chatInfoUrl = `https://api.telegram.org/bot${botToken}/getChat?chat_id=${channelUsername}`;
    const chatResp = await fetch(chatInfoUrl);
    const chatData = await chatResp.json();

    if (chatData.ok) {
      const chat = chatData.result;
      const memberCount = chat.members_count || 0;
      const now = new Date().toISOString();

      await saveSnapshot(supabase, channel.user_id, channel.id, "telegram", "members", memberCount, now);
      metrics++;

      // Fetch recent posts (if channel has public posts)
      if (channelUsername.startsWith("@")) {
        const cleanUsername = channelUsername.substring(1);
        const historyUrl = `https://api.telegram.org/bot${botToken}/getChatMenuButton?chat_id=${channelUsername}`;
        // Note: Bot API doesn't provide post history for channels
        // We can only get member count via Bot API
      }
    }
  } catch (error) {
    console.error("Telegram sync error:", error);
  }

  return { metrics, publications };
}

// ---------------------------------------------------------------------------
// VK sync
// ---------------------------------------------------------------------------
async function syncVK(channel: any, supabase: any) {
  let metrics = 0;
  let publications = 0;
  const accessToken = VK_ACCESS_TOKEN || channel.api_key;
  const groupId = channel.platform_id;

  if (!accessToken || !groupId) {
    return { metrics: 0, publications: 0 };
  }

  try {
    // Fetch group info
    const groupUrl = `https://api.vk.com/method/groups.getById?group_id=${groupId}&fields=members_count,photo_200&v=5.131&access_token=${accessToken}`;
    const groupResp = await fetch(groupUrl);
    const groupData = await groupResp.json();

    if (groupData.response && groupData.response.length > 0) {
      const group = groupData.response[0];
      const now = new Date().toISOString();

      const members = group.members_count || 0;
      await saveSnapshot(supabase, channel.user_id, channel.id, "vk", "members", members, now);
      metrics++;

      // Fetch recent posts
      const postsUrl = `https://api.vk.com/method/wall.get?owner_id=-${groupId}&count=20&v=5.131&access_token=${accessToken}`;
      const postsResp = await fetch(postsUrl);
      const postsData = await postsResp.json();

      if (postsData.response && postsData.response.items) {
        for (const post of postsData.response.items) {
          const { data: existing } = await supabase
            .from("publications")
            .select("id")
            .eq("user_id", channel.user_id)
            .eq("platform_post_id", `${post.owner_id}_${post.id}`)
            .single();

          if (!existing) {
            const publishedAt = new Date(post.date * 1000).toISOString();
            const text = post.text || "";
            const photo = post.attachments?.find((a: any) => a.type === "photo")?.photo?.photo_604;

            await supabase.from("publications").insert({
              user_id: channel.user_id,
              platform: "vk",
              channel_id: channel.id,
              platform_post_id: `${post.owner_id}_${post.id}`,
              title: text.substring(0, 100),
              content: text,
              image_url: photo,
              url: `https://vk.com/wall-${groupId}_${post.id}`,
              published_at: publishedAt,
            });
            publications++;
          }
        }
      }
    }
  } catch (error) {
    console.error("VK sync error:", error);
  }

  return { metrics, publications };
}

// ---------------------------------------------------------------------------
// GitHub sync
// ---------------------------------------------------------------------------
async function syncGitHub(channel: any, supabase: any) {
  let metrics = 0;
  let publications = 0;
  const token = GITHUB_TOKEN || channel.api_key;
  const repoName = channel.platform_id;

  if (!token || !repoName) {
    return { metrics: 0, publications: 0 };
  }

  try {
    const headers = {
      Authorization: `Bearer ${token}`,
      "Accept": "application/vnd.github.v3+json",
    };

    // Fetch repo info
    const repoUrl = `https://api.github.com/repos/${repoName}`;
    const repoResp = await fetch(repoUrl, { headers });
    const repoData = await repoResp.json();

    if (repoData.id) {
      const now = new Date().toISOString();

      const stars = repoData.stargazers_count || 0;
      await saveSnapshot(supabase, channel.user_id, channel.id, "github", "stars", stars, now);
      metrics++;

      const forks = repoData.forks_count || 0;
      await saveSnapshot(supabase, channel.user_id, channel.id, "github", "forks", forks, now);
      metrics++;

      const watchers = repoData.subscribers_count || 0;
      await saveSnapshot(supabase, channel.user_id, channel.id, "github", "watchers", watchers, now);
      metrics++;

      // Fetch releases as publications
      const releasesUrl = `https://api.github.com/repos/${repoName}/releases?per_page=20`;
      const releasesResp = await fetch(releasesUrl, { headers });
      const releasesData = await releasesResp.json();

      if (Array.isArray(releasesData)) {
        for (const release of releasesData) {
          const { data: existing } = await supabase
            .from("publications")
            .select("id")
            .eq("user_id", channel.user_id)
            .eq("platform_post_id", `github_${release.id}`)
            .single();

          if (!existing) {
            await supabase.from("publications").insert({
              user_id: channel.user_id,
              platform: "github",
              channel_id: channel.id,
              platform_post_id: `github_${release.id}`,
              title: release.name || release.tag_name,
              content: release.body,
              image_url: release.assets?.[0]?.browser_download_url,
              url: release.html_url,
              published_at: release.published_at,
            });
            publications++;
          }
        }
      }
    }
  } catch (error) {
    console.error("GitHub sync error:", error);
  }

  return { metrics, publications };
}

// ---------------------------------------------------------------------------
// YouTube token refresh
// ---------------------------------------------------------------------------
async function refreshYouTubeToken(refreshToken: string): Promise<{
  accessToken: string;
  refreshToken?: string;
  expiresAt?: string;
} | null> {
  const redirectUri = `${SUPABASE_URL}/functions/v1/platform-oauth-callback`;
  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });
  const data = await resp.json();
  if (!data.access_token) {
    console.error("YouTube token refresh failed:", data);
    return null;
  }
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token ?? refreshToken,
    expiresAt: data.expires_in
      ? new Date(Date.now() + data.expires_in * 1000).toISOString()
      : undefined,
  };
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------
async function saveSnapshot(
  supabase: any,
  userId: string,
  channelId: string,
  platform: string,
  metric: string,
  value: number,
  now: string
) {
  // Check if a snapshot for this channel/metric/date already exists
  const dateOnly = now.substring(0, 10);
  const { data: existing } = await supabase
    .from("analytics_snapshots")
    .select("id")
    .eq("user_id", userId)
    .eq("channel_id", channelId)
    .eq("metric", metric)
    .eq("date", dateOnly)
    .single();

  if (!existing) {
    await supabase.from("analytics_snapshots").insert({
      user_id: userId,
      channel_id: channelId,
      platform,
      metric,
      value,
      date: dateOnly,
      recorded_at: now,
      source: "api",
      reliability: "api",
    });
  }
}
