# MOBILIS COMPLETE SYSTEM WORKFLOW - With Driver Integration

## 🎯 ALL USER ROLES & WORKFLOWS

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MOBILIS CAR RENTAL SYSTEM                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐ │
│  │    RENTER    │  │   PARTNER    │  │    DRIVER    │  │   OPERATOR     │ │
│  │ (Car Renter) │  │ (Car Owner)  │  │ (Company)    │  │ (Booking Mgr)  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └────────────────┘ │
│                                                                             │
│  ┌────────────────────────────────────────────────────────────────────────┐│
│  │                              ADMIN / SUPER                             ││
│  │                         (System Management)                            ││
│  └────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔐 AUTHENTICATION & REGISTRATION

### User Sign-Up Flow (All Roles)
```
Sign-Up Screen: Select Role
    ├─ Renter (Rent cars)
    ├─ Partner (Offer cars)
    └─ Driver (Provide driving service)
            ↓
Basic Info Collection
    ├─ Full name, email, phone
    ├─ Address, location
    ├─ Password (6+ chars)
    └─ Terms agreement
            ↓
Email Confirmation
            ↓
Verification Options (Role-specific)
    ├─ RENTER: Skip or Verify (ID + Face)
    ├─ PARTNER: Skip or Verify (ID + Face) + Vehicle Application
    └─ DRIVER: Skip or Verify (License + NBI Clearance)
            ↓
Document Upload (If full verification chosen)
    ├─ RENTER: ID, Driver's License, Face photo
    ├─ PARTNER: ID, Face photo (+ Vehicle docs after login)
    └─ DRIVER: License, NBI Clearance, Availability setup
            ↓
Admin Review & Approval
    ├─ ADMIN → Verification Hub (renters/partners)
    ├─ ADMIN → Driver Intake Tab (drivers)
    └─ Status: Pending → Approved/Rejected
            ↓
Role-Based Dashboard (After approval or skip)
```

---

## 👥 DETAILED ROLE WORKFLOWS

### 1️⃣ RENTER WORKFLOW
```
┌────────────────────────────────────┐
│ RENTER DASHBOARD (Newsfeed)        │
├────────────────────────────────────┤
│ 5 Tabs:                            │
│ 1. HOME (Vehicle Discover)         │
│ 2. BOOKINGS (My Rentals)           │
│ 3. NOTIFICATIONS (Alerts)          │
│ 4. MESSAGES (Chat)                 │
│ 5. PROFILE (Settings)              │
└────────────────────────────────────┘

COMPLETE BOOKING LIFECYCLE:

1. BROWSE VEHICLES
   ├─ Only is_available=true shown
   ├─ Filter by category (Economy/SUV/Luxury/Van)
   └─ Sort by price, rating, popularity

2. SELECT VEHICLE & OPTIONS
   ├─ Choose dates (start/end)
   ├─ SELECT BOOKING TYPE:
   │  ├─ Self-Drive (with_driver=false)
   │  │  "I will drive"
   │  └─ With Driver (with_driver=true)
   │     "I need a professional driver"
   ├─ Pick location
   └─ Confirm booking

3. BOOKING CREATED
   ├─ Status: PENDING
   ├─ Payment: Process payment
   └─ Wait for operator approval

4. BOOKING AWAITING APPROVAL (OPERATOR'S DESK)
   └─ Renter can't do anything, just wait

5. BOOKING APPROVED ✅
   ├─ Status: APPROVED
   ├─ Notification sent
   ├─ If with driver:
   │  └─ Driver assigned by operator
   └─ Ready for trip

6. TRIP STARTS
   ├─ Status: ACTIVE
   ├─ Driver (or partner) picks up renter
   ├─ Real-time tracking (if with driver)
   └─ Try to reach destination

7. TRIP COMPLETES
   ├─ Status: COMPLETED
   ├─ Rate the vehicle (1-5 stars)
   ├─ Rate the driver (if with driver service)
   ├─ Leave comment
   └─ Payment processed

8. HISTORY
   ├─ View past trips
   ├─ See ratings given
   └─ Download receipt
```

### 2️⃣ PARTNER WORKFLOW
```
┌────────────────────────────────────┐
│ PARTNER DASHBOARD                  │
├────────────────────────────────────┤
│ 5 Tabs:                            │
│ 1. DASHBOARD (Stats & Overview)    │
│ 2. APPLICATIONS (Vehicle Status)   │
│ 3. BOOKINGS (Rental Requests)      │
│ 4. CONVERSATIONS (Chat)            │
│ 5. NOTIFICATIONS (Alerts)          │
└────────────────────────────────────┘

WORKFLOW:

1. SIGN UP
   └─ role="partner"

2. OPTIONAL: GET VERIFIED
   ├─ Upload ID
   ├─ Face scan
   └─ Admin reviews

3. APPLY VEHICLE
   ├─ Fill details:
   │  ├─ Brand, model, year
   │  ├─ Plate number
   │  └─ Price per day/hour
   ├─ Upload documents:
   │  ├─ OR (Official Receipt)
   │  ├─ CR (Certificate of Registration)
   │  └─ Insurance docs
   └─ Submit for approval

4. VEHICLE APPLICATION STATUS
   ├─ Applications tab shows status
   └─ Status: PENDING → APPROVED/REJECTED

5. IF APPROVED ✅
   ├─ Vehicle added to vehicles table
   ├─ Operator can now toggle is_available
   ├─ When is_available=true:
   │  └─ Shows in renter's newsfeed
   └─ Bookings start coming in

6. RECEIVE BOOKINGS
   ├─ Bookings tab shows requests
   ├─ Shows:
   │  ├─ Renter info
   │  ├─ Dates & duration
   │  ├─ Booking type:
   │  │  ├─ Self-drive (partner not involved)
   │  │  └─ With driver (partner might drive)
   │  └─ Payment amount
   └─ STATUS: PENDING (operator must approve)

7. WAIT FOR OPERATOR APPROVAL
   ├─ Partner can't approve/reject
   ├─ Operator decides in their panel
   └─ Two scenarios:
      ├─ IF Partner is_driver=true + with_driver=true:
      │  └─ Partner drives, no driver assignment needed
      └─ IF Partner is_driver=false OR Self-drive:
         └─ Operator assigns company driver (or none for self-drive)

8. IF BOOKING APPROVED ✅
   ├─ Status changes to APPROVED
   ├─ If partner drives:
   │  ├─ Partner gets pickup notification
   │  ├─ Drives renter to destination
   │  └─ Gets payment when completed
   └─ If self-drive:
      └─ Renter drives (partner doesn't participate)

9. EARNINGS
   ├─ Earnings tracked after trip completion
   ├─ Payment automatically processed
   └─ Partner sees earnings in dashboard

10. RATINGS
    └─ View ratings from renters
```

### 3️⃣ DRIVER WORKFLOW (NEW - To Implement)
```
┌────────────────────────────────────┐
│ DRIVER HOME SCREEN (NEW)           │
├────────────────────────────────────┤
│ 5 Tabs:                            │
│ 1. DASHBOARD (Profile & Stats)     │
│ 2. JOBS (Offers & Active Trips)    │
│ 3. EARNINGS (Money History)        │
│ 4. AVAILABILITY (Schedule)         │
│ 5. PROFILE (Settings & Docs)       │
└────────────────────────────────────┘

WORKFLOW:

1. DRIVER SIGN-UP
   ├─ role="driver"
   ├─ Basic info (name, email, phone, address)
   └─ Account created

2. OPTIONAL: GET VERIFIED
   ├─ Upload License:
   │  ├─ License number
   │  ├─ Expiry date
   │  ├─ Photo (front)
   │  └─ Photo (back)
   ├─ Upload NBI Clearance:
   │  ├─ Clearance number
   │  ├─ Expiry date
   │  └─ Document file
   └─ Set availability:
      ├─ Preferred work days
      ├─ Preferred areas
      └─ Work hours

3. ADMIN REVIEW (Driver Intake Tab)
   ├─ Admin checks:
   │  ├─ License valid & not expired?
   │  ├─ NBI clearance valid & not expired?
   │  └─ Background check passed?
   ├─ Admin approves/rejects
   │
   ├─ IF APPROVED ✅:
   │  ├─ drivers.verification_status = "approved"
   │  ├─ Assign tier: Standard (default) / Professional / Elite
   │  ├─ user.is_available = true
   │  └─ Driver can now receive job offers
   │
   └─ IF REJECTED ❌:
      ├─ drivers.verification_status = "rejected"
      ├─ Reason provided
      └─ Can reapply after fixing issues

4. MANAGE AVAILABILITY
   ├─ Availability tab
   ├─ Toggle: AVAILABLE / UNAVAILABLE
   ├─ Set work schedule:
   │  ├─ Select days: Mon, Tue, Wed, etc.
   │  ├─ Set hours: 8AM - 6PM (example)
   │  └─ Preferred areas
   └─ Only receives offers when AVAILABLE

5. RECEIVE JOB OFFERS
   ├─ Operator assigns booking to driver
   ├─ Job offer notification (push notification)
   ├─ Shows in JOBS tab:
   │  ├─ Renter name
   │  ├─ Pickup location + time
   │  ├─ Dropoff location
   │  ├─ Estimated earnings
   │  └─ 2 buttons: ACCEPT / DECLINE
   └─ Driver has 5 minutes to respond (or auto-decline)

6. ACCEPT JOB
   ├─ driver_job_assignments.status = "accepted"
   ├─ Status changes to ACTIVE
   ├─ Driver gets:
   │  ├─ Renter phone number
   │  ├─ Detailed route
   │  └─ Vehicle to use (if company car)
   ├─ Notification sent to:
   │  ├─ Renter: "Your driver is coming"
   │  └─ Operator: "Job confirmed"
   └─ Trip starts

7. ACTIVE TRIP
   ├─ Driver sees:
   │  ├─ Real-time GPS navigation
   │  ├─ Renter's exact location
   │  ├─ Pickup location
   │  ├─ Dropoff: location
   │  └─ Timer showing elapsed time
   ├─ Driver navigation:
   │  ├─ Navigate to renter (pickup)
   │  ├─ Pick up renter
   │  ├─ Navigate to destination (dropoff)
   │  └─ Confirm arrival
   └─ Renter sees driver's real-time location

8. TRIP COMPLETION
   ├─ Driver marks trip COMPLETE
   ├─ Renter confirms dropoff
   ├─ driver_trips entry created:
   │  ├─ Distance traveled
   │  ├─ Duration
   │  └─ Final payment
   ├─ Renter rates driver (1-5 stars)
   ├─ Earnings calculated:
   │  ├─ Trip fee
   │  ├─ Minus PSDC commission (15% or custom)
   │  └─ = Net earnings for driver
   └─ Payment queued for payout

9. EARNINGS HISTORY
   ├─ EARNINGS tab shows:
   │  ├─ Today's earnings
   │  ├─ This week's earnings
   │  ├─ This month's earnings
   │  ├─ Breakdown:
   │  │  ├─ Trip fee
   │  │  ├─ Commission paid to PSDC
   │  │  └─ Net earned
   │  ├─ All past trips
   │  └─ Payout status:
   │     ├─ Pending
   │     ├─ Paid (with date)
   │     └─ Payout method (bank transfer, GCash, etc.)
   └─ Automatic weekly/monthly payouts

10. DECLINE JOB
    ├─ Driver can decline any offer
    ├─ Offer goes back to operator
    ├─ Operator tries another driver
    └─ No penalty

11. PROFILE & RATINGS
    ├─ PROFILE tab shows:
    │  ├─ Driver name & photo
    │  ├─ Average rating (from renters)
    │  ├─ Total trips completed
    │  ├─ Document status:
    │  │  ├─ License ✓/✗
    │  │  └─ NBI ✓/✗
    │  ├─ Driver tier (Standard/Professional/Elite)
    │  └─ Recent feedback from renters
    └─ Performance tracked for tier upgrades
```

### 4️⃣ OPERATOR WORKFLOW
```
┌────────────────────────────────────┐
│ OPERATOR PANEL                     │
├────────────────────────────────────┤
│ 4 Tabs:                            │
│ 1. DASHBOARD (Overview & Stats)    │
│ 2. VEHICLES (Togglable Visibility) │
│ 3. BOOKINGS (Approval Workflow)    │
│ 4. SETTINGS                        │
└────────────────────────────────────┘

WORKFLOW:

1. MANAGE VEHICLE VISIBILITY
   ├─ VEHICLES tab
   ├─ Lists all active vehicles
   ├─ Shows owner (Partner name or "Company Fleet")
   ├─ Each vehicle has toggle:
   │  ├─ ON (is_available=true) → Visible in renter feed
   │  └─ OFF (is_available=false) → Hidden from renters
   └─ Update inventory in real-time

2. BOOKING APPROVAL WORKFLOW (3 SCENARIOS)

   BOOKING ARRIVES (Status: PENDING)
       ├─ Vehicle booked
       ├─ Renter selected: Self-Drive OR With Driver
       └─ Operator reviews

   📌 SCENARIO A: SELF-DRIVE BOOKING
   ├─ with_driver = false
   ├─ Renter will drive themselves
   ├─ Operator action: Just approve ✅
   ├─ Operator clicks: "Approve Booking"
   ├─ Status → APPROVED
   ├─ Booking fee goes to:
   │  ├─ Partner (if partner's vehicle)
   │  └─ Company (if company vehicle)
   └─ No driver involved

   📌 SCENARIO B: WITH DRIVER + PARTNER DRIVES
   ├─ with_driver = true
   ├─ Partner is_driver = true
   ├─ Partner will drive their own vehicle
   ├─ Operator action: Just approve ✅
   ├─ Operator clicks: "Approve Booking"
   ├─ Status → APPROVED
   ├─ Booking fee goes to:
   │  ├─ Partner (as vehicle owner + driver)
   │  └─ PSDC takes commission
   └─ Partner gets pickup notification

   📌 SCENARIO C: WITH DRIVER + NEEDS ASSIGNMENT
   ├─ with_driver = true
   ├─ Partner is_driver = false OR Company vehicle
   ├─ Need to assign company driver
   ├─ Operator action: "Approve & Assign Driver"
   ├─ Modal opens showing available drivers:
   │  ├─ role = 'driver'
   │  ├─ is_available = true
   │  ├─ Within preferred areas
   │  └─ Within preferred hours
   ├─ Operator selects a driver from list
   ├─ Job offer sent to driver (driver gets notification)
   ├─ Booking status → APPROVED
   ├─ Booking fee split:
   │  ├─ Driver fee: 60-70% (configurable)
   │  ├─ Partner/Company: 20-30%
   │  └─ PSDC commission: rest
   └─ Driver has 5 mins to accept/decline

3. DRIVER JOB REJECTION (Scenario C only)
   ├─ If driver declines job
   ├─ Offer goes back to operator
   ├─ Operator can:
   │  ├─ Offer to another driver
   │  └─ Or auto-cancel booking
   └─ Renter gets notification

4. BOOKING REJECTION
   ├─ Operator can reject any booking
   ├─ Modal asks for reason:
   │  ├─ "Driver not available"
   │  ├─ "Vehicle issue"
   │  ├─ "Duplicate booking"
   │  └─ Custom reason
   ├─ Refund processed to renter
   └─ Renter gets notification with reason

5. LIVE BOOKING MONITORING
   ├─ Once booking ACTIVE:
   │  ├─ See real-time trip progress
   │  ├─ Driver's GPS location (if with driver)
   │  ├─ Estimated time to arrival
   │  └─ Can cancel if something goes wrong
   └─ After completion: See ratings, feedback

6. STATS DASHBOARD
   ├─ Total vehicles in system
   ├─ Available vehicles (in feed)
   ├─ Pending bookings (needs action)
   ├─ Active bookings (in progress)
   ├─ Available drivers (can accept jobs)
   └─ All with quick filters & date ranges
```

### 5️⃣ ADMIN WORKFLOW
```
┌────────────────────────────────────┐
│ ADMIN DASHBOARD                    │
├────────────────────────────────────┤
│ Comprehensive System Management    │
│ • User Management                  │
│ • Verification & Approval          │
│ • Vehicle Registration              │
│ • Driver Management                │
│ • Revenue & Reporting              │
└────────────────────────────────────┘

KEY ADMIN JOBS:

1. USER VERIFICATION (Verification Hub)
   ├─ Review pending user documents
   ├─ Face match checking (98% threshold)
   ├─ Approve or reject verification
   └─ Set verification_status

2. PARTNER VEHICLE APPROVAL (Vehicle Intake Tab)
   ├─ Review vehicle applications
   ├─ Check documents:
   │  ├─ OR (Official Receipt)
   │  ├─ CR (Certificate of Registration)
   │  └─ Insurance documents
   ├─ Approve OR Reject
   ├─ If approved:
   │  └─ Vehicle created in vehicles table
   └─ If rejected:
      └─ Reason provided to partner

3. DRIVER APPROVAL (Driver Intake Tab)
   ├─ Review driver applications
   ├─ Check documents:
   │  ├─ License (not expired)
   │  └─ NBI Clearance (not expired)
   ├─ Verify background check
   ├─ If approved:
   │  ├─ Assign tier: Standard / Professional / Elite
   │  ├─ verification_status = "approved"
   │  └─ Driver available for job offers
   └─ If rejected:
      └─ Reason provided to driver

4. SYSTEM MONITORING
   ├─ Platform statistics
   ├─ User counts by role
   ├─ Vehicle inventory
   ├─ Booking trends
   ├─ Revenue tracking
   └─ Driver performance metrics
```

---

## 🔗 DATA FLOW CONNECTIONS

```
RENTER BOOKING → OPERATOR APPROVAL → DRIVER JOB OFFER → DRIVER ACCEPTANCE → ACTIVE TRIP → COMPLETION → RATINGS & EARNINGS

Users            Bookings           Job Assignments    Drivers         Driver Trips    Earnings
├─ renter_id ──→ ├─ renter_id       ├─ driver_id      ├─ user_id      ├─ driver_id ──→ ├─ driver_id
├─ role          ├─ vehicle_id      ├─ booking_id     ├─ License      ├─ booking_id    ├─ trip_id
└─ verified      ├─ with_driver     └─ status         ├─ NBI          ├─ distance      └─ net_earnings
                 ├─ driver_id
                 └─ status

PARTNER VEHICLE → ADMIN REVIEW → OPERATOR VISIBILITY → RENTER SEES → BOOKING CREATED

Users (Partner)  Vehicle App.     Vehicles           Dashboard       Bookings
├─ is_driver     ├─ status    →   ├─ is_available →  ├─ shows cars → ├─ status
└─ verified      └─ documents     ├─ owner_id       └─ filtered     └─ vehicle_id
```

---

## ✅ SUMMARY: WHO DOES WHAT

| Action | Renter | Partner | Driver | Operator | Admin |
|--------|--------|---------|--------|----------|-------|
| Browse & Book Vehicle | ✅ | ❌ | ❌ | ❌ | ❌ |
| Apply Vehicle | ❌ | ✅ | ❌ | ❌ | ❌ |
| Approve Vehicle | ❌ | ❌ | ❌ | ❌ | ✅ |
| Toggle Vehicle Visibility | ❌ | ❌ | ❌ | ✅ | ❌ |
| Accept Job Offer | ❌ | ❌ | ✅ | ❌ | ❌ |
| Assign Driver to Booking | ❌ | ❌ | ❌ | ✅ | ❌ |
| Approve/Reject Booking | ❌ | ❌ | ❌ | ✅ | ❌ |
| Approve Driver Docs | ❌ | ❌ | ❌ | ❌ | ✅ |
| Rate Driver/Vehicle | ✅ | ❌ | ❌ | ❌ | ❌ |
| Rate Renter (Driver) | ❌ | ❌ | ✅ | ❌ | ❌ |
| View Earnings | ❌ | ✅ | ✅ | ❌ | ❌ |
| Verify User Docs | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 📊 END-TO-END FLOW EXAMPLE

### Example: Renter Books Car With Driver Service

```
TIME 1: RENTER BOOKS
├─ Renter sees "Toyota Camry" (is_available=true)
├─ Owned by "Alex's Vehicles" (Partner)
├─ Selects dates: March 25-26, 2026
├─ Chooses: "With Driver Service"
├─ Booking created with:
│  ├─ renter_id = Renter's ID
│  ├─ vehicle_id = Camry
│  ├─ with_driver = true
│  ├─ status = "PENDING"
│  └─ driver_id = NULL (not assigned yet)
└─ Renter sees: "Waiting for operator approval"

TIME 2: OPERATOR RECEIVES BOOKING
├─ Booking appears in orange "PENDING" section
├─ Operator reviews:
│  ├─ Vehicle: Toyota Camry (Partner: Alex)
│  ├─ Renter: John Doe
│  ├─ Type: WITH DRIVER SERVICE
│  ├─ System checks: Is Alex a driver? (is_driver field)
│  └─ Answer: NO (Alex only owns the car)
├─ Operator sees message: "WITH DRIVER SERVICE - Partner won't drive, assign company driver"
└─ Operator clicks: "Approve & Assign Driver"

TIME 3: DRIVER SELECTION
├─ Modal opens showing available drivers:
│  ├─ Driver1: "Maria Santos" - Available, 4.8 rating
│  ├─ Driver2: "Jose Rivera" - Available, 4.5 rating
│  ├─ Driver3: "Ana Cruz" - Available, 4.9 rating
│  └─ [More drivers...]
├─ Operator selects: "Ana Cruz"
└─ Booking updated:
   ├─ status = "APPROVED"
   ├─ driver_id = Ana's ID
   └─ driver_assigned_at = NOW

TIME 4: DRIVER NOTIFICATION
├─ Ana gets push notification:
│  ├─ "New Job Offer"
│  ├─ "Pickup: Ortigas, Pasig @ 8:00 AM"
│  ├─ "Dropoff: BGC, Taguig"
│  ├─ "Earnings: ₱1,500"
│  ├─ [ACCEPT] [DECLINE] buttons
│  └─ 5-minute countdown
├─ Ana reviews:
│  ├─ Renter name: John Doe
│  ├─ Route on map
│  ├─ Estimated trip time: 45 minutes
│  └─ Earnings after commission: ₱1,050 (30% to PSDC)
└─ Ana clicks: [ACCEPT]

TIME 5: BOOKING CONFIRMED
├─ Job Assignment Status: "ACCEPTED"
├─ All parties notified:
│  ├─ Renter: "Your driver Ana is assigned"
│  ├─ Partner Alex: "Your car is booked (self-driving)"
│  └─ Operator: "Job assigned to Ana"
└─ Booking Status: "APPROVED" → Ready to start

TIME 6: TRIP DAY (March 25, 8:00 AM)
├─ Ana navigates to pickup location (Ortigas)
├─ Renter sees Ana's real-time GPS location
├─ Ana arrives and calls Renter
├─ Renter gets in the car
├─ Trip status changes to: "ACTIVE"
└─ GPS tracking active on renter's phone

TIME 7: TRIP IN PROGRESS
├─ Ana drives from Ortigas to BGC (45 minutes)
├─ Renter can see:
│  ├─ Ana's current location on map
│  ├─ Estimated arrival time
│  └─ Trip timer (elapsed time)
├─ Operator can see trip progress if they check
└─ No issues, smooth ride

TIME 8: TRIP COMPLETED (9:00 AM)
├─ Ana arrives at BGC, Taguig
├─ Ana confirms: "Trip Completed"
├─ Renter confirms: "Arrived at destination"
├─ Trip Status: "COMPLETED"
├─ GPS tracking ended
└─ Payment immediately processed

TIME 9: RATINGS & EARNINGS
├─ Renter rates Ana: ⭐⭐⭐⭐⭐ (5 stars)
├─ Renter comments: "Great driver, clean car!"
│
├─ Ana rates Renter: ⭐⭐⭐⭐⭐ (5 stars)
├─ Ana comments: "Polite and friendly"
│
├─ Driver Earnings Recorded:
│  ├─ Trip fee: ₱1,500
│  ├─ Commission (30%): ₱450 (to PSDC)
│  ├─ Net earnings: ₱1,050
│  └─ Status: "PENDING PAYOUT"
│
├─ Partner Earnings Recorded:
│  ├─ Booking fee: ₱3,000 (full booking amount)
│  ├─ (Commission already included in split)
│  ├─ Net to partner: ₱1,500
│  └─ Status: "PENDING PAYOUT"
│
└─ Ana sees in EARNINGS tab:
   ├─ ✅ Trip completed
   ├─ Renter rated: ⭐⭐⭐⭐⭐
   ├─ Earned: ₱1,050
   └─ Payout: Pending (weekly payout Friday)

TIME 10: NEXT FRIDAY (Weekly Payout)
├─ All driver earnings from week processed
├─ Auto-transfers to Ana's registered bank account
├─ Ana sees in EARNINGS tab:
│  ├─ Status changed to: "PAID"
│  ├─ Amount: ₱7,250 (5 trips x ~₱1,450 avg)
│  ├─ Paid on: Friday, March 31
│  └─ Payout method: Bank Transfer

TIME 11: FUTURE
├─ Ana's rating improved (now 4.92 average)
├─ After 30+ trips with high ratings:
│  ├─ Auto-promoted to "Professional" tier
│  └─ Gets priority for better-paying jobs
├─ Renter completed purchase:
│  ├─ Sees booking in history
│  ├─ Can re-book same car/driver
│  ├─ Gets "preferred customer" benefits
│  └─ Can book for others (referral program)
└─ Partner Alex:
   ├─ Sees vehicle is popular
   ├─ Considers buying more cars
   └─ Applies for vehicle #2
```

---

**This is the complete end-to-end system workflow including all roles!**

