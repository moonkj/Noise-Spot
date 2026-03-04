-- ──────────────────────────────────────────────────────────────
-- 035_cafe_request_rate_limit.sql
-- 카페 추가 요청 서버 rate limiting — 24시간 최대 3회
-- 기존: 클라이언트 SharedPreferences 전용 → 우회 가능
-- 수정: DB 트리거로 INSERT 직전 횟수 검사
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION check_cafe_request_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  recent_count INT;
BEGIN
  SELECT COUNT(*) INTO recent_count
    FROM cafe_requests
   WHERE user_id = auth.uid()
     AND created_at > NOW() - INTERVAL '24 hours';

  IF recent_count >= 3 THEN
    RAISE EXCEPTION 'rate_limit_exceeded'
      USING HINT = '24시간 내 최대 3건까지 요청할 수 있습니다.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cafe_request_rate_limit ON cafe_requests;

CREATE TRIGGER cafe_request_rate_limit
  BEFORE INSERT ON cafe_requests
  FOR EACH ROW
  EXECUTE FUNCTION check_cafe_request_rate_limit();
