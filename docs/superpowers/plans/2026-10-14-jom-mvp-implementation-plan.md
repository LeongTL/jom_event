# Jom MVP Implementation Plan

Oct 14, 2026 · @Leong

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** build and ship to a closed beta the MVP of Jom: a Flutter app (Android and iOS) where people in KL and Selangor discover, join, pay for, attend and review small offline events, and where hosts create events, scan tickets, complete events and see payouts.

**Architecture:** a Flutter client talks only to one Supabase project. The backend is a modular monolith with six modules (`identity`, `events`, `bookings`, `payments`, `reviews`, `chat`), each owning its own Postgres schema, migrations and edge functions, plus a small `shared` schema for helpers. Payments and SMS sit behind interfaces with mock implementations in the MVP.

**Tech stack:** Flutter and Dart, Riverpod, go_router, supabase_flutter, mobile_scanner (QR scan), qr_flutter (ticket QR), geolocator, url_launcher, Supabase (Postgres, Auth, Storage, Realtime, Edge Functions in TypeScript/Deno, pg_cron), pgTAP, k6, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-14-jom-mvp-design.md` (the approved design). The prototype `prototype/jom-hifi.html` is the source of truth for screens and copy. Executors read both alongside this plan.

## Global constraints

Every task's requirements include these, copied from the spec.

- Platforms: Android and iOS from one Flutter codebase. Flavors `dev`, `staging`, `prod`.
- Backend: Supabase only. One Postgres schema per module. A module reads and writes only its own tables and reaches another module through a function or view, never a join. Migrations live in one flat `supabase/migrations/` folder, prefixed by module (`identity_`, `events_`, ...) and numbered.
- Security: row-level security on every table. Signed-out users read only published events, host public profiles and reviews. Users cannot write booking status, payment results, `verified_at` or event status directly; only SQL functions and edge functions do.
- Money: integer sen everywhere, shown as `RM 45` or `Free`. Platform fee 10% of gross; gateway fee 1.5% of gross in the mock (illustrative); both rounded half up in integer maths. Host receives gross − gateway fee − platform fee. Fees are saved per booking. Payout due 3 working days after the event is completed. Refunds take 3 to 7 working days (copy only).
- Bookings: 1 or 2 people. Hold 15 minutes. Seats count `held`, `processing` and `confirmed`. States `held → processing → confirmed → attended`; side exits `payment_failed`, `cancelled`, `expired`, `no_show`. The gateway webhook, never the app screen, decides a payment result.
- Sign-in: Google or phone number with a one-time code. Browsing is open. Saving, joining (free or paid) and chatting need an account.
- Cancellation: the host picks `24h`, `48h`, `7d` or `none` per event; the policy is copied onto each booking as `cancel_cutoff_at` (null means no refund). A host deleting an event refunds every booking in full.
- Events: hosts create (draft or published), then may edit only title, description and spots after publishing; spots never below seats sold, maximum 40. Date, venue, price and refund window are locked once any guest has joined. Delete is allowed until the event starts. Completion: host taps Mark as completed, or a job completes it 24 hours after `ends_at`.
- Check-in: the host scans the ticket QR (signed token), online only; the manual list is the fallback. No-shows get no refund and cannot review.
- Chat: text only, one thread per attendee and host; phone numbers, WhatsApp and Instagram handles are rejected in chat and event text.
- Notifications: in-app only (bell badge, Chat badge, list). No push in the MVP.
- Time: tabs are computed in `Asia/Kuala_Lumpur` whatever the phone's zone. Now = live or starting within 120 minutes; Night = later tonight until 04:00; Weekend = Saturday and Sunday; All = the View-all page.
- Home: top 9 events by score `(live ? 3 : 0) + (starts in under 30 min ? 2 : 0) + (free ? 1 : 0) − distanceKm × 0.35`; pins at least 72 px apart, scaled to about 215 × 190 px and centred, stable per event id.
- Privacy (PDPA): location only with permission, rounded to about 1 km, never stored on the server; area-sheet fallback. Phone numbers never public. In-app account deletion. Privacy policy and terms before launch.
- Look: tokens copied from the prototype's CSS variables (`.phone[data-t=...]`), lime `#c8ff2e` odometer, film grain, accent per theme.
- Out of the MVP (do not build): real payment gateway, real SMS provider, push notifications, host eKYC, full event editing, admin backend, offline scanning, reminders before events.

## Review focus

The spec is silent on these inputs, and each would hurt a real user. The task that owns each one carries its test.

1. An event is deleted while a guest is mid-payment (`held` or `processing`), or a success webhook arrives after the delete: the guest is refunded or released, never charged for nothing. Owned by Task 9.
2. The same ticket is scanned twice, a ticket for another event is scanned, or a cancelled or unpaid booking is scanned: a clear message, no second check-in. Owned by Task 8.
3. Contact details disguised in chat or event text (spaced digits `0 1 2 3`, `wa.me/…`, `@handle`, "zero one two"): rejected. Owned by Task 2.
4. An event across midnight, a phone set to another time zone, or a Saturday-night event: the tab it appears in follows `Asia/Kuala_Lumpur`. Owned by Task 5.
5. Location permission denied, or no events match the tab and area: Home falls back to the selected area and shows "Nothing right now", no crash or empty dock. Owned by Task 15.

## File structure

```
jom/
├── app/                          Flutter app
│   ├── lib/core/                 config, theme (tokens), router, supabase client, money, grain
│   ├── lib/shared/               models, widgets (Odometer, PinMap, PosterCard, StatusPill)
│   ├── lib/features/             auth, home, event, booking, chat, notifications, reviews,
│   │                             profile, host (each: presentation, domain, data)
│   ├── test/                     unit and widget tests, mirroring lib/
│   └── integration_test/         end-to-end flows
├── supabase/
│   ├── config.toml               includes test OTP for dev and staging
│   ├── migrations/               flat, module-prefixed SQL
│   ├── functions/                payment-webhook, mock-gateway-pay, receipt-email,
│   │                             delete-account, _shared/ (payment_provider.ts, mock_provider.ts)
│   ├── tests/                    pgTAP tests
│   └── seed.sql                  6 areas, 20 hosts, 87 events across the tabs
├── tools/loadtest/               k6 scripts (Task 24)
├── prototype/jom-hifi.html       the visual source of truth
└── .github/workflows/            ci.yml, deploy-staging.yml, release.yml
```

## Phase 0: setup

### Task 1: Scaffold, flavors, local Supabase and CI

**Files:**
- Create: `app/` (Flutter project), `app/lib/core/config/app_config.dart`, `app/test/core/app_config_test.dart`, `.env.example`, `supabase/config.toml` (via `supabase init`), `supabase/tests/00_smoke.sql`, `.github/workflows/ci.yml`

**Interfaces:**
- Produces: `class AppConfig { final String flavor; final String supabaseUrl; final String supabaseAnonKey; factory AppConfig.fromMap(Map<String,String> env); }`; flavors `dev`, `staging`, `prod` via `--dart-define-from-file`.

- [x] **Step 1: Write failing tests in `app_config_test.dart`:** `reads_flavor_and_keys` (map with `FLAVOR=staging`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` gives equal fields) and `throws_when_a_key_is_missing` (missing `SUPABASE_URL` throws `StateError`).
- [x] **Step 2: Run** `cd app && flutter test test/core/app_config_test.dart`. Expected: FAIL (`AppConfig` undefined).
- [x] **Step 3: Implement** `AppConfig.fromMap` in `app_config.dart`; run `supabase init` and `supabase start`; in `config.toml` set `[auth.sms.test_otp]` so phone `+60123456789` accepts code `123456` (dev and staging only); add `supabase/tests/00_smoke.sql` (`select plan(1); select ok(true); select * from finish();`); `ci.yml` runs `flutter analyze`, `flutter test`, `supabase db reset`, `supabase test db` on every push.
- [x] **Step 4: Run** the Flutter test (PASS), `supabase test db` (PASS), and push to confirm CI is green.
- [x] **Step 5: Commit** `git add . && git commit -m "chore: scaffold app, local supabase and CI"`.

### Task 2: Schemas, shared helpers and the contact-info filter

**Files:**
- Create: `supabase/migrations/0001_shared_schemas.sql`, `supabase/tests/shared_contact_filter.sql`, `supabase/tests/rls_baseline.sql`

**Interfaces:**
- Produces: schemas `shared, identity, events, bookings, payments, reviews, chat`; `shared.contains_contact_info(body text) returns boolean`; `shared.add_working_days(d timestamptz, n int) returns timestamptz` (skips Saturday and Sunday; no holiday calendar in the MVP).
- Consumed by: Tasks 4, 7, 10.

- [x] **Step 1: Write failing pgTAP tests.** `contact_filter`: true for `0123456789`, `012-345 6789`, `0 1 2 3 4 5 6 7 8 9`, `+60 12 345 6789`, `wa.me/60123456789`, `whatsapp me`, `@mei.studio`, `ig: meistudio`, `zero one two three four five six seven eight`; false for `see you at 9:00`, `RM30 for 2 people`, `Jalan Telawi 3`, `bring a mat`. `add_working_days`: Fri 2026-10-16 10:00 + 3 = Wed 2026-10-21 10:00; Mon + 3 = Thu. `rls_baseline`: every table in the six module schemas has `relrowsecurity = true` (loop over `pg_class`).
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** the schemas and both functions as `immutable` SQL/PLpgSQL: normalise (lowercase, strip spaces, dots, dashes), spell-out digit words to digits, then match 8+ digit runs, `wa.me`, `whatsapp`, `telegram`, `t.me`, `@` handles and `ig:`/`insta`. Add an event trigger or a final test-only check that fails when a table without RLS exists, so later tasks cannot forget it.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(shared): schemas, contact filter, working-day helper"`.

## Phase 1: backend

### Task 3: Identity, hosts, saved events and notifications

**Files:**
- Create: `supabase/migrations/0010_identity_tables.sql`, `0011_identity_functions.sql`, `supabase/tests/identity_*.sql`

**Interfaces:**
- Produces tables: `identity.profiles(user_id pk, name, phone, is_host bool, created_at)`, `identity.hosts(user_id pk, host_name, area, bio, avatar_url, ssm_number null, verified_at null, created_at)`, `identity.host_payout_accounts(user_id pk, account_holder, bank, account_number)` (owner-only), `identity.saved_events(user_id, event_id, created_at, pk(user_id,event_id))`, `identity.notifications(id, user_id, type, ref_type, ref_id, title, body, created_at, read_at)`, `identity.notification_prefs(user_id pk, chat bool default true, review_requests bool default true)`; view `identity.host_public(user_id, host_name, area, bio, avatar_url, since)`.
- Produces functions: `identity.on_signup()` trigger creating the profile and prefs; `identity.update_profile(name text, phone text)`; `identity.apply_host(host_name text, area text, bio text, account_holder text, bank text, account_number text, ssm_number text default null) returns void` (sets `is_host`; `verified_at` stays null until you set it by hand); `identity.toggle_save(event_id uuid) returns boolean` (new state); `identity.notify(user_id uuid, type text, ref_type text, ref_id uuid, title text, body text) returns void` (respects prefs for `chat_message` and `review_request`; the types `booking`, `payment`, `event_cancelled`, `payout` are always written); `identity.mark_read(ids uuid[])`; `identity.unread_count() returns int`.

- [x] **Step 1: Write failing pgTAP tests.** `signup_creates_profile_and_prefs`; `toggle_save_twice_returns_true_then_false_and_leaves_no_row`; `toggle_save_requires_login` (anon call raises); `user_cannot_read_other_users_saved_or_notifications`; `payout_account_readable_only_by_owner`; `host_public_view_hides_bank_fields`; `notify_skips_chat_type_when_pref_off_but_not_payment_type`; `apply_host_sets_is_host_and_keeps_verified_at_null`; `user_cannot_set_verified_at_directly`.
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** tables, RLS policies and the functions above (`security definer` only where noted, with `search_path` pinned). Add a deferred FK note: `saved_events.event_id` is validated inside `toggle_save` by calling `events.exists_published(uuid)` (defined in Task 4) so no cross-schema FK is needed.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS (the `toggle_save` tests that need events are marked `todo` until Task 4, then enabled there).
- [x] **Step 5: Commit** `git commit -am "feat(identity): profiles, hosts, saved events, notifications"`.

### Task 4: Events tables, create, publish, update, lock rules

**Files:**
- Create: `supabase/migrations/0020_events_tables.sql`, `0021_events_functions.sql`, `supabase/tests/events_*.sql`

**Interfaces:**
- Produces: `events.areas(name pk, lat, lng)` seeded with Bangsar, KLCC, PJ, Sri Hartamas, Mid Valley, Bukit Bintang; `events.events(id uuid pk, host_id, title, description, glyph, color_a, color_b, poster_url, categories text[] (make|move|meet|other), area, venue, lat, lng, starts_at, ends_at, capacity int, price_sen int, cancel_policy text check in ('24h','48h','7d','none'), accept_bookings bool, source_url null, status ('draft','published','ended','cancelled'), created_at)`.
- Functions: `events.save_draft(payload jsonb) returns uuid`; `events.publish(event_id uuid)`; `events.update_event(event_id uuid, title text, description text, capacity int) returns void`; `events.exists_published(event_id uuid) returns boolean`; `events.is_bookable(e events.events) returns boolean` (accept_bookings and price_sen > 0); `events.has_guests(event_id uuid) returns boolean` (calls `bookings.seats_taken(event_id) > 0`, defined in Task 5; stub returns 0 until then).
- Consumes: `shared.contains_contact_info` (Task 2).

- [x] **Step 1: Write failing pgTAP tests.** `publish_requires_all_fields` (title, venue, starts_at < ends_at in the future, capacity 1..40, price_sen >= 0); `description_with_phone_number_is_rejected`; `only_owner_host_can_edit` (another user's call raises); `update_event_changes_only_title_description_capacity_after_publish`; `update_event_rejects_capacity_below_seats_sold` (stub `bookings.seats_taken` to return 12; capacity 11 raises, 12 passes); `update_event_rejects_capacity_above_40`; `draft_can_change_price_and_date_freely`; `published_event_without_guests_can_still_change_price` (via `save_draft` on a published event with no guests); `published_event_with_guests_rejects_price_date_venue_policy_change`; `anon_reads_published_only` (draft and cancelled invisible); `is_bookable_false_for_free_or_switch_off`.
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** the tables, RLS (`select` for anon on `status in ('published','ended')`; hosts read their own rows; no direct insert/update by clients) and the functions. `save_draft` is the only write path for editable fields and enforces the lock rule using `has_guests`.
- [x] **Step 4: Run** `supabase test db`; enable the `todo` tests from Task 3. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(events): tables, publish, limited edit, lock rules"`.

### Task 5: Home feed, time tabs, scoring and View all

**Files:**
- Create: `supabase/migrations/0022_events_feed.sql`, `supabase/tests/events_feed.sql`

**Interfaces:**
- Produces: `events.distance_km(lat1 float8, lng1 float8, lat2 float8, lng2 float8) returns float8` (haversine); `events.feed(p_tab text, p_lat float8, p_lng float8, p_km int default 5, p_now timestamptz default now()) returns table(event_id uuid, title text, glyph text, color_a text, color_b text, starts_at timestamptz, ends_at timestamptz, price_sen int, area text, distance_km float8, is_live bool, spots_left int, score float8)` (tab is `now`, `night` or `weekend`; at most 9 rows; ordered by score); `events.tab_counts(p_lat, p_lng, p_km, p_now) returns table(tab text, n int)`; `events.list_all(p_category text default 'all', p_lat, p_lng, p_km, p_now) returns` the same columns without the limit (`all|make|move|meet|free`); `events.hero_stats(p_tab, p_lat, p_lng, p_km, p_now) returns table(total int, live int, free int, closest_km float8)`.
- Consumes: `bookings.seats_taken(event_id uuid) returns int` (Task 6; stub until then).

- [x] **Step 1: Write failing pgTAP tests with a fixed `p_now`.** `now_tab_has_live_and_next_120_minutes`; `night_excludes_events_in_now_window`; `event_at_01_30_belongs_to_tonight_at_23_00` (review focus 4); `weekend_includes_saturday_and_sunday_only`; `saturday_night_event_is_in_night_and_weekend`; `tabs_ignore_session_time_zone` (set `timezone` to `America/New_York` and to `Asia/Tokyo`: same ids); `ended_and_cancelled_are_in_no_tab`; `feed_returns_top_9_by_score` (12 events, expect 9, order matches the formula); `score_matches_formula` (live +3, <30 min +2, free +1, minus 0.35 per km); `radius_filters_events`; `feed_empty_returns_zero_rows`; `hero_stats_counts_free_and_live`; `list_all_free_filter_uses_price_zero`; `event_with_two_categories_appears_in_both_filters`.
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** with all time maths done `at time zone 'Asia/Kuala_Lumpur'` and `p_now` injected so tests are deterministic. Night upper bound is 04:00 the next morning in KL time.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(events): home feed, time tabs, scoring, view all"`.

### Task 6: Bookings, seat holds, cancellation, expiry

**Files:**
- Create: `supabase/migrations/0030_bookings_tables.sql`, `0031_bookings_functions.sql`, `supabase/tests/bookings_*.sql`

**Interfaces:**
- Produces: `bookings.bookings(id uuid pk, event_id, attendee_id, people int check 1..2, status, hold_expires_at null, ticket_code unique, contact_name, contact_phone, cancel_cutoff_at null, amount_sen int, checked_in_at null, cancelled_at null, created_at)` with `ticket_code` like `KLS-48111`; `bookings.seats_taken(event_id uuid) returns int`.
- Functions: `bookings.create_booking(p_event_id uuid, p_people int, p_name text, p_phone text) returns bookings.bookings` (locks the event row via `events.lock_for_booking(event_id)`; refuses unpublished, started or full events; paid events become `held` with a 15-minute hold; free events become `confirmed` at once with no hold; sets `amount_sen = price × people` and `cancel_cutoff_at` from the event's policy via `events.cancel_cutoff(event_id)`; free events use `starts_at`); `bookings.cancel_booking(p_booking_id uuid) returns void` (owner only; refused after `cancel_cutoff_at` or when it is null; frees seats; for paid bookings calls `payments.refund_booking(booking_id, 'guest_cancelled')`); `bookings.expire_holds() returns int`; `bookings.mark_processing(booking_id)`, `bookings.mark_confirmed(booking_id)`, `bookings.mark_payment_failed(booking_id)` (internal, called by payments only); `bookings.my_bookings(p_scope text) returns setof` (`upcoming|past`); `bookings.event_counts(event_ids uuid[]) returns table(event_id, paid int, checked_in int)`; `bookings.guest_list(event_id uuid) returns table(booking_id, guest_name, people, status, ticket_code, method text)` (host of the event only).
- Consumes: `events.lock_for_booking`, `events.cancel_cutoff` (add both to the events module in this task's first step).

- [x] **Step 1: Write failing pgTAP tests.** `two_users_taking_last_seat_give_exactly_one_booking` (use two `dblink`/parallel sessions via `pg_advisory_lock` harness; second call raises `sold_out`); `held_confirmed_processing_count_as_seats_but_expired_cancelled_failed_do_not`; `paid_booking_is_held_for_15_minutes`; `free_booking_is_confirmed_immediately_with_no_hold`; `people_must_be_1_or_2`; `cannot_book_started_ended_or_draft_event`; `cancel_after_cutoff_is_refused`; `cancel_with_policy_none_is_refused`; `cancel_before_cutoff_frees_seat_and_creates_refund` (spy `payments.refund_booking`); `free_booking_cancel_just_releases_spot`; `expire_holds_expires_only_held_and_payment_failed_past_deadline`; `cancel_cutoff_is_copied_so_later_event_changes_do_not_move_it`; `user_sees_only_own_bookings`; `guest_list_only_for_event_host`; `ticket_code_is_unique_and_formatted`.
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** tables, RLS (attendee reads own; host reads through `guest_list` only; no direct writes) and the functions. Replace the Task 4 and 5 stubs of `seats_taken` with the real function.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(bookings): holds, free joins, cancellation, expiry"`.

### Task 7: Payments, mock gateway, fees and refunds

**Files:**
- Create: `supabase/migrations/0040_payments_tables.sql`, `0041_payments_functions.sql`, `supabase/functions/_shared/payment_provider.ts`, `supabase/functions/_shared/mock_provider.ts`, `supabase/functions/payment-webhook/index.ts`, `supabase/functions/mock-gateway-pay/index.ts`, `supabase/functions/payment-webhook/index_test.ts`, `supabase/tests/payments_*.sql`

**Interfaces:**
- Produces tables: `payments.payment_attempts(id, booking_id, reference text unique, method null, status ('created','success','failed','pending'), session_expires_at, raw jsonb, created_at)`, `payments.refunds(id, booking_id, amount_sen, reason, status ('requested','done','failed'), provider_ref null, attempts int, created_at)`, `payments.fee_snapshots(booking_id pk, gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen)`, `payments.payouts(id, host_id, event_id unique, amount_sen, status ('scheduled','paid'), due_at, paid_ref null, paid_at null)`.
- SQL functions: `payments.compute_fees(gross_sen int) returns table(gateway_fee_sen int, platform_fee_sen int, host_receives_sen int)` (`gross × 15 / 1000` and `gross × 10 / 100`, half up; 36000 gives 540, 3600, 31860); `payments.start_payment(p_booking_id uuid) returns table(attempt_id uuid, reference text, amount_sen int, expires_at timestamptz)` (booking must be `held` or `payment_failed` and unexpired; reuses an unexpired attempt); `payments.apply_gateway_result(p_attempt_id uuid, p_outcome text, p_method text) returns text` (`success|failed|pending`; idempotent; returns the booking status); `payments.refund_booking(p_booking_id uuid, p_reason text) returns void` (writes a `refunds` row and zeroes the fee snapshot's contribution to payouts; free bookings are a no-op); `payments.retry_failed_refunds() returns int`.
- TypeScript interface in `payment_provider.ts`: `interface PaymentProvider { createSession(a:{attemptId:string; reference:string; amountSen:number}): Promise<{sessionUrl:string; expiresAt:string}>; parseWebhook(req:Request): Promise<{attemptId:string; outcome:'success'|'failed'|'pending'; method:string}>; refund(a:{reference:string; amountSen:number}): Promise<{providerRef:string}>; }`. `mock_provider.ts` implements it: a reference ending `-FAIL` fails, `-SLOW` stays pending, otherwise success.

- [x] **Step 1: Write failing tests.** pgTAP: `compute_fees_36000_gives_540_3600_31860`; `compute_fees_rounds_half_up_at_odd_amounts` (1010 sen gives gateway 15, platform 101); `start_payment_refuses_expired_or_confirmed_booking`; `start_payment_reuses_unexpired_attempt`; `success_confirms_booking_saves_fee_snapshot_and_notifies_attendee_and_host`; `failed_sets_payment_failed_and_keeps_hold_time`; `pending_sets_processing`; `second_identical_result_changes_nothing` (idempotent); `success_after_hold_expired_confirms_if_seats_free_else_refunds`; `refund_booking_creates_one_refund_row_and_is_idempotent`; `users_cannot_write_payments_tables`. Deno test: `webhook_rejects_bad_signature_with_401`; `webhook_calls_apply_gateway_result_once_for_duplicate_delivery`.
- [x] **Step 2: Run** `supabase test db` and `deno test supabase/functions/payment-webhook`. Expected: FAIL.
- [x] **Step 3: Implement** the tables, RLS (attendee reads own attempts and refunds; host reads own payouts; nothing writable by clients) and the functions; the webhook verifies a shared-secret HMAC header (`x-gateway-signature`) then calls `apply_gateway_result` with the service role; `mock-gateway-pay` accepts `{attemptId, method, forceOutcome?}` from the app's Gateway screen in `dev` and `staging` only (returns 404 in `prod` until a real provider exists) and posts a signed webhook to `payment-webhook`.
- [x] **Step 4: Run** both suites. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(payments): attempts, idempotent results, fees, refunds, mock gateway"`.

### Task 8: Ticket QR, check-in, completion, no-shows and payouts

**Files:**
- Create: `supabase/migrations/0050_bookings_checkin.sql`, `0051_events_completion.sql`, `0052_payments_payouts.sql`, `supabase/tests/checkin_*.sql`, `supabase/tests/completion_*.sql`

**Interfaces:**
- Functions: `bookings.ticket_token(p_booking_id uuid) returns text` (`<booking_id>.<hmac_sha256_hex>` using a secret from `vault`; attendee owner only); `bookings.check_in(p_event_id uuid, p_token text) returns jsonb` → `{result: 'checked_in'|'already'|'wrong_event'|'not_confirmed'|'invalid', guest_name, people, ticket_code, at}`, host of the event only; `bookings.set_checked_in(p_booking_id uuid, p_value bool) returns void` (the manual list; host only; ticking sets `attended`, unticking returns it to `confirmed`; refused once the event is completed); `events.complete_event(p_event_id uuid) returns void` (host only; refused before `ends_at`; sets `ended`; calls `bookings.mark_no_shows(event_id)`, `payments.schedule_payout(event_id)`, and `identity.notify` review requests to attended guests and a payout notice to the host); `events.auto_complete() returns int` (published events with `ends_at < now() − 24 h`); `bookings.mark_no_shows(event_id uuid) returns int`; `payments.schedule_payout(event_id uuid) returns void` (sum of `host_receives_sen` for non-refunded confirmed, attended or no-show bookings (a no-show paid for the seat; built this way because `complete_event` marks no-shows first); `due_at = shared.add_working_days(now(), 3)`; one row per event); `payments.host_payout_summary() returns table(upcoming_sen bigint, paid_sen bigint)`; `payments.event_earnings(event_id uuid) returns table(gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen)`.

- [x] **Step 1: Write failing pgTAP tests.** `check_in_marks_attended_and_returns_guest_name`; `second_scan_returns_already_with_original_time` (review focus 2); `ticket_for_other_event_returns_wrong_event`; `cancelled_unpaid_or_expired_booking_returns_not_confirmed`; `tampered_token_returns_invalid`; `only_the_events_host_can_check_in`; `manual_toggle_can_untick_until_completed`; `complete_before_end_is_refused`; `complete_marks_unchecked_as_no_show_and_keeps_attended`; `complete_twice_changes_nothing`; `auto_complete_picks_only_events_ended_more_than_24h_ago`; `payout_sums_only_non_refunded_paid_bookings` (12 one-person RM30 bookings give 12 × 2655 = 31860 sen = RM318.60, the design example; a refunded booking is excluded); `payout_due_is_three_working_days_after_completion`; `event_with_no_check_ins_still_pays`; `completion_sends_review_request_only_to_attended_guests`; `no_show_cannot_review` (asserted in Task 10).
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** the functions; store the HMAC secret in Supabase Vault (`ticket_secret`), never in a table the client can read.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat: ticket qr, check-in, completion, no-shows, payouts"`.

### Task 9: Delete event with refunds

**Files:**
- Create: `supabase/migrations/0060_events_delete.sql`, `supabase/tests/events_delete.sql`

**Interfaces:**
- Functions: `events.delete_event(p_event_id uuid) returns jsonb` → `{refunded int, released int}` (host only; refused when `starts_at <= now()`; a draft or an event with no bookings is simply removed; otherwise marks it `cancelled`); `bookings.cancel_all_for_event(p_event_id uuid) returns table(booking_id uuid, was_status text)` (`held` → `cancelled` released, `processing`/`confirmed` → `cancelled` and refunded in full regardless of policy); a note that `payments.apply_gateway_result` refunds a success that arrives for a booking whose event is `cancelled` (already true through `bookings.mark_confirmed`; no code change was needed, a test pins it).

- [x] **Step 1: Write failing pgTAP tests.** `delete_with_12_paid_bookings_refunds_all_12_in_full_and_notifies_each` (title includes "was cancelled"); `delete_is_one_transaction` (a forced refund error rolls everything back, event stays published); `delete_after_start_is_refused`; `delete_by_non_host_is_refused`; `delete_with_no_bookings_removes_it_without_refunds`; `held_bookings_are_released_without_refund`; `processing_booking_is_cancelled_and_a_late_success_webhook_is_refunded` (review focus 1); `success_arriving_after_delete_never_confirms_the_booking`; `cancelled_event_disappears_from_feed_and_view_all`; `retry_failed_refunds_picks_up_failed_rows_up_to_5_attempts`.
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** `delete_event` calling `bookings.cancel_all_for_event`, then `payments.refund_booking` per paid row, then `identity.notify(... 'event_cancelled' ...)`; extend `apply_gateway_result` (Task 7) with the cancelled-event branch.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(events): delete with full refunds"`.

### Task 10: Reviews

**Files:**
- Create: `supabase/migrations/0070_reviews.sql`, `supabase/tests/reviews.sql`

**Interfaces:**
- Produces: `reviews.reviews(id, booking_id unique, event_id, host_id, attendee_id, stars int 1..5, tags text[], body null, created_at)`; view `reviews.host_rating(host_id, average numeric(2,1), count int)`; `reviews.submit_review(p_booking_id uuid, p_stars int, p_tags text[], p_body text) returns uuid`; `reviews.host_reviews(p_host_id uuid, p_limit int default 20) returns table(attendee_first_name, stars, body, created_at)`; `reviews.my_reviews() returns setof`; `reviews.reviewable(p_booking_id uuid) returns boolean` (calls `bookings.is_attended(booking_id)` and `events.is_ended(event_id)`).
- Allowed tags: `friendly_host`, `good_value`, `beginner_friendly`, `clean_venue`.

- [x] **Step 1: Write failing pgTAP tests.** `attended_guest_can_review_once`; `second_review_for_same_booking_raises`; `no_show_cannot_review`; `review_before_event_completed_raises`; `stars_outside_1_to_5_raise`; `unknown_tag_raises`; `body_with_contact_info_is_rejected`; `host_rating_averages_to_one_decimal`; `anon_can_read_host_reviews_but_not_attendee_ids`; `another_users_booking_cannot_be_reviewed`.
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** the table, RLS, view and functions; add `bookings.is_attended(uuid)` and `events.is_ended(uuid)` helpers.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(reviews): verified-attendee reviews and host rating"`.

### Task 11: Chat backend

**Files:**
- Create: `supabase/migrations/0080_chat.sql`, `supabase/tests/chat.sql`

**Interfaces:**
- Produces: `chat.threads(id, attendee_id, host_id, event_id null, last_message_at, unique(attendee_id, host_id))`, `chat.messages(id, thread_id, sender_id, body text check length 1..1000, created_at)`, `chat.thread_reads(thread_id, user_id, read_at)`; functions `chat.open_thread(p_host_id uuid, p_event_id uuid default null) returns uuid`, `chat.send_message(p_thread_id uuid, p_body text) returns chat.messages` (rejects when `shared.contains_contact_info`; notifies the other side with type `chat_message`), `chat.mark_thread_read(p_thread_id uuid)`, `chat.my_threads() returns table(thread_id, other_name, other_avatar, last_body, last_at, unread bool, event_title)`, `chat.unread_total() returns int`. Realtime is enabled on `chat.messages` and `identity.notifications`.

- [x] **Step 1: Write failing pgTAP tests.** `open_thread_twice_returns_same_thread`; `open_thread_requires_login`; `guest_can_message_host_without_booking`; `only_the_two_participants_can_read_or_send`; `send_rejects_phone_numbers_and_handles` (loops the Task 2 cases); `send_over_1000_chars_raises`; `send_notifies_other_side_unless_chat_pref_off`; `unread_flags_clear_after_mark_read`; `host_cannot_open_thread_with_self`.
- [x] **Step 2: Run** `supabase test db`. Expected: FAIL.
- [x] **Step 3: Implement** with RLS limited to participants and `publication supabase_realtime` additions.
- [x] **Step 4: Run** `supabase test db`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(chat): threads, messages, contact filter, unread"`.

### Task 12: Scheduled jobs, receipts, account deletion and seed data

**Files:**
- Create: `supabase/migrations/0090_jobs.sql`, `supabase/functions/receipt-email/index.ts`, `supabase/functions/delete-account/index.ts`, `supabase/seed.sql`, `supabase/tests/jobs.sql`, `supabase/functions/delete-account/index_test.ts`

**Interfaces:**
- `pg_cron` jobs: `expire-holds` every minute (`bookings.expire_holds()`), `auto-complete` every 15 minutes (`events.auto_complete()`), `retry-refunds` every 10 minutes (`payments.retry_failed_refunds()`).
- Edge function `receipt-email` (invoked from `apply_gateway_result` success and free joins through `pg_net`): logs the receipt in `dev` and `staging`, sends through the email provider in `prod` (provider chosen at release, Task 25).
- Edge function `delete-account` (authenticated user only): deletes saved events, notifications, prefs, chat messages sent by the user; anonymises `profiles` (name `Deleted user`, phone null) and keeps bookings and payments rows (money records) with the attendee name blanked; removes the auth user; for a host with future events with bookings it refuses with `host_has_active_events`.
- `seed.sql`: the 6 areas, 20 hosts, 87 events spread across Now, Night, Weekend and later (the prototype's counts), a mix of free and paid, categories, two with `none` and `7d` policies.

- [x] **Step 1: Write failing tests.** pgTAP: `cron_jobs_are_scheduled_with_expected_intervals` (reads `cron.job`); `seed_has_87_events_20_hosts_6_areas`; `seed_events_all_pass_contact_filter`. Deno: `delete_account_anonymises_profile_and_removes_personal_rows`; `delete_account_refuses_host_with_active_events`; `delete_account_requires_auth`.
- [x] **Step 2: Run** `supabase test db` and `deno test supabase/functions/delete-account`. Expected: FAIL.
- [x] **Step 3: Implement** the jobs, functions and seed.
- [x] **Step 4: Run** both. Expected: PASS. Then run `supabase db reset && supabase test db` once: the whole backend suite passes from scratch.
- [x] **Step 5: Commit** `git commit -am "feat: scheduled jobs, receipts, account deletion, seed"`.

### Task 12A: Staging project and deploy

Added after Task 12 so the app (Tasks 13 onward) runs against a real hosted backend with data. Not in the original 25.

**Files:**
- Create: `.github/workflows/deploy-staging.yml`, `docs/release/staging.md`, `app/env/staging.json` (git-ignored; `.env.example` documents the keys)

**Interfaces:**
- Produces: a hosted Supabase staging project with all migrations, the four edge functions, the seed data and the test phone login; `AppConfig` values for the `staging` flavor.
- Consumes: every migration and function from Tasks 1 to 12.

- [x] **Step 1: Write the failing check.** `tools/staging_smoke.sh` signs in with the test OTP over REST against `$SUPABASE_URL`, then calls `events.feed('now', 3.14, 101.68)` and expects 9 rows or fewer and no error; calls `identity.unread_count()` and expects `0`; calls `identity.notify` as the user and expects `42501`. Run it before deploying. Expected: FAIL (no staging project).
- [x] **Step 2: Create and link.** You create the Supabase staging project in the dashboard; run `supabase link --project-ref <ref>`.
- [x] **Step 3: Push and configure.** `supabase db push` (this also proves hosted Supabase allows the RLS event trigger, `pg_cron`, `pg_net` and Vault; if the event trigger is refused, replace it with a test-only check and ledger the ruling); `supabase functions deploy` for `payment-webhook`, `mock-gateway-pay`, `receipt-email`, `delete-account`; `supabase secrets set` for the webhook signing secret; store `ticket_secret` in Vault; in the dashboard set the test OTP (`+60123456789` = `123456`), expose the module schemas to the Data API, and add Google client IDs if available; load `seed.sql`.
- [x] **Step 4: Run** `tools/staging_smoke.sh` and `supabase db diff --linked` (expect no differences). Expected: PASS.
- [x] **Step 5: Add** `deploy-staging.yml` (on push to `main`: `supabase db push`, `supabase functions deploy`) and write `docs/release/staging.md`; commit `git commit -am "chore: staging project and deploy"`.

## Phase 2: attendee app

### Task 13: Core app: theme, router, money, data layer and shell

**Files:**
- Create: `app/lib/core/theme/tokens.dart`, `app/lib/core/theme/grain.dart`, `app/lib/core/router/app_router.dart`, `app/lib/core/money.dart`, `app/lib/core/supabase_client.dart`, `app/lib/shared/widgets/shell.dart`, `app/lib/shared/widgets/status_pill.dart`, `app/lib/shared/models/event_summary.dart`, tests under `app/test/core/` and `app/test/shared/`.

**Interfaces:**
- Produces: `String formatMoney(int sen)` (`0 → 'Free'`, `4500 → 'RM 45'`, `4550 → 'RM 45.50'`); `enum JomTheme { now, night, weekend }` with `JomTokens` copied from the prototype's `.phone[data-t=...]` variables; `class GrainBackground extends StatelessWidget`; `final routerProvider = Provider<GoRouter>`; `class EventSummary { id, title, glyph, colorA, colorB, startsAt, endsAt, priceSen, area, distanceKm, isLive, spotsLeft, score }` with `fromJson`; bottom bars `AttendeeTabs` (Explore, Saved, Bookings, Chat, Profile with unread badge slot) and `HostTabs` (Home, Events, Payouts, Chat, Profile).
- Routes: `/explore`, `/saved`, `/bookings`, `/chats`, `/chats/:threadId`, `/profile`, `/event/:id`, `/event/:id/checkout`, `/booking/:id/gateway`, `/booking/:id/processing`, `/booking/:id/failed`, `/booking/:id/ticket`, `/review/:bookingId`, `/host/:id`, `/notifications`, `/host-mode/home|events|events/:id|events/:id/edit|events/:id/scan|events/:id/checkin|events/:id/guests|new|payouts|payout-account|chats|profile`.

- [x] **Step 1: Write failing tests.** `formatMoney_free_whole_and_cents`; `tokens_match_prototype_for_each_theme` (golden values for `--bg` and accent of now, night, weekend copied from the HTML); `shell_shows_five_tabs_for_attendee_and_five_for_host`; `tab_badge_renders_count_and_hides_at_zero`; `router_redirects_unknown_path_to_explore`.
- [x] **Step 2: Run** `flutter test`. Expected: FAIL.
- [x] **Step 3: Implement** the files above; the grain is a cached noise shader or tiled image with `RepaintBoundary`.
- [x] **Step 4: Run** `flutter test && flutter analyze`. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(app): theme tokens, router, money, shell"`.

### Task 14: Sign-in sheet, sign-up and signed-out states

**Files:**
- Create: `app/lib/features/auth/domain/auth_gate.dart`, `app/lib/features/auth/presentation/sign_in_sheet.dart`, `phone_screen.dart`, `otp_screen.dart`, `name_screen.dart`, `signed_out_tab.dart`, `app/lib/features/auth/data/auth_repository.dart`, tests under `app/test/features/auth/`.

**Interfaces:**
- Produces: `enum AuthReason { join, save, chat }`; `Future<bool> requireAuth(WidgetRef ref, BuildContext context, AuthReason why)` (returns true immediately when signed in; otherwise opens the sheet and, after success, resumes by returning true so the caller completes its action); `abstract class AuthRepository { Stream<Session?> get session; Future<void> signInWithGoogle(); Future<void> sendOtp(String phone); Future<void> verifyOtp(String phone, String code); Future<void> setName(String name); Future<void> signOut(); }`.
- Sheet copy from the prototype: `join` → "Sign in to join / Free or paid, we need to know who is coming. Browsing stays open."; `save` → "Sign in to save / Saved events live in your account, so they follow you across phones."; `chat` → "Sign in to chat / Chat is between you and the host, so we need to know who you are."

- [x] **Step 1: Write failing tests.** `require_auth_returns_true_without_sheet_when_signed_in`; `require_auth_shows_heading_for_each_reason` (three headings); `after_successful_sign_in_the_pending_action_runs_once`; `phone_flow_with_test_otp_123456_signs_in`; `wrong_otp_shows_error_and_stays`; `first_sign_in_asks_for_name_then_continues`; `signed_out_saved_bookings_chat_profile_show_sign_in_prompt_with_the_two_buttons`; `browsing_explore_and_event_pages_needs_no_account`.
- [x] **Step 2: Run** `flutter test test/features/auth`. Expected: FAIL.
- [x] **Step 3: Implement** with `supabase_flutter` (Google via `google_sign_in` ID token; phone via `signInWithOtp`). Phone numbers are normalised to `+60`.
- [x] **Step 4: Run** the tests, then manually sign in on the `dev` flavor with the test number. Expected: PASS.
- [x] **Step 5: Commit** `git commit -am "feat(auth): sign-in sheet, phone otp, signed-out states"`.

### Task 15: Home: tabs, odometer, pin map, dock and area sheet

**Files:**
- Create: `app/lib/features/home/domain/pin_layout.dart`, `home_feed.dart`, `app/lib/features/home/data/home_repository.dart`, `app/lib/features/home/presentation/home_screen.dart`, `odometer.dart`, `pin_map.dart`, `dock.dart`, `area_sheet.dart`, `app/lib/core/location.dart`, tests under `app/test/features/home/`.

**Interfaces:**
- Produces: `List<Offset> layoutPins(List<int> ids, {Size area = const Size(215, 190), double minGap = 72})` (deterministic per id; relaxation; scaled to fill and centred); `class HomeFeed { Tab tab; List<EventSummary> top9; HeroStats stats; }`; `final homeFeedProvider = FutureProvider.family<HomeFeed, HomeQuery>`; `Future<LatLng> coarseLocation(Ref ref)` (rounds to 0.01°, falls back to the selected area's centre when permission is denied; never sent to the server except as the feed query's lat/lng); `class Odometer extends StatelessWidget` (lime `#c8ff2e` tiles, glow pulse).
- Calls: `events.feed`, `events.hero_stats`, `events.tab_counts`.

- [x] **Step 1: Write failing tests.** Unit: `layoutPins_is_deterministic_for_same_ids`; `layoutPins_keeps_72px_minimum_gap`; `layoutPins_fits_215x190_and_is_centred`; `layoutPins_is_stable_when_other_tabs_change_ids` (same id, same relative result with same set). Widget: `every_pin_has_a_dock_card_and_vice_versa`; `tapping_a_pin_scrolls_dock_without_rebuilding_cards`; `scrolling_dock_selects_pin`; `centred_card_is_lifted_and_neighbours_step_aside`; `tapping_centred_card_opens_event`; `tapping_side_card_centres_it`; `hero_wording_per_tab` (Now "N things are happening near you", Night "N ways to spend your night", Weekend "N things to do this weekend"); `empty_feed_shows_Nothing_right_now_and_no_dock` (review focus 5); `location_denied_uses_selected_area_centre`; `area_sheet_default_bangsar_5km_and_show_events_refetches`; `all_tab_opens_view_all_page`; `bell_shows_unread_badge`.
- [x] **Step 2: Run** `flutter test test/features/home`. Expected: FAIL.
- [x] **Step 3: Implement** the files; `pin_layout.dart` ports the prototype's `layoutAlt('map')` algorithm (seeded random from the event id, relaxation to 72 px, bbox scale, centre).
- [ ] **Step 4: Run** the tests; then run on a low-end Android device and confirm dock scrolling stays smooth with grain on. Expected: PASS. *Tests pass (97/97) and the app was run on the iOS simulator against staging; the low-end Android device check is NOT done (no Android toolchain on this Mac), so this step stays open.*
- [x] **Step 5: Commit** `git commit -am "feat(home): tabs, odometer, pin map, dock, area sheet"`.

### Task 16: View all, event pages, hearts and Saved

**Files:**
- Create: `app/lib/features/event/presentation/view_all_screen.dart`, `event_screen.dart`, `poster_card.dart`, `app/lib/features/event/data/event_repository.dart`, `app/lib/features/event/presentation/saved_screen.dart`, `app/lib/features/event/domain/saved_controller.dart`, tests under `app/test/features/event/`.

**Interfaces:**
- Produces: `EventRepository { Future<List<EventSummary>> listAll(String category, LatLng at, int km); Future<EventDetail> detail(String id); }`; `EventDetail` (summary plus description, venue, host, rating, count, `cancelPolicy`, `sourceUrl`, `isBookable`); `final savedProvider = AsyncNotifierProvider<SavedController, Set<String>>` with `Future<void> toggle(String eventId)` that calls `requireAuth(why: save)` then `identity.toggle_save`, updating every heart (poster, hero, bottom bar) from the same set; label rules `countdown(Duration)` → `⏱ in 17:42` under 2 hours (ticks each second), `⏱ in 1h 32m` beyond.
- Page choice: `isBookable` → paid page with "Join · RM 30"; otherwise the free page with "Join · Free".

- [ ] **Step 1: Write failing tests.** `view_all_has_category_chips_with_counts_and_sections_for_all`; `selecting_a_chip_shows_only_that_grid`; `poster_tags_happening_countdown_under_2h_clock_otherwise`; `tapping_heart_signed_out_opens_sign_in_save_then_saves_after_signing_in`; `heart_state_is_shared_between_poster_hero_and_bottom_bar`; `double_tap_does_not_duplicate`; `saved_tab_lists_hearted_events_and_greys_ended_with_Ended_tag`; `paid_event_page_shows_cancel_policy_text_per_policy` (24h/48h/7d → "Free cancellation up to … before", none → "No refunds once booked"); `free_page_shows_source_card_and_opens_url`; `get_directions_launches_maps_uri`; `join_signed_out_opens_sign_in_join_then_goes_to_checkout`; `message_button_requires_sign_in_chat_then_opens_thread`.
- [ ] **Step 2: Run** `flutter test test/features/event`. Expected: FAIL.
- [ ] **Step 3: Implement** the files (`url_launcher` for maps and source link).
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat(event): view all, event pages, hearts, saved"`.

### Task 17: Checkout, payment, ticket, cancellation and Bookings

**Files:**
- Create: `app/lib/features/booking/data/booking_repository.dart`, `app/lib/features/booking/data/payment_gateway_client.dart`, `app/lib/features/booking/presentation/checkout_screen.dart`, `gateway_screen.dart`, `processing_screen.dart`, `failed_screen.dart`, `ticket_screen.dart`, `cancel_sheet.dart`, `bookings_screen.dart`, `app/lib/features/booking/domain/hold_timer.dart`, tests under `app/test/features/booking/`.

**Interfaces:**
- Produces: `BookingRepository { Future<Booking> create(String eventId, int people, String name, String phone); Future<PaymentSession> startPayment(String bookingId); Future<void> cancel(String bookingId); Future<List<Booking>> mine(String scope); Stream<Booking> watch(String bookingId); Future<String> ticketToken(String bookingId); }`; `abstract class PaymentGatewayClient { Future<void> pay(PaymentSession s, String method); }` with `MockGatewayClient` calling `mock-gateway-pay` (used in `dev`/`staging`; the real client is a later task); `class HoldTimer` exposing `Stream<Duration>` to `hold_expires_at`.
- Outcomes: confirmed → ticket; failed → failed screen ("Your spot is held for another 06:12. If any money left your account, it's refunded automatically.", Try again, Give up); no answer → processing screen and Bookings shows "Processing" until the booking stream says otherwise.

- [ ] **Step 1: Write failing tests.** `paid_checkout_shows_hold_countdown_and_free_checkout_does_not`; `people_stepper_stops_at_1_and_2`; `checkout_total_shows_Free_or_RM_total`; `free_confirm_my_spot_creates_confirmed_booking_and_opens_ticket`; `paid_pay_goes_to_gateway_then_processing_until_stream_confirms`; `gateway_lists_methods_and_pay_calls_client_once_on_double_tap`; `failed_screen_try_again_reuses_hold_and_give_up_releases_and_goes_home`; `expired_hold_shows_spot_released_message`; `ticket_shows_qr_from_token_reference_and_buttons_directions_calendar_cancel_done`; `cancel_button_hidden_after_cutoff_or_for_policy_none`; `cancel_sheet_says_RM_amount_and_3_to_7_working_days_then_marks_cancelled`; `bookings_upcoming_past_with_status_pills`; `tapping_confirmed_booking_opens_ticket_and_attended_opens_review`; `sold_out_error_shows_friendly_message`.
- [ ] **Step 2: Run** `flutter test test/features/booking`. Expected: FAIL.
- [ ] **Step 3: Implement** the files (`qr_flutter` for the QR; `add_2_calendar` for Add to calendar; screens copy the prototype's text).
- [ ] **Step 4: Run** the tests; then on `dev` book a paid event with the mock gateway for success, failure and slow outcomes. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat(booking): checkout, mock payment, ticket, cancel, bookings"`.

### Task 18: Chat screens (attendee and host)

**Files:**
- Create: `app/lib/features/chat/data/chat_repository.dart`, `app/lib/features/chat/presentation/chat_list_screen.dart`, `chat_thread_screen.dart`, `app/lib/features/chat/domain/unread_provider.dart`, tests under `app/test/features/chat/`.

**Interfaces:**
- Produces: `ChatRepository { Future<String> openThread(String hostId, {String? eventId}); Stream<List<Message>> messages(String threadId); Future<void> send(String threadId, String body); Future<List<ThreadSummary>> mine(); Future<void> markRead(String threadId); }`; `final chatUnreadProvider = StreamProvider<int>` driving the tab badge (attendee and host). The same two screens serve both modes (host copy: "Messages from guests about your events.").

- [ ] **Step 1: Write failing tests.** `list_shows_one_row_per_host_with_unread_dot_and_subtitle`; `thread_shows_event_card_notice_and_bubbles_with_times`; `send_appends_message_and_clears_input`; `phone_number_error_shows_inline_Keep_the_chat_in_Jom_message`; `realtime_message_arrives_and_badge_updates`; `opening_thread_marks_it_read`; `signed_out_chat_tab_shows_sign_in_prompt`; `host_mode_uses_host_copy_and_same_threads`.
- [ ] **Step 2: Run** `flutter test test/features/chat`. Expected: FAIL.
- [ ] **Step 3: Implement** with Supabase Realtime on `chat.messages` filtered by thread.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat(chat): list, thread, realtime, badges"`.

### Task 19: Notifications screen

**Files:**
- Create: `app/lib/features/notifications/data/notification_repository.dart`, `presentation/notifications_screen.dart`, `domain/bell_provider.dart`, tests under `app/test/features/notifications/`.

**Interfaces:**
- Produces: `NotificationRepository { Stream<List<AppNotification>> watch(); Future<void> markRead(List<String> ids); Future<NotificationPrefs> prefs(); Future<void> setPrefs(NotificationPrefs p); }`; `final bellCountProvider = StreamProvider<int>`; tap routing by `ref_type`: `booking` → ticket, `thread` → chat thread, `event` → event page, `payout` → payouts (host).

- [ ] **Step 1: Write failing tests.** `list_shows_icon_title_body_time_and_unread_dot`; `opening_screen_marks_visible_items_read_and_badge_drops`; `tap_routes_by_ref_type` (four cases); `show_me_switches_chat_and_review_requests_toggle_prefs`; `booking_payment_and_event_change_rows_are_always_on_and_not_toggleable`; `footer_says_no_push_notifications_yet`; `bell_on_host_home_also_shows_count`.
- [ ] **Step 2: Run** `flutter test test/features/notifications`. Expected: FAIL.
- [ ] **Step 3: Implement** with Realtime on `identity.notifications`.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat(notifications): in-app list, bell, switches"`.

### Task 20: Reviews, host public profile and Profile

**Files:**
- Create: `app/lib/features/reviews/presentation/review_screen.dart`, `my_reviews_screen.dart`, `app/lib/features/reviews/data/review_repository.dart`, `app/lib/features/profile/presentation/profile_screen.dart`, `help_screen.dart`, `legal_screen.dart`, `host_public_screen.dart`, tests under `app/test/features/reviews/` and `app/test/features/profile/`.

**Interfaces:**
- Produces: `ReviewRepository { Future<void> submit(String bookingId, int stars, List<String> tags, String body); Future<List<Review>> mine(); Future<HostPublic> host(String hostId); }`; Profile rows My reviews, Notifications, Help & support, Terms & privacy, Log out, Delete account (confirm dialog calling `delete-account`), and the highlighted Switch to Host mode card.

- [ ] **Step 1: Write failing tests.** `review_has_five_tappable_stars_four_tags_and_verified_attendee_label`; `submit_requires_at_least_one_star_and_calls_repository_once`; `only_attended_booking_opens_review`; `host_public_shows_stats_coming_up_and_reviews`; `profile_log_out_returns_to_explore_signed_out`; `delete_account_asks_confirmation_then_calls_function_and_signs_out`; `host_with_active_events_gets_clear_refusal_message`; `terms_and_privacy_pages_render_from_assets`.
- [ ] **Step 2: Run** `flutter test test/features/reviews test/features/profile`. Expected: FAIL.
- [ ] **Step 3: Implement** the screens; terms and privacy text ship as markdown assets (drafted in Task 25).
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat: reviews, host profile, profile, account deletion"`.

## Phase 3: host mode

### Task 21: Host mode: apply, dashboard, events list, create, edit, delete

**Files:**
- Create: `app/lib/features/host/data/host_repository.dart`, `app/lib/features/host/presentation/host_home_screen.dart`, `host_events_screen.dart`, `event_form_screen.dart`, `delete_sheet.dart`, `apply_host_screen.dart`, `host_profile_screen.dart`, `app/lib/features/host/domain/event_form_state.dart`, tests under `app/test/features/host/`.

**Interfaces:**
- Produces: `HostRepository { Future<void> apply(HostApplication a); Future<String> saveDraft(EventForm f); Future<void> publish(String id); Future<void> update(String id, {String? title, String? description, int? capacity}); Future<DeleteResult> delete(String id); Future<List<HostEventRow>> events(String status); Future<HostDashboard> dashboard(); }`; `EventForm` validation mirrors the SQL rules (title, venue, end after start, spots 1..40, price ≥ 0, description passes a client-side contact check as a hint only; the server is authoritative); `enum EditMode { create, publishedEdit }` where `publishedEdit` locks date, venue, categories, price, switch and refund window and clamps the spots stepper to `[seatsSold, 40]`.

- [ ] **Step 1: Write failing tests.** `first_switch_to_host_opens_apply_with_payout_account_and_optional_ssm`; `host_home_shows_payout_card_next_event_fill_bar_and_tiles`; `events_tabs_draft_published_ended_list_cards_with_paid_over_spots_pill`; `new_event_form_has_description_when_where_price_spots_policy_chips_and_completion_note`; `publish_disabled_until_valid`; `contact_info_in_description_shows_server_error`; `edit_published_locks_date_venue_price_policy_and_clamps_spots_at_sold`; `edit_can_change_title_description_spots_and_saves`; `delete_sheet_shows_guest_count_and_total_and_confirms_then_returns_to_events`; `delete_after_start_is_hidden`; `host_profile_rows_and_switch_back_to_attendee`.
- [ ] **Step 2: Run** `flutter test test/features/host`. Expected: FAIL.
- [ ] **Step 3: Implement** the files; poster upload goes to a Supabase Storage bucket `posters` (public read, host-write to own folder), resized to 1200 px wide before upload.
- [ ] **Step 4: Run** the tests. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat(host): apply, dashboard, events, create, edit, delete"`.

### Task 22: Host event details, scanner, check-in list, completion, guests, payouts

**Files:**
- Create: `app/lib/features/host/presentation/host_event_screen.dart`, `scan_screen.dart`, `checkin_screen.dart`, `guest_list_screen.dart`, `complete_sheet.dart`, `payouts_screen.dart`, `payout_account_screen.dart`, `app/lib/features/host/domain/scan_controller.dart`, tests under `app/test/features/host/`.

**Interfaces:**
- Produces: `ScanController { Future<ScanResult> onCode(String raw); }` calling `bookings.check_in(event_id, token)` and mapping `checked_in|already|wrong_event|not_confirmed|invalid` to the result card ("Checked in just now", "Already checked in at 9:02 AM", "This ticket is for another event", "This booking is not paid or was cancelled", "Not a Jom ticket"); a 2-second debounce per code so a held camera does not fire twice; `HostRepository` additions `guests(eventId)`, `setCheckedIn(bookingId, value)`, `complete(eventId)`, `payouts()`, `earnings(eventId)`, `savePayoutAccount(...)`.
- Event details page shows: poster, status, title, date, venue, fill bar, tiles (joined, checked in, gross), Scan tickets and Guest list buttons, details card (description, price, refund window, payout), Messages row, completion note, Delete, and Mark as completed; the Complete sheet says how many guests did not check in.

- [ ] **Step 1: Write failing tests.** `event_details_shows_fill_bar_tiles_and_expected_payout_RM318_60_for_12_paid` (the card reads `event_earnings`: 36000 − 540 − 3600 = 31860 sen; the Payouts screen shows the same fee lines); `scan_valid_code_shows_green_card_with_name_people_and_ticket_code_and_counter_increments`; `scan_same_code_twice_shows_already_with_time_and_counter_unchanged`; `scan_other_event_and_unpaid_and_garbage_show_their_messages`; `same_code_within_2_seconds_calls_server_once`; `camera_permission_denied_shows_manual_list_prompt`; `no_signal_shows_use_manual_list_message`; `manual_list_ticks_and_unticks_until_completed`; `complete_sheet_shows_no_show_count_and_calls_complete_then_returns_to_events`; `complete_button_disabled_before_end_time_with_hint`; `payouts_screen_shows_upcoming_paid_out_and_fee_lines_for_each_event`; `payout_account_screen_saves_and_shows_verified_pill_only_when_verified_at_set`.
- [ ] **Step 2: Run** `flutter test test/features/host`. Expected: FAIL.
- [ ] **Step 3: Implement** with `mobile_scanner` (QR only, torch toggle); the prototype's "Simulate a scan" button exists only in a debug build behind `kDebugMode`.
- [ ] **Step 4: Run** the tests, then scan a real ticket QR shown on a second phone. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "feat(host): event details, qr scanner, check-in, completion, payouts"`.

## Phase 4: quality and release

### Task 23: End-to-end tests

**Files:**
- Create: `app/integration_test/attendee_journey_test.dart`, `host_journey_test.dart`, `app/integration_test/helpers/seed.dart`, `.github/workflows/e2e.yml`

- [ ] **Step 1: Write the failing journeys** against a local Supabase with the seed. `attendee_journey`: browse signed out → heart opens the sign-in sheet → phone sign-in with the test OTP → heart saves → join a paid event → mock payment success → ticket QR visible → message the host and see the reply → after the host completes, review. `free_join_journey`: free event → Join → sign-in → Confirm my spot → ticket. `host_journey`: apply as host → create and publish an event → a guest books → scan the guest's ticket token → Mark as completed → payout row exists with `due_at` 3 working days later and the amount equals the fee maths. `delete_journey`: a guest holds a paid booking, the host deletes the event, the guest sees a cancellation notification and a refund row exists.
- [ ] **Step 2: Run** `flutter test integration_test -d <emulator>`. Expected: FAIL until wired.
- [ ] **Step 3: Implement** helpers (create users through the admin API, advance time by calling the SQL functions with explicit `p_now` where available or by updating event times in the seed) and the CI workflow (Android emulator job).
- [ ] **Step 4: Run** all four journeys. Expected: PASS.
- [ ] **Step 5: Commit** `git commit -am "test: end-to-end journeys"`.

### Task 24: Load and device performance

**Files:**
- Create: `tools/loadtest/last_seat.js`, `feed.js`, `chat.js`, `tools/loadtest/README.md`

- [ ] **Step 1: Write the k6 scripts with thresholds.** `last_seat.js`: 200 virtual users call `create_booking` on an event with 5 seats; assert exactly 5 succeed and the rest get `sold_out`. `feed.js`: 100 users call `events.feed` on the 87-event seed; `p95 < 400 ms`. `chat.js`: 50 users send 20 messages each; 0 errors.
- [ ] **Step 2: Run** against the staging project. Expected: fail first if an index is missing.
- [ ] **Step 3: Fix** any breach with indexes on `bookings(event_id, status)`, `events(status, starts_at)` and `chat.messages(thread_id, created_at)`; add the migration.
- [ ] **Step 4: Run** again. Expected: all thresholds pass. On one low-end Android and one iPhone, check Home dock scrolling with grain and glow stays at 50 fps or better; if not, turn the grain down on low-end devices.
- [ ] **Step 5: Commit** `git commit -am "perf: load tests and indexes"`.

### Task 25: Closed beta and store release

**Files:**
- Create: `docs/release/checklist.md`, `app/assets/legal/privacy.md`, `app/assets/legal/terms.md`, `.github/workflows/release.yml`

- [ ] **Step 1: Write the release checklist** and make each line checkable by a command or a screenshot: staging and prod Supabase projects with identical migrations (`supabase db diff` is empty); privacy policy (PDPA: what is collected, location rounded to 1 km and not stored, how to delete); terms (platform role, host refund policy, no-show rule, "fees illustrative until gateway live"); app name and bundle id checked on both stores (assumed free; confirm); store listings and screenshots from the prototype; Google sign-in client IDs for both platforms; email provider for receipts chosen; scheduled jobs running on prod.
- [ ] **Step 2: Confirm the gateway status.** Because the real gateway is not built, the closed beta runs in `staging` mode with the mock gateway and every price labelled as test payments, or all events are free. State the choice in `docs/release/checklist.md`; no real money moves until the "After the MVP" payment task is done.
- [ ] **Step 3: Onboard 20 seed hosts by hand:** you verify holder name against host name, then set `verified_at` in the dashboard; rehearse one full event with a real host and 5 real guests.
- [ ] **Step 4: Build and ship** with `release.yml` (signed Android bundle, iOS archive) to TestFlight and Play internal testing; invite 20 to 50 people; track the KPIs from `project-plan.md` section 9.
- [ ] **Step 5: Commit** `git commit -am "chore: release checklist, legal pages, release workflow"`.

## After the MVP (not part of this plan's tasks)

Each item keeps the interface already in place: real payment gateway behind `PaymentProvider` (also the host payout process and the Malaysian regulatory check), real SMS provider replacing the test OTP, push notifications and pre-event reminders, host eKYC, full event editing, admin backend, offline scanning with a downloaded guest list, block and report in chat. Each gets its own design and plan.

## Self-review

- **Spec coverage:** every screen in the design's attendee and host tables maps to a task: Explore, View all, Area sheet (15, 16); events and sign-in (14, 16); checkout to cancel, Bookings (17); Saved (16); Chat (18); Review, host profile, Profile (20); Notifications (19); Host Home to Delete sheet (21); Event details, Scan, Complete sheet, Guest list, Check-in, Payouts, Payout account (22). Rules: booking and money (6, 7), check-in and completion (8), delete (9), chat filter (2, 11), time tabs and scoring (5), delete account (12).
- **Interfaces:** function names match across tasks (`create_booking`, `apply_gateway_result`, `refund_booking`, `check_in(event_id, token)`, `complete_event`, `schedule_payout`, `send_message`).
- **Not built, by decision:** real gateway, real SMS, push, eKYC, full edit, admin, offline scan.

## Execution handoff

Plan complete. Please review it. Which execution approach do you prefer: **subagent-driven** (a fresh subagent per task, reviewed before the next; most thorough) or **native** (I implement every task myself in one session, then one fresh reviewer checks the branch)? I recommend subagent-driven because the backend tasks (6 to 9) depend on each other's exact function signatures and a mistake in money or refunds would be costly.
