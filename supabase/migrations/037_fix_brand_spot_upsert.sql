-- ──────────────────────────────────────────────────────────────
-- 037_fix_brand_spot_upsert.sql
-- 잘못된 좌표 스팟 정리 + 스마트 upsert 함수
--
-- 문제: ignoreDuplicates=true (ON CONFLICT DO NOTHING) → 잘못된
--       좌표로 저장된 스팟이 영구 고착; 재발견 시 수정 불가
-- 해결:
--   1. 신고 0건 · Places API 발견 스팟 삭제 (잘못된 좌표 포함)
--      → 다음 _discoverNearbyCafes에서 정확한 좌표로 재등록
--   2. upsert_brand_spots_v2(): ON CONFLICT DO UPDATE SET location
--      → 재발견 시 Google Places의 권위 있는 좌표로 갱신
--      → report_count / average_db / trust_score 는 건드리지 않음
-- ──────────────────────────────────────────────────────────────

-- 1. 신고 이력 없는 Places API 스팟 삭제 (안전: 사용자 데이터 없음)
DELETE FROM spots
WHERE report_count = 0
  AND google_place_id IS NOT NULL
  AND last_report_at IS NULL;

-- 2. 스마트 upsert 함수 (배열 JSON 처리)
DROP FUNCTION IF EXISTS upsert_brand_spots_v2(JSONB);

CREATE OR REPLACE FUNCTION upsert_brand_spots_v2(places JSONB)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  p   JSONB;
  cnt INT := 0;
BEGIN
  FOR p IN SELECT jsonb_array_elements(places) LOOP
    INSERT INTO spots (
      name, google_place_id, location, formatted_address,
      average_db, report_count, trust_score
    ) VALUES (
      p->>'name',
      p->>'google_place_id',
      ST_MakePoint((p->>'lng')::FLOAT, (p->>'lat')::FLOAT)::geography,
      p->>'formatted_address',
      0, 0, 0
    )
    ON CONFLICT (google_place_id) DO UPDATE SET
      name             = EXCLUDED.name,
      location         = EXCLUDED.location,
      formatted_address = COALESCE(EXCLUDED.formatted_address, spots.formatted_address);
      -- report_count / average_db / trust_score / last_report_at: 갱신 안 함
    cnt := cnt + 1;
  END LOOP;
  RETURN cnt;
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_brand_spots_v2 TO anon;
