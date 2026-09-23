# create-operator

Admin-only Edge Function used by the Admin web portal to create operator login
accounts without exposing the Supabase service-role key to the browser.

The function:

- verifies the caller's Supabase access token;
- confirms the caller has the `admin` role;
- creates an email/password account in Supabase Auth;
- marks the email as confirmed;
- creates the matching `public.users` row with the `operator` role;
- removes the Auth account if saving the public profile fails.

## Deploy

```powershell
supabase functions deploy create-operator
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available to a
deployed Supabase Edge Function. Never put the service-role key in Flutter or
Vercel environment variables exposed to the browser.
