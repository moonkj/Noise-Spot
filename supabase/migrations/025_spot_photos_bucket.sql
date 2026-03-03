-- ──────────────────────────────────────────────────────────────
-- 025_spot_photos_bucket.sql
-- Supabase Storage: spot-photos 버킷 생성 + 관리자 전용 업로드 정책
-- ──────────────────────────────────────────────────────────────

-- 버킷 생성 (공개 읽기, 5MB 제한, JPG/PNG/WebP)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'spot-photos',
  'spot-photos',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE SET
  public            = true,
  file_size_limit   = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- 관리자만 업로드/수정/삭제 가능
CREATE POLICY "Admin can manage spot photos"
  ON storage.objects FOR ALL TO authenticated
  USING (
    bucket_id = 'spot-photos'
    AND auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid
  )
  WITH CHECK (
    bucket_id = 'spot-photos'
    AND auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid
  );
