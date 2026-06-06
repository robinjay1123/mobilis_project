# Identity Verification Form - Quick Start

## ✅ What's Been Created

### 1. **Form Screen** (New)
📁 `lib/mobile_ui/screens/auth/identity_verification_form_screen.dart`

Collects:
- Full Name
- Location/Address
- ID Type (dropdown)
- ID Number
- ID Image (front)

### 2. **Database Migration** (New)
📁 `supabase/migrations/20260506_add_id_type_and_id_number.sql`

Adds columns:
- `id_type` - VARCHAR text
- `id_number` - VARCHAR text

### 3. **Service Method** (New)
📍 `VerificationService.submitVerificationWithDetails()`

Saves all form data to `user_verifications` table

### 4. **Documentation** (New)
📁 `IDENTITY_VERIFICATION_FORM_GUIDE.md` - Complete guide

---

## 🚀 Setup (3 Steps)

### Step 1: Run Migration
```bash
supabase db push --include-all
```

### Step 2: Add Route
In your `main.dart` or route configuration:
```dart
'/identity-verification-form': (context) => const IdentityVerificationFormScreen(),
```

### Step 3: Navigate
```dart
Navigator.pushNamed(context, '/identity-verification-form');
```

**Done!** ✨

---

## 📊 Database Schema

```
user_verifications table now has:
├─ full_name (TEXT)
├─ location (TEXT)
├─ id_type (TEXT) ← NEW
├─ id_number (TEXT) ← NEW
├─ id_document_url (TEXT)
├─ verification_status (pending → verified → approved)
└─ ... other fields
```

---

## 💡 Use Cases

### ✅ Renter Verification
User signs up → Verification form → Collects all details → Admin reviews → Approved

### ✅ Partner Verification
Same as above OR use simple ID-only screen

### ✅ Driver Verification
Could use this form to collect driver name, address, license info

---

## 🔍 What Gets Saved

When user submits form:

```json
{
  "user_id": "uuid-here",
  "full_name": "John Doe",
  "location": "123 Main St, Manila",
  "id_type": "National ID",
  "id_number": "12345678901234",
  "id_document_url": "https://storage.url/image.jpg",
  "verification_status": "pending",
  "created_at": "2026-05-06T...",
  "updated_at": "2026-05-06T..."
}
```

---

## 🎨 Form Features

✅ Validates all required fields
✅ Allows camera OR gallery upload
✅ Shows image preview
✅ Auto-fills existing data
✅ Shows verification status
✅ Completion modal on success
✅ Dark/light theme support
✅ Clear error messages

---

## 📱 Screenshot Flow

1. **Form Screen**
   - Header: "Complete Your Profile"
   - Name input field
   - Location input field
   - ID Type dropdown
   - ID Number input field
   - Image upload section
   - Submit button

2. **Image Upload**
   - Camera button
   - Gallery button
   - Image preview
   - Retake/Change buttons

3. **Success Modal**
   - Success icon
   - "Verification Submitted!" message
   - "Back to Home" button

---

## 🔒 Admin Review

After submission, admin sees in verification panel:
- All form data (name, location, ID type, ID number)
- ID image for review
- Approve/Reject buttons
- Rejection reason field

When admin approves:
- `verification_status` → "verified"
- `users.id_verified` → true (auto-sync)

---

## 🧪 Quick Test

1. Run app
2. Navigate to `/identity-verification-form`
3. Fill all fields
4. Upload ID image
5. Click Submit
6. Check Supabase → `user_verifications` table
7. Verify all data is there

---

## 📚 Full Documentation

See `IDENTITY_VERIFICATION_FORM_GUIDE.md` for:
- Detailed API usage
- Complete code examples
- Troubleshooting
- Testing checklist
- Integration notes

---

## ❓ Quick FAQ

**Q: Can I use this for both renters and partners?**
A: Yes! It's role-agnostic. Use for any user type.

**Q: Does it require face photo?**
A: No! Only ID image needed. Simpler & faster.

**Q: Can users edit their submission?**
A: Yes! Form pre-fills existing data and allows re-submission.

**Q: When does verification complete?**
A: After admin reviews and approves in admin panel.

**Q: What if ID image upload fails?**
A: Form shows error. User can retake/change image and try again.

---

**Ready to use! 🎉**
