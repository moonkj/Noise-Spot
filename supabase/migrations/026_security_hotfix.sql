-- ──────────────────────────────────────────────────────────────
-- 026_security_hotfix.sql
-- Phase 32 보안 핫픽스 — 리뷰에서 발견된 Critical/Warning 이슈 일괄 수정
-- ──────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════
-- [SEC-NEW-02] 🔴 spots 테이블 anon INSERT 차단
-- 비인증 사용자가 가짜 스팟을 무제한 삽입 가능했음
-- ═══════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "spots_insert_anon" ON spots;

-- ═══════════════════════════════════════════════════════════════
-- [SEC-NEW-01] 🔴 get_admin_photo_spots() — 어드민 인증 체크 추가
-- 기존: 모든 authenticated 유저가 호출 가능 (SECURITY DEFINER)
-- 수정: 함수 내부에서 admin UUID 확인
-- ═══════════════════════════════════════════════════════════════
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
LANGUAGE plpgsql STABLE
SECURITY DEFINER
AS $$
BEGIN
  -- 어드민 UUID 확인
  IF auth.uid() IS NULL
     OR auth.uid() != 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid
  THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  RETURN QUERY
    SELECT s.id, s.name, s.google_place_id, s.formatted_address,
           s.photo_url, s.report_count, s.created_at
    FROM spots s
    ORDER BY s.created_at DESC
    LIMIT 500;
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- [SEC-NEW-03 / N-007] 🟡 get_spots_by_ids — anon 권한 제거 + 배열 제한 + photo_url 추가
-- 기존: anon도 호출 가능, 배열 크기 무제한, photo_url 컬럼 없음
-- ═══════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS get_spots_by_ids(TEXT[]);

CREATE OR REPLACE FUNCTION get_spots_by_ids(p_ids TEXT[])
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
  photo_url              TEXT           -- ← 신규 추가
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    s.id,
    s.name,
    s.google_place_id,
    s.formatted_address,
    ST_Y(s.location::geometry)::FLOAT AS lat,
    ST_X(s.location::geometry)::FLOAT AS lng,
    s.average_db,
    s.representative_sticker,
    s.report_count,
    s.trust_score,
    COALESCE(
      (SELECT COUNT(*)::INT FROM reports r
       WHERE r.spot_id = s.id
         AND r.created_at >= NOW() - INTERVAL '24 hours'),
      0
    ) AS recent_24h_count,
    s.last_report_at,
    s.photo_url               -- ← 신규 추가
  FROM spots s
  WHERE s.id::TEXT = ANY(p_ids[1:500]);  -- 최대 500개 제한
$$;

-- anon 제거, authenticated만 허용
GRANT EXECUTE ON FUNCTION get_spots_by_ids TO authenticated;
