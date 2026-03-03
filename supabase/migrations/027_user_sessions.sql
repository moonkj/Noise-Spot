-- ──────────────────────────────────────────────────────────────
-- 027_user_sessions.sql
-- 앱 접속 통계: user_sessions 테이블 + record/query RPCs
-- ──────────────────────────────────────────────────────────────

-- 유저 일별 접속 기록 (user_id + date 쌍으로 중복 제거)
CREATE TABLE IF NOT EXISTS user_sessions (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date    DATE NOT NULL DEFAULT CURRENT_DATE,
  PRIMARY KEY (user_id, date)
);

-- 인덱스: 날짜 기준 집계 쿼리 최적화
CREATE INDEX IF NOT EXISTS user_sessions_date_idx ON user_sessions(date);

-- RLS 활성화
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- 유저는 자신의 세션만 조회 가능 (관리자 통계는 SECURITY DEFINER RPC로)
CREATE POLICY "Users can insert own session"
  ON user_sessions FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- ── RPC 1: 앱 오픈 시 세션 기록 (any authenticated user) ──────────
CREATE OR REPLACE FUNCTION record_user_session()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN; END IF;
  INSERT INTO user_sessions (user_id, date)
  VALUES (auth.uid(), CURRENT_DATE)
  ON CONFLICT (user_id, date) DO NOTHING;
END;
$$;

GRANT EXECUTE ON FUNCTION record_user_session TO authenticated;

-- ── RPC 2: 관리자 통계 조회 ─────────────────────────────────────────
-- DAU  = 오늘 접속 unique 유저 수
-- WAU  = 최근 7일(오늘 포함) unique 유저 수
-- MAU  = 최근 30일(오늘 포함) unique 유저 수
-- total = 누적 unique 유저 수
CREATE OR REPLACE FUNCTION get_admin_user_stats()
RETURNS TABLE (
  dau   INT,
  wau   INT,
  mau   INT,
  total INT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    (SELECT COUNT(DISTINCT user_id)::INT FROM user_sessions
      WHERE date = CURRENT_DATE)                           AS dau,
    (SELECT COUNT(DISTINCT user_id)::INT FROM user_sessions
      WHERE date >= CURRENT_DATE - 6)                     AS wau,
    (SELECT COUNT(DISTINCT user_id)::INT FROM user_sessions
      WHERE date >= CURRENT_DATE - 29)                    AS mau,
    (SELECT COUNT(DISTINCT user_id)::INT FROM user_sessions) AS total;
$$;

GRANT EXECUTE ON FUNCTION get_admin_user_stats TO authenticated;
