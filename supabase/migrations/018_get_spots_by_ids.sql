-- RPC: get_spots_by_ids
-- Purpose: Returns spots with lat/lng extracted from PostGIS GEOGRAPHY(Point) column.
-- Used by My Map screen — direct table select returns geography as hex WKB,
-- so ST_Y / ST_X extraction via RPC is required.

CREATE OR REPLACE FUNCTION get_spots_by_ids(p_ids TEXT[])
RETURNS TABLE (
  id                     UUID,
  name                   TEXT,
  google_place_id        TEXT,
  formatted_address      TEXT,
  lat                    FLOAT,
  lng                    FLOAT,
  average_db             FLOAT,
  representative_sticker TEXT,
  report_count           INT,
  trust_score            FLOAT,
  recent_24h_count       INT,
  last_report_at         TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    s.id,
    s.name,
    s.google_place_id,
    s.formatted_address,
    ST_Y(s.location::geometry)::FLOAT AS lat,
    ST_X(s.location::geometry)::FLOAT AS lng,
    s.average_db,
    s.representative_sticker,
    s.report_count,
    s.trust_score,
    COALESCE(
      (SELECT COUNT(*)::INT FROM reports r
       WHERE r.spot_id = s.id
         AND r.created_at >= NOW() - INTERVAL '24 hours'),
      0
    ) AS recent_24h_count,
    s.last_report_at
  FROM spots s
  WHERE s.id::TEXT = ANY(p_ids);
$$;

GRANT EXECUTE ON FUNCTION get_spots_by_ids TO anon, authenticated;
