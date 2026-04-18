# Mobilis App - Complete Workflow Analysis & Fix Roadmap

**Document Date:** 2026-04-18  
**Status:** Critical issues identified, MVP-blocking components missing

---

## 🔴 CRITICAL ISSUES (BLOCKING)

### 1. **NO ADMIN SERVICE EXISTS** 
- **Impact:** Admin cannot approve/reject driver applications, partner applications, or manage users
- **Current State:** Zero admin service file
- **Required Methods:**
  - `approveDriverApplication(driverId, notes)` 
  - `rejectDriverApplication(driverId, reason)`
  - `approvePartnerApplication(partnerId, notes)`
  - `rejectPartnerApplication(partnerId, reason)`
  - `getApplicationsForReview(role)` - get pending applications
  - `suspendDriver(driverId, reason)`
  - `suspendPartner(partnerId, reason)`

### 2. **NO RENTER SERVICE EXISTS**
- **Impact:** Renters cannot complete verification workflow, cannot upload documents
- **Current State:** Zero renter service file
- **Required Methods:**
  - `getRenterProfile(userId)` 
  - `createRenterProfile(userId)`
  - `uploadVerificationDocument(renterId, docType, fileUrl)`
  - `getRenterVerificationStatus(userId)` 
  - `updateVerificationStatus(userId, status)`
  - `skipVerification(userId)` - sets basic renter status

### 3. **DRIVER/PARTNER APPLICATION APPROVAL MISSING**
- **Impact:** Applications created (application_status='pending') but stuck forever - admin has no way to approve
- **Current State:** 
  - `partner_service.submitVehicleApplication()` creates pending application ✅
  - No method to approve/reject it ❌
  - `driver_service` has no application submission/approval at all ❌
- **Missing:** 
  - Partner: `approveVehicleApplication()`, `rejectVehicleApplication()`
  - Driver: `submitDriverApplication()` wrapper
  - Both: Track rejection reasons

### 4. **VEHICLE CRUD INCOMPLETE** 
- **Impact:** Partners can only view vehicles, cannot create/edit/delete
- **Current State:**
  - `getPartnerVehicles()` ✅
  - `getVehicleById()` ✅
  - Availability management ✅
  - **Missing:** create, update, delete operations ❌
- **Required:**
  - `createVehicle(partnerId, vehicleDetails)`
  - `updateVehicle(vehicleId, vehicleDetails)`
  - `deleteVehicle(vehicleId)`

### 5. **UI NOT WIRED TO EXISTING SERVICES**
- **Impact:** Features work in backend but users can't access them
- **Current State:**
  - Operator stats calculated but never rendered (unused fields: `_totalBookings`, `_activeBookings`)
  - Admin stats calculated but never rendered (unused fields: `_totalVehicles`)
  - Methods exist but no UI buttons call them (`_assignDriver()`, `_updateVehicleStatus()`, `_showChatDialog()`)
- **Required:** Wire stats to dashboard cards, add action buttons

---

## 🟡 HIGH-PRIORITY ISSUES (WORKFLOW GAPS)

### 6. **Operator Workflow Incomplete**
- Can't assign drivers directly (only create job offers)
- Can't provide reason when approving/rejecting bookings
- Missing context tracking

### 7. **Renter Verification Not Started**
- Skip verification flow exists (sets id_verified=false initially)
- Can't actually upload ID, face scan, or documents
- No service methods to complete verification later

### 8. **Search/Filter Missing**
- Renter can't search vehicles by:
  - Date availability
  - Location
  - Vehicle type/category
  - Price range
- Partners can't filter their bookings meaningfully
- Admins can't filter applications by status

### 9. **No Application Status History/Audit Trail**
- No way to see who approved, when, with what notes
- Rejections don't have feedback for applicants
- Critical for debugging and user support

### 10. **Document Validation Missing**
- License/NBI expiry dates not validated
- No check if required documents exist before trip assignment
- No document expiry notifications

---

## ✅ WHAT'S WORKING

| Component | Status | Quality |
|-----------|--------|---------|
| Renter → Browse Vehicles | ✅ | Good |
| Renter → Create Booking | ✅ | Good |
| Driver → Upload Documents | ✅ | Good |
| Driver → Manage Availability | ✅ | Good |
| Driver → Accept Job Offers | ✅ | Good |
| Driver → Complete Trips | ✅ | Good |
| Driver → View Earnings | ✅ | Excellent |
| Partner → Create Vehicle | ⚠️ | Partial (availability only) |
| Partner → Submit Vehicle App | ✅ | Good |
| Operator → View Bookings | ✅ | Good |
| Admin → Dashboard Stats | ❌ | Stats fetched but not displayed |

---

## 📋 WORKFLOW IMPLEMENTATION ROADMAP

### **PHASE 1: CRITICAL (Must complete for MVP)**

#### 1.1 - Create AdminService (3-4 hours)
```dart
// lib/services/admin_service.dart
class AdminService {
  // User Management
  Future<List<Map>> getPendingVerifications()
  Future<List<Map>> getVerifiedUsers()
  Future<List<Map>> getUsersByRole(String role)
  Future<void> suspendUser(String userId, String reason)
  Future<void> unsuspendUser(String userId)
  
  // Driver Applications
  Future<List<Map>> getPendingDriverApplications()
  Future<void> approveDriverApplication(String driverId, String notes)
  Future<void> rejectDriverApplication(String driverId, String reason)
  
  // Partner Applications  
  Future<List<Map>> getPendingPartnerApplications()
  Future<void> approvePartnerApplication(String partnerId, String notes)
  Future<void> rejectPartnerApplication(String partnerId, String reason)
  
  // Vehicle Applications
  Future<List<Map>> getPendingVehicleApplications()
  Future<void> approveVehicleApplication(String appId, String notes)
  Future<void> rejectVehicleApplication(String appId, String reason)
  
  // Dashboard Stats
  Future<Map<String, int>> getDashboardStats()
  Future<List<Map>> getRecentApplications()
}
```

#### 1.2 - Create RenterService (2-3 hours)
```dart
// lib/services/renter_service.dart
class RenterService {
  Future<Map?> getRenterProfile(String userId)
  Future<Map> createRenterProfile(String userId)
  
  // Verification
  Future<void> uploadVerificationDocument(String renterId, String docType, String fileUrl)
  Future<List<Map>> getVerificationDocuments(String renterId)
  Future<void> submitVerificationForReview(String renterId)
  Future<String?> getVerificationStatus(String userId)
  Future<void> skipVerification(String userId)
  
  // Booking History
  Future<List<Map>> getBookingHistory(String userId)
  Future<Map?> getBookingById(String bookingId)
}
```

#### 1.3 - Wire Admin Dashboard Stats to UI (1.5 hours)
- Read existing stats from `_totalVehicles`, `_activeBookings`, etc.
- Create dashboard cards to display stats
- Add real-time listeners for stat updates

#### 1.4 - Wire Operator Stats to UI (1 hour)
- Display `_totalBookings`, `_activeBookings`, `_availableDrivers` in cards
- Add status breakdown (pending, confirmed, active, completed)

### **PHASE 2: HIGH-PRIORITY (Week 1)**

#### 2.1 - Complete Vehicle CRUD (2 hours)
```dart
// Add to VehicleService
Future<Map> createVehicle(String partnerId, Map vehicleData)
Future<void> updateVehicle(String vehicleId, Map vehicleData)
Future<void> deleteVehicle(String vehicleId)
Future<Map> uploadVehicleDocument(String vehicleId, String docType, String fileUrl)
```

#### 2.2 - Add Application Approval/Rejection to Services (2 hours)
```dart
// Add to PartnerService
Future<void> approveVehicleApplication(String appId, String notes)
Future<void> rejectVehicleApplication(String appId, String reason)

// Add to DriverService  
Future<Map> submitDriverApplication(Map documentData)
Future<void> withdrawApplication(String driverId)
```

#### 2.3 - Implement Operator Booking Workflow (2 hours)
```dart
// Add to BookingService
Future<void> approveBooking(String bookingId, String operatorNotes)
Future<void> rejectBooking(String bookingId, String reason)
Future<void> assignDriver(String bookingId, String driverId, double tripFee)
```

#### 2.4 - Create Admin Review Screens (3 hours)
- Driver applications review screen
- Partner applications review screen  
- User management screen (view, suspend, verify)
- Create action buttons wired to AdminService

### **PHASE 3: MEDIUM-PRIORITY (Week 2)**

#### 3.1 - Add Search/Filter (3 hours)
```dart
// VehicleService
Future<List<Map>> searchVehicles(Map filters) // date, location, type, price range

// BookingService
Future<List<Map>> searchBookings(Map filters) // date range, status, location

// AdminService  
Future<List<Map>> filterApplications(Map filters) // role, status, date range
```

#### 3.2 - Implement Renter Verification Complete Flow (2 hours)
- Wire document upload screens to RenterService
- Add verification status modal to dashboard
- Track verification progress (document types pending)

#### 3.3 - Add Document Expiry Validation (1.5 hours)
```dart
// Add to DriverService
Future<bool> validateDocumentExpiry(String driverId)
Future<List<Map>> getExpiringDocuments(String driverId)
```

#### 3.4 - Add Audit Trail for Applications (2 hours)
- Track approval/rejection timestamps
- Store approval/rejection reason
- Show history in application detail view

---

## 🛠️ IMPLEMENTATION STRATEGY

### **Step 1: Create Missing Services** (Priority: CRITICAL)
```bash
# Create these files:
lib/services/admin_service.dart
lib/services/renter_service.dart
```

### **Step 2: Extend Existing Services** (Priority: HIGH)
- Add approval methods to `partner_service.dart`
- Add approval methods to `driver_service.dart`  
- Add operator context to `booking_service.dart`
- Complete CRUD in `vehicle_service.dart`

### **Step 3: Wire UI to Services** (Priority: HIGH)
- Create admin application review screens
- Create renter verification workflow
- Add stats display to operator/admin dashboards
- Add action buttons (approve, reject, assign, etc.)

### **Step 4: Add Supporting Features** (Priority: MEDIUM)
- Search/filter across services
- Document validation
- Audit trail tracking
- Status history views

---

## 📊 ESTIMATED EFFORT

| Phase | Tasks | Hours | Priority |
|-------|-------|-------|----------|
| Phase 1 | Critical services + wiring | 12-14 | 🔴 |
| Phase 2 | High-priority workflows | 9-11 | 🟠 |
| Phase 3 | Medium features | 8-10 | 🟡 |
| **TOTAL** | | **29-35** | |

---

## ✅ CHECKLIST FOR COMPLETION

### Admin Workflow
- [ ] AdminService created with all required methods
- [ ] Admin dashboard displays real stats
- [ ] Admin can approve/reject driver applications
- [ ] Admin can approve/reject partner applications
- [ ] Admin can view pending verifications
- [ ] Admin can suspend users
- [ ] Application rejection includes reason tracking

### Renter Workflow
- [ ] RenterService created
- [ ] Renter can skip verification (basic renter)
- [ ] Renter can upload verification documents
- [ ] Renter verification can be completed in profile
- [ ] Renter status updates from basic→verified

### Driver Workflow
- [ ] Driver can submit application (wrapped in service)
- [ ] Driver application shows admin approval status
- [ ] Admin can approve driver (updates users.application_status='approved')
- [ ] Driver can't start trips until approved
- [ ] Document expiry validation works

### Partner Workflow
- [ ] Partner can create vehicles (add create method)
- [ ] Partner can submit vehicle applications
- [ ] Partner can see application status
- [ ] Admin can approve vehicle applications
- [ ] Admin can reject with reason

### Operator Workflow
- [ ] Operator dashboard shows real stats
- [ ] Operator can approve/reject bookings
- [ ] Operator can assign drivers to bookings
- [ ] Assignment includes context/notes

### General
- [ ] All compile errors fixed
- [ ] Unused fields wired to UI or removed
- [ ] Unused methods have TODO comments if needed later
- [ ] Error handling consistent across services
- [ ] Debug logging at critical points

---

## 🚀 NEXT STEP

**Recommendation:** Start with Phase 1 immediately:
1. Create `AdminService` (most critical)
2. Create `RenterService` (second most critical)
3. Wire stats to dashboards (unblock operator/admin workflows)

This will unblock 60% of workflow issues.
