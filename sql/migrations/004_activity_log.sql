-- MediaCRM — activity_log table migration
-- Supabase / PostgreSQL
--
-- Source of truth: ActivityService.log() in lib/data/repositories/entity_repository.dart
-- Consumer: ActivityLogEntry.fromJson in lib/data/models/notification_item.dart
-- Readers: settings_screen.dart (line 211), analytics_repository.dart (line 272)

-- Ensure UUID extension is available
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLE: activity_log
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  action TEXT NOT NULL,
  title TEXT NOT NULL,
  details TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Users can read only their own activity log entries
CREATE POLICY "Users can read own activity log"
  ON activity_log FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own activity log entries
CREATE POLICY "Users can insert own activity log"
  ON activity_log FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update only their own activity log entries
CREATE POLICY "Users can update own activity log"
  ON activity_log FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete only their own activity log entries
CREATE POLICY "Users can delete own activity log"
  ON activity_log FOR DELETE
  USING (auth.uid() = user_id);

-- ============================================================
-- INDEXES
-- ============================================================
-- Fast lookup by user (used by CloudService push/pull and UI)
CREATE INDEX IF NOT EXISTS idx_activity_log_user
  ON activity_log(user_id);

-- Fast sorting by created_at DESC (used by settings_screen and analytics_repository)
CREATE INDEX IF NOT EXISTS idx_activity_log_created
  ON activity_log(created_at DESC);
