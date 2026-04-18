-- Create Test Admin Account
-- Run this in Supabase SQL Editor

-- Step 1: Create admin user in auth.users
INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  raw_app_meta_data,
  raw_user_meta_data
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'authenticated',
  'authenticated',
  'testadmin@mobilis.com',
  -- Password: Admin@123456 (bcrypt encrypted)
  '$2a$10$YQW5cJlZ.l8GiLJ7Y4QD6uVVcLhQK9BKkw5TLkKL8KxB6xKL8cKA2',
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP,
  '{"provider":"email","providers":["email"]}',
  '{"full_name":"Test Admin"}'
);

-- Step 2: Create corresponding user profile with admin role
INSERT INTO public.users (
  id,
  email,
  full_name,
  phone,
  location,
  role,
  id_verified,
  created_at,
  updated_at
) VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'testadmin@mobilis.com',
  'Test Admin',
  '+63-test',
  'Mobilis HQ',
  'admin',
  TRUE,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
);

-- Test Credentials:
-- Email: testadmin@mobilis.com
-- Password: Admin@123456
-- Role: admin (should route to /admin-home)
