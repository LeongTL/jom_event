# Staging

The hosted backend the app talks to before release: Supabase project **jom-stg**, reference `habundtbjgzkidwcaogw`,
region ap-southeast-1 (Singapore), URL `https://habundtbjgzkidwcaogw.supabase.co`.
Mock payments and the test phone login are on here. Neither may ever exist on prod.

## What is deployed (set up 2026-10-15)

| Piece | How it got there |
|---|---|
| Tables, functions, cron jobs | `supabase db push` applied all 23 migrations in `supabase/migrations/` |
| Edge functions | `supabase functions deploy`: `payment-webhook`, `mock-gateway-pay`, `receipt-email`, `delete-account` |
| Edge function secrets | `supabase secrets set FLAVOR=staging GATEWAY_WEBHOOK_SECRET=<random>` |
| Demo data: 20 hosts, 87 events | `supabase db query --linked -f supabase/seed.sql` (by hand, once; never a migration, never on prod) |
| API schemas, test phone login | `supabase config push` from a minimal config holding only those settings (see below) |

Settings pushed: exposed API schemas `public`, `graphql_public`, `identity`, `events`, `bookings`, `payments`, `reviews`, `chat`;
phone sign-up on, a dummy Twilio entry (no real SMS can be sent), and the test number `+60123456789` = `123456`.

Do not run a plain `supabase config push` from the repo: it sends the whole local auth section and would switch off
email confirmation and MFA on staging. Push only the settings you mean to change, from a small config file:

```toml
project_id = "jom_stg_push"
[api]
schemas = ["public", "graphql_public", "identity", "events", "bookings", "payments", "reviews", "chat"]
```
```bash
supabase config diff --workdir <dir containing supabase/config.toml> --project-ref habundtbjgzkidwcaogw
supabase config push --workdir <dir> --project-ref habundtbjgzkidwcaogw
```

## Receipts

On since 2026-10-15. The database stores the functions URL and the service-role key in Vault and calls `receipt-email`
when a booking is confirmed. The function accepts any token whose role is `service_role` (the gateway has already checked
the signature, so `verify_jwt` must stay on for it, pinned in `config.toml`). On staging it only logs the email, and a
guest who signed in by phone has no email, so the answer is `skipped no_email`.

To (re)store the two secrets, for example after resetting the project's JWT secret, run this yourself in a terminal
where you are signed in to the CLI (it reads the key through your login and never prints it):
`bash tools/dev/set_staging_receipt_secrets.sh`

## Automatic redeploys

On since 2026-10-15. Once ci passes on `main`, `.github/workflows/deploy-staging.yml` links the project, runs `supabase db push`,
deploys the functions and runs `tools/staging_smoke.sh`. First run by hand (workflow_dispatch): all steps passed.
It needs the repository secrets `SUPABASE_ACCESS_TOKEN`, `STAGING_PROJECT_REF`, `STAGING_ANON_KEY` and the variable
`STAGING_DEPLOY_ENABLED=true` (all set). Set the variable to anything else to switch it off. Not yet seen: the run that
comes from merging to `main` (the `workflow_run` trigger); the first merge after this one will show it.

## Google sign-in

Switched on 2026-10-15 in the Supabase dashboard (Authentication, Providers, Google) with a Google Cloud project named Jom.
The **Web** OAuth client is configured and proven end to end with a real login in a browser, and its callback is
`https://habundtbjgzkidwcaogw.supabase.co/auth/v1/callback`. Its client ID is also in the git-ignored `app/env/staging.json`
as `GOOGLE_WEB_CLIENT_ID`. The client secret lives only in Supabase.

Still to do, and why the app's Google button says "Google sign-in isn't set up on this device yet" for now:
- an **iOS** OAuth client (bundle id `com.jom.jom`), its client ID passed to the app as `GOOGLE_IOS_CLIENT_ID`;
- an **Android** OAuth client (package `com.jom.jom` plus the signing SHA-1; this Mac has no Java, so install Android Studio first).

If the app name or bundle id changes at release (Task 25), these clients must be created again.

## Not done yet

- Google sign-in on a phone: the two clients above.
- Phone sign-in only works for the test number (`+60123456789` = `123456`): staging uses a dummy SMS provider, so a real
  number cannot receive a text. A real SMS provider is outside the MVP.

## Redeploying by hand (only needed if the automatic one is off or broken)

```bash
supabase link --project-ref habundtbjgzkidwcaogw
supabase db push
supabase functions deploy --project-ref habundtbjgzkidwcaogw
tools/staging_smoke.sh
```

## Checking it

The Flutter app has its own real-backend test: `cd app && flutter test --dart-define-from-file=env/staging.json --tags staging --run-skipped test/staging`.
It signs in with the test number, saves a name on the account and the profile, reads it back, puts the account back as it
was (no name) and signs out. Supabase allows one text per number every 3 seconds, so run it once at a time.

`tools/staging_smoke.sh` signs in with the test phone number and checks the open feed, the refusals and every function.
`EXPECT_SEEDED=1 tools/staging_smoke.sh` also checks the seed is there (20 hosts, most of the events still upcoming). It reads the project URL and public key from the
git-ignored `app/env/staging.json`, which is what the app's `staging` flavor uses. The seed's times are relative to when
it was loaded, so the Home tabs go stale. To refresh them, first delete the old seed events, then load the seed again
(running it twice without deleting would double the events):
`supabase db query --linked "delete from events.events where host_id::text like 'd5eed000%'"`
