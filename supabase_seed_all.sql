-- Comprehensive Test Users Seed Script
-- Insert test users for all roles

-- 1. Admin User
INSERT INTO users (id, name, email, phone, role, status, created_at)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  'Admin User',
  'admin@mobilis.com',
  '+63 900 000 0001',
  'admin',
  'active',
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- 2. Operator User
INSERT INTO users (id, name, email, phone, role, status, created_at)
VALUES (
  '33333333-3333-3333-3333-333333333333',
  'Operator User',
  'operator@mobilis.com',
  '+63 900 000 0002',
  'operator',
  'active',
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- 3. Driver User
INSERT INTO users (id, name, email, phone, role, status, created_at)
VALUES (
  '44444444-4444-4444-4444-444444444444',
  'Driver User',
  'driver@mobilis.com',
  '+63 900 000 0003',
  'driver',
  'active',
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- 4. Partner User
INSERT INTO users (id, name, email, phone, role, status, created_at)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Test Partner',
  'testpartner@mobilis.com',
  '+63 900 000 0004',
  'partner',
  'active',
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- 5. Renter User
INSERT INTO users (id, name, email, phone, role, status, created_at)
VALUES (
  '55555555-5555-5555-5555-555555555555',
  'Test Renter',
  'renter@mobilis.com',
  '+63 900 000 0005',
  'renter',
  'active',
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Confirmation
SELECT 'All test users seeded!' as message;
SELECT id, name, email, role, status FROM users WHERE email LIKE '%@mobilis.com' ORDER BY role;
