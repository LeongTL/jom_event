# Quality, safety and release: design (app tasks 8 and 9)

Nov 14, 2026 · Status: written from decisions and findings in this session; waiting for the owner to read it. No code written.

## Goal

Make the MVP safe and ready for a closed beta: fix the broken pipeline step, add report and block, load test, check on real devices, and prepare the store release.

## 1. Pipeline fixes

- **Flutter is pinned** to 3.47.9 in `ci.yml` and `e2e.yml` (done). Moving to 3.50 needs the 95 `package:flutter/material.dart` imports migrated first (the new Flutter deprecates them); that is a separate later task.
- **`deploy-staging` fails** (runs #25 and #27, 3 Nov): the log says `Target: local stack (127.0.0.1:54422) ... pass --remote for jom-stg`, so a newer Supabase CLI now defaults to the local stack. Fix: pin `supabase/setup-cli` to a fixed version in `deploy-staging.yml` and `ci.yml` instead of `latest`, and pass the remote flag the CLI names on `db push`. First reproduce by running the failing step, then confirm with a manual `workflow_dispatch`.
- Keep `.github/workflows` untouched by feature work; pipeline changes get their own commit.

## 2. Report and block

Decided defaults: report and block are included because chat and people search exist.

Database (`identity` module):
- `identity.blocks(blocker_id, blocked_id, created_at)` primary key on the pair; `identity.reports(id, reporter_id, target_type check in ('user','event','message'), target_id, reason check in ('spam','harassment','scam','fake_event','other'), note, status default 'open', created_at)`.
- `identity.block_user(p_user_id)` (also removes follows in both directions), `identity.unblock_user(p_user_id)`, `identity.report(p_target_type, p_target_id, p_reason, p_note)`; `identity.my_blocks()`.
- Effects of a block: the two cannot see each other in `identity.search_people`, cannot follow each other, and `chat.send_message` between them is refused with `blocked`; an existing thread is hidden from the blocker.
- Reports are readable only by admins (the web admin lists them later).

App:
- A **Report / Block** menu on the person page, the chat header and the event page (report only for events).
- A **Blocked users** list in Profile with Unblock.
- Reports show a thank-you message; nothing is shown to the reported person.

## 3. Load and scale

- Raise the k6 scripts: `last_seat` to 1000 users, `feed` to 500 to 1000, add a `search_people` and a `submit_receipt` script. Thresholds stay (p95 under 400 ms for reads).
- Run against staging; add indexes where a threshold fails (candidates: `bookings(event_id, status)`, `events(status, starts_at, visibility)`, `identity.profiles(lower(username))`, `identity.follows(followee_id)`, `payments.receipts(booking_id, status)`).
- Check the database connection pool and plan size before the run; record the result in `docs/release/`.

## 4. Real-device checks (iOS first, then Android)

Low-end Android: Home scrolling with the film grain on, dock scrolling. Real QR scan of a ticket shown on a second phone. Camera and gallery picker for receipts. Push delivery to a host (iOS needs a real device and an APNs key). Deep links from WhatsApp. Each check is written as a command or a screenshot in the release checklist.

## 5. Accounts and release

- **Decide the app name and bundle id** (`com.jom.jom` today). It affects the OAuth clients and the store pages.
- Google sign-in: create the iOS and Android OAuth clients (listed in `docs/release/staging.md`).
- Real SMS provider for phone sign-in (staging only accepts `+60123456789`).
- Apple Developer account, Google Play account, a Firebase project for push (APNs key uploaded), the share domain, Cloudflare.
- Privacy page: describe usernames, following, receipts (private bucket, deleted 30 days after the event) and push tokens. Terms page: add that payments are between guest and host and the platform holds no money. Have someone who knows Malaysian PDPA read both.
- Onboard the 20 seed hosts by hand (verify the account holder name against the host name, then approve), then build and ship with `release.yml` to TestFlight and Play internal testing.
- Security audit with the Cloudflare skill, started only when the owner says so, after the features exist.

## Tests

Pipeline: both workflows green on a pushed branch; a manual `deploy-staging` run passes the smoke test.
pgTAP: block hides search results, removes follows, refuses chat; report accepts only valid targets and reasons; reports readable by admins only; blocks are one-way visible to the blocker only.
Flutter: Report / Block menu, Blocked users list, a blocked person missing from search.
k6: the four thresholds on staging.

## Out of scope

Automatic moderation, the Flutter 3.50 migration, a real payment gateway.
