# Test User Seeding Guide

## Overview
This guide explains how to seed test user accounts for each role in the Mobilis app.

## Test User Credentials

| Role | Email | Password | User ID |
|------|-------|----------|---------|
| Admin | admin@mobilis.com | Passw0rd! | 22222222-2222-2222-2222-222222222222 |
| Operator | operator@mobilis.com | Passw0rd! | 33333333-3333-3333-3333-333333333333 |
| Driver | driver@mobilis.com | Passw0rd! | 44444444-4444-4444-4444-444444444444 |
| Partner | testpartner@mobilis.com | Passw0rd! | 11111111-1111-1111-1111-111111111111 |
| Renter | renter@mobilis.com | Passw0rd! | 55555555-5555-5555-5555-555555555555 |

## Process

### Option 1: Seed Individual Roles

1. Open Supabase Dashboard → **SQL Editor**
2. Run the appropriate SQL script:
   - `supabase_seed_admin.sql` - Admin only
3. Done. The script seeds both auth and public user records.

### Option 3: Use Supabase CLI

```bash
# Login to Supabase
supabase login

# Reset database (WARNING: deletes all data!)
supabase db reset

# Seed all test data
supabase db push
```

## Auth-First Seeding

The current seed scripts are auth-first:

1. Insert/Update `auth.users` with a valid bcrypt password hash
2. Upsert matching `public.users` row using the same UUID

This avoids foreign key failures from `public.users(id) -> auth.users(id)`.

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

### User ID / FK Errors
If you get an error referencing `users_id_fkey`:
1. Re-run the updated auth-first seed script
2. Confirm the user exists in `auth.users`
3. Confirm the same UUID exists in `public.users`

### Email Already Exists
If you seed the same email twice:
1. Delete the user from **Authentication** → **Users** in Supabase
2. Delete the record from `users` table in SQL Editor: `DELETE FROM users WHERE email = 'email@mobilis.com';`
3. Re-run the seed script

### Password Issues
If login fails:
1. Ensure you are using `Passw0rd!`
2. Re-run the seed script to refresh the auth password hash
3. If needed, delete the user in both `auth.users` and `public.users`, then re-seed

## Testing Workflow

```
1. Seed users (for example with supabase_seed_admin.sql)
2. Verify rows exist in auth.users and public.users
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
2. Add a row to your chosen seed script with correct schema
3. Re-run SQL script
