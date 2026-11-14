# Manual-Transfer Payment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Paid events work without a gateway: the guest holds a seat for 1 hour, pays the host by bank transfer or DuitNow QR, uploads a receipt, and the host accepts it or asks for a new one.

**Architecture:** New `payments.receipts` table plus `security definer` functions in the `payments` module drive the existing booking statuses (`held` → `processing` → `confirmed`); no new status. A per-minute job calls a new `receipt-reminders` Edge function that sends push through a new `send-push` function. The app gets a guest pay flow in `features/booking` and a host review flow in `features/host`. `PAYMENT_MODE` (`manual` default, `gateway` later) picks the flow; the mock gateway screens stay for `gateway`.

**Tech Stack:** Postgres/Supabase (pgTAP, pg_cron, pg_net, Storage), Deno Edge functions, Flutter 3.47.9 (CI pin, do not touch `.github/workflows`), Riverpod, go_router, `image_picker`, `firebase_core` + `firebase_messaging`.

**Spec:** `docs/superpowers/specs/2026-11-14-manual-payment-design.md` (context: `docs/decisions/2026-11-10-fiuu-and-pending.md`). Related, not built here: usernames and following (merged work this builds on), `2026-11-14-event-visibility-design.md`, `2026-11-14-web-back-office-design.md`.

## Global Constraints

- Hold = `least(1 hour, starts_at - 30 minutes - now())`, never below 15 minutes. Bookings close when `now() > starts_at - 1 hour` (`bookings_closed`).
- A `processing` booking has `hold_expires_at = null` and keeps its seat; no receipt in the hold = `expired`.
- Cooldown: the same user cannot book the same event for 30 minutes after a hold of theirs expired with no receipt (`cooldown_active`, seconds left in the error `hint`).
- Receipts: JPEG or PNG, up to 5 MB, compressed on the phone, private bucket `receipts`, path `{booking_id}/{uuid}.jpg`, files deleted 30 days after the event ends (the row stays). Status values: `pending`, `accepted`, `replaced`, `late`.
- Host reminders: push at upload (`push_count` 1), +15 min (2), +30 min (3), system chat message at +45 min (also a push). Nothing after a decision. No 24-hour guest message.
- The host has no "reject": only "Ask to upload again" (fresh hold, chat note, refused with `bookings_closed` inside the last hour).
- Reference code = existing `ticket_code`. Refunds are done outside the app; `record_refund` only records them.
- All new functions: `security definer set search_path = ''`, `revoke all ... from public`, grants only as listed.
- Notification types added: `receipt_submitted`, `receipt_reminder`, `receipt_accepted`, `receipt_requested`, `seat_assigned`, `late_receipt`.
- Do not push or open a PR. Commit with `git -c user.name=Leong -c user.email=leong@Leongs-MacBook-Air.local commit ...`. DB checks: `supabase db reset --no-seed` then `supabase test db <file>`; full run `tools/test_db.sh`. Flutter checks run from `app/`. Deno: `deno test supabase/functions`.

## Rulings made while planning (spec decides what it leaves open)

- **Free events are not touched.** The spec's "refuse free events in `create_booking`" belongs to the event-visibility spec (tasks 4 and 5); this plan changes only what manual payment needs.
- **Migration numbers** are re-ordered so each file only uses what exists: `0112` payment details, `0113` receipts table and buckets, `0114` manual hold, `0115` guest actions, `0116` host actions, `0117` device tokens and push, `0118` reminders and purge (the spec's list had the cooldown before the table it needs).
- **Tickets list:** `bookings.my_bookings('upcoming')` also returns unexpired `held` and `expired` bookings for events that have not ended, so "Pay now" and "Upload receipt late" can show. Existing tests that assert held or expired rows are absent are updated.
- **Hold length is 1 hour in the database for all modes** (the spec's `create_booking` change is unconditional); `PAYMENT_MODE` only chooses which screens the app opens.
- **`apply_host` keeps requiring bank details** (registration is redesigned in `2026-11-14-host-registration-design.md`); the new Payment details screen in Host Profile allows QR or bank, either one.
- **Compression** uses `image_picker`'s `maxWidth` and `imageQuality`, no extra package.
- **Push in the app** is behind a `PushService` interface; Firebase starts inside a try/catch so a build without `GoogleService-Info.plist` or `google-services.json` still runs, and push delivery stays "not tested on a device".

## Review Focus

- Submitting twice (double tap, retry): one `pending` receipt, the older one `replaced`, one host notification per submit.
- `submit_receipt` on a `confirmed`, `cancelled` or someone else's booking: refused, state unchanged.
- Host B calling `accept_receipt`, `request_new_receipt`, `assign_seat` or `record_refund` on host A's event: refused.
- Accepting a receipt for an event that was cancelled or deleted meanwhile: refused or the booking cancelled, never `confirmed`.
- A guest who cancelled their own hold, or who uploaded a late receipt, is not put in cooldown.

---

### Task 1: Host payment details (database)

**Files:**
- Create: `supabase/migrations/0112_identity_payment_details.sql`
- Test: `supabase/tests/identity_payment_details.sql`

**Interfaces:**
- Produces: `identity.host_payout_accounts.duitnow_qr_path text`; `bank`, `account_holder`, `account_number` nullable with check `duitnow_qr_path is not null or (bank, account_holder, account_number all not null)`; `identity.save_payment_details(p_holder text, p_bank text, p_number text, p_qr_path text) returns void` (host only, `authenticated`); private bucket `payment-qr` with policies: a host writes and reads under `{user_id}/`; a guest reads a file only while they hold a `held`, `processing` or `expired` booking of an event by that host.

- [ ] **Step 1: Write `identity_payment_details.sql` (pgTAP).** Tests: `qr_only_is_accepted`, `bank_only_is_accepted`, `nothing_is_refused` (`payment_details_required`), `partial_bank_without_qr_is_refused`, `non_host_cannot_save` (`not_a_host`), `save_overwrites_existing_account`, `guest_cannot_read_account_row_directly`, `qr_policy_lets_booked_guest_read_and_stranger_not` (rows in `storage.objects` + a held booking; read through the policy as each role).
- [ ] **Step 2: Run `supabase db reset --no-seed && supabase test db supabase/tests/identity_payment_details.sql`.** Expected: FAIL, column or function missing.
- [ ] **Step 3: Write the migration.** Alter the table (drop `not null`, add the column and check); `save_payment_details` upserts the caller's row and raises `payment_details_required` / `not_a_host`; `insert into storage.buckets (id, name, public) values ('payment-qr','payment-qr', false)` and `storage.objects` policies written with `bucket_id = 'payment-qr'` and `(storage.foldername(name))[1]` checks.
- [ ] **Step 4: Re-run Step 2.** Expected: all pass.
- [ ] **Step 5: Run `tools/test_db.sh`.** Expected: green (fix any older test the nullable columns break).
- [ ] **Step 6: Commit** `feat(identity): host payment details`.

### Task 2: Receipts table and bucket

**Files:**
- Create: `supabase/migrations/0113_payments_receipts.sql`
- Test: `supabase/tests/payments_receipts_table.sql`

**Interfaces:**
- Produces: `payments.receipts(id uuid pk default gen_random_uuid(), booking_id uuid not null references bookings.bookings(id), image_path text not null, status text not null check (status in ('pending','accepted','replaced','late')) default 'pending', note text, uploaded_at timestamptz not null default now(), decided_by uuid, decided_at timestamptz, push_count int not null default 0, chat_reminded boolean not null default false)`; RLS: the booking's attendee reads own rows, nothing else (the host reads through functions); private bucket `receipts` with policies: the attendee inserts under `{booking_id}/`, the attendee and the event's host read.

- [ ] **Step 1: Write tests:** `attendee_reads_only_own_receipts`, `host_cannot_select_receipts_table_directly`, `clients_cannot_insert_rows`, `status_check_rejects_unknown_value`, `bucket_policy_lets_attendee_upload_to_own_booking_folder_only`, `bucket_policy_lets_host_read_but_not_write`.
- [ ] **Step 2: Run the file.** Expected: FAIL, table missing.
- [ ] **Step 3: Write the migration** (table, RLS own-row select policy, `grant select to authenticated`, bucket and `storage.objects` policies using a helper `payments.is_host_of_booking(path_booking uuid)` that is `security definer`).
- [ ] **Step 4: Re-run the file.** Expected: pass.
- [ ] **Step 5: Commit** `feat(payments): receipts table and bucket`.

### Task 3: One-hour hold, closing time and cooldown

**Files:**
- Create: `supabase/migrations/0114_bookings_manual_hold.sql`
- Modify: older pgTAP files that assert the 15-minute hold (`bookings_create.sql`, `bookings_cancel_and_expire.sql`, others found by `grep -ln "15 minutes" supabase/tests`)
- Test: `supabase/tests/bookings_manual_hold.sql`

**Interfaces:**
- Consumes: Task 2 (`payments.receipts`).
- Produces: `bookings.create_booking(p_event_id uuid, p_people int, p_name text, p_phone text)` (same signature, `create or replace` from the `0091` body) with the new rules; error `bookings_closed` also when `now() > starts_at - interval '1 hour'`; error `cooldown_active` with `hint` = seconds left.

- [ ] **Step 1: Write `bookings_manual_hold.sql`.** Tests: `far_event_hold_is_one_hour`, `near_event_hold_is_start_minus_30_minutes` (event in 70 min → hold ends at start - 30 min), `hold_never_below_15_minutes` (event in 65 min), `closed_one_hour_before_start` (event in 59 min → `bookings_closed`), `cooldown_blocks_for_30_minutes_after_expiry_with_no_receipt` (hint is the seconds left, within 1 to 1800), `cooldown_ends_after_30_minutes`, `cooldown_not_applied_after_own_cancel`, `cooldown_not_applied_when_a_late_receipt_exists`, `cooldown_is_per_event_and_per_user`, `last_seat_race_still_locks_event` (second user gets `sold_out`).
- [ ] **Step 2: Run it.** Expected: FAIL on hold length.
- [ ] **Step 3: Update the older tests** that assert 15 minutes to 1 hour (the old values are the failures to fix).
- [ ] **Step 4: Write the migration.** Hold: `now() + greatest(interval '15 minutes', least(interval '1 hour', ev.starts_at - interval '30 minutes' - now()))`. Cooldown: an `expired` booking of the same attendee and event whose `hold_expires_at > now() - interval '30 minutes'` and which has no row in `payments.receipts`; raise `cooldown_active` with `using hint`. Keep the free-event branch, `shared.send_receipt` call and unique-code loop exactly as in `0091`.
- [ ] **Step 5: Run Step 2 command, then `tools/test_db.sh`.** Expected: green.
- [ ] **Step 6: Commit** `feat(bookings): one hour hold, closing time, cooldown`.

### Task 4: Guest actions: instructions and receipt upload

**Files:**
- Create: `supabase/migrations/0115_payments_guest_actions.sql`
- Test: `supabase/tests/payments_guest_actions.sql`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces: `payments.pay_instructions(p_booking_id uuid) returns table (amount_sen int, reference text, qr_path text, bank text, account_holder text, account_number text, hold_expires_at timestamptz, status text)` (attendee only, `authenticated`); `payments.submit_receipt(p_booking_id uuid, p_image_path text) returns payments.receipts` (attendee only, `authenticated`); `shared.notify_host_receipt(p_booking_id uuid)` (internal; writes `receipt_submitted`, or `late_receipt` for a late one, with `ref_type 'booking'`); `bookings.my_bookings('upcoming')` also returns unexpired `held` and `expired` bookings of events that have not ended.

- [ ] **Step 1: Write the tests:** `pay_instructions_returns_amount_reference_and_host_details_to_attendee`, `pay_instructions_empty_for_other_users_and_signed_out`, `pay_instructions_refused_when_confirmed_or_cancelled`, `submit_from_held_moves_to_processing_and_clears_hold`, `submit_from_processing_replaces_older_pending_receipt`, `submit_from_expired_stores_late_receipt_and_keeps_booking_expired`, `submit_on_confirmed_cancelled_or_foreign_booking_refused` (`not_owner` / `not_payable`), `submit_rejects_path_outside_own_booking_folder` (`bad_receipt_path`), `submit_notifies_host_once_per_submit`, `submit_after_event_started_refused` (`event_started`), `my_bookings_lists_held_and_expired_for_future_events`, `existing_upcoming_and_past_results_unchanged_for_processing_and_confirmed`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement** the three functions and the `my_bookings` change in `0115`; `submit_receipt` locks the booking row, sets `processing`/null hold for `held`, inserts the receipt, marks previous pending `replaced`, calls `shared.notify_host_receipt`.
- [ ] **Step 4: Run Step 2 command, then `tools/test_db.sh`.** Expected: green after updating tests that assumed held rows were hidden.
- [ ] **Step 5: Commit** `feat(payments): pay instructions and receipt upload`.

### Task 5: Host actions

**Files:**
- Create: `supabase/migrations/0116_payments_host_actions.sql`
- Test: `supabase/tests/payments_host_actions.sql`

**Interfaces:**
- Consumes: Task 4 and `chat.open_thread` (`0080_chat.sql`).
- Produces (all host-of-the-event only, `authenticated`): `payments.pending_receipts(p_event_id uuid default null) returns table (receipt_id uuid, booking_id uuid, event_id uuid, event_title text, guest_id uuid, guest_name text, guest_username text, amount_sen int, image_path text, status text, uploaded_at timestamptz)`; `payments.accept_receipt(p_receipt_id uuid) returns void`; `payments.request_new_receipt(p_booking_id uuid, p_note text) returns void`; `payments.assign_seat(p_event_id uuid, p_user_id uuid, p_people int, p_receipt_id uuid, p_allow_over_capacity boolean) returns uuid` (booking id); `payments.record_refund(p_booking_id uuid, p_note text) returns void`; `chat.post_system_message(p_thread_id uuid, p_body text) returns void` (service role only).

- [ ] **Step 1: Write the tests** (names are the assertions): `pending_receipts_lists_pending_and_late_for_own_events_only`, `accept_confirms_booking_marks_receipt_accepted_and_notifies_guest`, `accept_sends_the_receipt_email_hook`, `accept_refused_for_other_host`, `accept_refused_when_event_cancelled`, `accept_twice_is_a_no_op_not_an_error`, `request_new_receipt_returns_to_held_with_fresh_hold_and_replaces_receipt`, `request_new_receipt_posts_note_in_chat_thread_and_notifies_guest`, `request_new_receipt_refused_inside_last_hour` (`bookings_closed`), `request_new_receipt_refused_for_other_host`, `assign_seat_creates_confirmed_booking_for_user_with_no_order` (amount = price × people), `assign_seat_confirms_guests_expired_booking_and_links_late_receipt`, `assign_seat_to_another_event_of_same_host`, `assign_seat_refuses_event_full_unless_over_capacity_allowed`, `assign_seat_refused_for_other_host_event_or_unknown_user`, `record_refund_cancels_and_frees_the_seat_and_keeps_note`, `record_refund_refused_for_other_host`, `post_system_message_not_callable_by_clients`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement the functions in `0116`.** Lock order as in `bookings.mark_confirmed` (event row first, then booking); `accept_receipt` calls `bookings.mark_confirmed` then `shared.send_receipt` and `identity.notify(... 'receipt_accepted' ...)`; `request_new_receipt` sets `held` with the Task 3 hold formula; thread via `chat.open_thread` logic (internal copy that takes the guest id), message through `post_system_message`.
- [ ] **Step 4: Run Step 2 command, then `tools/test_db.sh`.** Expected: green.
- [ ] **Step 5: Commit** `feat(payments): host receipt actions`.

### Task 6: Device tokens and push sender

**Files:**
- Create: `supabase/migrations/0117_identity_device_tokens.sql`, `supabase/functions/send-push/index.ts`, `handler.ts`, `index_test.ts`
- Test: `supabase/tests/identity_device_tokens.sql`

**Interfaces:**
- Produces: `identity.device_tokens(user_id, token, platform text check in ('ios','android'), updated_at, primary key (user_id, token))`; `identity.register_device_token(p_token text, p_platform text) returns void` (`authenticated`, idempotent); `shared.send_push(p_user_id uuid, p_title text, p_body text, p_ref_type text, p_ref_id uuid) returns void` (internal; queues a `pg_net` call to `send-push` using the Vault pattern of `shared.send_receipt`, never raises); Edge `send-push` handler `handle(req, deps)` where `deps.tokens(userId): Promise<string[]>` and `deps.fcm(token, title, body, data): Promise<'ok'|'gone'>`; tokens answered `gone` are deleted.

- [ ] **Step 1: Write the tests.** pgTAP: `register_stores_token_for_caller_only`, `register_twice_keeps_one_row`, `register_needs_login`, `bad_platform_refused`, `send_push_never_raises_without_vault_secrets`. Deno (`index_test.ts`): `sends_to_every_token_of_the_user`, `deletes_tokens_fcm_reports_gone`, `rejects_requests_without_the_service_key`, `fcm_failure_for_one_token_does_not_stop_the_others`.
- [ ] **Step 2: Run `supabase db reset --no-seed && supabase test db supabase/tests/identity_device_tokens.sql` and `deno test supabase/functions/send-push`.** Expected: FAIL.
- [ ] **Step 3: Implement** the migration and the function (FCM HTTP v1 with a service-account secret `FCM_SERVICE_ACCOUNT`; follow `receipt-email/handler.ts` for structure).
- [ ] **Step 4: Re-run Step 2 commands.** Expected: pass.
- [ ] **Step 5: Wire `shared.notify_host_receipt` (Task 4) to also call `shared.send_push`** with a test `submit_pushes_host_once_when_tokens_exist` (the pg_net queue row is the assertion); re-run `tools/test_db.sh`.
- [ ] **Step 6: Commit** `feat: device tokens and send-push`.

### Task 7: Reminders and receipt-file purge

**Files:**
- Create: `supabase/migrations/0118_payments_receipt_reminders.sql`, `supabase/functions/receipt-reminders/index.ts`, `handler.ts`, `index_test.ts`
- Test: `supabase/tests/payments_receipt_reminders.sql`

**Interfaces:**
- Consumes: Tasks 4 to 6.
- Produces: `payments.claim_due_reminders() returns table (receipt_id uuid, host_id uuid, booking_id uuid, kind text)` where `kind` is `push` or `chat` (service role only; atomically bumps `push_count` or sets `chat_reminded` so a row is claimed once); `payments.claim_expired_receipt_files() returns table (receipt_id uuid, image_path text)` (receipts whose event ended more than 30 days ago and whose file is not purged yet; marks them purged); pg_cron job `receipt-reminders` every minute calling the Edge function through `pg_net`; Edge `handle(req, deps)` with `deps.claim()`, `deps.push(hostId, bookingId, count)`, `deps.chat(bookingId)`, `deps.purge(paths)`.

- [ ] **Step 1: Write the tests.** pgTAP (move `uploaded_at` back to simulate time): `reminder_timeline_push_at_0_15_30_then_chat_at_45`, `nothing_claimed_after_accept`, `nothing_claimed_after_request_new_receipt`, `a_row_is_claimed_only_once`, `late_receipts_get_no_reminders`, `purge_claims_only_receipts_30_days_after_event_end_and_row_stays`, `claim_functions_not_callable_by_clients`. Deno: `pushes_then_posts_chat_in_order`, `purge_removes_files_through_the_storage_api`, `one_failing_push_does_not_block_the_rest`.
- [ ] **Step 2: Run both suites.** Expected: FAIL.
- [ ] **Step 3: Implement** the SQL (`claim_*` with `for update skip locked`), the cron registration (pattern of `0090_jobs.sql`; a no-op until the Vault secrets exist), and the handler.
- [ ] **Step 4: Re-run Step 2 commands, then `tools/test_db.sh` and `deno test supabase/functions`.** Expected: green.
- [ ] **Step 5: Commit** `feat(payments): receipt reminders and purge`.

### Task 8: Manual provider and payment mode

**Files:**
- Create: `supabase/functions/_shared/manual_provider.ts`, `supabase/functions/_shared/manual_provider_test.ts`
- Modify: `app/lib/core/config/app_config.dart`, `app/test/core/` (existing config test), `docs/release/staging.md` (document `PAYMENT_MODE`)

**Interfaces:**
- Produces: `ManualTransferProvider implements PaymentProvider` (`createSession` returns `{ sessionUrl: '', expiresAt }`, `parseWebhook` throws `not_supported`, `refund` returns `{ providerRef: 'manual:' + reference }`); `AppConfig.paymentMode` (`'manual'` default, `'gateway'`), read from the `PAYMENT_MODE` key.

- [ ] **Step 1: Write the tests.** Deno: `create_session_returns_no_url`, `webhook_is_not_supported`, `refund_returns_a_manual_reference`. Dart: `payment_mode_defaults_to_manual`, `payment_mode_gateway_is_read`, `unknown_payment_mode_throws`.
- [ ] **Step 2: Run `deno test supabase/functions/_shared` and `cd app && flutter test test/core`.** Expected: FAIL.
- [ ] **Step 3: Implement both.**
- [ ] **Step 4: Re-run Step 2 commands.** Expected: pass.
- [ ] **Step 5: Commit** `feat: manual transfer provider and payment mode`.

### Task 9: Guest pay flow (app)

**Files:**
- Create: `app/lib/features/booking/domain/pay_instructions.dart`, `app/lib/features/booking/presentation/pay_screen.dart`, `waiting_screen.dart`, `app/test/features/booking/pay_flow_test.dart`
- Modify: `app/lib/features/booking/data/booking_repository.dart`, `app/lib/features/booking/presentation/checkout_screen.dart`, `app/lib/core/router/app_router.dart`, `app/pubspec.yaml` (`image_picker`), `app/ios/Runner/Info.plist` (camera and photo usage text), `app/test/helpers/fake_bookings.dart`

**Interfaces:**
- Consumes: Tasks 4, 8 (`paymentMode` through an `appConfigProvider` or the existing config provider).
- Produces: `PayInstructions {int amountSen; String reference; String? qrUrl; String? bank, holder, number; DateTime? holdExpiresAt; String status}`; `BookingRepository.payInstructions(String bookingId)`, `uploadReceipt(String bookingId, Uint8List bytes)` (uploads to `receipts/{bookingId}/{uuid}.jpg`, then `submit_receipt`; throws `BookingError`), `ReceiptPicker` interface (`pick(ImageSource) → Uint8List?`) with a fake for tests; routes `/booking/:id/pay`, `/booking/:id/waiting`; keys `pay-amount`, `pay-reference`, `pay-qr`, `copy-account`, `hold-countdown`, `upload-receipt`, `waiting-screen`.

- [ ] **Step 1: Write `pay_flow_test.dart`:** `checkout_in_manual_mode_opens_pay_screen_not_gateway`, `checkout_in_gateway_mode_still_opens_gateway`, `pay_screen_shows_amount_reference_qr_and_bank_with_copy_buttons`, `pay_screen_hides_missing_qr_or_bank_section`, `pay_screen_counts_down_the_hold`, `upload_picks_image_submits_then_shows_waiting`, `upload_error_shows_message_and_stays`, `waiting_screen_says_waiting_for_host_with_no_countdown`, `expired_hold_shows_late_upload_option`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement** the repository methods, screens, routes and checkout switch; `image_picker` with `maxWidth: 1600, imageQuality: 80`, reject files over 5 MB after compression.
- [ ] **Step 4: Run the file, then `flutter analyze` and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): guest pay by transfer`.

### Task 10: Tickets list states, cooldown and closed booking (app)

**Files:**
- Modify: `app/lib/features/booking/presentation/tickets_screen.dart`, `ticket_card.dart`, `checkout_screen.dart`, `app/lib/features/booking/domain/booking.dart` (`BookingError` reads the `hint`), `app/lib/features/booking/data/booking_repository.dart`
- Test: `app/test/features/booking/tickets_states_test.dart`

**Interfaces:**
- Consumes: Task 9. Produces: `BookingError.cooldownSeconds` (int?) parsed from `PostgrestException.hint`; Tickets card states keyed `ticket-state-held`, `ticket-state-processing`, `ticket-state-confirmed`, `ticket-state-expired`.

- [ ] **Step 1: Write tests:** `held_card_says_pay_now_and_opens_pay_screen`, `processing_card_says_waiting_for_host`, `confirmed_card_opens_ticket`, `expired_card_offers_upload_late_and_chat_with_host`, `cooldown_error_shows_minutes_left`, `bookings_closed_shows_bookings_closed`, `held_and_expired_cards_not_shown_for_ended_events`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): ticket states for manual payment`.

### Task 11: Host pending receipts and receipt detail (app)

**Files:**
- Create: `app/lib/features/host/domain/receipt.dart`, `app/lib/features/host/presentation/pending_receipts_screen.dart`, `receipt_detail_screen.dart`, `app/test/features/host/receipts_test.dart`
- Modify: `app/lib/features/host/data/host_repository.dart`, `host_home_screen.dart`, `host_event_screen.dart`, `guest_list_screen.dart`, `app/lib/core/router/app_router.dart`, `app/test/helpers/fake_host.dart`

**Interfaces:**
- Consumes: Task 5. Produces: `PendingReceipt {String id, bookingId, eventId, eventTitle, guestName, guestUsername; int amountSen; String imagePath; bool late; DateTime uploadedAt}`; `HostRepository.pendingReceipts({String? eventId})`, `receiptImageUrl(String path)` (signed URL), `acceptReceipt(String id)`, `askNewReceipt(String bookingId, String note)`; routes `/host-mode/receipts`, `/host-mode/receipts/:id`; keys `pending-receipts-card`, `receipt-image`, `receipt-accept`, `receipt-ask`, `receipt-note`.

- [ ] **Step 1: Write tests:** `host_home_shows_pending_count_and_opens_list`, `event_page_lists_its_pending_receipts`, `late_receipts_are_marked_late`, `detail_shows_image_amount_name_and_username`, `accept_confirms_and_returns_to_list`, `ask_again_requires_a_note_and_calls_the_repository`, `ask_again_error_bookings_closed_shows_message`, `unconfirmed_guests_sit_at_top_of_checkin_list`, `list_empty_state`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement** with zoom through `InteractiveViewer`.
- [ ] **Step 4: Run the file and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): host pending receipts`.

### Task 12: Assign seat and refund by hand (app)

**Files:**
- Create: `app/lib/features/host/presentation/assign_seat_screen.dart`, `refund_sheet.dart`, `app/test/features/host/assign_refund_test.dart`
- Modify: `host_repository.dart`, `host_event_screen.dart`, `guest_list_screen.dart`, `receipt_detail_screen.dart`, `app_router.dart`, `fake_host.dart`

**Interfaces:**
- Consumes: Tasks 5, 11 and the people search (`PeopleRepository.search`). Produces: `HostRepository.assignSeat({eventId, userId, people, receiptId, allowOverCapacity})`, `recordRefund(String bookingId, String note)`; route `/host-mode/assign-seat?eventId=`; keys `assign-search`, `assign-event`, `assign-people`, `assign-over-capacity`, `assign-confirm`, `refund-note`.

- [ ] **Step 1: Write tests:** `search_results_show_name_handle_and_avatar_only`, `choose_another_event_of_the_host`, `people_is_one_or_two`, `over_capacity_switch_only_appears_when_the_event_is_full`, `full_event_without_switch_shows_event_full_message`, `late_receipt_can_be_linked`, `assign_calls_repository_with_the_chosen_values`, `refund_needs_a_note_and_calls_repository`, `refund_offered_on_confirmed_and_late_bookings_only`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): assign seat and refund by hand`.

### Task 13: Payment details form (app)

**Files:**
- Create: `app/lib/features/host/presentation/payment_details_screen.dart`, `app/test/features/host/payment_details_test.dart`
- Modify: `host_profile_screen.dart` (the "Payout account" row opens it), `apply_host_screen.dart` (optional QR upload), `host_repository.dart`, `host.dart`, `app_router.dart` (`/host-mode/payout-account` now opens the new screen), `fake_host.dart`

**Interfaces:**
- Consumes: Task 1. Produces: `HostRepository.savePaymentDetails({holder, bank, number, Uint8List? qr})` (uploads to `payment-qr/{userId}/qr.jpg`); `HostProfile.qrPath`, bank fields nullable; keys `details-qr`, `details-bank`, `details-holder`, `details-number`, `details-save`, `details-warning`.

- [ ] **Step 1: Write tests:** `either_qr_or_full_bank_enables_save`, `nothing_filled_keeps_save_disabled`, `partial_bank_without_qr_shows_what_is_missing`, `warning_says_these_are_shown_to_guests_who_book`, `saving_uploads_the_qr_then_calls_repository`, `existing_details_are_prefilled`, `apply_host_form_still_requires_bank_and_accepts_an_optional_qr`.
- [ ] **Step 2: Run the file.** Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the file and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): host payment details`.

### Task 14: Push in the app, notification labels

**Files:**
- Create: `app/lib/core/push/push_service.dart`, `app/test/core/push_service_test.dart`
- Modify: `app/pubspec.yaml` (`firebase_core`, `firebase_messaging`), `app/lib/main.dart`, `app/lib/features/host/presentation/host_home_screen.dart` (permission on first open, banner when refused), `app/lib/features/notifications/domain/notification_labels.dart`, `notification.dart`, `app/ios/Runner/Runner.entitlements` and `AppDelegate` only as the packages require, `app/test/helpers/fake_push.dart`, `app/test/features/notifications/notification_labels_test.dart`, `app/test/features/host/` (banner test)

**Interfaces:**
- Produces: `abstract class PushService {Future<PushStatus> requestPermission(); Future<String?> token(); Stream<String> tokenChanges();}` (`PushStatus {granted, denied}`), `FirebasePushService` (starts Firebase inside try/catch, returns `denied` when it cannot start), `pushServiceProvider`, `registerPushToken(ref)` (calls `identity.register_device_token`); label icons and routes for the six notification types (`receipt_submitted`, `receipt_reminder`, `late_receipt` → `/host-mode/receipts/<receipt id>` through `ref_type 'receipt'`; `receipt_accepted`, `receipt_requested` → `/booking/<id>/pay` or ticket; `seat_assigned` → ticket).

- [ ] **Step 1: Write tests:** `first_host_mode_open_asks_permission_once`, `granted_registers_the_token_and_refresh_updates_it`, `denied_shows_the_banner_reminders_only_in_app`, `firebase_start_failure_is_handled_as_denied`, `signed_out_user_registers_nothing`, `six_new_notification_types_have_icons_and_routes`.
- [ ] **Step 2: Run the files.** Expected: FAIL.
- [ ] **Step 3: Implement.** Run `flutter pub get` under the local Flutter and confirm the packages resolve (CI is 3.47.9, local 3.47.7).
- [ ] **Step 4: Run the files, `flutter analyze` and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): host push registration and notification labels`.

### Task 15: Device checks (no code)

- [ ] **Step 1: Local stack:** `supabase start`, seeded DB, `supabase functions serve --no-verify-jwt --env-file <scratchpad file>`, local Vault secrets not set (push stays queued-off). A second local user stands in as the host through SQL for the cross-account steps.
- [ ] **Step 2: iOS simulator with the mobile MCP** (iPhone 17 Pro `3A69CF5F-EE4E-4E2E-8D38-202255D0402F`; no BACKSPACE, clear fields with the Simulator tool's `press_key delete`): host saves payment details (QR + bank); guest books a paid event, sees pay screen with the host's details and a 1-hour countdown, uploads a receipt from the gallery, sees Waiting for host; host sees it in Pending receipts, opens the image, asks to upload again (guest chat shows the note, fresh hold), guest uploads again, host accepts, guest gets the ticket; an expired hold shows late upload; cooldown message; assign seat by search; refund by hand. Expected: every step works, no overflow or error screens.
- [ ] **Step 3: Android emulator only if Step 2 is clean** (`Pixel_10_Pro`, scratchpad env with `10.0.2.2`; screenshots lag, re-take before judging): repeat the same walk, camera picker included.
- [ ] **Step 4: Report** the feature list with status for database tests, Flutter tests, iOS, Android and push. Push delivery is "not tested on a device" (simulators cannot receive it; needs an Apple Developer account, an APNs key in Firebase and a real iPhone). Nothing pushed, no PR.
