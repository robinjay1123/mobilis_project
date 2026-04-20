-- Add image_url column to vehicles table if it doesn't exist
ALTER TABLE vehicles ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Comment on the new column
COMMENT ON COLUMN vehicles.image_url IS 'URL to the vehicle image stored in Supabase Storage';
