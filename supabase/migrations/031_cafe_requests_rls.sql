-- ──────────────────────────────────────────────────────────────
-- 031_cafe_requests_rls.sql
-- cafe_requests DELETE 정책 추가 (어드민 전용)
-- 기존: service_role만 DELETE 가능 → deleteRequest() 호출 시 RLS 오류
-- 수정: 어드민 UUID도 DELETE 허용
-- ──────────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "admin can delete requests" ON cafe_requests;

CREATE POLICY "admin can delete requests"
  ON cafe_requests FOR DELETE TO authenticated
  USING (auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid);
