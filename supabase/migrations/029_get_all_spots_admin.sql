-- ──────────────────────────────────────────────────────────────
-- 029_get_all_spots_admin.sql
-- get_all_spots_admin: 전체 카페 조회 (관리자용, 검색 필터 지원)
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_all_spots_admin(search_query TEXT DEFAULT NULL)
RETURNS TABLE (
  id              UUID,
  name            TEXT,
  formatted_address TEXT,
  lat             FLOAT,
  lng             FLOAT,
  report_count    INT,
  created_at      TIMESTAMPTZ
)
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT
    s.id,
    s.name,
    s.formatted_address,
    ST_Y(s.location::geometry) AS lat,
    ST_X(s.location::geometry) AS lng,
    s.report_count,
    s.created_at
  FROM spots s
  WHERE search_query IS NULL OR s.name ILIKE '%' || search_query || '%'
  ORDER BY s.created_at DESC
  LIMIT 200;
$$;

GRANT EXECUTE ON FUNCTION get_all_spots_admin TO anon;
