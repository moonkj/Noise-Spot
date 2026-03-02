-- Admin RLS policies for cafe_requests
-- Allows the admin user to read ALL requests and update their status.

-- Admin can SELECT all pending/approved/rejected requests (not just their own)
CREATE POLICY "admin can read all requests"
  ON cafe_requests FOR SELECT TO authenticated
  USING (auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid);

-- Admin can UPDATE status on any request
CREATE POLICY "admin can update all requests"
  ON cafe_requests FOR UPDATE TO authenticated
  USING (auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid)
  WITH CHECK (auth.uid() = 'da2a8b72-a3c2-415b-bae5-63f2fa0b92a0'::uuid);
