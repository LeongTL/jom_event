# Web back office (host and admin): design (task 10, after the app)

Nov 14, 2026 · Status: written from decisions in `docs/decisions/2026-11-10-fiuu-and-pending.md`; waiting for the owner to read it. No code written. Visual reference: `docs/superpowers/design/jom-backoffice-hifi.html` (hi-fi, clickable). It is older than the decisions below, see "Changes to the reference".

## Goal

A website where an approved host can run their events (see guests, confirm payments, create and edit events) and where platform admins approve and manage hosts. It reuses the Flutter app's code, design and Supabase backend.

## Decided (from the owner)

- Built with **Flutter web**, for easy maintenance.
- Host side: events (create and edit), guests, pending payments (confirm receipts), reviews, host profile.
- Admin side: approvals, host list with suspend, and a platform-wide overview of events and bookings.
- Several admins, same rights, role given by hand in the database. Every approval, rejection and suspension is logged with who and when.
- Two-factor sign-in is required for every admin. After signing in, the session lasts a fixed 1 week for hosts and admins, then they sign in again with two-factor (admins).
- No commission in the MVP, so no platform-fee or payout screens.

## Defaults I chose

- Same Flutter project, a second entry point `app/lib/main_web.dart` that mounts only the back-office routes and shares the data layer, models, theme and widgets with the app.
- Host sign-in on the web uses the same methods as the app (Google or phone code). Admin sign-in is email and password plus an authenticator-app code (Supabase MFA, TOTP).
- Hosted as a static site (Cloudflare Pages) at `admin.<domain>`; the share domain and the back office are separate sites.
- Roles decide the shell after sign-in: admin (`identity.is_admin()`) sees the admin shell, an approved host sees the host shell, everyone else sees "Not authorised". A person who is both sees a switch.
- Layout is a left navigation on desktop and tablet, and a top bar with a menu on a phone.
- Session length is set in Supabase as a fixed time limit of 7 days. Supabase may require a paid plan for this setting; check before building. Suggested, not required: ask for the second factor again before approving or suspending a host when the sign-in is older than one day.

## Host side

| Page | Content |
|---|---|
| **Overview** | Bookings this week, bookings and saves trend, next event with fill bar, "Needs attention" (pending receipts, late receipts, unread messages count, events that ended and are not completed), recent bookings. |
| **Events** | List by Draft, Published, Ended and Cancelled; visibility (Public or Private) tag; filled or saves count; create, edit and delete through the same functions as the app (`events.save_draft`, `publish`, `update_event`, `delete_event`) with the same lock rules. |
| **Event detail** | Tabs: Guests (with receipt and payment status, check-in), Details, Visibility and share (switch, link, QR download), Earnings (gross collected, informational, no fees). Completion and delete actions. |
| **Pending payments** | Pending and late receipts across all events: image viewer, expected amount, guest name and @username; **Accept**, **Ask to upload again**, **Assign seat**, **Refund by hand** (all from the manual-payment spec). |
| **Guests** | All guests across events; export CSV. |
| **Reviews** | Reviews and rating summary (read-only). |
| **Host profile** | Public profile, payment details (DuitNow QR and bank), edit. |

## Admin side

| Page | Content |
|---|---|
| **Applications** | Pending host applications with the full application; **Approve** or **Reject** with a reason (calls `identity.admin_review_host`). |
| **Hosts** | All hosts with status, events count, rating; **Suspend** and **Unsuspend** with a reason. |
| **Overview** | Platform counts (events, bookings, new users) and recent activity; read-only, never edits a booking. |
| **Reports** | Reports from users (from the quality spec) with their status. |
| **Activity log** | The `identity.admin_actions` list: who did what and when. |

Admin pages call only functions that check `identity.is_admin()`; they live in their own routes and files, apart from the host pages, so a host can never reach them. No admin page shows a guest's phone number; a host's payout details are visible in an application only.

## Changes to the reference design

The hi-fi file shows features that the decisions changed: remove the **Payouts** page and the **Platform fee this month** card (no commission); add the **Pending payments** page and the admin side; the event form is editable (the reference shows "Edit in app" buttons); the **Earnings** tab shows gross only.

## Tests (written first)

pgTAP: every admin function refuses a non-admin; host functions refuse a suspended or pending host; `admin_actions` is append-only.
Flutter (widget): role routing to the right shell, host and admin navigation, the Pending payments actions, event form create and edit with the lock rules, Applications approve and reject, Hosts suspend, "Not authorised" for others; responsive layout at desktop and phone widths.
Build: `flutter build web` passes in CI; one browser smoke test with Playwright (sign in with a test host, open Overview).
Security: the security audit (Cloudflare skill) covers this surface after it exists.

## Out of scope

Payouts and commission; a Gateway reconciliation view; hiding a suspended host's published events (a later admin action); a mobile admin app.
