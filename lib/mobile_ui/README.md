# Mobile UI Structure

This folder contains the mobile user interface for the Mobilis car rental app.

## Folder Structure

```
lib/mobile_ui/
├── theme/
│   ├── app_colors.dart          # Color definitions and constants
│   └── app_theme.dart           # Material theme configuration
├── widgets/
│   ├── custom_button.dart       # Reusable button component
│   └── custom_text_field.dart   # Reusable text field component
└── screens/
    ├── auth/
    │   ├── login_screen.dart    # Login screen
    │   └── signup_screen.dart   # Registration/Signup screen
    └── home/
        └── dashboard_screen.dart # Main dashboard/home screen
```

## Screens Included

### Authentication Screens (`screens/auth/`)

1. **Login Screen** (`login_screen.dart`)
   - Email and password input fields
   - "Remember device for 30 days" checkbox
   - "Forgot Password?" link
   - Social login options (Google, Apple)
   - Link to signup page

2. **Signup Screen** (`signup_screen.dart`)
   - Personal details section (Full Name, Email, Phone, Location, Address)
   - Security section (Password, Confirm Password)
   - Terms of Service acceptance checkbox
   - Anti-Scam Protection information
   - Redirects back to login

### Home Screen (`screens/home/`)

1. **Dashboard Screen** (`dashboard_screen.dart`)
   - User greeting with profile
   - Current location selector
   - Search bar with filters
   - Categories section (Economy, SUV, Luxury, Van)
   - Top Rental Partners carousel
   - Featured Cars list with ratings, features, and pricing
   - Bottom navigation bar (Home, Bookings, Notifications, Messages, Profile)

## Design System

### Colors (`theme/app_colors.dart`)
- Primary Yellow: `#FFD700`
- Dark Background: `#1A1F2E`
- Text Colors: Primary (white), Secondary, Tertiary
- Status Colors: Success (green), Error (red), Warning (amber)

### Theme (`theme/app_theme.dart`)
- Custom Material 3 dark theme
- Custom text styles and typography
- Input decoration theme for form fields
- Button styles

## Reusable Components

### CustomButton
A primary action button with loading state support.

**Props:**
- `label` (String) - Button text
- `onPressed` (VoidCallback) - Callback function
- `isLoading` (bool) - Shows loading indicator
- `backgroundColor` (Color) - Optional custom color
- `textColor` (Color) - Optional custom text color
- `borderRadius` (double) - Border radius

### CustomTextField
A labeled text input field with icon support.

**Props:**
- `label` (String) - Field label
- `hintText` (String) - Placeholder text
- `controller` (TextEditingController) - Text editing controller
- `keyboardType` (TextInputType) - Keyboard type
- `obscureText` (bool) - Hide text (for passwords)
- `prefixIcon` (Widget) - Icon before text
- `suffixIcon` (Widget) - Icon after text
- `validator` (Function) - Validation function
- `maxLines` (int) - Max lines for multi-line input

## Navigation

Routes are defined in `main.dart`:
- `/login` - Login screen
- `/signup` - Signup screen
- `/dashboard` - Main dashboard

## Next Steps

- **Web UI**: Create `lib/web_ui/` folder for web-specific screens
- **State Management**: Add Provider, Riverpod, or BLoC for state management
- **API Integration**: Connect screens to Supabase backend
- **Image Assets**: Add car images and partner logos
- **Animations**: Add page transitions and micro-interactions

## Color Reference

```
Primary Yellow: #FFD700
Dark Background: #1A1F2E
Dark Secondary: #2D3748
Dark Tertiary: #374151
Text Primary: #FFFFFF
Text Secondary: #9CA3AF
Text Tertiary: #6B7280
Border: #374151
```
