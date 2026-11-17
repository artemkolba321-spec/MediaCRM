-- MediaCRM — Add OAuth token expiry and refresh_token columns
-- Supabase / PostgreSQL

ALTER TABLE platform_channels
  ADD COLUMN IF NOT EXISTS refresh_token TEXT,
  ADD COLUMN IF NOT EXISTS oauth_expires_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS has_credentials BOOLEAN DEFAULT false;

-- Ensure has_credentials has a default for existing rows
UPDATE platform_channels SET has_credentials = true
  WHERE (platform_token IS NOT NULL OR api_key IS NOT NULL) AND has_credentials IS NULL;
