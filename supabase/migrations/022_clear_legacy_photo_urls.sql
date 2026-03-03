-- ──────────────────────────────────────────────────────────────
-- 022_clear_legacy_photo_urls.sql
-- 레거시 Places API redirect URL(API 키 포함)을 NULL로 초기화.
-- Places API (New) CDN URL로 재취득하도록 유도.
-- ──────────────────────────────────────────────────────────────

UPDATE spots
SET photo_url = NULL
WHERE photo_url IS NOT NULL;
