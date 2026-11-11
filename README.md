# Maintenance

## Username accounts and admin password changes

This app uses a private alias (`<username>@maintenance.invalid`) with Supabase
Auth because Supabase password sign-in requires an email address or phone
number. Users only enter their username in the app; the alias is never shown as
their contact information.

Before creating accounts:

1. Apply `supabase/migrations/20261111000000_add_username_to_profiles.sql`.
   It adds a case-insensitive unique username and updates the existing
   `auth.users` profile-creation function to save usernames without referencing
   a `profiles.email` column.
2. In Supabase, make sure new user signups are allowed and the **Email**
   provider is enabled under **Authentication > Sign In / Providers**. The app
   sends Supabase a private `<username>@maintenance.invalid` alias behind the
   scenes, so Supabase's Email provider is still required even though users
   never enter an email address.
3. Turn off **Confirm email** in the Email provider settings. The `.invalid`
   alias cannot receive mail, and users should not need email confirmation.
4. Deploy the password function with the Supabase CLI:

   ```text
   supabase functions deploy admin-set-password
   ```

   Configure the function's `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
   `SUPABASE_SERVICE_ROLE_KEY` secrets if they are not already provided by the
   Supabase Edge Functions runtime. The service-role key must never be added to
   the Flutter app.
5. Create an account, then promote the intended first administrator from the
   Supabase SQL editor:

   ```sql
   update public.profiles
   set role = 'admin', status = 'approved'
   where username = 'your_username';
   ```

The administrator's **Change password** action uses the Edge Function, which
checks the caller's profile role before using the server-only service role key
to update the selected account. Admins can use it for their own password and
for any user account.
