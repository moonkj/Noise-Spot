-- ──────────────────────────────────────────────────────────────
-- 024_admin_photo_management.sql
-- 관리자용 전체 스팟 조회 RPC (사진 URL 관리용)
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION get_admin_photo_spots()
RETURNS TABLE (
  id                UUID,
  name              TEXT,
  google_place_id   TEXT,
  formatted_address TEXT,
  photo_url         TEXT,
  report_count      INT,
  created_at        TIMESTAMPTZ
)
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT
    s.id,
    s.name,
    s.google_place_id,
    s.formatted_address,
    s.photo_url,
    s.report_count,
    s.created_at
  FROM spots s
  ORDER BY s.created_at DESC
  LIMIT 500;
$$;

GRANT EXECUTE ON FUNCTION get_admin_photo_spots TO authenticated;
