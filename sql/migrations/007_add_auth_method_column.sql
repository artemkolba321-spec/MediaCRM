-- MediaCRM — Add auth_method column to platform_channels
-- This column tracks how credentials were obtained (oauth, botToken, accessToken, etc.)
-- It is set by Edge Functions during OAuth/connect flows.

ALTER TABLE platform_channels
  ADD COLUMN IF NOT EXISTS auth_method TEXT DEFAULT 'none';

-- Backfill existing rows that already have credentials
UPDATE platform_channels
  SET auth_method = 'oauth'
  WHERE has_credentials = true
    AND auth_method IS NULL;
