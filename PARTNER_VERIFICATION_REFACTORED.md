# Partner Verification Refactored

## 🎯 NEW LOGIC

### Two-Step Process (Like Renter Verification)

#### **Step 1: Partner Identity Verification** ✅
- **ONLY requirement** to become a partner
- Upload: National ID (front + back) ONLY - Simple!
- No face photo needed
- No OR/CR needed here
- Admin reviews → Approves/Rejects
- Same flow as renter verification
- Uses `user_verifications` table (id_document_url only)

#### **Step 2: Vehicle Application** (Separate)
- **ONLY when adding a vehicle**
- Upload: OR + CR documents
- Uses `partner_vehicle_applications` + `vehicle_documents` tables
- Admin reviews vehicle documents separately

---

## 📊 Database Tables Used

### Partner Verification (Step 1)
```
user_verifications
├─ id
├─ user_id
├─ id_document_url (National ID front + back)
├─ face_photo_url
├─ verification_status (pending → verified/rejected)
└─ admin_notes
```

### Vehicle Application (Step 2)
```
partner_vehicle_applications
├─ id
├─ partner_id (FK to users)
├─ vehicle_info (brand, model, price, etc)
├─ application_status (pending → approved/rejected)
└─ created_at

vehicle_documents
├─ id
├─ application_id (FK to partner_vehicle_applications)
├─ document_type (or, cr, insurance, registration)
├─ file_url
├─ status (pending → verified/rejected)
└─ expiry_date
```

---

## 🔧 Services to Use

### 1. **PartnerVerificationService** (NEW)
For partner identity verification (Step 1)

```dart
final partnerVerifyService = PartnerVerificationService();

// Submit identity verification (ID only - no face photo)
await partnerVerifyService.submitPartnerVerification(
  userId: userId,
  idDocumentUrl: idUrl,  // ID front + back combined
);

// Skip verification (basic partner)
await partnerVerifyService.skipPartnerVerification(userId);

// Check if verified
final isVerified = await partnerVerifyService.isPartnerVerified(userId);
```

### 2. **VehicleDocumentService** (NEW)
For uploading vehicle documents during vehicle application (Step 2)

```dart
final vehicleDocService = VehicleDocumentService();

// Upload OR document
await vehicleDocService.uploadVehicleDocument(
  applicationId: appId,
  partnerId: userId,
  file: orFile,
  documentType: 'or',
  expiryDate: DateTime.parse('2027-12-31'),
);

// Upload CR document
await vehicleDocService.uploadVehicleDocument(
  applicationId: appId,
  partnerId: userId,
  file: crFile,
  documentType: 'cr',
  expiryDate: DateTime.parse('2027-12-31'),
);

// Check if all required docs uploaded
final hasAll = await vehicleDocService.hasAllRequiredDocuments(appId);
```

### 3. **AdminService** (UPDATED)
Separate methods for partner verification vs vehicle documents

```dart
final adminService = AdminService();

// === PARTNER VERIFICATION (Step 1) ===
final pendingPartnerVerifs = await adminService.getPendingPartnerVerifications();
final partnerVerif = await adminService.getPartnerVerificationForReview(userId);

await adminService.approvePartnerVerification(
  userId: userId,
  adminNotes: 'ID verified, approved as partner',
);

await adminService.rejectPartnerVerification(
  userId: userId,
  reason: 'ID expired - please resubmit',
);

// === VEHICLE DOCUMENTS (Step 2) ===
final pendingVehicleDocs = await adminService.getAllPendingVehicleDocuments();

await adminService.verifyVehicleDocument(
  documentId: docId,
  adminNotes: 'OR valid',
);

await adminService.rejectVehicleDocument(
  documentId: docId,
  reason: 'CR expired',
);
```

---

## 🚀 Application Flow

```
PARTNER SIGNUP
├─ Sign up with email/password + role=partner
│
└─ Step 1: IDENTITY VERIFICATION (ID ONLY)
   ├─ Upload National ID front
   ├─ Upload National ID back
   ├─ Submit to admin
   ├─ Admin reviews user_verifications
   └─ → Approved? Go to Step 2 : Rejected (request resubmit)
      
      Step 2: ADD FIRST VEHICLE
      ├─ Fill vehicle details (brand, model, price, etc)
      ├─ Upload OR document
      ├─ Upload CR document
      ├─ Submit vehicle application
      ├─ Admin reviews vehicle_documents
      └─ → Approved? Vehicle now live : Rejected (request updates)
         
         ADD MORE VEHICLES
         ├─ Repeat Step 2 for each new vehicle
         └─ No need to re-verify identity
```

---

## 📱 UI Updates Needed

### Current Issues
- `owner_verification_screen.dart` asks for OR/CR during partner signup
- Should ONLY ask for ID + Face verification

### Changes
1. Remove "Vehicle Registration" item from `owner_verification_screen.dart`
2. Create new `partner_verification_screen.dart` (same as `document_verification_screen.dart`)
3. Update vehicle application flow to collect OR/CR separately

### New Flow
```
1. VerificationOptionsScreen (role=partner)
   └─ Show "Partner Identity Verification" button

2. DocumentVerificationScreen (ID ONLY - Front + Back)
   └─ Simple 2-step upload (not 3 like renter's face verification)

3. PartnerHomeScreen
   └─ After verification, show:
      ├─ Add Vehicle button
      └─ My Vehicles list

4. AddVehicleScreen
   └─ Collect:
      ├─ Vehicle details
      ├─ OR document
      ├─ CR document
      └─ Submit for admin approval

5. Unverified Ad Popup ⚠️
   └─ When partner tries to add vehicle without verification:
      ├─ Modal appears: "Complete Identity Verification First"
      ├─ Show reason: "Upload your ID to add vehicles"
      └─ "Verify Now" button → DocumentVerificationScreen
```

---

## ✅ Summary

| What | Where | When | Details |
|------|-------|------|---------|
| **National ID (Front + Back)** | `user_verifications.id_document_url` | During partner signup | Simple 2-step upload |
| **No Face Photo** | - | - | Removed for simplicity |
| **OR + CR docs** | `vehicle_documents` | When adding vehicle | Separate from ID verification |
| **Admin reviews ID** | AdminService.approvePartnerVerification() | After signup | Auto-syncs id_verified to users table |
| **Unverified Popup** | AddVehicleScreen | Before listing ad | Shows modal: "Complete verification first" |

**Data Flow:**
```
Upload ID → user_verifications.id_document_url → Admin approves 
  → trigger updates users.id_verified = true 
  → Partner can now add vehicles
```
