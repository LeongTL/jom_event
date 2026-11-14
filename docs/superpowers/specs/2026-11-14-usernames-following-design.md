# Usernames and following: design

Nov 14, 2026 · Status: design approved in chat on 14 Nov; this file is waiting for the owner to read it before the implementation plan is written. No code has been written.

Context: `docs/decisions/2026-11-10-fiuu-and-pending.md` (section "Usernames and following") and the MVP design `2026-10-14-jom-mvp-design.md`. This covers app tasks 1 and 2 together.

## Goal

Every guest and host has a unique @username shown under their name. People find each other by searching, and can follow guests and hosts to get closer to each other (交流). The host's later "assign a seat by hand" feature reuses the same search.

## Decided (from the owner)

- Username is shown under the name, for example `@feederfeedz`.
- It can be changed at any time, as long as no one else has it.
- Search by name or @username. There is no separate numeric ID: the username is the ID.
- "Connect" means following a guest or host. It is not direct messaging.
- Report and block are a later task (app task 8), not in this slice.

## Rules I chose (defaults, can be changed)

- Format: 3 to 20 characters, letters, digits, `_` and `.`; stored lowercase; cannot start or end with `.`; no two `.` in a row.
- Reserved words are refused: `admin`, `jom`, `support`, `help`, `official`, `host`, `staff`, `moderator`, `system`.
- A username that looks like a phone number or contact detail is refused (reuse `shared.contains_contact_info`).
- Existing users and new sign-ups get an automatic username (their name, lowercased and cleaned, plus 4 digits) so nobody is without one. They can change it afterwards.
- A freed username can be taken by anyone straight away (no holding period).
- Following needs sign-in. A follow notifies the person followed, in the app only.

## Database (identity module)

Migrations `0110_identity_usernames.sql` and `0111_identity_follows.sql`. Clients read their own rows only; every write goes through functions, as the rest of the module does.

- `identity.profiles.username text` with a unique index on `lower(username)`; a check constraint for the format.
- A backfill gives every existing profile an automatic username; the sign-up trigger does the same for new users.
- `identity.set_username(p_username text) returns text`: normalises, validates the format, reserved words and contact filter, refuses a name that someone else has, saves, and returns the saved username. Errors are specific: `username_invalid`, `username_reserved`, `username_taken`.
- `identity.username_available(p_username text) returns boolean`: for the live check on the edit screen.
- `identity.search_people(p_query text, p_limit int default 20) returns table(user_id, name, username, avatar_url, is_host)`: signed-in users only; query at least 2 characters; matches the start of the username or the start of a word in the name; never returns phone, email or any other column; excludes the caller. `avatar_url` comes from `identity.hosts` and is empty for guests.
- `identity.follows(follower_id, followee_id, created_at)`, primary key on the pair, `check (follower_id <> followee_id)`, both reference `identity.profiles` with `on delete cascade`.
- `identity.follow(p_user_id uuid)` and `identity.unfollow(p_user_id uuid)`: idempotent; `follow` writes a notification for the person followed through the existing `identity.notify`.
- `identity.follow_counts(p_user_id uuid) returns (followers int, following int, i_follow boolean)`.
- `identity.list_followers(p_user_id, p_limit, p_offset)` and `identity.list_following(...)`: return name, username, avatar_url, is_host.
- Security: functions that read other people's rows are `security definer` with `search_path` pinned; execute is granted to `authenticated` only (the public host profile function is the only signed-out read and returns the username, never other personal data).

## App (Flutter, `app/lib/features/profile` and `features/reviews`)

- **Profile:** the @username under the name, and an "Edit username" row opening a screen with one field, a live availability message, and Save. Errors use the specific messages above.
- **Host public page:** the @username under the host name, a Follow / Following button, and follower and following counts that open the lists.
- **Find people:** a search screen opened from Profile; results show a letter circle or the host avatar, name and @username; tapping a result opens that person (host public page for hosts; a small profile page with Follow for guests).
- **Followers / Following lists:** from the counts.
- **Signed out:** Follow opens the existing sign-in sheet with the line "Sign in to follow".
- **Notifications:** "X started following you" appears in the existing Notifications list; the label function in `features/notifications/domain/notification_labels.dart` gets the new type.

## Out of scope here

Report and block; direct messages between users; the in-app chat filter change (needed only once usernames appear in chat); the web back office; the host "assign a seat by hand" screen itself.

## Tests (written first)

pgTAP (`supabase/tests`):
- username format: too short, too long, bad characters, leading or trailing `.`, `..`
- reserved words refused; phone-like names refused
- uniqueness is case-insensitive; changing frees the old name at once
- a taken name gives `username_taken`
- every profile has a username after backfill and after sign-up
- `search_people` needs 2 characters, caps results, excludes the caller, returns no phone or email, works for guests and hosts
- follow is idempotent; no self-follow; unfollow removes; counts are right; `i_follow` is right
- a follow writes one notification
- a signed-out caller cannot call the search or follow functions
- deleting a user removes their follows

Flutter (`app/test`):
- repository and fake client for username, search and follow
- Edit username screen: live availability, each error message, Save disabled while invalid
- Profile shows the @username; Host public page shows it with the Follow button, toggles, and updates counts
- signed-out Follow opens the sign-in sheet
- Notifications label for a new follower

Device checks (not run in this design): iOS first, then Android, by the owner or a local session on their Mac.
