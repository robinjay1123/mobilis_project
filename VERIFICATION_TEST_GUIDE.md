# 🧪 Verification Workflow - Quick Test Guide

## Test Scenarios

### Scenario 1: New User Registration → Basic Renter Badge

**Steps**:
1. Open app → Click "Sign Up"
2. Select "Rent a Car"
3. Enter:
   - Full Name: John Doe
   - Email: john@example.com
   - Phone: +1234567890
   - Location: New York, USA (or click GPS button)
   - Address: 123 Main St, New York
   - Password: Test@123
4. Accept terms → Sign Up

**Expected**:
- ✅ User created successfully
- ✅ Navigate to verification options
- ✅ Dashboard loads
- ✅ Yellow badge shows "Basic Renter" next to name
- ✅ Verification popup appears: "Verification Required"

---

### Scenario 2: Dismiss Verification Popup

**From Scenario 1**:
1. Click "Not Now" or dismiss popup
2. Close popup

**Expected**:
- ✅ Popup closes
- ✅ Can browse vehicles
- ✅ Vehicles load and display normally
- ✅ Can search/filter cars
- ✅ Badge still shows "Basic Renter"

---

### Scenario 3: Try to Book Without Verification

**From Scenario 2**:
1. Click on any vehicle
2. Click "Book Now" button

**Expected**:
- ✅ Verification modal appears: "Complete your identity verification"
- ✅ Cannot proceed with booking

---

### Scenario 4: Complete Verification

**From Scenario 1 or 3**:
1. Click "Verify Now" in modal OR
2. Go to Profile → Verification Docs
3. Click on "Identity Verification" card
4. Fill form:
   - Full Name: John Doe
   - ID Type: Passport
   - ID Number: AB123456
   - Phone: +1234567890
   - Location: New York
   - ID Photo: Take photo or upload
5. Click "Submit Verification"

**Expected**:
- ✅ Success dialog shows "Verification Submitted"
- ✅ Navigate back to dashboard
- ✅ Badge still shows "Basic Renter"
- ✅ Verification docs show "Pending" status

---

### Scenario 5: Admin Approves Verification (Real-time)

**From Scenario 4**:
1. Open admin dashboard (different browser/device)
2. Navigate to Verifications section
3. Find pending verification for John Doe
4. Click "Approve"
5. Confirm approval

**Expected (Real-time Update)**:
- ✅ Original user app:
  - Badge changes to "Verified" (green)
  - Notification appears: "Verification Approved"
  - Verification docs show "Verified" status
  - Can now book vehicles
- ✅ Admin app: Shows verification as approved

---

### Scenario 6: Theme Switching

**Steps**:
1. Open Dashboard
2. Go to Profile → Settings
3. Toggle Dark/Light Mode

**Expected**:
- ✅ Verification docs screen colors update correctly
- ✅ Text, backgrounds, borders all respect theme
- ✅ Badge colors remain visible and readable
- ✅ Notifications tab uses correct theme colors
- ✅ Messages tab uses correct theme colors

---

### Scenario 7: Notifications Tab

**Steps**:
1. User receives notifications (booking, messages, etc)
2. Go to Dashboard → Notifications tab

**Expected Empty**:
- ✅ Shows empty state with icon
- ✅ Text: "No Notifications Yet"
- ✅ Description visible

**Expected With Notifications**:
- ✅ Each notification has colored icon
- ✅ Title, message, timestamp visible
- ✅ Booking notifications have calendar icon
- ✅ Message notifications have chat icon
- ✅ Success notifications have check icon

---

### Scenario 8: Messages Tab

**Steps**:
1. Create booking (if with driver)
2. Go to Dashboard → Messages tab

**Expected Empty**:
- ✅ Shows empty state with icon
- ✅ Text: "No Conversations Yet"
- ✅ Description visible

**Expected With Conversations**:
- ✅ Each conversation card shows:
  - Person icon
  - Recipient name
  - Last message
  - Timestamp
  - Unread count (if any)
- ✅ Header shows total unread count badge
- ✅ Can tap to open conversation

---

### Scenario 9: Verification Field Order

**Steps**:
1. Go to Profile → Verification Docs
2. Click "Identity Verification"
3. Observe field order

**Expected Order**:
1. Full Name ✅
2. ID Type ✅
3. ID Number ✅
4. Phone Number ✅
5. Location ✅ (NO geolocation icon)
6. ID Photo ✅

**Key**: Location should be a simple text input, NOT with GPS/geolocation button.

---

### Scenario 10: Skip Verification Once Per Session

**Steps**:
1. Dismiss verification popup on dashboard
2. Scroll around dashboard
3. Navigate to different tabs
4. Come back to dashboard

**Expected**:
- ✅ Popup doesn't show again in same session
- ✅ Badge still shows "Basic Renter"
- ✅ Can still browse vehicles

---

### Scenario 11: Badge Updates on Verification Status Change

**Steps**:
1. User verified (badge shows "Verified")
2. Admin rejects verification with comment
3. Observe user's app in real-time

**Expected**:
- ✅ Badge immediately changes back
- ✅ Notification arrives: "Verification Rejected"
- ✅ Verification docs show rejection reason

---

## Test Checklist

General:
- [ ] No compile errors
- [ ] App builds successfully
- [ ] No runtime errors

Signup:
- [ ] Location field present
- [ ] GPS auto-detect works
- [ ] Form validation works

Dashboard:
- [ ] Badge shows "Basic Renter" for unverified
- [ ] Badge shows "Verified" for verified
- [ ] Badge updates in real-time
- [ ] Verification popup appears once

Verification:
- [ ] Field order: Name → ID Type → ID Number → Phone → Location
- [ ] Location is simple text input (no GPS)
- [ ] Can upload photo
- [ ] Form submission works
- [ ] Status changes to "Pending" after submission

Admin Approval:
- [ ] Admin can approve verification
- [ ] User gets notification immediately
- [ ] Badge changes to "Verified" in real-time
- [ ] Full name synced from verification
- [ ] Can now book vehicles

Themes:
- [ ] Dark mode works everywhere
- [ ] Light mode works everywhere
- [ ] Colors contrast properly
- [ ] Theme toggle works

Tabs:
- [ ] Notifications empty state displays
- [ ] Notifications with data display properly
- [ ] Messages empty state displays
- [ ] Messages with conversations display properly
- [ ] Unread count shows correctly

---

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Popup shows every time | Check `_hasShownVerificationPrompt` flag |
| Badge not updating | Check real-time subscription |
| Location has GPS button | Should be removed - simple text only |
| Theme colors wrong | Check `isDark` variable usage |
| Field order wrong | Should be: Name, ID Type, ID Number, Phone, Location |
| Notifications not showing | Check notification service notification creation |
| Messages not loading | Check conversation loading and chat service |

---

## Debug Tips

Enable verbose logging:
```dart
// In dashboard_screen.dart
debugPrint('✅ Verification status: $userVerified');
debugPrint('🔔 Notifications count: ${_notifications.length}');
debugPrint('💬 Conversations count: ${_conversations.length}');
```

Check real-time subscription:
```dart
// In browser DevTools → Firebase/Supabase logs
// Should see subscribe/unsubscribe messages for:
// - public:users:id=eq.{userId}
// - public:notifications:user_id=eq.{userId}
```

---

**Status**: Ready for testing ✅
