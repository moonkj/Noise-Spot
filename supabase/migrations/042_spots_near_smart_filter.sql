-- ──────────────────────────────────────────────────────────────
-- 042_spots_near_smart_filter.sql
-- get_spots_near: 스마트 표시 조건
--   · report_count >= 1 → last_report_at 기준 30일 이내 활성 스팟
--   · report_count = 0  → created_at 기준 7일 이내만 표시
--     (신규 발견 카페는 1주일 동안 표시, 그 이후 측정 없으면 자동 숨김)
-- ──────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS get_spots_near(FLOAT, FLOAT, FLOAT, TEXT);

CREATE OR REPLACE FUNCTION get_spots_near(
  user_lat        FLOAT,
  user_lng        FLOAT,
  radius_meters   FLOAT DEFAULT 3000,
  filter_sticker  TEXT DEFAULT NULL
)
RETURNS TABLE (
  id                     UUID,
  name                   TEXT,
  google_place_id        TEXT,
  formatted_address      TEXT,
  lat                    FLOAT,
  lng                    FLOAT,
  average_db             FLOAT,
  representative_sticker TEXT,
  report_count           INT,
  trust_score            FLOAT,
  recent_24h_count       INT,
  last_report_at         TIMESTAMPTZ,
  photo_url              TEXT
)
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT
    s.id,
    s.name,
    s.google_place_id,
    s.formatted_address,
    ST_Y(s.location::geometry)  AS lat,
    ST_X(s.location::geometry)  AS lng,
    s.average_db,
    s.representative_sticker,
    s.report_count,
    s.trust_score,
    COUNT(r.id) FILTER (
      WHERE r.created_at > NOW() - INTERVAL '24 hours'
    )::INT                       AS recent_24h_count,
    s.last_report_at,
    s.photo_url
  FROM spots s
  LEFT JOIN reports r ON r.spot_id = s.id
  WHERE
    ST_DWithin(
      s.location,
      ST_MakePoint(user_lng, user_lat)::geography,
      LEAST(radius_meters, 5000)
    )
    AND (
      -- 측정 기록 있는 스팟: 최근 30일 이내 활성
      (s.report_count >= 1 AND s.last_report_at > NOW() - INTERVAL '30 days')
      OR
      -- 신규 발견 스팟(측정 0회): 등록 후 7일 이내만 표시
      (s.report_count = 0 AND s.created_at > NOW() - INTERVAL '7 days')
    )
    AND (filter_sticker IS NULL OR s.representative_sticker = filter_sticker)
  GROUP BY s.id
  ORDER BY ST_Distance(
    s.location,
    ST_MakePoint(user_lng, user_lat)::geography
  );
$$;

GRANT EXECUTE ON FUNCTION get_spots_near TO anon;

-- ──────────────────────────────────────────────────────────────
-- 기존 비카페 스팟 직접 삭제 (PC방·의류점·침구점 등)
-- ──────────────────────────────────────────────────────────────
DELETE FROM spots
WHERE report_count = 0
  AND (
    name ILIKE '%PC%'
    OR name ILIKE '%옷%'
    OR name ILIKE '%의류%'
    OR name ILIKE '%광목%'
    OR name ILIKE '%침구%'
    OR name ILIKE '%가구%'
    OR name ILIKE '%마사지%'
    OR name ILIKE '%안마%'
    OR name ILIKE '%헬스%'
    OR name ILIKE '%세탁%'
    OR name ILIKE '%미용실%'
  );
