# Web back office, step 1 (foundation, sign-in, roles, admin shell, Applications) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter web target with its own entry point where a host or an admin signs in, lands in the right shell, and an admin can approve or reject host applications.

**Architecture:** `app/lib/main_web.dart` starts `BackOfficeApp` (own router, own screens under `app/lib/backoffice/`) on the same data layer, models, theme (`calmTheme`) and widgets as the app; `main.dart` and the mobile app are not edited. Role is decided after sign-in from `identity.is_admin()`, `identity.my_host_status()` and the session's assurance level. Two-factor for admins is enforced in the database (`identity.require_admin()` needs `aal2`), not only in the screens.

**Tech Stack:** Flutter web, Riverpod, go_router, supabase_flutter (Auth MFA TOTP), qr_flutter, Postgres/pgTAP.

**Spec:** `docs/superpowers/specs/2026-11-14-web-back-office-design.md` step 1 only (with `docs/decisions/2026-11-10-fiuu-and-pending.md`; visual reference `docs/superpowers/design/jom-backoffice-hifi.html`: tokens, 236px sidebar, 760px phone break). "Decided" is the owner's; "Defaults I chose" are used as written.

## Spec check against main (done before writing this plan)

Match: `identity.is_admin()`, `identity.admin_review_host(user, decision, reason)` (approve | reject | suspend | unsuspend; reject and suspend need a reason; approve works on pending or rejected), `identity.pending_hosts()` (user_id, host_name, area, created_at), `identity.host_application(user)` (name, area, bio, ssm, bank holder, bank, account number, qr_path, status, reject_reason), `identity.admin_actions` (admin_id, action, target_user_id, reason, created_at) all exist in `0124_identity_admin_review.sql` as named. `identity.my_host_status()` (0123) gives the host role. The mobile app calls none of the admin functions.

Differences and gaps:
1. **Two-factor is not enforced anywhere on the server.** `require_admin()` only checks the admins table, so a password-only session can call every admin function. Fixed in 0132 (`aal2` required). Effect: the k6 helper that approves hosts with a password-only admin (`tools/loadtest/lib.js`) stops working and is changed in Task 1.
2. **An admin cannot read a host's DuitNow QR.** `host_application` returns `qr_path`, but the `payment-qr` bucket lets only the host and a paying guest read it. Fixed in 0132 (admin with `aal2` may select).
3. `pending_hosts()` carries no bio or payout details; the detail page uses `host_application` (matches the spec: payout details only inside an application).
4. `admin_actions` is "append-only" only by privileges (nobody but the table owner can write; no update or delete is granted). The existing test covers insert only; Task 1 adds update and delete. No function reads the log yet (the Activity log page is a later step).
5. Nothing creates an admin account (email and password): it is a user made by hand plus a row in `identity.admins`. Documented in `docs/release/web-backoffice.md`.
6. `supabase/config.toml` has TOTP MFA off (`enroll_enabled`/`verify_enabled` false) and no session limit. The comment in that file says MFA needs Pro; the Supabase docs say TOTP is free on every plan, and that **session time-box and inactivity timeout need the Pro plan** (pricing page: "Session timeouts: Pro"; sessions guide: "only available on Pro Plans and up", enforced at the next token refresh, so a session lasts the time-box plus the JWT lifetime).
7. The app's `dart:io Platform` use in `SupabaseAuthRepository.signInWithGoogle` would throw on web; the web entry overrides it with the OAuth redirect flow. `flutter build web` of the existing app already compiles.
8. The local Flutter is 3.47.7; CI stays pinned to 3.47.9.

## Global Constraints

- Migrations after 0131: **0132** only.
- Do not run anything against hosted staging; configure the local stack only; hosted steps are written in `docs/release/web-backoffice.md`.
- No host pages, no other admin pages (Hosts, Overview, Reports, Activity log): the admin nav shows Applications only.
- The mobile app and `app/lib/main.dart` stay unchanged; the mobile tests stay green.
- No admin page shows a guest's phone number. Payout details appear in an application only.
- CI stays on Flutter 3.47.9; the `flutter build web` step goes in its own commit, last.
- Roles: admin (`is_admin()` and `aal2`) → admin shell; approved host → placeholder host shell; both → a switch; anyone else → "Not authorised".

## Review Focus

- An admin signed in with a password only (`aal1`) never sees the admin shell and every admin function refuses (Tasks 1, 3).
- A suspended or pending host, and a rejected one, sees "Not authorised", not the host shell (Task 3).
- Reject cannot be sent without a reason; a second admin deciding the same application gets a readable "already decided" message, not a crash (Task 5).
- A person who is both admin and host can switch, and signing out clears the choice (Task 3).
- Narrow phone width: the nav becomes a top bar with a menu and nothing overflows (Task 4).

---

### Task 1: Server side two-factor, admin QR read, k6 helper

**Files:** Create `supabase/migrations/0132_admin_two_factor.sql`, `supabase/tests/admin_two_factor.sql`; Modify `supabase/tests/admin_review_host.sql`, `supabase/tests/blocks_reports.sql` (admin claims gain `"aal":"aal2"`), `tools/e2e_reset.sql` (add `public.e2e_approve_host`), `tools/loadtest/lib.js` (+ README line)

**Interfaces:** `identity.require_admin()` raises `mfa_required` (errcode P0001) when the JWT `aal` is not `aal2`; `identity.is_admin()` unchanged; policy `payment_qr_admin_read` on `storage.objects` (select, `bucket_id = 'payment-qr'`, `identity.is_admin()` and `aal2`); `public.e2e_approve_host(uuid)` (service role, local only).

- [ ] Failing pgTAP in `admin_two_factor.sql`: an admin with claims `aal1` gets `mfa_required` from `admin_review_host`, `pending_hosts`, `host_application`, `open_reports`; with `aal2` they work; a non-admin with `aal2` still gets `not_admin`; `is_admin()` is true for the admin at `aal1` (routing needs it); an admin at `aal2` can select a `payment-qr` object, an admin at `aal1` and a plain user cannot; `update` and `delete` on `admin_actions` are refused for `authenticated` (42501); a decision writes one `admin_actions` row with the admin id and a timestamp. Run → FAIL.
- [ ] Implement 0132 (replace `require_admin` keeping its grants; add the policy). Update the two older test files to use `aal2` claims. Run `tools/test_db.sh` → PASS.
- [ ] `lib.js`: local path approves with `e2e_approve_host` through the service role; hosted path takes `ADMIN_TOKEN` (an `aal2` access token) instead of email and password. Dry run `k6 inspect`. Commit.

### Task 2: Web target and the second entry point

**Files:** Create `app/web/` (flutter create, title "Jom back office"), `app/lib/main_web.dart`, `app/lib/backoffice/app.dart`; Modify `app/.metadata` (add web), `app/test/backoffice/` (new)

**Interfaces:** `BackOfficeApp` (`ConsumerWidget`, `MaterialApp.router`, `calmTheme()`, routes below); `main_web.dart` reads the same `--dart-define` keys as `main.dart`, calls `initSupabase`, overrides `authRepositoryProvider` with `WebAuthRepository` (extends `SupabaseAuthRepository`; `signInWithGoogle` uses `signInWithOAuth(OAuthProvider.google, redirectTo: Uri.base.origin)`).

- [ ] Failing widget test: `BackOfficeApp` pumped with a fake signed-out session shows the sign-in screen (`bo-signin`). Implement the shell of the app and router. `flutter build web -t lib/main_web.dart` passes.
- [ ] Verify `flutter test` (whole suite) and `flutter build apk --debug` are unaffected. Commit.

### Task 3: Roles and the shell choice

**Files:** Create `app/lib/backoffice/access/access.dart` (domain), `access_repository.dart`, `app/test/backoffice/access_test.dart`, `app/test/helpers/fake_access.dart`

**Interfaces:** `enum Shell { signIn, mfa, admin, host, notAuthorised }`; `Shell decideShell({required bool signedIn, required bool isAdmin, required bool aal2, required String hostStatus, Shell? chosen})` (pure: `signedIn` false → signIn; `isAdmin && !aal2` and no approved host → mfa; `isAdmin && aal2` → admin unless `chosen == Shell.host` and the host is approved; approved host without admin → host; everything else → notAuthorised); `AccessRepository { Future<bool> isAdmin(); Future<String> hostStatus(); AssuranceLevel level }`; `accessProvider`; `chosenShellProvider` (state, reset on sign-out).

- [ ] Failing unit tests for every cell of `decideShell` (signed out; plain user; pending, rejected and suspended host; approved host; admin at aal1 (mfa) and at aal2; admin and approved host with and without a choice; admin at aal1 who is also an approved host still reaches the host shell and can enrol). Implement. Commit.

### Task 4: Sign-in screens and the shells

**Files:** Create `app/lib/backoffice/auth/{signin_screen.dart,mfa_screen.dart,backoffice_auth.dart}`, `app/lib/backoffice/shell/{admin_shell.dart,host_placeholder.dart,not_authorised.dart}`; Test `app/test/backoffice/{signin_test.dart,shell_test.dart}`, `app/test/helpers/fake_backoffice_auth.dart`

**Interfaces:** `BackOfficeAuth { Future<void> signInWithPassword(String email, String password); Future<TotpEnrollment> enrollTotp(); Future<void> verifyTotp(String factorId, String code); Future<String?> verifiedFactorId(); }`, `TotpEnrollment { factorId, uri, secret }`; keys `bo-signin`, `bo-tab-host`, `bo-tab-admin`, `bo-phone`, `bo-send-code`, `bo-code`, `bo-google`, `bo-email`, `bo-password`, `bo-signin-submit`, `bo-mfa-code`, `bo-mfa-verify`, `bo-mfa-secret`, `bo-not-authorised`, `bo-host-shell`, `bo-admin-shell`, `bo-nav-applications`, `bo-menu` (phone), `bo-switch`, `bo-signout`.

- [ ] Failing widget tests: phone host path (send code, verify, lands in the host placeholder when approved); admin path (email and password, then the code screen; enrol when no factor with the secret shown, challenge when one exists; wrong code shows a message and stays); a plain user lands on "Not authorised" with Sign out; a person who is both sees `bo-switch` and it flips the shell; at 1200 px the nav is a left column, at 390 px a top bar with `bo-menu` and no overflow.
- [ ] Implement the screens (tokens from `calmTheme`/`Calm`; sidebar 236 px; phone break below 760 px as in the reference). Commit.

### Task 5: Admin Applications page

**Files:** Create `app/lib/backoffice/admin/{admin_repository.dart,applications_screen.dart,application_detail_screen.dart}`, `app/test/helpers/fake_admin.dart`; Test `app/test/backoffice/applications_test.dart`

**Interfaces:** `AdminRepository { Future<List<PendingHost>> pendingHosts(); Future<HostApplication> application(String userId); Future<void> review(String userId, String decision, {String? reason}); Future<String?> qrUrl(String path) }` (RPCs on schema `identity`; `qrUrl` = signed URL from the `payment-qr` bucket); `PendingHost`, `HostApplication` mirror the function columns; error codes `mfa_required`, `not_admin`, `bad_state`, `reason_required` map to readable text; keys `app-row-<id>`, `app-detail`, `app-approve`, `app-reject`, `app-reject-reason`, `app-reject-send`, `app-empty`.

- [ ] Failing widget tests: the list shows pending applications (name, area, date) and an empty state; opening one shows bio, SSM number, bank holder, bank, account number and the QR; Approve calls `review(id, 'approve')`, shows a confirmation and removes the row; Reject asks for a reason, refuses an empty or blank one without calling the repository, then calls `review(id, 'reject', reason: …)`; a `bad_state` answer shows "Already decided" and refreshes the list; no phone number appears anywhere on the page.
- [ ] Implement; Commit.

### Task 6: Local config, session limit, docs

**Files:** Modify `supabase/config.toml` (TOTP `enroll_enabled` and `verify_enabled` true; `[auth.sessions] timebox = "168h"`; `additional_redirect_urls` gains `http://127.0.0.1:3000`); Create `docs/release/web-backoffice.md`

- [ ] Write the doc: the hosted steps (enable MFA TOTP, session time-box 7 days needs the Pro plan, otherwise the fallback below, create an admin user and the `identity.admins` row, redirect URLs, Google provider, Cloudflare Pages), how to run the web app locally, how to make a local test admin. State the Pro-plan answer with its sources. Fallback without Pro (not built): the web app records the sign-in time and signs out after 7 days (weaker: enforced by the browser only).
- [ ] `supabase stop && supabase start`, confirm `GET /auth/v1/settings` lists MFA and the time-box takes effect locally. Commit.

### Task 7: Browser tests, then phones

- [ ] `tools/web_dev_users.sh` (local only): creates a test admin (email and password), a plain user, an approved host and two pending applicants through the local auth admin API. Serve `flutter build web` output, then in the browser tool: admin signs in with password, enrols TOTP (code computed from the shown secret), approves one application and rejects another with a reason; the database shows both `admin_actions` rows with who and when and the hosts' new status; a plain user sees "Not authorised"; screenshots at 1280 px and 390 px.
- [ ] iOS smoke through the mobile MCP (sign in with the test phone, Explore, an event, Profile, Blocked users), then Android only if iOS is clean.

### Task 8: CI web build (own commit), summary

- [ ] Add a `flutter build web -t lib/main_web.dart` step to the `app` job of `ci.yml` after `flutter test` (no change to the Flutter pin). Commit alone. Final self-review. Summary table.

## Rulings made while building

- Ruling: an admin at `aal1` always goes to the code screen, even if they are also an approved host (Task 3 text said they could reach the host shell). Why: one rule is simpler and an admin account should never skip the second factor. Cost if wrong: an admin-host must give the code to reach the host placeholder.
- Ruling: no URL routes (go_router) in the back office yet; the person's role picks the screen and an application opens as a pushed page. Why: one list and one detail page; routes add nothing until step 2 has more pages. Cost if wrong: no deep link to one application; the browser back button leaves the app.
- Ruling: `.metadata` was not edited to list the web platform. Why: it is tool bookkeeping and `flutter create` had already generated `app/web`. Cost if wrong: `flutter upgrade` may not migrate web files.
