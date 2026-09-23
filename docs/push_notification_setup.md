# Push Notification Setup

This project now includes the app-side push notification wiring for Android, iOS, and web.

## What is already done

- Firebase messaging dependencies are added in `pubspec.yaml`.
- The app initializes push notifications in `lib/services/push_notification_service.dart`.
- User push tokens are saved to `user_push_tokens`.
- Every in-app notification can also be queued in `push_notification_queue`.
- Android, iOS, and web platform hooks are already added.

## What you need to add

### Android

1. Create a Firebase app for Android.
2. Download `google-services.json`.
3. Put it here:C:\Users\robin\OneDrive\Documents\flutter\mobilis_by_psdc_app\android\app\google-services.json

```text
android/app/google-services.json
```

### iOS

1. Create a Firebase app for iOS.
2. Download `GoogleService-Info.plist`.
3. Put it here:

```text
ios/Runner/GoogleService-Info.plist
```

### Web

1. Open this file:

```text
web/firebase-web-config.js
```

2. Replace the placeholder values with your real Firebase web config.

3. Build or run web with matching Dart defines:

```powershell
flutter run -d chrome `
  --dart-define=FIREBASE_WEB_API_KEY=YOUR_FIREBASE_WEB_API_KEY `
  --dart-define=FIREBASE_WEB_APP_ID=YOUR_FIREBASE_WEB_APP_ID `
  --dart-define=FIREBASE_WEB_MESSAGING_SENDER_ID=YOUR_FIREBASE_MESSAGING_SENDER_ID `
  --dart-define=FIREBASE_WEB_PROJECT_ID=YOUR_FIREBASE_WEB_PROJECT_ID `
  --dart-define=FIREBASE_WEB_AUTH_DOMAIN=YOUR_PROJECT.firebaseapp.com `
  --dart-define=FIREBASE_WEB_STORAGE_BUCKET=YOUR_PROJECT.firebasestorage.app `
  --dart-define=FIREBASE_WEB_MEASUREMENT_ID=YOUR_FIREBASE_MEASUREMENT_ID `
  --dart-define=FIREBASE_WEB_VAPID_KEY=YOUR_FIREBASE_WEB_VAPID_KEY
```

## Supabase migrations

Run these new migrations:

- `20260620000400_add_announcements.sql`
- `20260620000500_add_user_push_tokens.sql`
- `20260620000600_add_push_notification_queue.sql`

## Important note

The app now stores tokens and queues push jobs, but actual delivery still needs a sender.

That sender can be:

- a Supabase Edge Function
- a backend worker
- a cron job that reads `push_notification_queue` and sends through Firebase Cloud Messaging

## Supabase sender secrets

For the included sender function, add these secrets:

- `SUPABASE_SERVICE_ROLE_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `FCM_PROJECT_ID` optional, because it can be read from the service account JSON

Use the full contents of your Firebase admin SDK JSON file as
`FIREBASE_SERVICE_ACCOUNT_JSON`.

## Recommended next step

Build a Supabase Edge Function that:

1. Reads pending rows from `push_notification_queue`
2. Sends them through Firebase Admin SDK or FCM HTTP v1
3. Marks rows as `sent` or saves `error_message`
