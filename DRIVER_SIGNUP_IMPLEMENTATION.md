# Driver Sign-Up Implementation Guide

## 📋 DATABASE REQUIREMENTS

### ✅ EXISTING Tables (Already Present)
```sql
-- users table - Already has all fields
CREATE TABLE users (
  id UUID PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  full_name VARCHAR,
  phone VARCHAR,
  location VARCHAR,
  address VARCHAR,
  role VARCHAR DEFAULT 'renter', -- renter, partner, driver, operator, admin
  is_driver BOOLEAN DEFAULT FALSE, -- CAN this partner drive?
  is_available BOOLEAN DEFAULT TRUE, -- For drivers: are they available for jobs?
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### ❌ MISSING Tables (Need to Create)

#### 1. **drivers** Table
For driver-specific profile information
```sql
CREATE TABLE drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

  -- Verification status
  verification_status VARCHAR DEFAULT 'pending', -- pending, approved, rejected

  -- License
  license_number VARCHAR UNIQUE NOT NULL,
  license_expiry DATE NOT NULL,
  license_verified BOOLEAN DEFAULT FALSE,

  -- NBI Clearance
  nbi_clearance_number VARCHAR UNIQUE NOT NULL,
  nbi_expiry DATE NOT NULL,
  nbi_verified BOOLEAN DEFAULT FALSE,
  nbi_file_url VARCHAR, -- URL to NBI document

  -- Tier/Badge
  driver_tier VARCHAR DEFAULT 'standard', -- standard, professional, elite
  rating FLOAT DEFAULT 0.0, -- Average rating (0-5)
  total_trips INTEGER DEFAULT 0,

  -- Availability
  preferred_days VARCHAR, -- JSON: ["Mon", "Tue", "Wed", ...] or free-form
  preferred_areas VARCHAR, -- JSON: ["Metro Manila", "Quezon City", ...] or free-form

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. **driver_documents** Table
For storing and tracking driver documents
```sql
CREATE TABLE driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,

  -- Document type
  document_type VARCHAR NOT NULL, -- license, nbi_clearance, police_clearance, medical_cert, etc

  -- Document details
  file_url VARCHAR NOT NULL,
  issue_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  status VARCHAR DEFAULT 'pending', -- pending, verified, rejected, expired

  -- Admin review
  admin_notes TEXT,
  verified_at TIMESTAMP,
  verified_by UUID REFERENCES users(id),

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 3. **driver_job_assignments** Table
For job offers and acceptances
```sql
CREATE TABLE driver_job_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Status: pending_offer -> accepted -> rejected -> no_show
  status VARCHAR DEFAULT 'pending_offer',
  offered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  replied_at TIMESTAMP,

  -- Compensation
  trip_fee DECIMAL(10,2) DEFAULT 0,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 4. **driver_trips** Table
For tracking driver's trip history
```sql
CREATE TABLE driver_trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Trip details
  pickup_location VARCHAR,
  pickup_time TIMESTAMP,
  dropoff_location VARCHAR,
  dropoff_time TIMESTAMP,

  -- Trip status
  status VARCHAR DEFAULT 'pending', -- pending, started, completed, cancelled
  distance_km FLOAT,
  duration_minutes INTEGER,

  -- Rating
  renter_rating FLOAT, -- 1-5
  renter_comment TEXT,
  driver_comment TEXT,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 5. **driver_earnings** Table
For tracking driver earnings
```sql
CREATE TABLE driver_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES driver_trips(id) ON DELETE SET NULL,

  -- Earnings breakdown
  trip_fee DECIMAL(10,2) NOT NULL,
  commission_percentage DECIMAL(5,2) DEFAULT 15, -- PSDC commission %
  commission_amount DECIMAL(10,2),
  net_earnings DECIMAL(10,2),

  -- Payout
  payout_status VARCHAR DEFAULT 'pending', -- pending, paid, cancelled
  paid_at TIMESTAMP,
  payout_method VARCHAR, -- bank_transfer, gcash, etc

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 6. **driver_availability_schedule** Table
For tracking when drivers are available
```sql
CREATE TABLE driver_availability_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Recurring availability
  day_of_week VARCHAR, -- Monday, Tuesday, ... or NULL for one-time
  start_time TIME, -- HH:MM format
  end_time TIME,

  -- One-time availability
  date DATE, -- NULL for recurring

  is_available BOOLEAN DEFAULT TRUE,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🔄 DRIVER SIGN-UP WORKFLOW

### Flow Diagram
```
1. SIGN-UP SCREEN
   ├─ Role selection: "Become a Driver"
   ├─ Basic info: Full name, email, phone, address
   ├─ Terms acceptance
   └─ Account created with role="driver"
           ↓

2. EMAIL CONFIRMATION
   ├─ Email verification sent
   └─ Navigate to verification options
           ↓

3. VERIFICATION OPTIONS
   ┌────────────────────────────────────┐
   │ Full Verification (Recommended)    │
   │ Upload: License + NBI Clearance    │
   │ OR                                 │
   │ Skip For Now                       │
   │ Limited until verified             │
   └────────────────────────────────────┘
           ↓

4. DRIVER LICENSE UPLOAD (If full verification)
   ├─ License number (text input)
   ├─ License expiry date (date picker)
   ├─ License photo (front + back)
   └─ Quality check, file stored in driver_documents
           ↓

5. NBI CLEARANCE UPLOAD
   ├─ NBI clearance number (text input)
   ├─ NBI expiry date (date picker)
   ├─ NBI document PDF/Image
   └─ File stored in driver_documents
           ↓

6. AVAILABILITY SETUP
   ├─ Preferred working days
   │  (Select: Monday, Tuesday, Wednesday, etc.)
   ├─ Preferred areas/zones
   │  (Text input or dropdown)
   └─ Initial availability toggle (active/inactive)
           ↓

7. ADMIN REVIEW (Driver Intake Tab)
   ├─ Admin checks:
   │  ✓ License valid?
   │  ✓ NBI Clearance valid?
   │  ✓ Background check passed?
   ├─ Admin assigns tier: Standard / Professional / Elite
   ├─ Admin approves/rejects
   │
   ├─ IF APPROVED:
   │  • drivers.verification_status = "approved"
   │  • drivers.driver_tier = "standard" (default)
   │  • user.is_available = true
   │
   └─ IF REJECTED:
      • drivers.verification_status = "rejected"
      • rejection reason stored
      • Can reapply after fixing issues
           ↓

8. DRIVER HOME SCREEN ✅
   ├─ Dashboard: Stats, available jobs, ratings
   ├─ Jobs: Pending offers, accepted jobs, completed trips
   ├─ Earnings: Trip history, total earnings, payouts
   ├─ Availability: Toggle on/off, manage schedule
   └─ Profile: Documents, performance, feedback
```

---

## 📱 SCREEN REQUIREMENTS (To Implement)

### 1. **Driver Sign-Up Screen** (New)
File: `lib/mobile_ui/screens/auth/driver_signup_screen.dart`

Fields:
- Full name *
- Email *
- Phone *
- Address *
- Password *
- Confirm Password *
- Terms checkbox *
- License Number (optional - can fill later)
- NBI Number (optional - can fill later)

### 2. **Driver License Upload Screen** (New)
File: `lib/mobile_ui/screens/driver/driver_license_upload_screen.dart`

Fields:
- License number (text input)
- License expiry date (date picker)
- License front photo (upload)
- License back photo (upload)
- Verification status

### 3. **Driver NBI Clearance Upload Screen** (New)
File: `lib/mobile_ui/screens/driver/driver_nbi_upload_screen.dart`

Fields:
- NBI clearance number (text input)
- NBI expiry date (date picker)
- NBI document (upload PDF/Image)
- Verification status

### 4. **Driver Availability Setup Screen** (New)
File: `lib/mobile_ui/screens/driver/driver_availability_screen.dart`

Fields:
- Preferred working days (checkboxes: Mon-Sun)
- Preferred areas (text input with autocomplete)
- Availability toggle (ON/OFF)
- Work hours (optional: start/end time)

### 5. **Driver Home Screen** (Modify existing or new)
File: `lib/mobile_ui/screens/driver/driver_home_screen.dart`

Tabs:
1. **Dashboard**:
   - Profile card (name, rating, tier)
   - Stats (completed trips, total earnings, rating)
   - Pending job offers (with map showing location)
   - Recent trips

2. **Jobs**:
   - Pending offers (show, accept/decline)
   - Active jobs (current trip with real-time tracking)
   - Completed trips (with ratings)

3. **Earnings**:
   - Trip history with earnings breakdown
   - Total earnings (daily/weekly/monthly filters)
   - Payout history
   - Payout method settings

4. **Availability**:
   - Toggle availability on/off
   - Manage work schedule
   - Preferred zones
   - Preferred hours

5. **Profile**:
   - Driver info
   - Documents status
   - Ratings & feedback
   - Settings

---

## 🔧 SERVICES TO CREATE/UPDATE

### 1. **New: DriverService**
File: `lib/services/driver_service.dart`

Methods:
```dart
// Profile
- getDriverProfile(userId)
- updateDriverProfile(userId, data)
- getDriverStats(userId)

// Documents
- uploadDriverDocument(type, file, expiryDate)
- getDriverDocuments(userId)
- getDocumentStatus(userId)

// Availability
- setAvailability(driverId, available)
- updateSchedule(driverId, schedule)
- getAvailability(driverId)

// Jobs
- getAvailableJobs(driverId) // List bookings needing drivers
- acceptJob(jobAssignmentId)
- declineJob(jobAssignmentId, reason)
- getPendingOffers(driverId)
- getActiveJobs(driverId)
- getCompletedTrips(driverId)

// Earnings
- getEarnings(driverId, period) // daily, weekly, monthly
- getTripEarnings(tripId)
- getPastPayouts(driverId)
- requestPayout(driverId, amount, method)

// Ratings
- ratePastTrip(tripId, rating, comment)
- getAverageRating(driverId)
```

### 2. **Update: BookingService**
Add methods for driver assignment:
```dart
- assignDriver(bookingId, driverId) // Operator assigns
- getBookingsNeedingDriver() // For driver job offers
- getDriverBookings(driverId) // Get driver's assigned trips
```

### 3. **Update: AuthService**
Add driver-specific validation:
```dart
- getUserRole() // Already exists
- updateUserVerificationStatus(verified)
- getUserTier() // For drivers: standard/professional/elite
```

---

## 📊 DATABASE MODIFICATIONS REQUIRED

### SQL Setup Script
```sql
-- Run in Supabase SQL Editor to create new tables

-- 1. drivers table
CREATE TABLE drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  verification_status VARCHAR DEFAULT 'pending',
  license_number VARCHAR UNIQUE NOT NULL,
  license_expiry DATE NOT NULL,
  license_verified BOOLEAN DEFAULT FALSE,
  nbi_clearance_number VARCHAR UNIQUE NOT NULL,
  nbi_expiry DATE NOT NULL,
  nbi_verified BOOLEAN DEFAULT FALSE,
  nbi_file_url VARCHAR,
  driver_tier VARCHAR DEFAULT 'standard',
  rating FLOAT DEFAULT 0.0,
  total_trips INTEGER DEFAULT 0,
  preferred_days VARCHAR,
  preferred_areas VARCHAR,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. driver_documents table
CREATE TABLE driver_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
  document_type VARCHAR NOT NULL,
  file_url VARCHAR NOT NULL,
  issue_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  status VARCHAR DEFAULT 'pending',
  admin_notes TEXT,
  verified_at TIMESTAMP,
  verified_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. driver_job_assignments table
CREATE TABLE driver_job_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR DEFAULT 'pending_offer',
  offered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  replied_at TIMESTAMP,
  trip_fee DECIMAL(10,2) DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. driver_trips table
CREATE TABLE driver_trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pickup_location VARCHAR,
  pickup_time TIMESTAMP,
  dropoff_location VARCHAR,
  dropoff_time TIMESTAMP,
  status VARCHAR DEFAULT 'pending',
  distance_km FLOAT,
  duration_minutes INTEGER,
  renter_rating FLOAT,
  renter_comment TEXT,
  driver_comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 5. driver_earnings table
CREATE TABLE driver_earnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trip_id UUID REFERENCES driver_trips(id) ON DELETE SET NULL,
  trip_fee DECIMAL(10,2) NOT NULL,
  commission_percentage DECIMAL(5,2) DEFAULT 15,
  commission_amount DECIMAL(10,2),
  net_earnings DECIMAL(10,2),
  payout_status VARCHAR DEFAULT 'pending',
  paid_at TIMESTAMP,
  payout_method VARCHAR,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. driver_availability_schedule table
CREATE TABLE driver_availability_schedule (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day_of_week VARCHAR,
  start_time TIME,
  end_time TIME,
  date DATE,
  is_available BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add index for faster queries
CREATE INDEX idx_drivers_user_id ON drivers(user_id);
CREATE INDEX idx_driver_documents_driver_id ON driver_documents(driver_id);
CREATE INDEX idx_driver_trips_driver_id ON driver_trips(driver_id);
CREATE INDEX idx_driver_earnings_driver_id ON driver_earnings(driver_id);
CREATE INDEX idx_job_assignments_driver_id ON driver_job_assignments(driver_id);
```

---

## ✅ IMPLEMENTATION CHECKLIST

### Phase 1: Database Setup
- [ ] Create all new tables using SQL script
- [ ] Create indexes
- [ ] Test database queries

### Phase 2: Update SignupScreen
- [ ] Add "Become a Driver" option in role selection
- [ ] Create driver_signup_screen.dart if choosing driver role
- [ ] Update navigation flow in signup_screen.dart

### Phase 3: Driver Verification Screens
- [ ] Create driver_license_upload_screen.dart
- [ ] Create driver_nbi_upload_screen.dart
- [ ] Create driver_availability_screen.dart
- [ ] File upload handlers

### Phase 4: Driver Service
- [ ] Create DriverService with all required methods
- [ ] Integrate with Supabase client
- [ ] Error handling

### Phase 5: Driver Home Screen
- [ ] Create driver_home_screen.dart with 5 tabs
- [ ] Dashboard tab with stats
- [ ] Jobs tab with pending/active/completed
- [ ] Earnings tab with history
- [ ] Availability tab with schedule management
- [ ] Profile tab

### Phase 6: Integration with Operator
- [ ] Update Operator booking workflow to show driver pool
- [ ] Operator can see available drivers
- [ ] Integration with driver_job_assignments table

### Phase 7: Admin Integration
- [ ] Update Admin Driver Intake tab to review applications
- [ ] Add approval/rejection workflow
- [ ] Tier assignment (standard/professional/elite)

### Phase 8: Testing & Refinement
- [ ] Test complete driver signup flow
- [ ] Test job offer/acceptance flow
- [ ] Test earnings tracking
- [ ] Test real-time notifications

---

## 🔐 SECURITY & VALIDATION

### Validation Rules
- License expiry must be in future
- NBI expiry must be in future
- License number must be unique
- NBI number must be unique
- Phone format validation
- Email verification required

### Authorization
- Only drivers can decline jobs
- Only operator can assign drivers
- Only system can update driver_trips
- Only admin can verify documents

---

## 📲 NOTIFICATION TRIGGERS

When implemented, drivers should be notified via:

1. **Job Offer Notification**
   - When operator assigns booking to driver
   - Show job details: pickup, dropoff, time, earnings

2. **Job Acceptance Confirmation**
   - When driver accepts a job
   - Send to operator & renter

3. **Trip Start Notification**
   - When renter marks trip as started
   - Send GPS location tracking link

4. **Trip Complete**
   - When renter marks trip complete
   - Prompt for rating & payout processing

5. **Payout Confirmation**
   - When earnings paid out
   - Show amount & method

---

## 🚀 NEXT STEPS

1. **Execute the SQL setup script** in Supabase to create all tables
2. **Create DriverService** class
3. **Implement Driver Sign-Up Screens** (3 screens)
4. **Create Driver Home Screen** (5 tabs)
5. **Update Admin Driver Intake** to match new workflow
6. **Test complete driver workflow**

---

## 📞 QUESTIONS FOR CLARIFICATION

1. Driver commission: Is it always 15%? Or variable?
2. Payout frequency: Daily, weekly, monthly?
3. Driver tier progression: Manual by admin or auto-calculated?
4. Real-time tracking: During trip only? Or always?
5. Can drivers reject jobs? With penalty?
6. Multi-language support needed for driver app?

