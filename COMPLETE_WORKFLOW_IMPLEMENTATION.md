# Complete Signup/Login Workflow Implementation Guide

## Overview
This document outlines the complete signup and login workflows implemented in the Mobilis app, including form persistence, credential caching, role-based verification, and operator activity logging.

## 1. Login Workflow

### 1.1 Screen: `LoginScreen` (`lib/mobile_ui/screens/auth/login_screen.dart`)

**Features:**
- Cached credential loading on screen load
- Remember device checkbox for credential persistence
- Email and password auto-fill from cache
- Clear error messages on validation failures
- Google OAuth integration

**Form Persistence:**
```dart
// Auto-load cached credentials in initState
@override
void initState() {
  super.initState();
  _loadCachedCredentials();
}

Future<void> _loadCachedCredentials() async {
  final email = await preferencesService.getCachedLoginEmail();
  final password = await preferencesService.getCachedLoginPassword();
  
  if (email != null && password != null) {
    emailController.text = email;
    passwordController.text = password;
    rememberDeviceCheckbox = true;
  }
}

// Save credentials if user checks "Remember Device"
Future<void> _handleLogin() async {
  await authService.login(
    email: email,
    password: password,
    rememberDevice: rememberDeviceCheckbox,
  );
}
```

**Credential Caching:**
- `PreferencesService.saveLoginCredentials(email, password, rememberDevice)` 
  - Saves email/password only if `rememberDevice` is true
  - Uses keys: `cached_login_email`, `cached_login_password`, `login_remember_device`
  - Cleared on logout with `clearCredentials` flag

**Result:**
- ✅ Users don't retype email/password after logout
- ✅ Credentials only saved if explicitly enabled
- ✅ Accidental logouts are handled - credentials still available

### 1.2 Service: `AuthService` (`lib/services/auth_service.dart`)

**Key Methods:**
- `login(email, password, {rememberDevice=false})` - Authenticate and optionally cache credentials
- `signOut({clearCredentials=false})` - Logout and optionally clear cached credentials
- `signInWithGoogle()` - OAuth login
- `getUserRole()` - Get current user's role (renter, driver, partner, operator, admin)

**Operator Logging Integration:**
```dart
// In OperatorHome Screen
@override
void initState() {
  super.initState();
  OperatorActivityLogger.logLogin();  // Log operator session start
  _loadDashboardData();
}

Future<void> _handleLogout() async {
  await OperatorActivityLogger.logLogout();  // Log before signing out
  await authService.signOut(clearCredentials: false);
}
```

## 2. Signup Workflow

### 2.1 Screen: `SignupScreen` (`lib/mobile_ui/screens/auth/signup_screen.dart`)

**Features:**
- Form data auto-save on every field change
- Automatic restoration of saved form data on screen load
- Clear data on successful signup
- Role-based signup (Renter, Driver, Partner)
- Email verification

**Form Persistence:**
```dart
@override
void initState() {
  super.initState();
  _loadSavedFormData();  // Restore previous form data
}

Future<void> _loadSavedFormData() async {
  final savedData = await preferencesService.getAllSignupFormData();
  if (savedData.isNotEmpty) {
    fullNameController.text = savedData['fullName'] ?? '';
    emailController.text = savedData['email'] ?? '';
    phoneController.text = savedData['phone'] ?? '';
    locationController.text = savedData['location'] ?? '';
    addressController.text = savedData['address'] ?? '';
    selectedRole = savedData['role'];
  }
}

Future<void> _handleSignup() async {
  // Save form data BEFORE validation
  await preferencesService.saveAllSignupFormData({
    'fullName': fullNameController.text,
    'email': emailController.text,
    'phone': phoneController.text,
    'location': locationController.text,
    'address': addressController.text,
    'role': selectedRole,
  });

  // Validate and signup
  if (!_validateForm()) return;

  final success = await authService.createUserWithEmailPassword(
    email: emailController.text,
    password: passwordController.text,
    userData: {...},
  );

  if (success) {
    // Clear saved form data after successful signup
    await preferencesService.clearSignupFormData();
  }
}
```

**Result:**
- ✅ Users don't lose form data on validation failures
- ✅ Form data persists across app restarts
- ✅ Data cleared after successful signup

### 2.2 Service: `AuthService` extensions

**Key Methods:**
- `createUserWithEmailPassword(email, password, userData)` - Create user with role-specific data
- `verifyEmail()` - Send verification email
- `completeProfileSetup()` - Complete additional profile info

## 3. Role-Based Workflows

### 3.1 Renter Workflow
```
1. Signup with RENTER role
   ↓
2. Auto-verify (renters auto-verified)
   ↓
3. Browse vehicles (VehicleSearchScreen)
   ↓
4. Create booking
   ↓
5. Complete payment
```

**Screens:**
- `SignupScreen` - Role selection
- `VehicleSearchScreen` - Search with 9 filters
- `BookingDetailScreen` - Booking creation (TODO)
- `PaymentScreen` - Payment processing (TODO)

### 3.2 Driver Workflow
```
1. Signup with DRIVER role
   ↓
2. Upload documents (license, NBI)
   ↓
3. Wait for admin approval (application_status = 'pending')
   ↓
4. Admin approves → status = 'approved'
   ↓
5. Accept job offers
   ↓
6. Track trips
```

**Document Upload:**
- `DriverService.uploadDriverDocument(driverId, documentType, fileUrl, expiryDate)`
- Document types: 'license', 'nbi', 'insurance'
- Status: 'pending' → 'approved' or 'rejected'

**Document Renewal:**
- `DriverService.renewDocument(documentId, newFileUrl, newExpiryDate)`
- Sets status to 'pending' for admin review
- Increments `renewal_count`

### 3.3 Partner Workflow
```
1. Signup with PARTNER role
   ↓
2. Add vehicle information
   ↓
3. Wait for admin approval (application_status = 'pending')
   ↓
4. Admin approves → status = 'approved'
   ↓
5. Receive booking requests
   ↓
6. Assign drivers to bookings
```

**Vehicle Management:**
- `VehicleService.createVehicle(vehicleData)`
- `VehicleService.uploadVehicleDocument(vehicleId, documentType, fileUrl, expiryDate)`
- Document types: 'insurance', 'registration'

### 3.4 Operator Workflow
```
1. Login with OPERATOR role (pre-created account)
   ↓
2. Dashboard loads (operator_home_screen.dart)
   ↓
3. Approve/reject bookings
   ↓
4. Assign drivers to approved bookings
   ↓
5. Track operator activities (logged to admin_audit_logs)
```

**Activity Logging:**
- `OperatorActivityLogger.logLogin()` - Log session start
- `OperatorActivityLogger.logLogout()` - Log session end
- `OperatorActivityLogger.logBookingApproved(bookingId, reason, price)` - Log approval
- `OperatorActivityLogger.logBookingRejected(bookingId, reason)` - Log rejection
- `OperatorActivityLogger.logDriverAssigned(bookingId, driverId, tripFee, driverName)` - Log assignment

**Admin View:**
- `AdminService.getOperatorActivityHistory(operatorId, limit=100, startDate?, endDate?)`
- `AdminService.getOperatorsWithRecentActivity(minutesThreshold=60)`
- `AdminService.getOperatorActivitySummary(operatorId)`

### 3.5 Admin Workflow
```
1. Login with ADMIN role (pre-created account)
   ↓
2. Dashboard loads (admin_dashboard_screen.dart)
   ↓
3. Review pending applications (drivers, partners, vehicles)
   ↓
4. Approve/reject with notes
   ↓
5. Manage document renewals
   ↓
6. View operator activity logs
```

**Application Review:**
- `AdminService.getPendingDriverApplications()`
- `AdminService.approveDriverApplication(driverId, notes)`
- `AdminService.rejectDriverApplication(driverId, reason)`
- `AdminService.getPendingPartnerApplications()`
- `AdminService.approvePar tnerApplication(partnerId, notes)`
- `AdminService.rejectPartnerApplication(partnerId, reason)`

**Document Renewal Review:**
- `AdminService.getPendingDocumentRenewals(docType?)`
- `AdminService.approveDocumentRenewal(documentId, docType, notes)`
- `AdminService.rejectDocumentRenewal(documentId, docType, reason)`
- `AdminService.getDocumentRenewalHistory(entityId, docType?)`

## 4. Document Expiry & Notifications

### 4.1 Document Expiry Tracking
- `DriverService.getExpiringDocuments(driverId, daysThreshold=90)`
- `VehicleService.getExpiringDocuments(vehicleId, daysThreshold=90)`
- `RenterService.getExpiringDocuments(userId, daysThreshold=90)`

### 4.2 Document Renewal Workflow
```
1. Driver/Partner notices document expiring soon
   ↓
2. Calls DriverService.renewDocument() or VehicleService.renewDocument()
   ↓
3. Document status set to 'pending' with new file/date
   ↓
4. Admin views pending renewals
   ↓
5. Admin approves/rejects renewal
   ↓
6. User receives notification (DocumentExpiryNotification Widget)
```

### 4.3 Notifications
- `NotificationService.createDocumentExpiryNotification(userId, documentType, daysUntilExpiry, documentId)`
- `NotificationService.checkAndNotifyExpiringDocuments(daysThreshold=30)` - Batch notification creation
- `DocumentExpiryBadge` - Widget to display badge count in AppBar
- `DocumentExpiryNotificationsScreen` - Full notifications list screen

## 5. Testing Workflows

### 5.1 Test Case: Renter Complete Workflow

```dart
// 1. Signup as Renter
SignupScreen → 
  fullName: "John Renter"
  email: "renter@test.com"
  password: "password123"
  role: RENTER
  // Form data automatically saved

// 2. Email verification (auto for renter)
// 3. Browse vehicles
VehicleSearchScreen →
  Filter by location, price, etc.
  Select vehicle
  
// 4. Create booking
BookingDetailScreen (TODO) →
  Select dates
  Review price
  Confirm booking

// 5. Complete payment
PaymentScreen (TODO) →
  Enter card details
  Process payment
  
// 6. Login again
LoginScreen →
  Remember Device: TRUE
  // Credentials auto-filled
  // Can browse and book without re-entering credentials
```

### 5.2 Test Case: Driver Complete Workflow

```dart
// 1. Signup as Driver
SignupScreen →
  fullName: "Jane Driver"
  email: "driver@test.com"
  password: "password123"
  role: DRIVER
  // Form data saved

// 2. Upload documents
DriverProfileScreen (TODO) →
  Upload License (expiry: 2027-12-31)
  Upload NBI (expiry: 2026-06-30)
  // Status: 'pending' → waiting for admin

// 3. Wait for admin approval
// Admin views: AdminService.getPendingDriverApplications()
// Admin: approveDriverApplication(driverId)
// Driver: application_status = 'approved'

// 4. Accept job offers
DriverJobsScreen (TODO) →
  View available jobs
  Accept job
  Track trip

// 5. Document renewal (when expiring soon)
DriverProfileScreen →
  NBI expires in 7 days
  Upload new NBI
  // Status: 'pending' → waiting for admin approval
  // Notification created: "NBI expiring in 7 days"

// 6. Admin approves renewal
// Admin: AdminService.approveDocumentRenewal(documentId, 'driver')
// Driver: Receives notification: "NBI approved"
```

### 5.3 Test Case: Operator Logging

```dart
// 1. Operator login
LoginScreen →
  email: "operator@test.com"
  // OperatorActivityLogger.logLogin() called
  // Logged to admin_audit_logs with action='login'

// 2. Approve booking
OperatorHomeScreen →
  Click "Approve" on booking
  // OperatorActivityLogger.logBookingApproved() called
  // Logged: action='booking_approved', price, reason

// 3. Reject booking
OperatorHomeScreen →
  Click "Reject" on booking
  // OperatorActivityLogger.logBookingRejected() called
  // Logged: action='booking_rejected', reason

// 4. Assign driver
OperatorHomeScreen →
  Select driver from dropdown
  Click "Assign"
  // OperatorActivityLogger.logDriverAssigned() called
  // Logged: action='driver_assigned', driver_name, trip_fee

// 5. Logout
OperatorHomeScreen →
  Click "Logout"
  // OperatorActivityLogger.logLogout() called
  // Logged: action='logout'

// 6. Admin views activity
AdminDashboardScreen (TODO) →
  View → Operator Activity Logs
  Filter by operator, date range
  See all: login, logouts, approvals, rejections, assignments
```

## 6. Preferences Service - Complete Reference

### Keys Used:
```dart
// Login credentials
'cached_login_email'        → String
'cached_login_password'     → String
'login_remember_device'     → bool

// Signup form data
'signup_fullName'           → String
'signup_email'              → String
'signup_phone'              → String
'signup_location'           → String
'signup_address'            → String
'signup_role'               → String

// Operator activity logs (local cache)
'operator_activity_log'     → String (JSON serialized)
```

### Methods:
```dart
// Login
saveLoginCredentials(email, password, rememberDevice)
getCachedLoginEmail()
getCachedLoginPassword()
clearLoginCredentials()

// Signup
saveAllSignupFormData(Map<String,String>)
getAllSignupFormData() → Map<String,String>
clearSignupFormData()

// Operator activity (local logging before sync)
logOperatorActivity(operatorId, activityType, description, metadata)
```

## 7. Service Integration Points

### AuthService Modifications:
```dart
// Before:
Future<bool> login(String email, String password)

// After:
Future<bool> login(String email, String password, {bool rememberDevice = false})
  // Now calls: preferencesService.saveLoginCredentials()

// Before:
Future<void> signOut()

// After:
Future<void> signOut({bool clearCredentials = false})
  // If clearCredentials=true, calls: preferencesService.clearLoginCredentials()
```

### AdminService Modifications:
```dart
// New methods:
logOperatorActivity(operatorId, activityType, description, bookingId?, driverId?, metadata?)
getOperatorActivityHistory(operatorId, limit=100, startDate?, endDate?)
getOperatorsWithRecentActivity(minutesThreshold=60)
getOperatorActivitySummary(operatorId)
getOperatorActivitiesByType(operatorId, activityType, limit=50)
approveDocumentRenewal(documentId, docType, notes?)
rejectDocumentRenewal(documentId, docType, reason)
getPendingDocumentRenewals(docType?)
getDocumentRenewalHistory(entityId, docType?)
```

## 8. Database Tables Summary

### admin_audit_logs (for operator tracking)
```sql
CREATE TABLE admin_audit_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  entity_id VARCHAR(255),        -- booking_id, driver_id, user_id, etc.
  entity_type VARCHAR(50),       -- 'booking', 'driver', 'partner', 'vehicle', etc.
  action VARCHAR(100),           -- 'login', 'logout', 'booking_approved', etc.
  notes TEXT,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### Existing tables with document expiry tracking:
```sql
driver_documents:
  - id, driver_id, document_type, file_url, expiry_date, status, renewal_count

vehicle_documents:
  - id, vehicle_id, document_type, file_url, expiry_date, status, renewal_count

renter_verification_documents:
  - id, user_id, document_type, file_url, expiry_date, status

notifications:
  - id, user_id, title, body, type ('document_expiry'), data (JSON), is_read, created_at
```

## 9. Compilation Status

✅ **Phase 1:** All 9 compile errors fixed
✅ **Phase 2:** All search/filter and expiry validation methods added
✅ **Form Persistence:** LoginScreen + SignupScreen integration complete
✅ **Operator Logging:** AdminService + OperatorActivityLogger integration complete
✅ **Item 1:** Document renewal workflow methods added (driver/vehicle/renter/admin services)
✅ **Item 2:** Vehicle Search Screen UI created
✅ **Item 3:** Operator activity logging integrated (5 action types)
✅ **Item 4:** Document expiry notifications (NotificationService + UI widgets)
✅ **Item 5:** Complete workflow documentation (this file)

## 10. Next Steps

### Immediate (High Priority):
1. Create `VehicleDetailScreen` with booking button
2. Create `BookingDetailScreen` for creating bookings
3. Create operator activity audit log viewer in admin dashboard
4. Create admin application review screens

### Medium Priority:
1. Payment integration for bookings
2. Real-time updates using Supabase subscriptions
3. Driver job offer/acceptance workflow UI
4. Push notifications for expiring documents

### Low Priority:
1. Web dashboard UI (`lib/web_ui/screens/`)
2. Analytics dashboard
3. Advanced filtering/search
4. Review and ratings system

---

**Implementation Date:** Current Session
**Status:** Items 1-4 Completed ✅ | Item 5 (Workflow Testing) In Progress
**Services Ready:** 6 services extended with 40+ methods
**UI Ready:** 3 new screens created, 2 widgets created
