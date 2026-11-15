# Quality and safety (pipeline fix, report and block, load scripts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the broken staging deploy step, let people report and block, and raise the load scripts and indexes for the 1000 user run.

**Architecture:** Blocks and reports live in the `identity` schema; `identity.blocks` is one-way rows read only by the blocker, and block effects are enforced inside the existing functions (`search_people`, `follow`, `chat.open_thread`, `chat.send_message`, `chat.my_threads`). The app adds a repository (`SafetyRepository`) with a Report / Block menu and a Blocked users screen. k6 scripts and index migrations are code only; nothing runs against hosted staging.

**Tech Stack:** Postgres/pgTAP (`tools/test_db.sh`), Flutter + Riverpod + go_router, k6, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-14-quality-and-release-design.md` sections 1, 2 and the k6 scripts and indexes of 3 (with `docs/decisions/2026-11-10-fiuu-and-pending.md`). "Decided" are the owner's.

## Global Constraints

- Migrations after the latest on main (0127): `0128` and up.
- Do not run anything against the hosted staging project. Sections 4 and 5 are out of scope. No PR. Flutter pin stays 3.47.9; only Task 1 touches `.github/workflows`, in its own commit.
- Report targets exactly `user`, `event`, `message`; reasons exactly `spam`, `harassment`, `scam`, `fake_event`, `other`; status default `open`.
- Reports are readable only by admins (`identity.is_admin()`); blocks are visible only to the blocker; nothing is shown to the reported or blocked person.

## Review Focus

- Blocking twice or blocking yourself must not error badly or create a self-block (Task 2).
- A block removes follows in both directions and hides search both ways (Task 2).
- An existing thread with a blocked person disappears from the blocker's inbox and neither side can send (Task 2).
- A message report only works for a participant of that message's thread (Task 2).
- Unblock restores search and following but not the deleted follows (Task 2).

---

### Task 1: Pipeline fix (done first, own commit)

- [x] Reproduced: the failing `deploy-staging` log says `Target: local stack (127.0.0.1:54422) · default; pass --remote for jom-stg` then `ECONNREFUSED 127.0.0.1:54422`; CLI 3.1.0 `db push --help` says "Local by default. Pass --remote for the linked project" and `functions deploy` has no `--project-ref` any more (only `--remote`).
- [x] `ci.yml` and `deploy-staging.yml` pin `supabase/setup-cli` to `3.1.0`; `db push --remote`; `functions deploy --remote`. Commit `ci: pin Supabase CLI ...`.

### Task 2: Blocks and reports in the database

**Files:** Create `supabase/migrations/0128_identity_blocks_reports.sql`, `0129_blocks_effects.sql`; Test `supabase/tests/blocks_reports.sql`

**Interfaces:** `identity.blocks(blocker_id, blocked_id, created_at)` pk the pair, check not self; `identity.reports(id, reporter_id, target_type, target_id, reason, note, status, created_at)`; `identity.block_user(p_user_id uuid) returns void`; `identity.unblock_user(p_user_id uuid) returns void`; `identity.report(p_target_type text, p_target_id uuid, p_reason text, p_note text) returns void`; `identity.my_blocks() returns table (user_id uuid, name text, username text, avatar_url text, blocked_at timestamptz)`; `identity.open_reports()` admin only; `identity.is_blocked_between(a uuid, b uuid) returns boolean` (internal).

- [ ] Failing pgTAP: block adds a row, twice is fine, self raises `cannot_block_self`, unknown user raises `user_not_found`; follows in both directions are deleted; `search_people` hides each from the other; `follow` either way raises `blocked`; `chat.open_thread` and `chat.send_message` raise `blocked`; `chat.my_threads` hides the thread from both; unblock restores search and follow; `my_blocks` lists only mine and not who blocked me; report accepts valid targets and reasons, rejects others (`bad_target`, `bad_reason`), a message report from a non participant raises `not_participant`, a missing event raises `event_not_found`; an authenticated user cannot select `reports` directly; `open_reports` raises `not_admin` for a non admin and lists for an admin; signed out raises `login_required`.
- [ ] Run → FAIL. Implement the migrations (security definer, `search_path = ''`, revoke from public). Run `tools/test_db.sh` → PASS. Commit.

### Task 3: App data layer

**Files:** Create `app/lib/features/safety/data/safety_repository.dart`, `domain/blocked_user.dart`; Modify `app/test/helpers/` (new `fake_safety.dart`); Test `app/test/features/safety/safety_repository_test.dart`

**Interfaces:** `abstract class SafetyRepository { Future<void> block(String userId); Future<void> unblock(String userId); Future<List<BlockedUser>> blocked(); Future<void> report({required ReportTarget target, required String targetId, required ReportReason reason, String? note}); }`, `enum ReportTarget { user, event, message }`, `enum ReportReason { spam, harassment, scam, fakeEvent, other }` with `.wire` strings; `safetyRepositoryProvider`, `blockedUsersProvider`.

- [ ] Failing test: `BlockedUser.fromJson`, the reason and target wire strings, the fake. Implement → PASS. Commit.

### Task 4: Report / Block menu and Blocked users list

**Files:** Create `safety/presentation/report_sheet.dart`, `blocked_users_screen.dart`, `safety_menu.dart`; Modify `person_screen.dart`, `chat_thread_screen.dart`, `event_screen.dart`, `profile_screen.dart`, `app_router.dart` (`/blocked-users`); Test `app/test/features/safety/safety_ui_test.dart`

**Interfaces:** keys `person-menu`, `chat-menu`, `event-report`, `message-report` (long press), `report-reason-<wire>`, `report-submit`, `block-confirm`, `blocked-users-row`, `unblock-<userId>`, `profile-blocked-users`; thank-you text "Thanks, we will look at it."; blocked list empty text "You have not blocked anyone."

- [ ] Failing widget tests: the person menu shows Report and Block; Report opens reasons, submit calls the repository and shows the thank-you; Block asks to confirm then calls `block` and pops; the chat menu likewise; long press on a message offers Report; the event page has Report only (no Block); Profile has Blocked users; the list shows rows and Unblock calls `unblock` and removes the row; empty state.
- [ ] Implement → `flutter test`, analyze, format → PASS. Commit.

### Task 5: k6 scripts and indexes

**Files:** Modify `tools/loadtest/last_seat.js`, `feed.js`, `README.md`; Create `search_people.js`, `submit_receipt.js`, `supabase/migrations/0130_load_indexes.sql`; Test `supabase/tests/load_indexes.sql`

**Interfaces:** `last_seat` 1000 users (still 1 booked per seat, rest `sold_out`), `feed` 500 to 1000, new `search_people` (p95 < 400 ms) and `submit_receipt` scripts; `run.sh` accepts the new names. Indexes from the spec that do not exist yet: `bookings(event_id, status)`, `events(status, starts_at, visibility)`, `identity.profiles(lower(username))`, `identity.follows(followee_id)` (already exists, skip), `payments.receipts(booking_id, status)`.

- [ ] Failing pgTAP: each named index exists. Implement the migration → PASS.
- [ ] Scripts: `k6 inspect` each (dry run, no network) and a small local run of `search_people` and `submit_receipt`. Commit.

### Task 6: Devices and review

- [ ] iOS through the mobile MCP (report a person, an event and a chat message; block a person, search, follow, message; Blocked users and Unblock), then Android only if iOS is clean. Final self-review. Summary table.
