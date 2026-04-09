-- Seed Admin User Account
-- Run this script in Supabase SQL Editor
-- Then create auth user with the email/password below

-- Insert admin user into users table
INSERT INTO users (
  id,
  name,
  email,
  phone,
  role,
  status,
  created_at
) VALUES (
  '22222222-2222-2222-2222-222222222222',
  'Admin User',
  'admin@mobilis.com',
  '+63 900 000 0001',
  'admin',
  'active',
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Output confirmation
SELECT 'Admin user seeded successfully!' as message;
SELECT id, name, email, role, status FROM users WHERE email = 'admin@mobilis.com';
