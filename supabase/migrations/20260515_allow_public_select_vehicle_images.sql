-- Allow the app to read vehicle gallery rows without requiring auth.
-- Storage bucket permissions do not control access to this table.

ALTER TABLE vehicle_images ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_public_select_vehicle_images" ON vehicle_images;
CREATE POLICY "allow_public_select_vehicle_images"
  ON vehicle_images
  FOR SELECT
  TO public
  USING (true);