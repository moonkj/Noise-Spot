-- RPC: fetch manually added spots with lat/lng (admin only)
CREATE OR REPLACE FUNCTION get_admin_spots()
RETURNS TABLE (
  id                UUID,
  name              TEXT,
  formatted_address TEXT,
  lat               FLOAT,
  lng               FLOAT,
  report_count      INT,
  created_at        TIMESTAMPTZ
)
LANGUAGE sql STABLE
SECURITY DEFINER
AS $$
  SELECT
    s.id,
    s.name,
    s.formatted_address,
    ST_Y(s.location::geometry) AS lat,
    ST_X(s.location::geometry) AS lng,
    s.report_count,
    s.created_at
  FROM spots s
  WHERE s.google_place_id IS NULL
  ORDER BY s.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION get_admin_spots TO authenticated;

-- Admin can UPDATE any spot
CREATE POLICY "admin can update spots"
  ON spots FOR UPDATE TO authenticated
  USING (auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid)
  WITH CHECK (auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid);

-- Admin can DELETE any spot
CREATE POLICY "admin can delete spots"
  ON spots FOR DELETE TO authenticated
  USING (auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid);
