-- ──────────────────────────────────────────────────────────────
-- 019_cleanup_dev_data.sql
-- 개발 중 임시 데이터 초기화
-- 1. reports 전체 삭제
-- 2. 관련 spot 통계 리셋
-- 3. google_place_id 없는 테스트 스팟 삭제
-- 4. 모든 tag_text / mood_tag NULL 처리
-- ──────────────────────────────────────────────────────────────

-- Step 1: 모든 측정 기록 삭제
DELETE FROM reports;

-- Step 2: reports에 연결된 user_stats 초기화
UPDATE user_stats
SET total_reports = 0,
    total_cafes    = 0;

-- Step 3: 모든 spot 통계 리셋 (average_db, report_count 등)
UPDATE spots
SET average_db             = 0,
    report_count           = 0,
    representative_sticker = NULL,
    last_report_at         = NULL,
    trust_score            = 0;

-- Step 4: google_place_id가 없는 테스트 스팟 삭제
--         (google_place_id가 있는 스팟은 Google Places API로 등록된 실제 카페)
DELETE FROM spots
WHERE google_place_id IS NULL;

-- Step 5: tag_text / mood_tag 컬럼 일괄 NULL (혹시 남아 있는 경우 대비)
-- (reports가 이미 삭제됐으므로 spots 테이블에 직접 적용할 컬럼이 없으면 skip)
