# Host registration, approval and the host-entrance flag: design (app task 6)

Nov 14, 2026 · Status: written from decisions in `docs/decisions/2026-11-10-fiuu-and-pending.md`; waiting for the owner to read it. No code written.

## Goal

One app for guests and hosts. A user registers as an Event owner from Settings (Profile). After a platform admin approves them, Profile shows the entry to Host mode. A feature flag controls whether the host entrance appears in this app at all, so the host side can be split into a second app later.

## Decided (from the owner)

- One app for now.
- Settings shows "Register as Event owner". After approval it shows the entry to the host view instead; until then only the register button (or the pending state).
- Admins approve hosts. Several admins are allowed, with the same rights. The admin role is given by hand in the database. Every approval, rejection and suspension records which admin did it and when.
- Until the web admin exists, you approve hosts by hand in the Supabase dashboard.

## Defaults I chose

- Host states: `pending`, `approved`, `rejected`, `suspended`. A rejected user sees the reason and may apply again; a suspended host sees "Your host access is paused. Contact support" and keeps their guest account.
- Existing hosts are marked `approved` by the migration so nothing breaks.
- A suspended or rejected host cannot create, edit or publish events; their published events stay visible unless the admin hides them (a later task).
- The flag is a single key `host_entry_enabled` (default true) read at app start and on resume.

## Database (identity module)

- `identity.hosts` gets `status text not null default 'pending' check (status in ('pending','approved','rejected','suspended'))`, `reviewed_by uuid`, `reviewed_at timestamptz`, `reject_reason text`. `verified_at` stays as the "verified" badge.
- `identity.apply_host(...)` now creates or updates the host row with status `pending` and does **not** set `profiles.is_host`. Applying again after a rejection sets it back to `pending`.
- `profiles.is_host` becomes true only on approval and false on suspension. `identity.is_host(user)` keeps meaning "approved host", so `events.save_draft`, `events.publish` and friends need no change.
- `identity.my_host_status()` returns `none | pending | approved | rejected | suspended` with the reason.
- `identity.admins(user_id primary key, created_at)`; `identity.is_admin()`; rows are inserted by hand only (no function can insert).
- `identity.admin_actions(id, admin_id, action, target_user_id, reason, created_at)`: append-only (no update or delete grants).
- `identity.admin_review_host(p_user_id, p_decision, p_reason)` (`approve | reject | suspend | unsuspend`): admin only; updates status and `is_host`; writes `admin_actions`; notifies the host (`host_approved`, `host_rejected`, `host_suspended`).
- `identity.pending_hosts()` and `identity.host_application(p_user_id)`: admin only; return the application (name, area, bio, payout and payment details, SSM number).
- `app.flags` table (`key`, `value`) and `app.get_flags()` readable by anon and authenticated; written by hand.
- Hand approval until the web admin exists, kept in `docs/release/staging.md`: a short SQL snippet that inserts the first admin and calls `identity.admin_review_host` as that admin.

## App (Flutter)

- Profile card state machine (replaces the always-on "Switch to Host mode" card):
  - `none`: **Register as Event owner** opens `apply_host_screen` (host name, area, bio, SSM optional, payout account, DuitNow QR and bank details for guests to pay).
  - `pending`: "Application under review" (no button).
  - `approved`: **Switch to Host mode** (existing behaviour).
  - `rejected`: the reason and **Apply again**.
  - `suspended`: the paused message.
- With `host_entry_enabled = false` the whole card and the Host mode switch are hidden; approved hosts keep working on the web (later) and existing deep links to host routes redirect to Home.
- Host mode routes are guarded: `/host-mode/*` redirects unless the status is `approved`.
- Notifications labels for `host_approved`, `host_rejected`, `host_suspended`.

## Tests (written first)

pgTAP: apply creates `pending` and does not make a host; `is_host` false until approval; approve, reject, suspend and unsuspend change `is_host` correctly; non-admin calls fail; admin actions are logged with who and when and cannot be edited or deleted; a rejected user can apply again; existing hosts become `approved`; flags are readable by anon.
Flutter: Profile card for each of the five states; the Host mode switch hidden when the flag is off; route guard; apply form validation; notification labels.
Device checks: iOS first, then Android.

## Out of scope

The web admin screens (see that spec); hiding a suspended host's published events; host profile editing beyond what exists.
