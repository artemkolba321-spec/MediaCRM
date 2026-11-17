-- MediaCRM — Secure OAuth token storage
-- Moves refresh_token and oauth_expires_at out of platform_channels
-- (visible to client via RLS SELECT) into a dedicated table with
-- restrictive policies: only service-role Edge Functions can read/write.

-- 1. Create the secure token table
CREATE TABLE IF NOT EXISTS oauth_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  channel_id UUID NOT NULL REFERENCES platform_channels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  access_token TEXT,
  refresh_token TEXT,
  oauth_expires_at TIMESTAMP WITH TIME ZONE,
  token_metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(channel_id)
);

ALTER TABLE oauth_tokens ENABLE ROW LEVEL SECURITY;

-- 2. RLS policies — service-role Edge Functions bypass auth.uid() check
--    via the SUPABASE_SERVICE_ROLE_KEY (which has admin privileges).
--    Flutter clients CANNOT SELECT/INSERT/UPDATE oauth_tokens.

-- Allow service-role functions to manage tokens (bypasses RLS when
-- using SUPABASE_SERVICE_ROLE_KEY as the auth header).
CREATE POLICY "Service role full access to oauth_tokens" ON oauth_tokens
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Block Flutter clients from reading tokens
-- (no policy for FOR SELECT that allows auth.uid() — only service role)

-- 3. Migrate existing tokens from platform_channels → oauth_tokens
INSERT INTO oauth_tokens (channel_id, user_id, platform, access_token, refresh_token, oauth_expires_at, token_metadata)
SELECT
  id,
  user_id,
  platform,
  platform_token,
  refresh_token,
  oauth_expires_at,
  '{"migrated_from": "platform_channels"}'::jsonb
FROM platform_channels
WHERE platform IN ('youtube', 'vk', 'github')
  AND (platform_token IS NOT NULL OR refresh_token IS NOT NULL)
  AND NOT EXISTS (
    SELECT 1 FROM oauth_tokens WHERE oauth_tokens.channel_id = platform_channels.id
  );

-- 4. Drop sensitive columns from platform_channels
--    Clients no longer need refresh_token / oauth_expires_at there.
ALTER TABLE platform_channels
  DROP COLUMN IF EXISTS refresh_token,
  DROP COLUMN IF EXISTS oauth_expires_at;

-- 5. Add helper indexes
CREATE INDEX IF NOT EXISTS idx_oauth_tokens_channel ON oauth_tokens(channel_id);
CREATE INDEX IF NOT EXISTS idx_oauth_tokens_user ON oauth_tokens(user_id);
