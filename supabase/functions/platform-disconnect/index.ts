// Supabase Edge Function: platform-disconnect
// Removes credentials from a channel and marks it as disconnected.

import { serve } from "https://deno.land/std@0.208.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  try {
    const { channel_id } = await req.json();
    if (!channel_id) {
      return new Response(
        JSON.stringify({ ok: false, message: "channel_id is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE);

    await supabase
      .from("platform_channels")
      .update({
        has_credentials: false,
        auth_method: "none",
        status: "disconnected",
        platform_token: null,
        api_key: null,
        error: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", channel_id);

    return new Response(
      JSON.stringify({ ok: true, message: "Channel disconnected" }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Disconnect error:", error);
    return new Response(
      JSON.stringify({ ok: false, message: error.message || "Unknown error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
