-- MediaCRM — Allow anonymous sign-in in Supabase Auth
-- Run this in Supabase Dashboard → SQL Editor

-- Enable anonymous sign-in for the project
-- This is a project-level setting, not a table change.
-- It allows client apps to call auth.signInAnonymously().

-- Note: This setting is applied via Supabase Dashboard:
--   Authentication → Providers → Anonymous → Enable
-- Or via the Supabase CLI:
--   supabase secrets set SUPABASE_ANON_KEY=<key>
-- The API endpoint to enable it:
--   PUT https://<project-ref>.supabase.co/rest/v1/
--   Headers: apikey=<anon_key>, Authorization=Bearer <anon_key>
--   Body: {"enabled": true}
--
-- However, the simplest way is through the Dashboard:
--   Settings → Authentication → Enable "Allow sign up with anonymous users"

-- RLS policies already protect data via auth.uid() = user_id.
-- Anonymous users get a valid UUID as auth.uid(), so all existing
-- RLS policies work without changes.

-- Optional: Add a column to profiles to track anonymous users
-- This helps distinguish anonymous from permanent accounts.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;

-- Update existing profiles to be non-anonymous
UPDATE profiles SET is_anonymous = false WHERE is_anonymous IS NULL;
