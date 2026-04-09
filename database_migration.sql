-- ============================================================================
-- MOBILIS CAR RENTAL SYSTEM - COMPLETE DATABASE MIGRATION
-- ============================================================================
-- This script creates/alters all tables needed for the complete system workflow
-- including drivers, bookings, jobs, earnings, and all supporting tables
--
-- Run this in Supabase SQL Editor before seeding test users
-- ============================================================================

-- 1. ALTER users TABLE - Add missing columns for drivers and partners
-- ============================================================================
ALTER TABLE users
ADD COLUMN IF NOT EXISTS is_driver BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS latitude NUMERIC,
ADD COLUMN IF NOT EXISTS longitude NUMERIC;

-- 2. CREATE drivers TABLE - For driver-specific data
-- ============================================================================
CREATE TABLE IF NOT EXISTS drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

  -- Documents
  license_number VARCHAR(50),
  license_expiry DATE,
  nbi_clearance_number VARCHAR(50),
  nbi_expiry DATE,

  -- Verification
  verification_status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected
  rejection_reason TEXT,
  rejection_date TIMESTAMP,
  
  -- Performance & Rating
  tier VARCHAR(50) DEFAULT 'standard', -- standard, professional, elite
  average_rating NUMERIC(3,2) DEFAULT 0.0,
  total_trips_completed INTEGER DEFAULT 0,

  -- Availability
  preferred_work_days VARCHAR(100), -- e.g., "Mon,Tue,Wed,Thu,Fri"
  preferred_areas VARCHAR(255), -- e.g., "Makati,BGC,Pasig"
  work_hours_start TIME,
  work_hours_end TIME,

  -- Tracking
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  verified_at TIMESTAMP,

  CONSTRAINT tier_check CHECK (tier IN ('standard', 'professional', 'elite')),
  CONSTRAINT status_check CHECK (verification_status IN ('pending', 'approved', 'rejected'))
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_drivers_user_id ON drivers(user_id);
CREATE INDEX IF NOT EXISTS idx_drivers_verification_status ON drivers(verification_status);
CREATE INDEX IF NOT EXISTS idx_drivers_tier ON drivers(tier);

-- 3. CREATE driver_documents TABLE - For license and NBI uploads
-- ============================================================================
CREATE TABLE IF NOT EXISTS driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  document_type VARCHAR(50) NOT NULL, -- license, nbi_clearance
  file_url VARCHAR(500),
  issue_date DATE,
  expiry_date DATE,
  uploaded_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT doc_type_check CHECK (document_type IN ('license', 'nbi_clearance'))
);

CREATE INDEX IF NOT EXISTS idx_driver_docs_driver_id ON driver_documents(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_docs_type ON driver_documents(document_type);

-- 4. CREATE driver_availability_schedule TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS driver_availability_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL, -- 0=Sunday to 6=Saturday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  preferred_area VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT day_check CHECK (day_of_week >= 0 AND day_of_week <= 6)
);

CREATE INDEX IF NOT EXISTS idx_availability_driver_id ON driver_availability_schedule(driver_id);

-- 5. ALTER vehicles TABLE - Ensure necessary columns
-- ============================================================================
ALTER TABLE vehicles
ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS is_available BOOLEAN DEFAULT false;

-- 6. ALTER bookings TABLE - Add driver-related and status fields
-- ============================================================================
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS with_driver BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS driver_id UUID REFERENCES drivers(user_id),
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT,
ADD COLUMN IF NOT EXISTS driver_assigned_at TIMESTAMP;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_bookings_driver_id ON bookings(driver_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

-- 7. CREATE driver_job_assignments TABLE - For job offer workflow
-- ============================================================================
CREATE TABLE IF NOT EXISTS driver_job_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  status VARCHAR(50) DEFAULT 'offered', -- offered, accepted, declined, cancelled

  offered_at TIMESTAMP DEFAULT NOW(),
  accepted_at TIMESTAMP,
  declined_at TIMESTAMP,
  decline_reason VARCHAR(255),

  -- Estimated earnings shown to driver
  estimated_earnings NUMERIC(10,2),

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT assignment_status_check CHECK (status IN ('offered', 'accepted', 'declined', 'cancelled')),
  UNIQUE(booking_id, driver_id)
);

CREATE INDEX IF NOT EXISTS idx_job_assignments_driver_id ON driver_job_assignments(driver_id);
CREATE INDEX IF NOT EXISTS idx_job_assignments_booking_id ON driver_job_assignments(booking_id);
CREATE INDEX IF NOT EXISTS idx_job_assignments_status ON driver_job_assignments(status);

-- 8. CREATE driver_trips TABLE - For trip tracking
-- ============================================================================
CREATE TABLE IF NOT EXISTS driver_trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,

  -- Trip Details
  start_location VARCHAR(255),
  end_location VARCHAR(255),
  distance_km NUMERIC(10,2),
  duration_minutes INTEGER,

  -- Timing
  started_at TIMESTAMP,
  completed_at TIMESTAMP,

  -- Rating from renter to driver
  renter_rating INTEGER,
  renter_feedback TEXT,

  -- Rating from driver to renter
  driver_rating INTEGER,
  driver_feedback TEXT,

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),

  CONSTRAINT rating_check CHECK (renter_rating IS NULL OR (renter_rating >= 1 AND renter_rating <= 5)),
  CONSTRAINT driver_rating_check CHECK (driver_rating IS NULL OR (driver_rating >= 1 AND driver_rating <= 5))
);

CREATE INDEX IF NOT EXISTS idx_driver_trips_driver_id ON driver_trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_trips_booking_id ON driver_trips(booking_id);

-- 9. CREATE driver_earnings TABLE - For earnings tracking and payouts
-- ============================================================================
CREATE TABLE IF NOT EXISTS driver_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  trip_id UUID NOT NULL REFERENCES driver_trips(id) ON DELETE CASCADE,

  -- Earnings breakdown
  trip_fee NUMERIC(10,2) NOT NULL,
  commission_amount NUMERIC(10,2) NOT NULL, -- Amount paid to PSDC
  commission_percentage NUMERIC(5,2) DEFAULT 15.0, -- Default 15%
  net_earnings NUMERIC(10,2) NOT NULL, -- trip_fee - commission_amount

  -- Payout status
  payout_status VARCHAR(50) DEFAULT 'pending', -- pending, paid, failed
  payout_date TIMESTAMP,
  payout_method VARCHAR(50), -- bank_transfer, gcash, etc.

  created_at TIMESTAMP DEFAULT NOW(),
  paid_at TIMESTAMP,

  CONSTRAINT payout_status_check CHECK (payout_status IN ('pending', 'paid', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_earnings_driver_id ON driver_earnings(driver_id);
CREATE INDEX IF NOT EXISTS idx_earnings_payout_status ON driver_earnings(payout_status);

-- 10. CREATE driver_tier_history TABLE - Track tier changes
-- ============================================================================
CREATE TABLE IF NOT EXISTS driver_tier_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(user_id) ON DELETE CASCADE,
  old_tier VARCHAR(50),
  new_tier VARCHAR(50) NOT NULL,
  reason VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tier_history_driver_id ON driver_tier_history(driver_id);

-- 11. CREATE partner_vehicles_applications TABLE (if not exists)
-- ============================================================================
CREATE TABLE IF NOT EXISTS partner_vehicle_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES users(id),

  -- Vehicle Details
  brand VARCHAR(100) NOT NULL,
  model VARCHAR(100) NOT NULL,
  year INTEGER NOT NULL,
  plate_number VARCHAR(50) UNIQUE NOT NULL,

  -- Pricing
  price_per_day NUMERIC(10,2) NOT NULL,
  price_per_hour NUMERIC(10,2),

  -- Documents
  or_document_url VARCHAR(500), -- Official Receipt
  cr_document_url VARCHAR(500), -- Certificate of Registration
  insurance_document_url VARCHAR(500),
  vehicle_photo_url VARCHAR(500),

  -- Status
  application_status VARCHAR(50) DEFAULT 'pending', -- pending, approved, rejected
  rejection_reason TEXT,
  created_vehicle_id UUID REFERENCES vehicles(id),

  created_at TIMESTAMP DEFAULT NOW(),
  reviewed_at TIMESTAMP,

  CONSTRAINT app_status_check CHECK (application_status IN ('pending', 'approved', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_vehicle_apps_partner_id ON partner_vehicle_applications(partner_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_apps_status ON partner_vehicle_applications(application_status);

-- 12. CREATE user_verification TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

  -- Doc verification
  id_document_url VARCHAR(500),
  face_photo_url VARCHAR(500),
  verification_status VARCHAR(50) DEFAULT 'pending', -- pending, verified, rejected
  face_match_percentage NUMERIC(5,2),
  rejection_reason TEXT,

  created_at TIMESTAMP DEFAULT NOW(),
  verified_at TIMESTAMP,

  CONSTRAINT verification_status_check CHECK (verification_status IN ('pending', 'verified', 'rejected'))
);

CREATE INDEX IF NOT EXISTS idx_user_verifications_status ON user_verifications(verification_status);

-- ============================================================================
-- GRANT PERMISSIONS (if needed for RLS)
-- ============================================================================
-- Uncomment if using Row Level Security:
-- GRANT ALL ON drivers TO authenticated;
-- GRANT ALL ON driver_documents TO authenticated;
-- GRANT ALL ON driver_job_assignments TO authenticated;
-- GRANT ALL ON driver_trips TO authenticated;
-- GRANT ALL ON driver_earnings TO authenticated;

-- ============================================================================
-- CONFIRMATION MESSAGE
-- ============================================================================
SELECT 'Database migration completed successfully!' as message;
SELECT
  'Tables created/updated:' as info,
  'drivers, driver_documents, driver_availability_schedule, driver_job_assignments, driver_trips, driver_earnings, driver_tier_history, partner_vehicle_applications, user_verifications' as tables_modified;
