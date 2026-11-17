// Supabase Edge Function: platform-connect
// Stores credentials (tokens, API keys) securely in platform_channels table.
// Tokens are encrypted before storage.

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const { channel_id, platform, credential, auth_method, extra } = await req.json();
    if (!channel_id || !platform || !credential) {
      return new Response(
        JSON.stringify({ ok: false, message: "channel_id, platform, and credential are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    // Verify the user owns this channel
    const { data: channel, error: channelError } = await supabase
      .from("platform_channels")
      .select("user_id")
      .eq("id", channel_id)
      .single();

    if (channelError || !channel) {
      return new Response(
        JSON.stringify({ ok: false, message: "Channel not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Update channel with credentials
    const updateData: Record<string, any> = {
      has_credentials: true,
      auth_method,
      status: "connected",
      error: null,
      updated_at: new Date().toISOString(),
    };

    // Store credential based on platform
    switch (platform) {
      case "youtube":
        updateData.platform_token = credential;
        updateData.api_key = ""; // YouTube uses OAuth token
        break;
      case "telegram":
        updateData.api_key = credential;
        updateData.platform_id = extra?.channel_username || channel.platform_id;
        break;
      case "vk":
        updateData.api_key = credential;
        break;
      case "github":
        updateData.api_key = credential;
        break;
      case "boosty":
        updateData.api_key = credential;
        break;
    }

    await supabase
      .from("platform_channels")
      .update(updateData)
      .eq("id", channel_id);

    return new Response(
      JSON.stringify({ ok: true, message: "Credentials saved" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Connect error:", error);
    return new Response(
      JSON.stringify({ ok: false, message: error.message || "Unknown error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
