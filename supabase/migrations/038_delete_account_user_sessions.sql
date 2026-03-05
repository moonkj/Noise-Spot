-- ──────────────────────────────────────────────────────────────
-- 038_delete_account_user_sessions.sql
-- delete_my_account_data에 user_sessions 삭제 추가
-- 019 마이그레이션에서 누락 (027에서 user_sessions 테이블 추가됨)
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION delete_my_account_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  DELETE FROM reports        WHERE user_id = uid;
  DELETE FROM user_badges    WHERE user_id = uid;
  DELETE FROM user_bookmarks WHERE user_id = uid;
  DELETE FROM user_profiles  WHERE user_id = uid;
  DELETE FROM user_stats     WHERE user_id = uid;
  DELETE FROM user_sessions  WHERE user_id = uid;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_my_account_data TO authenticated;
