# Web back office: what to set up

The back office is the Flutter web build `app/lib/main_web.dart` (admins review host applications; the host side comes
later). It uses the same Supabase project as the app. Nothing here has been done on a hosted project: do these steps
yourself, in this order, on staging first.

## 1. Authenticator codes (two-factor) for admins

Dashboard → Authentication → Multi-Factor → turn **TOTP** on (enrol and verify). TOTP is on every plan, free included.
The database already refuses every admin function unless the session has given the code (migration `0132`), so this
setting is what lets admins get that far.

## 2. Session limit: needs the Pro plan

Supabase can sign people out after a fixed time (**time-box**) or inactivity. Both are **Pro plan and above** (Dashboard →
Authentication → Sessions). On Free they are not available. Limits apply at the next token refresh, so a session can last
up to the time-box plus one access-token lifetime.

- Local stack: `supabase/config.toml` sets `[auth.sessions] timebox = "168h"` (7 days).
- Hosted, on Pro: set Time-box user sessions to 7 days.
- Hosted, on Free (nothing built for it yet): admins stay signed in until they sign out. If you stay on Free, the
  fallback is a client-side sign-out when the sign-in is older than 7 days; say so and it gets built.

Sources: supabase.com/docs/guides/auth/sessions, supabase.com/pricing, supabase.com/docs/guides/auth/auth-mfa/totp.

## 3. Redirect URL for Google (hosts)

Dashboard → Authentication → URL Configuration → add the back office address to Redirect URLs (the same origin the site
is served from). Hosts can also sign in with a phone code.

## 4. Make someone an admin

An admin is a row in `identity.admins`. Create the user (Dashboard → Authentication → Users → Add user, with email and
password), then run in the SQL editor:

```sql
insert into identity.admins (user_id) select id from auth.users where email = 'person@example.com';
```

The first sign-in asks them to set up an authenticator app (QR code); after that they type the 6 digit code.

## 5. Build and host

```bash
cd app
flutter build web -t lib/main_web.dart --dart-define-from-file=env/staging.json
```

Serve `app/build/web` from any static host. The sign-in settings are build-time like the app's.

## Run it locally

```bash
supabase start && tools/web_dev_users.sh
cd app && flutter run -d chrome --web-port 3000 -t lib/main_web.dart --dart-define-from-file=env/local.json
```

`tools/web_dev_users.sh` makes admin@jom.test, plain@jom.test, host@jom.test and two pending applications (all with
password `Passw0rd!local`). Local only.

## Load tests

`tools/loadtest` approves hosts as an admin. Locally it does that through a test helper. Against a hosted project it
needs `ADMIN_TOKEN`, an access token of an admin who has given the authenticator code.
