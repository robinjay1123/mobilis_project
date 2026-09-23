# send-push-queue

This Supabase Edge Function processes pending rows from `push_notification_queue`
and sends them to Firebase Cloud Messaging.

## Required secrets

Set these secrets before deploying:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `FCM_PROJECT_ID` (optional override if you want to force a different Firebase project id)

## Recommended secrets command

Use your downloaded Firebase admin SDK JSON file content as the value for
`FIREBASE_SERVICE_ACCOUNT_JSON`.

Example:

```powershell
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"mobilis-project",...}'
```

If your JSON already contains the correct `project_id`, you can skip
`FCM_PROJECT_ID`.

## What changed

This function now generates a fresh OAuth access token from the Firebase service
account on each run, so you no longer need to manually manage
`FCM_ACCESS_TOKEN`.

## Example invoke flow

Call the function from a cron job or scheduled task so it can send pending items
from `push_notification_queue`.
