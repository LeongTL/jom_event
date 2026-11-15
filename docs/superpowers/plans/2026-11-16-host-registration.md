# Host registration, approval and the host-entrance flag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A user applies as an Event owner, an admin approves or rejects by hand, and the Profile card, the Host mode routes and a feature flag follow the application's state.

**Architecture:** `identity.hosts` gets a status; `profiles.is_host` stays the "approved" bit so `identity.is_host` and every events function are untouched. Admins, their action log and `admin_review_host` live in `identity`; flags in a new `app` schema. The app reads `identity.my_host_status()` and `app.get_flags()` into providers; the Profile card switches on the status and the router's `redirect` guards `/host-mode/*` from a listenable fed by those providers.

**Tech Stack:** Postgres/pgTAP (`supabase test db`, `tools/test_db.sh`), Flutter, Riverpod, go_router, `tools/e2e.sh` journeys.

**Spec:** `docs/superpowers/specs/2026-11-14-host-registration-design.md` (with `docs/decisions/2026-11-10-fiuu-and-pending.md`). "Decided" items are the owner's; "Defaults I chose" are used as written.

## Global Constraints

- Migrations are numbered after the latest in `supabase/migrations` (0122 on this base): `0123` to `0125`.
- Status values exactly `pending`, `approved`, `rejected`, `suspended`; flag key exactly `host_entry_enabled`, default true.
- Existing hosts become `approved` in the migration; `supabase/seed.sql` hosts are inserted `approved`.
- The admin role is given by hand only: no function inserts into `identity.admins`; `identity.admin_actions` has no update or delete grant.
- Notification types `host_approved`, `host_rejected`, `host_suspended`.
- The payment details form of the manual payment task (`/host-mode/payout-account`, `ApplyHostScreen(edit: true)`, `payment_details_screen.dart`) keeps working.
- Do not change `.github/workflows`; CI stays on Flutter 3.47.9. No PR.

## Review Focus

- A suspended host's open sessions: `is_host` false makes `save_draft`/`publish` refuse (pgTAP in Task 2).
- Applying again while `pending` or `approved` must not reset an approved host to pending (Task 1).
- Signed-out user: `my_host_status` returns `none`, never an error (Task 1).
- Flag off: `/host-mode/*` and the card are gone, deep links go to Explore (Tasks 5 and 6).
- Host mode routes while the status is still loading are blocked, never open (Task 5).
- Notification text for the decision never leaks the admin's identity (Task 2).

---

### Task 1: Status on hosts, apply creates `pending`, `my_host_status`

**Files:**
- Create: `supabase/migrations/0123_identity_host_status.sql`
- Test: `supabase/tests/host_registration.sql`; modify `supabase/tests/identity_host.sql`, `identity_payment_details.sql`, `payments_receipt_reminders.sql`, `payments_host_actions.sql`, `payments_push_wiring.sql`, `payments_guest_actions.sql` (they relied on `apply_host` making a host), `supabase/seed.sql`

**Interfaces:**
- Produces: `identity.hosts.status/reviewed_by/reviewed_at/reject_reason`; `identity.apply_host(...)` (same signature) sets `pending`, never touches `is_host`; `identity.my_host_status() returns table(status text, reason text)` (`none` when no row or signed out).

- [ ] **Step 1: Failing pgTAP** `host_registration.sql` (plan N): apply creates `status = 'pending'` and `is_host` false; `my_host_status` is `none` before, `pending` after; signed-out gives `none`; a host row that existed before the migration is `approved` (insert via the old shape, then check the backfill by running the migration's backfill statement, or assert seed hosts are `approved` in `seed_tests/seed.sql`); applying again as `approved` keeps `approved` and `is_host`; applying again as `rejected` sets `pending` and clears `reject_reason`.
- [ ] **Step 2:** `supabase test db` → FAIL (no column).
- [ ] **Step 3: Migration 0123**: add the four columns (`status text not null default 'pending' check (...)`); `update identity.hosts h set status = 'approved' where exists (select 1 from identity.profiles p where p.user_id = h.user_id and p.is_host)`; recreate `apply_host` without the `is_host` update, with `on conflict do update set ..., status = case when hosts.status = 'rejected' then 'pending' else hosts.status end, reject_reason = case when hosts.status = 'rejected' then null else hosts.reject_reason end`; `my_host_status()` security definer returning `coalesce(status,'none')`, `reject_reason`; grant to anon and authenticated.
- [ ] **Step 4:** Update the six old tests: after `apply_host` add a superuser `update identity.profiles set is_host = true` (and `update identity.hosts set status = 'approved'`) so they keep testing their own subject; `identity_host.sql` assertions that said apply sets `is_host` now say it does not. Seed hosts get `status` `approved` in `supabase/seed.sql`; `seed_tests/seed.sql` gets one check.
- [ ] **Step 5:** `supabase test db` → PASS. Commit.

### Task 2: Admins, the action log, `admin_review_host`, applications

**Files:** Create `supabase/migrations/0124_identity_admin_review.sql`; Test `supabase/tests/admin_review_host.sql`

**Interfaces:**
- Produces: `identity.admins(user_id pk references auth.users on delete cascade, created_at)`; `identity.is_admin() returns boolean`; `identity.admin_actions(id, admin_id, action, target_user_id, reason, created_at)` (no foreign keys, append-only); `identity.admin_review_host(p_user_id uuid, p_decision text, p_reason text) returns void`; `identity.pending_hosts() returns table(user_id, host_name, area, created_at)`; `identity.host_application(p_user_id uuid)` returns name, area, bio, ssm_number, account_holder, bank, account_number, qr_path, status, reject_reason.

- [ ] **Step 1: Failing pgTAP** (plan N): non-admin `admin_review_host` and `pending_hosts` and `host_application` raise `not_admin`; approve sets `status approved`, `is_host` true, `reviewed_by`, `reviewed_at`, one `admin_actions` row with admin, action, target and time, and a `host_approved` notification; reject needs a reason (`reason_required`), sets `rejected` and `reject_reason`, notifies `host_rejected`; suspend sets `suspended` and `is_host` false and `events.save_draft` then raises `not_host`; unsuspend sets `approved` and `is_host` true; wrong state (approve a non-pending, suspend a non-approved) raises `bad_state`; unknown decision raises `bad_decision`; authenticated cannot `insert`/`update`/`delete` `admin_actions` or insert `admins`; two admins have the same rights.
- [ ] **Step 2:** FAIL. **Step 3:** Migration 0124 (security definer, `search_path = ''`, `identity.notify(...)` for the three types with fixed titles, no admin identity in the text; revoke from public, grant to authenticated). **Step 4:** PASS. Commit.

### Task 3: Flags

**Files:** Create `supabase/migrations/0125_app_flags.sql`; modify `supabase/config.toml` (add `app` to exposed `schemas`); Test `supabase/tests/app_flags.sql`

**Interfaces:** Produces `app.flags(key text primary key, value jsonb not null)` seeded with `host_entry_enabled = true`; `app.get_flags() returns table(key text, value jsonb)` callable by anon and authenticated; no write grants.

- [ ] **Steps:** failing pgTAP (anon and authenticated read the default `true`; authenticated cannot update; a hand update to `false` shows in `get_flags`) → migration → PASS → `tools/test_db.sh` → commit.

### Task 4: App data: status, flags, providers

**Files:** Create `app/lib/features/host/domain/host_status.dart`, `app/lib/core/flags/flags_repository.dart`; modify `host_repository.dart`, `app/test/helpers/fake_host.dart`; Test `app/test/features/host/host_status_test.dart`

**Interfaces:**
- Produces: `enum HostState { none, pending, approved, rejected, suspended }`, `class HostStatus { HostState state; String? reason; }`; `HostRepository.myStatus() -> Future<HostStatus>`; `final hostStatusProvider = FutureProvider.autoDispose<HostStatus>`; `FlagsRepository.hostEntryEnabled() -> Future<bool>` (true when the call fails, so a network blip does not hide a working host); `hostEntryEnabledProvider`.

- [ ] Failing test (parse each of the five states and a reason; flag parse, missing key is true) → implement → PASS → commit.

### Task 5: Profile card states and the apply screen

**Files:** Modify `profile_screen.dart`, `apply_host_screen.dart`; Test `app/test/features/profile/host_card_test.dart`

**Interfaces:** Consumes Task 4. Keys: `host-card-none` (text "Register as Event owner", opens `/host-mode/apply`), `host-card-pending` ("Application under review", not tappable), `host-card-approved` ("Switch to Host mode" → `/host-mode/home`), `host-card-rejected` (reason + "Apply again" → apply), `host-card-suspended` ("Your host access is paused. Contact support"); no card at all when the flag is off. The old key `host-mode-card` is kept on the approved card so existing tests and journeys keep working.

- [ ] Failing widget tests for the five states and the flag off, plus: the apply form still asks for the holder, bank and account number and the submit shows a "pending" confirmation → implement → PASS → commit.

### Task 6: Route guard

**Files:** Modify `app/lib/core/router/app_router.dart`; Test `app/test/core/host_guard_test.dart`

**Interfaces:** `String? hostGuard(String path, HostState? state, bool entryEnabled)`: for `/host-mode/*` returns `/explore` unless the entrance is on and the state is `approved`; `/host-mode/apply` is allowed for `none` and `rejected` when the entrance is on; `null` otherwise. `createRouter({ValueListenable<HostAccess>? access})` wires it into `redirect` after `deepLinkRedirect` and uses `access` as `refreshListenable`; `routerProvider` builds `access` from `hostStatusProvider` and `hostEntryEnabledProvider` (and refreshes on app resume).

- [ ] Failing unit tests of `hostGuard` for every state × flag, plus a router test (approved goes through, pending is sent to `/explore`, unknown state while loading is blocked) → implement → PASS → commit.

### Task 7: Notification labels

**Files:** Modify `notification_labels.dart`; Test: extend the existing labels test.

- [ ] Failing test: `notifIcon` is not the fallback for `host_approved`, `host_rejected`, `host_suspended`; `notifRoute` of `host_approved` is `/host-mode/home`, of the other two `/profile` → implement → PASS → commit.

### Task 8: Hand approval docs

**Files:** Modify `docs/release/staging.md`

- [ ] Add a section "Approve a host by hand": the SQL that inserts the first admin (`insert into identity.admins (user_id) values ('<uuid>')`), then, as that admin, `select set_config('request.jwt.claims', '{"sub":"<admin uuid>","role":"authenticated"}', true); select identity.admin_review_host('<host uuid>', 'approve', null);` and how to list `identity.pending_hosts()`; the flag update (`update app.flags set value = 'false' where key = 'host_entry_enabled'`); the note that the hosted project must add `app` to the exposed schemas. Commit.

### Task 9: Journeys and e2e scaffolding

**Files:** Modify `tools/e2e_reset.sql` (`public.e2e_make_admin(uuid)`, service role only; clears admins on rerun), `app/integration_test/helpers/seed.dart` (`newHost` applies then an admin approves through `admin_review_host`; `newAdmin`, `setFlag`), `tools/loadtest/lib.js` note; Create `app/integration_test/host_registration_journey_test.dart`

- [ ] Journey: a new user with no application sees "Register as Event owner", applies, sees "Application under review" and no Host mode; the host-mode route is refused; admin rejects with a reason, the user sees it and "Apply again"; applies again, admin approves, the card says "Switch to Host mode" and the Host mode home opens; admin suspends, the card shows the paused message and `/host-mode/home` goes to Explore; flag off hides the card for an approved host. Run all journeys through `tools/e2e.sh` (existing journeys use `newHost`, which now goes through approval). Commit.

### Task 10: Devices and review

- [ ] iOS through the mobile MCP (each of the five card states, the guard, the flag off), then Android only if iOS is clean. Final whole-branch self-review. Summary table.
