# Manual-transfer payment: design (app task 3)

Nov 14, 2026 · Status: written from decisions recorded in `docs/decisions/2026-11-10-fiuu-and-pending.md`; waiting for the owner to read it before the implementation plan. No code written.

## Goal

Paid events work without a payment gateway. The guest holds a seat, pays the host directly by bank transfer or DuitNow QR, uploads the receipt, and the host confirms it. The platform holds no money and takes no commission in the MVP. The gateway (Fiuu) comes back later behind the same `PaymentProvider` interface (`supabase/functions/_shared/payment_provider.ts`).

## Decided (from the owner)

- Host shows a DuitNow QR image and bank details; at least one is required.
- Hold is **1 hour**. It stops running while a receipt waits for the host. No receipt in 1 hour releases the seat.
- A receipt uploaded after the hour does not hold the seat. The guest can still upload it; the host sees a "late receipt", may assign a seat by hand, and if the event is full decides whether to go over capacity or refund by hand.
- Wrong amount or any problem: the host does not accept; "Ask to upload again" gives the guest a fresh 1-hour hold and posts the message in chat.
- Host reminders: push when the receipt is uploaded, then pushes at 15 and 30 minutes. If still undecided, the system posts a message in the host's chat thread, which also sends a push. The old 24-hour message to the guest is dropped.
- Same guest cannot book the same event again for 30 minutes after a hold of theirs expired without a receipt.
- Bookings close 1 hour before the event starts. Hold = the shorter of 1 hour and "time to start minus 30 minutes", never below 15 minutes.
- The host can assign a seat to any registered user found by searching name or @username, for this event or another of the host's events, with no order needed. Over capacity is the host's choice.
- Refunds are done by the host outside the app; the app records them.
- Host gets a push when a receipt is uploaded (reverses the earlier "no push in the MVP").

## Defaults I chose (change if wrong)

- The chat message after the three pushes is posted 15 minutes after the third push (45 minutes after upload).
- Receipts are images (JPEG or PNG, up to 5 MB, compressed on the phone) in a private storage bucket, kept 30 days after the event ends, then deleted by a job. A receipt row stays; only the file goes.
- A guest can upload more than one receipt per booking; the newest pending one is the one shown to the host.
- The host cannot reject a receipt outright; the only negative action is "Ask to upload again". A guest who never fixes it loses the seat at the end of the new hour.
- The reference code the guest puts on the transfer is the existing `ticket_code`.
- Payment mode is a flavor setting `PAYMENT_MODE` = `manual` (MVP) or `gateway` (later). The mock gateway screens stay for `gateway` mode and tests.

## Booking states

Existing statuses are reused; no new status is needed.

| Status | Meaning in manual mode | `hold_expires_at` |
|---|---|---|
| `held` | Guest picked a seat, has not uploaded (or the host asked for a new receipt) | now + hold |
| `processing` | A receipt is waiting for the host | null (no expiry) |
| `confirmed` | Host accepted, or assigned the seat | null |
| `expired` | Hold ran out with no receipt | past |
| `cancelled` | Guest cancelled, or host refunded by hand | n/a |

A late receipt is a receipt row attached to an `expired` booking. Accepting it through "Assign seat" turns that booking `confirmed` (or creates a new booking when none exists).

## Database

Migrations (numbers follow `0111`):

- `0112_identity_payment_details.sql`: add `duitnow_qr_path text` to `identity.host_payout_accounts`; make `bank`, `account_holder`, `account_number` nullable with a check that either the QR path or all three bank fields exist. The columns stay readable only by the host and admins; guests get them through the function below.
- `0113_bookings_manual_hold.sql`: change `bookings.create_booking`: refuse free events (see the event-visibility spec), refuse when `now() > starts_at - 1 hour` (`bookings_closed`), refuse during a cooldown (`cooldown_active`, returns the time left), set `hold_expires_at = now() + least(1 hour, starts_at - 30 minutes - now())` and never below 15 minutes. `bookings.expire_holds` is unchanged (it already skips rows with a null hold).
- `0114_payments_receipts.sql`: table `payments.receipts(id, booking_id, image_path, status check in ('pending','accepted','replaced','late'), note, uploaded_at, decided_by, decided_at, push_count int default 0, chat_reminded boolean default false)`; private storage bucket `receipts` with policies: the booking's attendee may insert under `{booking_id}/`, the attendee and the event's host may read. RLS: attendee reads own rows; host reads rows of their events through functions only.
- `0115_payments_manual_actions.sql` functions, all `security definer` with pinned `search_path`:
  - `payments.pay_instructions(p_booking_id)`: for the booking's attendee in `held`, `processing` or `expired`; returns amount, `ticket_code` as reference, host QR path and bank details. Never returns anything for other callers.
  - `payments.submit_receipt(p_booking_id, p_image_path)`: attendee only. `held` becomes `processing` (hold cleared). `expired` stores the receipt as `late`. Already `processing` marks the older pending receipt `replaced`. Notifies the host (in-app and push) and starts the reminder clock.
  - `payments.accept_receipt(p_receipt_id)`: host of the event only. `processing` becomes `confirmed`; receipt `accepted`; notifies the guest; the existing receipt email still goes out.
  - `payments.request_new_receipt(p_booking_id, p_note)`: host only. `processing` returns to `held` with a fresh hold (same cap rules; refused with `bookings_closed` once the event is less than an hour away); older receipt `replaced`; posts the note in the guest's chat thread; notifies the guest.
  - `payments.assign_seat(p_event_id, p_user_id, p_people, p_receipt_id, p_allow_over_capacity)`: host of that event only; target user is any registered user; refuses `event_full` unless `p_allow_over_capacity`; creates a `confirmed` booking (or confirms the guest's expired one); `amount_sen = price * people`; links a late receipt if given; notifies the guest.
  - `payments.record_refund(p_booking_id, p_note)`: host only. Booking `cancelled`, seat freed, note kept. No money moves in the app.
  - `payments.pending_receipts(p_event_id default null)`: host only; pending and late receipts with guest name, @username, expected amount, image path.
- `0116_identity_device_tokens.sql`: `identity.device_tokens(user_id, token, platform, updated_at)`, `identity.register_device_token(p_token, p_platform)`.
- `0117_payments_receipt_reminders.sql`: scheduled job (pattern of `0090_jobs.sql`, every minute) calls the Edge function `receipt-reminders`.
- Chat: add `chat.post_system_message(p_thread_id, p_body)` (service role only) so the system can write in the host's thread; the existing `chat.send_message` contact filter stays for people.
- Receipt purge job: deletes storage files 30 days after the event's end.

## Edge functions

- `send-push`: sends a push to every token of a user (FCM HTTP v1; iOS goes through APNs configured in Firebase). Called by the database functions through `pg_net` and by `receipt-reminders`.
- `receipt-reminders`: for each pending receipt: push at upload (`push_count` 1), push at +15 min (2), push at +30 min (3), then a system chat message at +45 min (which also sends a push). Stops once the receipt is decided.
- Provider: a `ManualTransferProvider` implements `PaymentProvider` for `createSession` (returns no URL, only the instructions), `parseWebhook` (not used) and `refund` (records a refund due). `payment-webhook` stays for `gateway` mode.

## App (Flutter)

Guest, `features/booking`:
- Checkout creates the held booking, then opens **Pay by transfer**: amount, reference code (`ticket_code`), QR image, bank name, holder and account number with copy buttons, and a countdown.
- **Upload receipt**: pick from gallery or camera (`image_picker`), compress, upload, then the **Waiting for host** screen ("Waiting for host to confirm", no countdown).
- Tickets list shows: Pay now (held), Waiting for host (processing), Ticket (confirmed), Expired with "Upload receipt late" and "Chat with host".
- A booking inside a cooldown shows when the guest can try again; a closed event shows "Bookings closed".
- The `gateway_screen`, `processing_screen` and `failed_screen` stay for `gateway` mode only.

Host, `features/host`:
- **Pending receipts** list on Host Home and on the event page; at the top of the check-in list for unconfirmed guests.
- **Receipt detail**: image (zoom), expected amount, guest name and @username, buttons **Accept** and **Ask to upload again** (note box).
- **Assign seat**: search people, pick one of the host's events, people (1 or 2), "Allow over capacity" shown only when full, optional late receipt.
- **Refund by hand** on a confirmed or late booking, with a note.
- Payment details form (in Host Profile and in `apply_host_screen`): upload QR, bank, holder, number, with a warning "These are shown to guests who book your events".
- Push permission is requested the first time the host opens Host mode; if refused, a banner says reminders will only show inside the app.

Notification types added to `notification_labels.dart`: `receipt_submitted`, `receipt_reminder`, `receipt_accepted`, `receipt_requested`, `seat_assigned`, `late_receipt`.

## Tests (written first)

pgTAP: hold length with a far and a near event; closed 1 hour before start; cooldown blocks 30 minutes and then allows; `submit_receipt` states for held, processing and expired; non-owner cannot submit or read; `accept_receipt` host-only and confirms; `request_new_receipt` gives a fresh hold and refuses near the start; `assign_seat` with and without capacity, to another event, for a user with no booking; `record_refund` frees the seat; `pay_instructions` returns data only to the booking's attendee; receipts bucket policies; refund and expiry job unchanged for gateway mode.
Deno: `send-push` and `receipt-reminders` timeline (push at 0, 15, 30, chat at 45, nothing after a decision).
Flutter: pay screen, upload flow, waiting screen, tickets list states, host pending list, receipt detail actions, assign seat with over-capacity switch, payment details validation, notification labels.
Device checks (iOS first, then Android): camera and gallery picker, QR image display, push delivery. Push on iOS needs a real device, an Apple Developer account and an APNs key in Firebase; the simulator cannot receive it.

## Out of scope

The gateway integration; commission and payouts; chat redesign; web back office screens (see that spec).

## Risks to test

A fake receipt (the host checks their own bank, not the image); a host who never answers (reminders only, no auto-cancel); two guests racing for the last seat (existing row lock still applies); a guest uploading after the event started; receipts containing personal data (private bucket, 30-day purge).
