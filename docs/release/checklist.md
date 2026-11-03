# Release checklist

Each line has the command or screenshot that proves it. `[x]` means it was checked, with the date; the rest are open.
"Beta" lines gate the closed beta, "Public" lines gate a public store launch.

## Decision: what the closed beta is (Task 25 step 2)

The real payment gateway is not built, so the closed beta runs the **`staging` flavor against the jom-stg backend with
the mock gateway**. Every payment is a test payment: the Gateway screen shows the mock's "force success / failure / slow"
controls, the terms say "payments are test payments and no real money moves", and testers are told so in the invite.
No real money moves until the payment-gateway task from "After the MVP" is done. Changing this (for example making
every beta event free) is a one-line edit here before the invite goes out.

Because of this, the beta does not need a prod project. The prod lines below are Public.

## Backend

| | Gate | Line | Proof |
|---|---|---|---|
| [ ] | Public | Prod Supabase project exists, FLAVOR secret is `prod` (no mock gateway, no test OTP) | `supabase secrets list --project-ref <prod>` shows `FLAVOR=prod`; `supabase config` has no test OTP |
| [ ] | Public | Staging and prod run identical migrations | `supabase db diff --linked` is empty for each project |
| [x] 2026-10-31 | Beta | Staging has all migrations, functions and the smoke test passes | `tools/staging_smoke.sh`; last `deploy-staging` run passed |
| [ ] | Public | Scheduled jobs run on prod | `supabase db query --linked "select jobname, active from cron.job"` lists `expire-holds`, `auto-complete`, `retry-refunds` (and the rest of `0090_jobs.sql`) as active |
| [ ] | Public | Email provider for receipts chosen and its key stored as an edge function secret | `supabase secrets list` shows it; a real booking on prod sends a receipt (`receipt-email` logs `sent`) |
| [ ] | Public | Real SMS provider replaces the test OTP | outside the MVP; prod sign-in by phone works with a real number |

## App

| | Gate | Line | Proof |
|---|---|---|---|
| [x] 2026-11-03 | Beta | Privacy policy covers what is collected, location rounded to 1 km and not stored, how to delete (PDPA) | `app/assets/legal/privacy.md`; `flutter test test/legal_assets_test.dart` |
| [x] 2026-11-03 | Beta | Terms cover the platform role, host refund policy, no-show rule, fees illustrative until the gateway is live | `app/assets/legal/terms.md`; same test |
| [ ] | Public | A lawyer has reviewed both pages (both are marked "Draft") | sign-off noted here |
| [x] 2026-11-03 | Beta | Calm prototype is committed | `git ls-files docs/superpowers/kl-local-session-calm.html` |
| [ ] | Beta | App name and bundle id `com.jom.jom` are free on both stores | App Store Connect and Play Console accept the new app record (screenshot). If the id changes, change it in `build.gradle.kts`, `project.pbxproj`, `AppConfig.mapUserAgentPackage` and recreate the Google clients |
| [ ] | Beta | Google sign-in client IDs for iOS and Android exist and are in `APP_ENV_JSON` (`GOOGLE_IOS_CLIENT_ID`; the Android client needs the upload key's SHA-1 from Play Console) | Google button signs in on a signed build from TestFlight and Play internal |
| [ ] | Public | Production map tile provider chosen; `MAP_TILE_URL` (with its key) is in `APP_ENV_JSON`. OpenStreetMap's public tiles are not for production traffic | `AppConfig.fromMap` throws without it for `FLAVOR=prod` (tested); map screenshot from a release build |
| [ ] | Beta | The signed Android release opens the map and loads Home data (proves `INTERNET`: it is in `AndroidManifest.xml`) | install the `app-release.aab` build from Play internal, screenshot of Home with events and of the map |
| [ ] | Beta | Store listings and screenshots made from the Calm prototype | screenshots in both consoles |

## Closed beta

- [ ] Secrets in the repo for `release.yml` (list at the top of that file). Android: create the upload keystore
  (`keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000`), keep it
  outside git, add `base64 -i upload.jks` as `ANDROID_KEYSTORE_BASE64`. iOS: distribution certificate, App Store
  provisioning profile for `com.jom.jom`, and an App Store Connect API key.
- [ ] `release.yml` ran green once by hand (Actions, release, Run workflow) and both builds reached TestFlight and Play internal testing.
- [ ] Onboard the 20 seed hosts by hand: compare the payout account holder name with the host name, then set `verified_at`
  in the dashboard (`update identity.hosts set verified_at = now() where user_id = '<id>'`).
- [ ] Rehearse one full event with a real host and 5 real guests: publish, book, pay (test), scan, complete, payout row appears.
- [ ] Invite 20 to 50 people. Track the KPIs from `docs/source/project-plan.md` section 9 (active hosts, weekly new events,
  hosts with 2 or more events; downloads, browse and favourite rate, browse to message, message to booking, show-up rate, reviews).
