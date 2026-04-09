# Database Migration Guide

## Overview
This guide explains the database migration script (`database_migration.sql`) that sets up all tables required for the complete Mobilis car rental system workflow.

## What Was Changed

### 1. **users Table** - Added Driver Support
```sql
Added columns:
- is_driver (BOOLEAN) - Whether user can drive (for partners)
- is_available (BOOLEAN) - For driver availability toggle
- latitude, longitude (NUMERIC) - For location tracking
```

**Why**: The users table now needs to support all roles (renter, partner, driver, operator, admin) with driver-specific fields.

---

### 2. **NEW: drivers Table** - Driver Profile Management
```
Columns:
- id, user_id (FK to users)
- license_number, license_expiry
- nbi_clearance_number, nbi_expiry
- verification_status (pending/approved/rejected)
- tier (standard/professional/elite)
- average_rating, total_trips_completed
- preferred_work_days, preferred_areas
- work_hours_start, work_hours_end
- created_at, updated_at, verified_at
```

**Why**: Drivers need separate profile data including documents, ratings, tier system, and availability preferences.

---

### 3. **NEW: driver_documents Table** - Document Upload Tracking
```
Columns:
- id, driver_id (FK)
- document_type (license, nbi_clearance)
- file_url, issue_date, expiry_date
- uploaded_at
```

**Why**: Track all driver documents with expiry dates for verification and admin review.

---

### 4. **NEW: driver_availability_schedule Table** - Work Schedule
```
Columns:
- id, driver_id (FK)
- day_of_week (0-6)
- start_time, end_time
- preferred_area
- created_at
```

**Why**: Drivers set weekly schedules with time slots and preferred areas for job assignment.

---

### 5. **vehicles Table** - Added Ownership & Availability
```sql
Added columns:
- owner_id (FK to users) - Links vehicle to partner who owns it
- is_available (BOOLEAN) - Shows/hides vehicle in renter feed
```

**Why**: Operator needs to toggle vehicle visibility, and system must track vehicle ownership for partner earnings.

---

### 6. **bookings Table** - Added Driver Workflow
```sql
Added columns:
- with_driver (BOOLEAN) - Self-drive vs with driver service
- driver_id (FK to drivers.user_id) - Assigned driver
- approved_at, rejected_at, driver_assigned_at
- rejection_reason
```

**Why**: Bookings now support the complete approval and driver assignment workflow.

---

### 7. **NEW: driver_job_assignments Table** - Job Offer System
```
Columns:
- id, driver_id (FK), booking_id (FK)
- status (offered/accepted/declined/cancelled)
- offered_at, accepted_at, declined_at
- decline_reason, estimated_earnings
- created_at, updated_at
```

**Why**: Tracks job offers to drivers with acceptance/decline workflow and 5-minute timer.

---

### 8. **NEW: driver_trips Table** - Trip Tracking & Ratings
```
Columns:
- id, driver_id (FK), booking_id (FK)
- start_location, end_location
- distance_km, duration_minutes
- started_at, completed_at
- renter_rating, renter_feedback
- driver_rating, driver_feedback
- created_at, updated_at
```

**Why**: Records completed trips with ratings from both driver and renter.

---

### 9. **NEW: driver_earnings Table** - Earnings & Payouts
```
Columns:
- id, driver_id (FK), trip_id (FK)
- trip_fee, commission_amount, commission_percentage
- net_earnings (trip_fee - commission)
- payout_status (pending/paid/failed)
- payout_date, payout_method
- created_at, paid_at
```

**Why**: Calculates and tracks driver earnings with commission breakdown and payout status.

---

### 10. **NEW: driver_tier_history Table** - Performance Tracking
```
Columns:
- id, driver_id (FK)
- old_tier, new_tier
- reason, created_at
```

**Why**: Audit trail for driver tier promotions/demotions based on performance.

---

### 11. **NEW: partner_vehicle_applications Table** - Vehicle Approval
```
Columns:
- id, partner_id (FK)
- brand, model, year, plate_number
- price_per_day, price_per_hour
- or_document_url, cr_document_url, insurance_document_url
- application_status (pending/approved/rejected)
- rejection_reason, created_vehicle_id
- created_at, reviewed_at
```

**Why**: Pipeline for partner vehicle registration with document uploads and admin approval.

---

### 12. **NEW: user_verifications Table** - ID Verification
```
Columns:
- id, user_id (FK)
- id_document_url, face_photo_url
- verification_status (pending/verified/rejected)
- face_match_percentage, rejection_reason
- created_at, verified_at
```

**Why**: Stores user ID verification documents and face matching results for renters/partners.

---

## How to Run the Migration

### Step 1: Open Supabase Dashboard
1. Go to https://supabase.com
2. Login to your project
3. Go to **SQL Editor** → **New Query**

### Step 2: Copy & Run Migration Script
1. Copy the entire contents of `database_migration.sql`
2. Paste into the SQL Editor
3. Click **Run**

### Step 3: Verify Success
Look for confirmation messages:
```
Database migration completed successfully!
Tables created/updated: drivers, driver_documents, driver_availability_schedule, driver_job_assignments, driver_trips, driver_earnings, driver_tier_history, partner_vehicle_applications, user_verifications
```

### Step 4: Seed Test Users (Optional)
After migration completes, run the seeding script:
```sql
-- Run supabase_seed_all.sql to create 5 test users
```

---

## Database Relationships Diagram

```
users (Master table)
  ├─ id (PK)
  ├─ role (admin, operator, partner, driver, renter)
  ├─ is_driver (for partners who drive)
  └─ is_available (for drivers)
      │
      ├──→ drivers (1:1 relationship)
      │     ├─ user_id (FK) (one driver per user)
      │     ├─ verification_status
      │     ├─ tier
      │     └─→ driver_documents (1:N)
      │          ├─ document_type (license, nbi)
      │          └─ expiry_date
      │     └─→ driver_availability_schedule (1:N)
      │          ├─ day_of_week
      │          └─ preferred_area
      │     └─→ driver_job_assignments (1:N)
      │          ├─ booking_id (FK)
      │          └─ status (offered/accepted/declined)
      │     └─→ driver_trips (1:N)
      │          ├─ booking_id (FK)
      │          ├─ renter_rating
      │          └─ driver_rating
      │     └─→ driver_earnings (1:N)
      │          ├─ trip_id (FK)
      │          └─ payout_status
      │
      ├──→ vehicles (N:1 relationship)
      │     ├─ owner_id (FK to partner/user)
      │     ├─ is_available
      │     └─→ partner_vehicle_applications (1:N)
      │          ├─ application_status
      │          └─ document URLs
      │
      ├──→ bookings (1:N from renter)
      │     ├─ renter_id (FK)
      │     ├─ vehicle_id (FK)
      │     ├─ with_driver (BOOLEAN)
      │     ├─ driver_id (FK) - assigned driver
      │     ├─ status (pending/approved/active/completed)
      │     └─→ driver_job_assignments (1:1)
      │
      └──→ user_verifications (1:1)
           ├─ person_id_document_url
           └─ verification_status
```

---

## Key Workflows Enabled

### Driver Sign-Up & Verification
1. Driver signs up → user record created with role='driver'
2. Driver uploads license & NBI → driver_documents created
3. Driver sets availability → driver_availability_schedule entries
4. Admin reviews in Driver Intake → updates drivers.verification_status
5. If approved → drivers.tier assigned, is_available=true

### Booking with Driver Service
1. Renter books with with_driver=true
2. Operator receives booking in Bookings tab
3. If partner can't drive → driver_job_assignments created (offered status)
4. Driver gets notification with offer details
5. Driver accepts → status changes to 'accepted'
6. Booking approved → driver_id assigned to booking

### Trip Completion & Earnings
1. Trip starts → driver_trips created
2. Trip ends → driver_trips.completed_at recorded
3. Both rate each other → ratings saved in driver_trips
4. driver_earnings entry created with split calculation
5. Weekly payout → driver_earnings.payout_status='paid'

---

## Migration Checklist

- [ ] Backup existing database (if any)
- [ ] Run database_migration.sql in Supabase SQL Editor
- [ ] Verify all tables created successfully
- [ ] Verify all indexes created
- [ ] Run supabase_seed_all.sql to create test users
- [ ] Test driver sign-up flow
- [ ] Test booking with driver assignment
- [ ] Verify earnings calculation
- [ ] Check all UI screens connect to correct tables

---

## Rollback (if needed)

If you need to rollback, you can drop tables in reverse order:

```sql
DROP TABLE IF EXISTS driver_earnings CASCADE;
DROP TABLE IF EXISTS driver_tier_history CASCADE;
DROP TABLE IF EXISTS driver_trips CASCADE;
DROP TABLE IF EXISTS driver_job_assignments CASCADE;
DROP TABLE IF EXISTS driver_availability_schedule CASCADE;
DROP TABLE IF EXISTS driver_documents CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS partner_vehicle_applications CASCADE;
DROP TABLE IF EXISTS user_verifications CASCADE;

-- Remove columns from existing tables
ALTER TABLE bookings DROP COLUMN IF EXISTS with_driver, DROP COLUMN IF EXISTS driver_id,
  DROP COLUMN IF EXISTS approved_at, DROP COLUMN IF EXISTS rejected_at,
  DROP COLUMN IF EXISTS rejection_reason, DROP COLUMN IF EXISTS driver_assigned_at;

ALTER TABLE vehicles DROP COLUMN IF EXISTS owner_id, DROP COLUMN IF EXISTS is_available;

ALTER TABLE users DROP COLUMN IF EXISTS is_driver, DROP COLUMN IF EXISTS is_available,
  DROP COLUMN IF EXISTS latitude, DROP COLUMN IF EXISTS longitude;
```

---

## Next Steps

After running this migration:

1. **Seed test users** → Run `supabase_seed_all.sql`
2. **Test driver workflows** → Follow DRIVER_SIGNUP_IMPLEMENTATION.md
3. **Review service methods** → Check DriverService.dart implementation
4. **Test UI screens** → Test driver sign-up flow in app
5. **Test bookings** → Create booking with driver assignment
6. **Monitor earnings** → Verify driver earnings track correctly

---

**For questions or issues, refer to**:
- COMPLETE_SYSTEM_WORKFLOW.md - Full workflow documentation
- DRIVER_SIGNUP_IMPLEMENTATION.md - Driver implementation details
- SEEDING_GUIDE.md - Test user seeding instructions
