-- MediaCRM — Migration 008: Add missing platform_channels columns
-- Adds 'url' and 'settings' columns required by the Flutter PlatformChannel model.
-- Migrates existing 'slug' data into 'url' for backwards compatibility.

-- 1. Add 'url' column (used by Flutter model for channel link display)
ALTER TABLE platform_channels
  ADD COLUMN IF NOT EXISTS url TEXT;

-- 2. Migrate existing 'slug' values into 'url' for backwards compatibility
UPDATE platform_channels
  SET url = slug
  WHERE slug IS NOT NULL AND url IS NULL;

-- 3. Add 'settings' column (JSONB for platform-specific settings)
ALTER TABLE platform_channels
  ADD COLUMN IF NOT EXISTS settings JSONB DEFAULT '{}';

-- 4. Ensure NOT NULL constraints for required fields
-- name is already NOT NULL from migration 001
-- Add NOT NULL with default for url to prevent Flutter parse errors
ALTER TABLE platform_channels
  ALTER COLUMN url SET DEFAULT '';
