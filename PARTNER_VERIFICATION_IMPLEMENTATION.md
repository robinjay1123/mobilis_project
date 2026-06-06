# Partner Verification Implementation Guide

## 🎯 Quick Summary

Partner verification is now **SIMPLE & FAST**:
- ✅ Only requires **National ID (front + back)**
- ✅ NO face photo needed
- ✅ Data saved to `user_verifications` table
- ✅ Admin approval syncs to `users.id_verified`

---

## 📁 New Files Created

### 1. Partner Document Verification Screen
**File:** `lib/mobile_ui/screens/auth/partner_document_verification_screen.dart`

Simple 3-step flow:
1. ID Front
2. ID Back
3. Review & Submit

**Usage:**
```dart
Navigator.pushNamed(context, '/partner-document-verification');
```

### 2. Unverified Ad Popup Widget
**File:** `lib/mobile_ui/widgets/unverified_ad_popup.dart`

Shows warning when unverified user tries to add vehicle/post ad.

**Usage:**
```dart
import '../../widgets/unverified_ad_popup.dart';

// In your add vehicle screen or anywhere user tries to list ad
final authService = AuthService();
final isVerified = await authService.isUserVerified();

if (!isVerified) {
  await UnverifiedAdPopup.show(
    context: context,
    title: 'Verification Required',
    message: 'You need to complete identity verification before you can add a vehicle.',
    userRole: 'partner',
  );
  return;
}

// Proceed with adding vehicle
```

---

## 🔧 Updated Services

### PartnerVerificationService
- `submitPartnerVerification()` - Now takes ONLY `idDocumentUrl` (no face photo)
- Saves to `user_verifications` table
- Admin approval triggers trigger that syncs `id_verified` to users table

```dart
final partnerVerifyService = PartnerVerificationService();

// Submit verification (ID only)
await partnerVerifyService.submitPartnerVerification(
  userId: userId,
  idDocumentUrl: idUrl,  // Front + Back combined
);

// Check if verified
final isVerified = await partnerVerifyService.isPartnerVerified(userId);
```

---

## 🛣️ Data Flow

```
Partner Signs Up (role=partner)
    ↓
PartnerDocumentVerificationScreen
    ├─ Step 1: Upload ID Front
    ├─ Step 2: Upload ID Back
    └─ Step 3: Review & Submit
        ↓
    Saved to user_verifications table
    verification_status = 'pending'
        ↓
    Admin reviews & approves
        ↓
    Database TRIGGER fires:
        └─ updates users.id_verified = true
            (VerificationService sync function)
        ↓
    Partner can NOW add vehicles!
```

---

## 📱 Routes to Add

Add these to your `main.dart` or route configuration:

```dart
'/partner-document-verification': (context) => const PartnerDocumentVerificationScreen(),
```

---

## ✅ Where to Add the Popup

Add the unverified popup in any screen where partners try to:
1. **Add a new vehicle** - Before showing vehicle details form
2. **Edit vehicle** - Before opening editor
3. **Post an ad** - Before showing posting form
4. **List a vehicle** - Before proceeding

**Example in AddVehicleScreen:**
```dart
import '../../widgets/unverified_ad_popup.dart';

class AddVehicleScreen extends StatefulWidget {
  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  
  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    final authService = AuthService();
    final user = authService.currentUser;
    
    if (user == null) return;

    final supabase = Supabase.instance.client;
    final userDoc = await supabase
        .from('users')
        .select('id_verified')
        .eq('id', user.id)
        .maybeSingle();

    final isVerified = userDoc?['id_verified'] as bool? ?? false;

    if (!isVerified && mounted) {
      // Show popup
      await UnverifiedAdPopup.show(
        context: context,
        title: 'Verification Required',
        message: 'You need to verify your identity before adding a vehicle.',
        userRole: 'partner',
      );
      
      // Navigate back
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... rest of screen
  }
}
```

---

## 🗄️ Database Table

**Table:** `user_verifications`

| Column | Type | Details |
|--------|------|---------|
| `id` | UUID | Primary key |
| `user_id` | UUID | References users(id) |
| `id_document_url` | TEXT | Front \| Back (pipe separated) |
| `face_photo_url` | TEXT | NULL (not needed for partner) |
| `verification_status` | TEXT | 'pending' → 'verified' or 'rejected' |
| `rejection_reason` | TEXT | Admin feedback if rejected |
| `created_at` | TIMESTAMP | When submitted |
| `verified_at` | TIMESTAMP | When admin approved |
| `verified_by` | UUID | Admin who verified |
| `updated_at` | TIMESTAMP | Last update |

**Auto-Sync Trigger:**
```sql
-- When verification_status changes to 'verified'
-- Trigger: trigger_sync_user_verification_status
-- Updates: users.id_verified = true
```

---

## 🚀 Testing Checklist

- [ ] Can partner see partner-document-verification screen?
- [ ] Can partner upload ID front image?
- [ ] Can partner upload ID back image?
- [ ] Can partner review & submit?
- [ ] Data saved to user_verifications table?
- [ ] verification_status = 'pending'?
- [ ] Admin can see pending verification?
- [ ] Admin can approve verification?
- [ ] users.id_verified syncs to true after approval?
- [ ] Unverified partner sees popup when trying to add vehicle?
- [ ] Popup shows "Verify Now" button?
- [ ] Clicking "Verify Now" navigates to partner-document-verification?
- [ ] Verified partner can add vehicle without popup?

---

## 🎓 Key Differences: Partner vs Renter

| Feature | Partner | Renter |
|---------|---------|--------|
| **ID Required** | ✅ Front + Back | ✅ Front + Back |
| **Face Photo** | ❌ NO | ✅ YES |
| **Steps** | 3 (ID Front, ID Back, Review) | 4 (+ Face Photo) |
| **Screen** | PartnerDocumentVerificationScreen | DocumentVerificationScreen |
| **When** | During signup | After signup |
| **Restriction** | Can't add vehicles | Can't book vehicles |

---

## 💡 Why Keep It Simple?

- **Faster onboarding** - Partners can get started immediately
- **Less friction** - Only essential document needed
- **Better UX** - 3 steps instead of 4
- **Still secure** - ID verification is the main security measure
- **Matches renter flow** - Consistent across roles
