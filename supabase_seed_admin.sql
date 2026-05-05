-- Seed admin account (Auth-first)
-- Run in Supabase SQL Editor as project owner/service role.
-- Default password: Passw0rd!

DO $$
DECLARE
  has_full_name boolean;
  has_name boolean;
  has_status boolean;
  has_application_status boolean;
  has_id_verified boolean;
  has_verification_status boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'full_name'
  ) INTO has_full_name;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'name'
  ) INTO has_name;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'status'
  ) INTO has_status;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'application_status'
  ) INTO has_application_status;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'id_verified'
  ) INTO has_id_verified;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'verification_status'
  ) INTO has_verification_status;

  INSERT INTO auth.users (
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) VALUES (
    '22222222-2222-2222-2222-222222222222',
    'authenticated',
    'authenticated',
    'admin@mobilis.com',
    crypt('Passw0rd!', gen_salt('bf')),
    now(),
    now(),
    jsonb_build_object('provider', 'email', 'providers', jsonb_build_array('email')),
    jsonb_build_object('full_name', 'Admin User', 'role', 'admin'),
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE
    SET email = EXCLUDED.email,
        raw_user_meta_data = EXCLUDED.raw_user_meta_data,
        updated_at = now();

  IF has_full_name THEN
    INSERT INTO public.users (id, full_name, email, phone, role)
    VALUES (
      '22222222-2222-2222-2222-222222222222',
      'Admin User',
      'admin@mobilis.com',
      '+63 900 000 0001',
      'admin'
    )
    ON CONFLICT (id) DO UPDATE
      SET full_name = EXCLUDED.full_name,
          email = EXCLUDED.email,
          phone = EXCLUDED.phone,
          role = EXCLUDED.role;
  ELSIF has_name THEN
    INSERT INTO public.users (id, name, email, phone, role)
    VALUES (
      '22222222-2222-2222-2222-222222222222',
      'Admin User',
      'admin@mobilis.com',
      '+63 900 000 0001',
      'admin'
    )
    ON CONFLICT (id) DO UPDATE
      SET name = EXCLUDED.name,
          email = EXCLUDED.email,
          phone = EXCLUDED.phone,
          role = EXCLUDED.role;
  ELSE
    INSERT INTO public.users (id, email, phone, role)
    VALUES (
      '22222222-2222-2222-2222-222222222222',
      'admin@mobilis.com',
      '+63 900 000 0001',
      'admin'
    )
    ON CONFLICT (id) DO UPDATE
      SET email = EXCLUDED.email,
          phone = EXCLUDED.phone,
          role = EXCLUDED.role;
  END IF;

  IF has_status THEN
    UPDATE public.users SET status = 'active' WHERE id = '22222222-2222-2222-2222-222222222222';
  END IF;

  IF has_application_status THEN
    UPDATE public.users SET application_status = 'none' WHERE id = '22222222-2222-2222-2222-222222222222';
  END IF;

  IF has_id_verified THEN
    UPDATE public.users SET id_verified = true WHERE id = '22222222-2222-2222-2222-222222222222';
  END IF;

  IF has_verification_status THEN
    UPDATE public.users SET verification_status = 'verified' WHERE id = '22222222-2222-2222-2222-222222222222';
  END IF;
END $$;

SELECT 'Admin user seeded successfully via auth + public tables.' AS message;
SELECT id, email, role FROM public.users WHERE email = 'admin@mobilis.com';
