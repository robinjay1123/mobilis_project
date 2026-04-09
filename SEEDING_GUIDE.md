# Test User Seeding Guide

## Overview
This guide explains how to seed test user accounts for each role in the Mobilis app.

## Test User Credentials

| Role | Email | Password | User ID |
|------|-------|----------|---------|
| Admin | admin@mobilis.com | Admin@123456 | 22222222-2222-2222-2222-222222222222 |
| Operator | operator@mobilis.com | Operator@123456 | 33333333-3333-3333-3333-333333333333 |
| Driver | driver@mobilis.com | Driver@123456 | 44444444-4444-4444-4444-444444444444 |
| Partner | testpartner@mobilis.com | Partner@123456 | 11111111-1111-1111-1111-111111111111 |
| Renter | renter@mobilis.com | Renter@123456 | 55555555-5555-5555-5555-555555555555 |

## Process

### Option 1: Seed All Users at Once (Recommended)

1. Open Supabase Dashboard → **SQL Editor**
2. Click **New Query**
3. Copy contents of `supabase_seed_all.sql`
4. Paste into editor and click **Run**
5. Go to **Authentication** → **Users** and create auth users for each test account using the emails and passwords above

### Option 2: Seed Individual Roles

1. Open Supabase Dashboard → **SQL Editor**
2. Run the appropriate SQL script:
   - `supabase_seed_admin.sql` - Admin only
3. Create corresponding auth user(s) in Supabase Authentication

### Option 3: Use Supabase CLI

```bash
# Login to Supabase
supabase login

# Reset database (WARNING: deletes all data!)
supabase db reset

# Seed all test data
supabase db push
```

## Creating Auth Users in Supabase

After running SQL script:

1. Go to **Authentication** → **Users**
2. Click **Add User** for each test user
3. Enter email and password from table above
4. **Important**: The User ID generated in auth MUST match the ID in the SQL script
   - If already seeded with matching UUID, auth will link automatically
   - Copy the generated User ID and verify it matches your SQL script ID

## Navigation After Login

Each role is automatically routed to the appropriate dashboard:

- **Admin** → `/admin-home` (Admin Panel)
- **Operator** → `/operator-home` (Operator Bookings Panel)
- **Driver** → `/driver-home` (Driver Dashboard)
- **Partner** → `/partner-home` (Partner Vehicle Management)
- **Renter** → `/dashboard` (Main Renter Dashboard)

## Database Schema

The seeding scripts use the following users table structure:
- `id` (UUID) - Primary key
- `name` (TEXT) - User's full name
- `email` (TEXT) - Email address
- `phone` (TEXT) - Phone number
- `role` (TEXT) - Role: admin, operator, driver, partner, renter
- `status` (TEXT) - Account status: active, inactive, suspended
- `latitude` (NUMERIC, optional) - User location latitude
- `longitude` (NUMERIC, optional) - User location longitude
- `created_at` (TIMESTAMP) - Account creation time

## Troubleshooting

### User ID Mismatch
If you get an error about user ID:
1. Check the generated User ID in Supabase Auth → Users
2. Verify it matches the ID in the SQL script (should be same UUID)
3. If mismatch, delete and recreate the auth user with matching ID

### Email Already Exists
If you seed the same email twice:
1. Delete the user from **Authentication** → **Users** in Supabase
2. Delete the record from `users` table in SQL Editor: `DELETE FROM users WHERE email = 'email@mobilis.com';`
3. Re-run the seed script

### Password Issues
If login fails:
1. Check that you created the auth user with the correct password
2. Try resetting password in Supabase Auth dashboard
3. Create a new auth user with new credentials

## Testing Workflow

```
1. Seed all users (supabase_seed_all.sql)
2. Create auth users (5 users total - Admin, Operator, Driver, Partner, Renter)
3. Test login with each credential
4. Verify dashboard navigation works correctly
5. Test role-specific features
```

## Production Notes

⚠️ **NEVER use these test credentials in production**
- Change all passwords before deploying
- Remove seed scripts from repository
- Use proper user management in production

## Creating Additional Test Users

To add more users:
1. Generate a new UUID (use `uuidgen` on Mac/Linux or online UUID generator)
2. Add new row to `supabase_seed_all.sql` with correct schema
3. Create auth user in Supabase dashboard
4. Re-run SQL script if needed
