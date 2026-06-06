# Identity Verification Form Implementation

## 🎯 Overview

A comprehensive identity verification form that collects user details and ID information:
- ✅ Full Name
- ✅ Location / Address
- ✅ Type of ID (dropdown with 7 options)
- ✅ ID Number
- ✅ ID Image (front)
- ✅ Auto-saves to `user_verifications` table

---

## 📱 New Screen

**File:** `lib/mobile_ui/screens/auth/identity_verification_form_screen.dart`

**Route to add:**
```dart
'/identity-verification-form': (context) => const IdentityVerificationFormScreen(),
```

---

## 📊 Form Fields & Database Mapping

| Form Field | Database Table | Column | Type |
|-----------|----------------|--------|------|
| Full Name | `user_verifications` | `full_name` | TEXT |
| Location/Address | `user_verifications` | `location` | TEXT |
| Type of ID | `user_verifications` | `id_type` | TEXT |
| ID Number | `user_verifications` | `id_number` | TEXT |
| ID Image | `user_verifications` | `id_document_url` | TEXT |

---

## 🗄️ Database Migration

**File:** `supabase/migrations/20260506_add_id_type_and_id_number.sql`

Added two new columns to `user_verifications`:
```sql
ALTER TABLE public.user_verifications
  ADD COLUMN IF NOT EXISTS id_type TEXT,
  ADD COLUMN IF NOT EXISTS id_number TEXT;
```

**Run it:**
```bash
supabase db push --include-all
```

---

## 🔧 Updated Service Methods

### VerificationService

#### New Method: `submitVerificationWithDetails()`
Submits verification with all form fields.

```dart
final result = await VerificationService.submitVerificationWithDetails(
  userId: userId,
  fullName: 'John Doe',
  location: '123 Main St, Manila',
  idType: 'National ID',
  idNumber: '12345678',
  idDocumentUrl: 'https://storage.url/id.jpg',
);

if (result['success']) {
  print('Verification submitted: ${result['message']}');
  final verificationData = result['data'];
}
```

#### Updated Method: `uploadIdentityPhoto()`
Now returns `file_url` field for easy access.

```dart
final result = await VerificationService.uploadIdentityPhoto(
  userId: userId,
  idPhotoFile: imageFile,
);

if (result['success']) {
  final imageUrl = result['file_url']; // Easy access
  final allData = result['data']; // Legacy access
}
```

---

## 📱 Usage Example

### In your app's main.dart (add route):
```dart
routes: {
  '/identity-verification-form': (context) => 
    const IdentityVerificationFormScreen(),
  // ... other routes
},
```

### Navigate to form:
```dart
Navigator.pushNamed(context, '/identity-verification-form');

// Or with callback when done
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => IdentityVerificationFormScreen(
      onVerificationComplete: () {
        print('Verification submitted!');
        Navigator.pop(context);
      },
    ),
  ),
);
```

---

## 🎨 Form Features

### 1. **Pre-fill Existing Data**
If user has already started verification, form auto-fills with existing data:
```
full_name → Name field
location → Location field
id_type → ID Type dropdown
id_number → ID Number field
```

### 2. **ID Type Dropdown**
7 predefined types:
- National ID
- Passport
- Driver's License
- TIN ID
- Senior Citizen ID
- PWD ID
- Other

### 3. **Image Upload/Capture**
- Camera: Take photo directly
- Gallery: Select from device
- Retake/Change options after selection
- Image preview before submission

### 4. **Form Validation**
- All fields required (*)
- Shows error messages
- Prevents submission if incomplete

### 5. **Verification Status Display**
- Shows "Already Verified" if status is verified
- Shows pending message if awaiting approval
- Shows rejection reason if rejected

### 6. **Completion Modal**
- Success message after submission
- Shows pending review message
- "Back to Home" button closes and returns

---

## 💾 Data Flow

```
User fills form
    ↓
Validates all fields
    ↓
Uploads ID image to storage
    ↓
Saves all details to user_verifications:
    ├─ full_name
    ├─ location
    ├─ id_type
    ├─ id_number
    ├─ id_document_url (image URL)
    └─ verification_status = 'pending'
        ↓
Shows completion modal
    ↓
Admin reviews & approves
    ↓
Database trigger syncs:
    └─ users.id_verified = true
```

---

## 🔒 Security & RLS

Verification data is protected by Row-Level Security (RLS):
- Users can only view their own verification
- Only admins can update status
- All inserts require authentication

---

## 🧪 Testing Checklist

- [ ] Form loads correctly?
- [ ] All fields are required?
- [ ] Dropdown has all 7 ID types?
- [ ] Can take photo from camera?
- [ ] Can upload from gallery?
- [ ] Can retake/change photo?
- [ ] Form validates all fields before submit?
- [ ] Error messages show for empty fields?
- [ ] Submission works and shows modal?
- [ ] Data saved to user_verifications table?
- [ ] All fields (name, location, id_type, id_number, id_document_url) saved?
- [ ] Existing data pre-fills on reload?
- [ ] Admin can see and approve verification?
- [ ] After approval, users.id_verified = true?
- [ ] Already verified message shows if status='verified'?

---

## 🎓 Differences: Form vs Simple Screen

| Feature | Form Screen | Simple Screen |
|---------|------------|---------------|
| Name Collection | ✅ YES | ❌ NO |
| Location Collection | ✅ YES | ❌ NO |
| ID Type Dropdown | ✅ YES | ❌ NO |
| ID Number Field | ✅ YES | ❌ NO |
| ID Image Upload | ✅ YES | ✅ YES |
| Face Photo | ❌ NO | ❌ NO |
| Pre-fill Existing | ✅ YES | ✅ YES |
| Storage Path | Single | Front+Back |

---

## 📝 Integration Notes

### For Renter Verification:
Use this form-based screen for comprehensive identity verification during signup.

### For Partner Verification:
Can use either:
1. **Simple Screen** (partner_document_verification_screen) - ID only
2. **Form Screen** (identity_verification_form_screen) - Full details

### For Driver Verification:
Can use the form screen to collect driver name, address, and license details.

---

## 🐛 Troubleshooting

**Q: Form not showing pre-filled data?**
- A: Make sure `_loadExistingVerification()` is called in `initState()`
- Check if user has existing verification in `user_verifications` table

**Q: Image upload fails?**
- A: Check if `id_images` bucket exists in Supabase Storage
- Verify file permissions and quotas

**Q: Data not saving?**
- A: Check if all required fields have values
- Verify database migration ran successfully
- Check RLS policies allow inserts

**Q: Dropdown not showing?**
- A: Ensure `_idTypes` list is populated correctly
- Check theme colors for visibility

---

## 🚀 Next Steps

1. ✅ Run database migration
2. ✅ Add route to your router
3. ✅ Import and use the screen
4. ✅ Test form submission
5. ✅ Wire admin review panel
6. ✅ Set up approval notifications
