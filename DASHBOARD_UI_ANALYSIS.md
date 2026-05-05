# Dashboard & Home Screen UI Analysis

## Overview
This document analyzes the three role-based home/dashboard screens (Renter, Driver, Partner) to identify implemented UI functionalities, missing features, and service integrations.

---

## 1. RENTER DASHBOARD (RenterHomeScreen)
**File:** `lib/mobile_ui/screens/home/dashboard_screen.dart`

### Bottom Navigation Tabs (5 tabs)
1. **Home** - Main dashboard view
2. **Bookings** - User's rental bookings
3. **Notifications** - Alert notifications
4. **Messages** - Chat conversations
5. **Profile** - User profile & settings

### Home Tab (Tab 0) - Features Implemented ✅
- **Header Section:**
  - User greeting with name
  - Current location display
  - Search bar with filter button (UI only, no functionality)
  
- **Categories Section:**
  - Horizontal scroll list: Economy, SUV, Luxury, Van
  - Category selection working (visual feedback only)
  
- **Your Trips Section:**
  - Horizontal scrolling booking cards
  - Shows: Car name, partner name, status (Active/Upcoming/Past/Cancelled), days, locations, total cost, rating
  - Pull-to-refresh enabled
  
- **Top Rental Partners Section:**
  - Horizontal scroll with partner avatars
  - Shows rating, verified badge
  
- **Featured Cars Section:**
  - Full vehicle listing with details
  - Car specs: transmission, fuel type, seats
  - Price per day display
  - Favorite button (UI only)
  - "Book Now" button → navigates to `/vehicle-detail`

- **Data Loading:**
  - ✅ Vehicles: `VehicleService.getAvailableVehicles()`
  - ✅ Bookings: `BookingService.getRenterBookings(userId)`
  - ✅ Conversations: `ChatService.getConversations(userId)`
  - ✅ Notifications: `NotificationService.getNotifications(userId)`

### Bookings Tab (Tab 1) - Features Implemented ✅
- **Tabbed Filter System:**
  - Upcoming, Active, Past, Cancelled
  - Displays filtered booking lists
  - Each booking shows:
    - Car name, partner name, status badge
    - Days, pickup/dropoff locations
    - Total cost, partner rating
  
- **Booking Details Modal:**
  - Tappable cards show full details (UI partially implemented)
  - Data from `BookingService.getRenterBookings()`

### Notifications Tab (Tab 2) - Features Implemented ✅
- **Notification List:**
  - Uses `NotificationItem` widget
  - Shows icon, title, message, timestamp
  - Different icons based on notification type (booking, message, payment, etc.)
  - Shows relative time ("5m ago", "2h ago")

### Messages Tab (Tab 3) - Features Implemented ✅
- **Conversation List View:**
  - When no conversation selected: shows all conversations
  - Uses `ConversationTile` widget
  - Shows: sender name, last message, timestamp, unread count
  - Tap to open conversation

- **Individual Conversation View:**
  - Back button to return to list
  - Message thread with bubbles (custom `MessageBubble` widget)
  - Differentiates sender vs receiver messages
  - Message timestamps
  - **Input Area:**
    - Text field with rounded design
    - Send button
    - ⚠️ **NOT FUNCTIONAL** - `onPressed: () {}` (empty handler)

- **Data Source:**
  - `ChatService.getConversations(userId)` - loads conversations
  - Each conversation includes nested messages array
  - Last message extracted for conversation list

### Profile Tab (Tab 4) - Features Implemented ✅
- **Dynamic Page Selection:**
  - Main profile page (default)
  - Can navigate to: Settings, Payment Methods, Verification Documents
  
- **Main Profile Page:**
  - User info card (email, phone, location)
  - Settings & Payment links
  - Verification status banner
  - Email confirmation alert (if needed)

- **Sub-pages:**
  - `SettingsScreen` - Theme toggle, payment methods, verification
  - `PaymentMethodsScreen` - Manage payment methods
  - `VerificationDocumentsScreen` - Upload/manage documents

---

## 2. DRIVER HOME SCREEN (DriverHomeScreen)
**File:** `lib/mobile_ui/screens/driver/driver_home_screen.dart`

### Tab Bar (5 tabs)
1. **Dashboard** - Driver stats & overview
2. **Jobs** - Completed trips (named "Jobs Tab")
3. **Earnings** - Revenue summary
4. **Availability** - Online/offline status
5. **Profile** - Driver info & settings

### Dashboard Tab (Tab 0) - Features Implemented ✅
- **Profile Card:**
  - Driver avatar/icon
  - Name from `AuthService.currentUser?.userMetadata['full_name']`
  - Badge display: BASIC DRIVER / VERIFIED DRIVER / CERTIFIED PSDC DRIVER
  - Stats in columns: Rating, Trips, Status
  - Uses `DriverService.getDriverStats(userId)`

- **Verification Popup:**
  - Shows periodically if driver not verified
  - Can be skipped (shows every 3 skips)
  - Navigation to verification flow (commented out: `/verify-driver`)

- **Pending Job Offers Section:**
  - ⚠️ **PLACEHOLDER** - Shows "No pending job offers at the moment"
  - No data integration yet

### Jobs Tab (Tab 1) - Features Implemented ✅
- **Trip History:**
  - Loads from `DriverService.getCompletedTrips(userId, limit: 10)`
  - Trip cards show:
    - Pickup location
    - Status badge (green "completed")
    - Dropoff location
  - ⚠️ **Limited Info** - Only pickup, dropoff, status shown

### Earnings Tab (Tab 2) - Features Implemented ✅
- **Earnings Card:**
  - "Total Earnings (Last 30 Days)" header
  - Large amount display
  - Calls `DriverService.getEarnings(userId, dateRange)`
  - Default: 0.0 if no data
  
- **Earnings History:**
  - ⚠️ **PLACEHOLDER** - "No earnings history available"
  - No data integration yet

### Availability Tab (Tab 3) - Features Implemented ✅
- **Availability Toggle:**
  - Switch to turn on/off availability
  - Shows: "You are Available/Unavailable"
  - Subtitle: "Receiving job offers" / "Not receiving jobs"
  - ✅ Local state management (changes UI)
  - ⚠️ **NO PERSISTENCE** - Changes not saved to backend
  
- **Work Schedule Section:**
  - Header visible
  - ⚠️ **INCOMPLETE** - Content cut off in file

### Profile Tab (Tab 4) - Features Implemented ✅
- **Driver Info Card:**
  - Email, Phone, Location from `AuthService.currentUser`
  
- **Settings:**
  - Theme toggle (Dark/Light mode)
  - Logout button
  - Works with theme provider

### Service Integration ✅
- `AuthService` - Current user, email confirmation, verification status
- `DriverService` - Driver stats, completed trips, earnings
- Theme provider integration

---

## 3. PARTNER HOME SCREEN (PartnerHomeScreen)
**File:** `lib/mobile_ui/screens/partner/partner_home_screen.dart`

### Bottom Navigation (5 items)
1. **Dashboard** - Overview & stats
2. **Alerts** - Notifications
3. **Messages** - Chat
4. **Bookings** - Rental requests
5. **Profile** - Partner info

### Drawer Menu (Left Slide Menu)
- Dashboard Overview
- My Vehicles
- Partnership (Apply/manage vehicles)
- Booking Requests
- Revenue & Earnings
- Dark Mode toggle
- Reviews & Ratings
- Settings
- Logout

### Dashboard Tab (Tab 0) - Features Implemented ✅
- **Dashboard Header:**
  - Drawer toggle button
  - Partner name & logo

- **Partner Profile Card:**
  - Name from `AuthService.currentUser?.userMetadata['full_name']`
  - Verification status
  - Partnership status (Basic/Approved/Certified)

- **Verification Banner:**
  - ⚠️ **CONDITIONAL** - Shows if `verificationStatus != 'verified'` and not dismissed
  - Actions: Dismiss or "Verify Now" → `/owner-verification`
  - Success banner if verified: "Your fleet is ready for listings"

- **Stats Row (3 cards):**
  - **EARNINGS:** Total partner earnings
  - **ACTIVE:** Number of active vehicles
  - **RATING:** Average rating (or '-')
  - Data from: `PartnerService.getApplicationCounts()`, `BookingService.getPartnerBookingCounts()`

- **Quick Actions (3 buttons):**
  - Add Vehicle → `/apply-vehicle`
  - Manage Fleet → `/vehicle-availability`
  - (Third action cuts off)

- **Recent Requests Section:**
  - ⚠️ **INCOMPLETE** - Referenced but not fully visible in read

### Notifications Tab (Tab 1) - Features Implemented ✅
- **Notification List:**
  - Similar to renter notifications
  - Uses `NotificationService.getNotifications(userId)`

### Messages Tab (Tab 2) - Features Implemented ✅
- **Conversation List:**
  - Header with back button, "Messages" title
  - Lists conversations using `ConversationTile` widget
  - Shows: Renter info, last message, timestamp, unread count
  - Tap to open conversation
  
- **Individual Conversation:**
  - ⚠️ **PARTIALLY IMPLEMENTED** - Conversation display visible but incomplete
  - Message bubbles likely work (similar to renter)
  - Data source: `ChatService.getConversations(userId)`

### Bookings Tab (Tab 3) - Features Implemented ✅
- **Header:** "Bookings" with back button + "Availability" quick action link

- **Booking Status Tabs (4 tabs):**
  - Upcoming, Active, Completed, Cancelled
  - Tab-based filtering

- **Booking List by Status:**
  - Using `_buildBookingsList(status)` method
  - Shows booking details by status

- **Data Integration:**
  - `BookingService.getRecentPartnerBookings(partnerId)`
  - Filters by status programmatically

### Profile Tab (Tab 4) - Features Implemented ✅
- **Profile Sections:**
  - Partner info, settings, etc.
  - ⚠️ **NOT FULLY VISIBLE** - Content cut off in file read

### Data Loading ✅
- `PartnerService.getPartnerProfile(userId)`
- `PartnerService.getApplicationCounts(partnerId)`
- `PartnerService.getVehicleApplications(partnerId)`
- `BookingService.getPartnerBookingCounts(partnerId)`
- `BookingService.getRecentPartnerBookings(partnerId)`
- `ChatService.getConversations(userId)`
- `NotificationService.getNotifications(userId)`

---

## 4. MESSAGING & CHAT SERVICE

### ChatService Implementation ✅
**File:** `lib/services/chat_service.dart`

**Available Methods:**
```dart
// Get all conversations for a user
getConversations(String userId) 
  → List<Map<String, dynamic>>

// Get or create conversation between two users
getOrCreateConversation(String userId1, String userId2)
  → Map<String, dynamic>

// Get messages for a conversation
getMessages(String conversationId)
  → List<Map<String, dynamic>>

// Send a message
sendMessage({
  required String conversationId,
  required String senderId,
  required String content,
}) → Map<String, dynamic>

// Mark messages as read
markMessagesAsRead(String conversationId, String readerId)
  → void
```

### Chat UI Components ✅
- `ConversationTile` widget - Displays conversation preview
- `MessageBubble` widget - Individual message display
- `message_bubble.dart` imported in dashboards

### Database Schema (Inferred from ChatService)
```
conversations
  - id
  - created_at
  - updated_at
  - messages[]

messages
  - id
  - conversation_id
  - sender_id
  - content
  - created_at
  - is_read

conversation_participants
  - conversation_id
  - user_id
  - joined_at
```

---

## 5. IDENTIFIED GAPS & MISSING IMPLEMENTATIONS

### Critical Missing Features ❌

| Feature | Location | Status | Impact |
|---------|----------|--------|--------|
| **Message Sending** | Renter/Partner Messages Tab | Not Functional | Users cannot send messages |
| **Earnings History** | Driver Earnings Tab | Placeholder only | Shows no actual data |
| **Pending Job Offers** | Driver Dashboard | Placeholder only | Driver doesn't see available jobs |
| **Availability Persistence** | Driver Availability Tab | Local state only | Changes not saved to backend |
| **Work Schedule** | Driver Availability Tab | Incomplete/cut off | Functionality unclear |
| **Partner Recent Requests** | Partner Dashboard | Incomplete | Section layout unclear |
| **Message Conversation Detail** | Partner Messages Tab | Incomplete | Conversation display not fully coded |
| **Booking Details Modal** | Renter Bookings | Basic implementation | Limited interaction options |

### Partially Implemented Features ⚠️

| Feature | Location | What Works | What's Missing |
|---------|----------|-----------|-----------------|
| **Verification Status** | All dashboards | Display & banner | Navigation to verification flow commented out |
| **Category Filter** | Renter Home | Visual selection | No actual filtering applied |
| **Search Bar** | Renter Home | UI placeholder | No search functionality |
| **Favorite Button** | Renter Featured Cars | Icon display | No save/persistence |
| **Theme Toggle** | Driver/Partner Profile | Works in code | UI integration may vary |
| **Chat Conversation View** | Renter/Partner | List view works | Opening individual conversations incomplete |

### Service Methods Called But Not Visible in UI 🔍

| Service Method | Called In | Not Shown | Reason |
|---------------|-----------|----------|--------|
| `needsIdVerification()` | Renter Dashboard | Verification Modal | Triggers based on auth check |
| `isUserVerified()` | Renter Dashboard | Affects verification | Checked on load |
| `getMessages(conversationId)` | Could be used | Message detail | Not called when conversation selected |
| `sendMessage()` | Could be used | Message sending | Send button has empty handler |
| `markMessagesAsRead()` | Could be used | Read status | Not integrated |

---

## 6. TODO COMMENTS FOUND

**File:** `lib/mobile_ui/screens/vehicle/vehicle_detail_screen.dart` (Line 209)
```dart
// TODO: Implement actual booking logic with BookingService
```

**File:** `lib/mobile_ui/screens/auth/login_screen.dart` (Line 386)
```dart
// TODO: Navigate to forgot password
```

**File:** `lib/mobile_ui/screens/partner/vehicle_registration_upload_screen.dart` (Line 360)
```dart
// TODO: Implement actual image picker
```

---

## 7. WIDGET REFERENCES

### Custom Widgets Used ✅
- `BookingCard` - Displays booking information
- `MessageBubble` - Individual message in conversation
- `ConversationTile` - Conversation list item
- `NotificationItem` - Notification list item
- `StatusBadge` - Status indicator
- `CostBreakdownRow` - Cost details display
- `TripTimelineStep` - Trip timeline visualization

**Widgets File:** `lib/mobile_ui/widgets/`

---

## 8. NAVIGATION ROUTES REFERENCED

```
/vehicle-detail          → Vehicle details page (implemented)
/id-verification         → ID verification (commented out in some places)
/owner-verification      → Owner verification (partner)
/apply-vehicle          → Vehicle application/registration
/vehicle-availability   → Manage vehicle availability
/verify-driver          → Driver verification (commented out)
/login                  → Login page
/settings               → Settings screen
/payment-methods        → Payment methods screen
```

---

## 9. CONNECTIVITY & OFFLINE SUPPORT

**ConnectivityService Integration:** ✅
- Used in Renter & Partner dashboards
- Listens for connectivity changes
- Shows offline warning snackbar
- Prevents certain operations when offline

---

## 10. VERIFICATION SYSTEM

### Renter Verification ✅
- Email confirmation check on load
- ID verification check after 3-second delay
- Modal prevents interaction if unverified
- Shows verification modal periodically
- Checks `AuthService.needsIdVerification()` & `isUserVerified()`

### Driver Verification ⚠️
- Shows periodic popup if not verified
- Skip counter (shows every 3 skips)
- Navigation button commented out
- Status: pending, verified, certified

### Partner Verification ⚠️
- Verification banner shown if not verified
- "Verify Now" button links to `/owner-verification`
- Status: pending, verified, basic/approved/certified partnership

---

## 11. DATA PERSISTENCE & STATE MANAGEMENT

### Local State Management 🟡
- Dashboard uses `setState()` for UI updates
- Navigation index tracking
- Selected conversation/booking tracking
- Driver availability toggle (NOT persisted)
- Category/filter selections (visual only)

### Backend Integration ✅
- All user data loaded from services on init
- Refresh capability (pull-to-refresh on renter home)
- Services interact with Supabase

### Missing: 🔴
- State persistence (availability, preferences)
- Offline data caching
- Real-time updates/subscriptions (for new messages)
- Conversation refresh/reload

---

## 12. SUMMARY TABLE

| Role | Tab Count | Full UI | Services Used | Gaps | Priority |
|------|-----------|---------|----------------|------|----------|
| **Renter** | 5 | 85% | 5 services | Message sending, filtering | HIGH |
| **Driver** | 5 | 60% | 2 services | Job offers, earnings, availability persistence | HIGH |
| **Partner** | 5 | 70% | 6 services | Recent requests section, message details | MEDIUM |

---

## 13. RECOMMENDATIONS FOR COMPLETION

### Immediate (P0)
1. **Implement message sending** - Add functionality to `onPressed` in message input field
2. **Fix driver availability persistence** - Save toggle state to backend
3. **Complete earnings history** - Add data binding to earnings data
4. **Show pending job offers** - Integrate job service

### Short-term (P1)
1. **Complete message detail view** - Show full conversation with proper UI
2. **Add verification navigation** - Uncomment and test verification flows
3. **Search & filter** - Implement actual vehicle filtering
4. **Real-time message updates** - Add WebSocket/subscription support

### Medium-term (P2)
1. **Offline support** - Cache conversations and bookings
2. **State management** - Consider Provider/Riverpod for app-wide state
3. **Work schedule** - Complete driver availability scheduling
4. **Analytics** - Track user interactions

---

## 14. CHAT/MESSAGE SCREENS LOCATION

**Integrated In:** 
- Renter: Tab 3 of `dashboard_screen.dart`
- Partner: Tab 2 of `partner_home_screen.dart`
- Driver: NO dedicated message tab ❌

**No separate screen files found** - All messaging UI is inline in home screens.

**Widgets used:**
- `lib/mobile_ui/widgets/message_bubble.dart`
- `lib/mobile_ui/widgets/conversation_tile.dart`

**Service:** `lib/services/chat_service.dart`
