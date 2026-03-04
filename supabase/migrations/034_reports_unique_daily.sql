-- ──────────────────────────────────────────────────────────────
-- 034_reports_unique_daily.sql
-- 리포트 하루 1회 제한 — DB 레벨 UNIQUE 인덱스 추가
-- 기존: 앱 레이어 체크만 → 동시 요청으로 중복 INSERT 가능
-- 수정: (user_id, spot_id, UTC 날짜) 조합 고유 인덱스
--
-- NOTE: created_at::date 는 IMMUTABLE 표현식이므로 인덱스 사용 가능.
-- 앱은 이미 24h 체크를 수행하므로 이 인덱스는 2차 방어선.
-- ──────────────────────────────────────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS reports_user_spot_daily_unique
  ON reports (user_id, spot_id, (created_at::date));
