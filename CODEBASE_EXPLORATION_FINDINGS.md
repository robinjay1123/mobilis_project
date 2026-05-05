# Codebase Exploration Findings

## 1. Database Schema - Vehicles Table (Transmission Column)

### Migration Timeline:

**Status: TRANSMISSION COLUMN HAS BEEN DROPPED (NO LONGER EXISTS)**

#### Created in Baseline Schema
- **File:** [supabase/migrations/20250401_baseline_schema.sql](supabase/migrations/20250401_baseline_schema.sql#L59)
- **Line:** 59
- **Definition:** `transmission VARCHAR(100),`
- **Context:** Initial database schema creation

#### Re-added in Search Columns Migration
- **File:** [supabase/migrations/20260422_add_vehicle_type_and_search_columns.sql](supabase/migrations/20260422_add_vehicle_type_and_search_columns.sql#L13)
- **Line:** 13
- **Definition:** `ADD COLUMN IF NOT EXISTS transmission TEXT,`
- **Purpose:** Enable vehicle search and filtering functionality in renter UI

#### Dropped in Obsolete Columns Cleanup
- **File:** [supabase/migrations/20260511_drop_obsolete_vehicle_columns.sql](supabase/migrations/20260511_drop_obsolete_vehicle_columns.sql#L1-L12)
- **Lines:** 1-12 (Full file content)
- **Dropped Columns:** `image_url`, `transmission`, `fuel_type`
- **Reason:** These columns are no longer used by the app schema. Vehicle images are stored separately in `vehicle_images` table via relation.

### Current Schema Status:
- **Status:** ❌ DOES NOT EXIST in current schema
- **Last Modified:** Migration 20260511 (most recent)
- **Impact:** Transmission data is no longer part of vehicles table. Any UI that displays transmission info needs alternative data source or must be updated to not display it.

---

## 2. Currency Symbols ($) Usage in UI

### Files Using Currency Symbols:

#### 1. Admin Dashboard - Revenue Display
- **File:** [lib/mobile_ui/screens/admin/admin_dashboard_screen.dart](lib/mobile_ui/screens/admin/admin_dashboard_screen.dart#L840)
- **Line:** 840
- **Code:** `'\$${_totalRevenue.toStringAsFixed(2)}'`
- **Context:** Displays total revenue in admin dashboard
- **Display Pattern:** `$` prefix with 2 decimal places (e.g., `$12,345.67`)

#### 2. Booking Card - Total Cost
- **File:** [lib/mobile_ui/widgets/booking_card.dart](lib/mobile_ui/widgets/booking_card.dart#L193)
- **Line:** 193
- **Code:** `'\$$totalCost'`
- **Context:** Shows total cost in booking cards
- **Display Pattern:** `$` prefix (e.g., `$150`)

#### 3. Dashboard Overview Tab - Total Revenue
- **File:** [lib/mobile_ui/screens/admin/tabs/dashboard_overview_tab.dart](lib/mobile_ui/screens/admin/tabs/dashboard_overview_tab.dart#L43)
- **Line:** 43
- **Code:** `value: '\$${_formatNumber(totalRevenue)}'`
- **Context:** Dashboard statistics card showing total revenue
- **Display Pattern:** `$` prefix with formatted number (e.g., `$1,234,567.89`)

### Currency Implementation Summary:
- **Total Files:** 3 files contain currency symbols
- **Pattern:** All use hardcoded `$` symbol (USD currency)
- **Formatting:** Mix of direct display and number formatting methods
- **No localization detected:** All hardcoded to USD currency symbol

---

## 3. Operators Page - CRUD Operations

### Operators Web Interface
- **File:** [lib/web_ui/screens/operator/operator_web_screen.dart](lib/web_ui/screens/operator/operator_web_screen.dart)
- **Class:** `OperatorWebScreen` (StatefulWidget) - Lines 1-26
- **State Class:** `_OperatorWebScreenState` extends State<OperatorWebScreen>

### Operators Management Capabilities:

#### Navigation/UI Structure
- **Navigation Index:** `_selectedIndex` variable to track current page
- **Sidebar Status:** `_sidebarExpanded` boolean for collapsible sidebar
- **Lines:** 28-32

#### Statistics/Tracking
- **Total Users:** `_totalUsers` (Line 36)
- **Total Partners:** `_totalPartners` (Line 37)
- **Total Vehicles:** `_totalVehicles` (Line 38)
- **Pending Verifications:** `_pendingVerifications` (Line 39)
- **Active Bookings:** `_activeBookings` (Line 40)
- **Total Bookings:** `_totalBookings` (Line 41)

#### Data Lists
- **Pending Applications:** `_pendingApplications` (Line 44)
- **Recent Bookings:** `_recentBookings` (Line 45)
- **Vehicles:** `_vehicles` (Line 46)
- **Partner Vehicles:** `_partnerVehicles` (Line 47)

#### Vehicle Management Form Fields
- **Form Controllers:** Lines 51-68
  - Brand, Model, Year, Plate Number
  - Price (daily and hourly rates)
  - Category, Vehicle Type, Name
  - Description, Color
  - Location (with latitude/longitude)
- **Selected Status:** `_selectedStatus` (Line 69) - default 'active'
- **Image Management:** `_selectedImages` list for multi-image uploads
- **Submission State:** `_isSubmittingVehicle` loading flag

#### Key Methods
- **Initialization:** `initState()` - calls `_loadDashboardData()`
- **Cleanup:** `dispose()` - disposes all TextEditingControllers
- **Location Services:** `_getCurrentVehicleLocation()` method (Line 87+)
  - Uses Geolocator plugin for GPS coordinates
  - Uses Geocoding plugin for address reverse-lookup
  - Returns location string, latitude, and longitude

#### Storage Integration
- **Bucket Name:** `vehicle_images` (Line 50)
- **Image Upload Support:** Web and mobile support via `image_picker`

### Features Detected:
- ✅ Vehicle creation/update functionality
- ✅ Location-based operations (GPS tracking)
- ✅ Multi-image upload capability
- ✅ Dashboard statistics tracking
- ✅ Partner vehicle management
- ✅ Booking management
- ✅ User/verification management

---

## 4. Booking Details Display Implementation

### Primary Implementation
- **File:** [lib/mobile_ui/screens/home/dashboard_screen.dart](lib/mobile_ui/screens/home/dashboard_screen.dart#L2444)
- **Method:** `_showBookingDetails()`
- **Lines:** 2444-2550

### How Booking Details Modal Works:

#### Modal Configuration
- **Type:** Modal Bottom Sheet
- **Background Color:** `AppColors.darkBgSecondary`
- **Border Radius:** 20px circular border (top corners only)
- **Scrollable:** Uses `SingleChildScrollView` for content overflow

#### Header Section
- **Title:** "Trip Details" (Text widget)
- **Close Button:** Icon button (Icons.close) to dismiss modal
- **Lines:** 2455-2475

#### Car Information Display (BOOKING SUMMARY)
- **Container Layout:** Lines 2476-2505
- **Components:**
  - **Car Icon/Placeholder:** 50x50 container with `Icons.directions_car`
    - Note: Uses placeholder icon, NOT actual car image
    - Background color: `AppColors.darkBgTertiary`
    - Border radius: 8px
  
  - **Car Details:**
    - Car Name: `booking['carName']` (14px, bold, primary text)
    - Rental Partner: `booking['rentalPartner']` (12px, secondary text)
  
  - **Status Badge:** `StatusBadge` widget showing booking status

#### Trip Timeline Section
- **Section Title:** "Trip Timeline" (Lines 2507-2515)
- **Timeline Components:**
  - **Pickup Step:** Lines 2516-2525
    - Label: "Pickup"
    - Date: `booking['startDate']`
    - Time: "2:00 PM" (hardcoded)
    - Icon: `Icons.location_on`
    - Active state: true
  
  - **Dropoff Step:** Lines 2526-2535
    - Label: "Dropoff"
    - Date: `booking['endDate']`
    - Time: "2:00 PM" (hardcoded)
    - Icon: `Icons.location_on`
    - Completion state: checks if `booking['status'] == 'Completed'`

### Booking Data Structure Expected:
```dart
{
  'carName': String,              // e.g., "Toyota Camry"
  'rentalPartner': String,        // e.g., "ABC Rentals"
  'status': String,               // e.g., "active", "completed"
  'startDate': String/DateTime,   // Pickup date
  'endDate': String/DateTime,     // Dropoff date
}
```

### Display Triggers:
- **Line 1946:** Called on GestureDetector tap for bookings
- **Line 1960:** Called on list item onTap gesture
- **Passed Data:** `bookings[index]` - individual booking map

### Visual Elements:
- ✅ Car icon placeholder (NOT actual image URL implementation)
- ✅ Booking summary (car name + partner name)
- ✅ Status badge
- ✅ Timeline visualization
- ❌ No actual car image display (uses placeholder icon instead)
- ❌ No pricing breakdown
- ❌ No location maps or detailed address

### Limitations/Notes:
- **Car Image:** Uses `Icons.directions_car` placeholder instead of actual vehicle image
- **Related Widget:** Line 1398 references `final imageUrl = car['image_url'] as String?` but the booking details modal doesn't use it
- **Time Display:** Pickup and dropoff times are hardcoded to "2:00 PM" - should be dynamic from data
- **Customizable Components:** Uses `StatusBadge` and `TripTimelineStep` widgets from `mobile_ui/widgets/`

---

## Summary Table

| Item | File Path | Line Number(s) | Status |
|------|-----------|-----------------|--------|
| **Transmission Column** | supabase/migrations/20260511_drop_obsolete_vehicle_columns.sql | 8 | ❌ Dropped |
| **Currency Display** (Admin) | lib/mobile_ui/screens/admin/admin_dashboard_screen.dart | 840 | ✅ Active |
| **Currency Display** (Booking) | lib/mobile_ui/widgets/booking_card.dart | 193 | ✅ Active |
| **Currency Display** (Stats) | lib/mobile_ui/screens/admin/tabs/dashboard_overview_tab.dart | 43 | ✅ Active |
| **Operators Page** | lib/web_ui/screens/operator/operator_web_screen.dart | 1-100+ | ✅ Active |
| **Booking Details Modal** | lib/mobile_ui/screens/home/dashboard_screen.dart | 2444-2550 | ✅ Active |

