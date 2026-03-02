-- 카페 추가 요청 테이블
CREATE TABLE IF NOT EXISTS cafe_requests (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  cafe_name   TEXT        NOT NULL,
  address     TEXT,
  note        TEXT,
  status      TEXT        NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE cafe_requests ENABLE ROW LEVEL SECURITY;

-- 로그인 사용자는 자신의 요청 삽입 가능
CREATE POLICY "users can insert own requests"
  ON cafe_requests FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- 사용자는 자신의 요청만 조회 가능
CREATE POLICY "users can read own requests"
  ON cafe_requests FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- 서비스 롤(admin)은 모든 요청 조회/수정 가능
CREATE POLICY "service role full access"
  ON cafe_requests FOR ALL TO service_role
  USING (true) WITH CHECK (true);
