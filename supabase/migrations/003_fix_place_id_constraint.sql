-- ============================================================
-- Migration 003: Replace partial unique index with proper UNIQUE constraint
-- This allows ON CONFLICT (google_place_id) DO NOTHING to work correctly
-- in Supabase PostgREST upsert calls.
-- ============================================================

-- Drop the partial unique index (partial indexes can't be used as upsert targets)
DROP INDEX IF EXISTS idx_spots_place_id;

-- Add a proper UNIQUE constraint (PostgreSQL allows multiple NULLs by default)
ALTER TABLE spots
  ADD CONSTRAINT spots_google_place_id_key UNIQUE (google_place_id);

-- ============================================================
-- Allow anon role to INSERT spots (venue/place data is public)
-- Required because cafe discovery runs before auth session may be
-- fully established (MapController builds immediately on tab load).
-- ============================================================
CREATE POLICY "spots_insert_anon"
  ON spots FOR INSERT TO anon WITH CHECK (true);
