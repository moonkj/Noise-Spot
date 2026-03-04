-- ──────────────────────────────────────────────────────────────
-- 034_reports_unique_daily.sql
-- 리포트 하루 1회 제한 — DB 레벨 트리거 (2차 방어선)
-- 기존: 앱 레이어 체크만 → 동시 요청으로 중복 INSERT 가능
-- 수정: BEFORE INSERT 트리거로 같은 날(UTC) 동일 스팟 중복 차단
--
-- NOTE: created_at::date 는 STABLE (session timezone 의존) 이므로
-- UNIQUE 인덱스 표현식 사용 불가 → 트리거 방식으로 동일 효과 구현.
-- 앱은 이미 24h 체크를 수행하므로 이 트리거는 2차 방어선.
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION check_report_daily_unique()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  dup_count INT;
BEGIN
  SELECT COUNT(*) INTO dup_count
    FROM reports
   WHERE user_id  = NEW.user_id
     AND spot_id  = NEW.spot_id
     AND created_at::date = NOW()::date;

  IF dup_count > 0 THEN
    RAISE EXCEPTION 'duplicate_daily_report'
      USING HINT = '오늘은 이미 이 스팟을 측정했습니다.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS report_daily_unique ON reports;

CREATE TRIGGER report_daily_unique
  BEFORE INSERT ON reports
  FOR EACH ROW
  EXECUTE FUNCTION check_report_daily_unique();
