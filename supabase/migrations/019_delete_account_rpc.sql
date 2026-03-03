-- Migration 019: delete_my_account_data RPC
-- SECURITY DEFINER bypasses RLS — safe because auth.uid() is validated inside.

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
END;
$$;

GRANT EXECUTE ON FUNCTION delete_my_account_data TO authenticated;
