-- ============================================================
-- Cafe Vibe — Initial Schema Migration
-- Run this in: Supabase Dashboard → SQL Editor
-- Prerequisites: Enable PostGIS extension first (Extensions tab)
-- ============================================================

-- 1. Enable PostGIS spatial extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 2. spots table
-- ============================================================
CREATE TABLE spots (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                   TEXT NOT NULL,
  google_place_id        TEXT,                             -- Hybrid DB Strategy: stored once from Places API
  location               GEOGRAPHY(Point, 4326) NOT NULL, -- PostGIS spatial column
  average_db             FLOAT NOT NULL DEFAULT 0,
  representative_sticker TEXT CHECK (representative_sticker IN ('STUDY', 'MEETING', 'RELAX')),
  report_count           INT NOT NULL DEFAULT 0,
  trust_score            FLOAT NOT NULL DEFAULT 0,        -- 0=None, 1=Bronze, 2=Silver, 3=Gold
  last_report_at         TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Spatial index (GIST) — essential for ST_DWithin performance
CREATE INDEX idx_spots_location ON spots USING GIST(location);

-- Unique index on google_place_id — prevents duplicate spots from same Place
CREATE UNIQUE INDEX idx_spots_place_id ON spots(google_place_id)
  WHERE google_place_id IS NOT NULL;

-- Index for filtering out stale spots
CREATE INDEX idx_spots_last_report ON spots(last_report_at DESC NULLS LAST);

-- ============================================================
-- 3. reports table
-- ============================================================
CREATE TABLE reports (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  spot_id          UUID NOT NULL REFERENCES spots(id) ON DELETE CASCADE,
  -- Only the dB number is stored — audio is NEVER recorded or transmitted
  measured_db      FLOAT NOT NULL CHECK (measured_db >= 0 AND measured_db < 120),
  selected_sticker TEXT NOT NULL CHECK (selected_sticker IN ('STUDY', 'MEETING', 'RELAX')),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Performance indexes
CREATE INDEX idx_reports_spot_id ON reports(spot_id);
CREATE INDEX idx_reports_user_id ON reports(user_id);
CREATE INDEX idx_reports_created_at ON reports(created_at DESC);
-- Composite: enables recent count per spot in a single scan
CREATE INDEX idx_reports_spot_recent ON reports(spot_id, created_at DESC);

-- ============================================================
-- 4. Row Level Security
-- ============================================================
ALTER TABLE spots ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Spots: public read, authenticated insert
CREATE POLICY "spots_read_all"
  ON spots FOR SELECT USING (true);

CREATE POLICY "spots_insert_auth"
  ON spots FOR INSERT TO authenticated WITH CHECK (true);

-- Reports: public read, authenticated insert for own rows
CREATE POLICY "reports_read_all"
  ON reports FOR SELECT USING (true);

CREATE POLICY "reports_insert_own"
  ON reports FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 5. get_spots_near — radius query RPC using PostGIS ST_DWithin
-- Returns spots within radius, excluding 30-day inactive spots.
-- Includes recent_24h_count for Social Proof display.
-- ============================================================
CREATE OR REPLACE FUNCTION get_spots_near(
  user_lat        FLOAT,
  user_lng        FLOAT,
  radius_meters   FLOAT DEFAULT 3000,
  filter_sticker  TEXT DEFAULT NULL
)
RETURNS TABLE (
  id                     UUID,
  name                   TEXT,
  lat                    FLOAT,
  lng                    FLOAT,
  average_db             FLOAT,
  representative_sticker TEXT,
  report_count           INT,
  trust_score            FLOAT,
  recent_24h_count       INT,
  last_report_at         TIMESTAMPTZ
)
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT
    s.id,
    s.name,
    ST_Y(s.location::geometry)  AS lat,
    ST_X(s.location::geometry)  AS lng,
    s.average_db,
    s.representative_sticker,
    s.report_count,
    s.trust_score,
    COUNT(r.id) FILTER (
      WHERE r.created_at > NOW() - INTERVAL '24 hours'
    )::INT                       AS recent_24h_count,
    s.last_report_at
  FROM spots s
  LEFT JOIN reports r ON r.spot_id = s.id
  WHERE
    ST_DWithin(
      s.location,
      ST_MakePoint(user_lng, user_lat)::geography,
      LEAST(radius_meters, 5000)   -- Hard cap: 5km max
    )
    -- Exclude spots with no activity in the last 30 days
    AND (
      s.last_report_at IS NULL
      OR s.last_report_at > NOW() - INTERVAL '30 days'
    )
    AND (filter_sticker IS NULL OR s.representative_sticker = filter_sticker)
  GROUP BY s.id
  ORDER BY ST_Distance(
    s.location,
    ST_MakePoint(user_lng, user_lat)::geography
  )
  LIMIT 100;
$$;

-- ============================================================
-- 6. update_spot_after_report — EMA average update RPC
-- Formula: NewAvg = (OldAvg × 0.7) + (NewDb × 0.3)
-- Also updates trust_score grade based on report_count.
-- ============================================================
CREATE OR REPLACE FUNCTION update_spot_after_report(
  p_spot_id   UUID,
  p_new_db    FLOAT,
  p_sticker   TEXT,
  p_user_id   UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_old_avg     FLOAT;
  v_new_avg     FLOAT;
  v_count       INT;
  v_trust       FLOAT;
BEGIN
  -- Lock the row to prevent concurrent update races
  SELECT average_db, report_count
  INTO v_old_avg, v_count
  FROM spots
  WHERE id = p_spot_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Spot % not found', p_spot_id;
  END IF;

  -- EMA: first report uses the raw value directly
  v_new_avg := CASE
    WHEN v_count = 0 THEN p_new_db
    ELSE (v_old_avg * 0.7) + (p_new_db * 0.3)
  END;

  -- Trust score grade (report count includes the new one)
  v_trust := CASE
    WHEN v_count + 1 >= 50 THEN 3   -- Gold
    WHEN v_count + 1 >= 20 THEN 2   -- Silver
    WHEN v_count + 1 >= 5  THEN 1   -- Bronze
    ELSE 0
  END;

  UPDATE spots SET
    average_db             = v_new_avg,
    report_count           = v_count + 1,
    representative_sticker = p_sticker,
    trust_score            = v_trust,
    last_report_at         = NOW()
  WHERE id = p_spot_id;
END;
$$;
