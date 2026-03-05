-- ──────────────────────────────────────────────────────────────
-- 039_delete_account_full_rpc.sql
-- 완전 계정삭제 RPC — Edge Function 없이 auth.users까지 삭제
-- SECURITY DEFINER (postgres 슈퍼유저 권한) → auth.users 직접 삭제 가능
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION delete_my_account_full()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  uid UUID := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 사용자 데이터 전체 삭제
  DELETE FROM public.reports        WHERE user_id = uid;
  DELETE FROM public.user_badges    WHERE user_id = uid;
  DELETE FROM public.user_bookmarks WHERE user_id = uid;
  DELETE FROM public.user_profiles  WHERE user_id = uid;
  DELETE FROM public.user_stats     WHERE user_id = uid;
  DELETE FROM public.user_sessions  WHERE user_id = uid;

  -- auth.users 행 삭제 (SECURITY DEFINER = postgres 슈퍼유저 권한)
  DELETE FROM auth.users WHERE id = uid;
END;
$$;

GRANT EXECUTE ON FUNCTION delete_my_account_full TO authenticated;
