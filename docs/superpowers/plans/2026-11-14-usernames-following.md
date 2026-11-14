# Usernames and Following Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every user gets a unique, changeable @username; people can search each other and follow guests and hosts.

**Architecture:** Two new migrations in the `identity` module (all writes through `security definer` functions, clients read their own rows only) and a new `features/people` Flutter feature, plus small edits to Profile, Host public page, Notifications and the sign-in sheet. Follows the codebase pattern: abstract repository + `Supabase...` implementation + test fake wired in `pump_app.dart`.

**Tech Stack:** Postgres/Supabase (pgTAP), Flutter 3.47.9 (CI pin, do not touch `.github/workflows`), Riverpod, go_router.

**Spec:** `docs/superpowers/specs/2026-11-14-usernames-following-design.md` (context: `docs/decisions/2026-11-10-fiuu-and-pending.md`, section "Usernames and following").

## Global Constraints

- Username: 3 to 20 characters, letters, digits, `_` and `.`; stored lowercase; no leading or trailing `.`; no `..`.
- Reserved: `admin`, `jom`, `support`, `help`, `official`, `host`, `staff`, `moderator`, `system`.
- Contact-like names refused through `shared.contains_contact_info`.
- Auto username = name lowercased, cleaned, plus 4 digits; a freed name is free at once.
- Errors raised by the database: `username_invalid`, `username_reserved`, `username_taken`.
- Search: signed-in only, query at least 2 characters, default limit 20, excludes the caller, returns no phone or email.
- Follow: signed-in only, idempotent, no self-follow, notifies the person followed in the app only (type `follow`).
- Out of scope: report/block, direct messages, chat filter change, web back office, host assign-seat screen.
- Do not push, do not open a PR. Commit with `git -c user.name=Leong -c user.email=leong@Leongs-MacBook-Air.local commit ...` (no git identity on this Mac).
- DB checks: `supabase db reset --no-seed` then `supabase test db <file>`; full run `tools/test_db.sh`. Flutter checks run from `app/`.

## Review Focus

- Input `"  Mei_Tan "` or `"MEI_TAN"`: trimmed and lowercased before every check; saving your own current name again succeeds (not `username_taken`).
- Search text containing `%` or `_`: matched literally, never as a wildcard that returns everyone.
- An erased account (`Deleted user`): no username, not searchable, its follows removed.
- Double tap on Follow (or following twice): one follow row, one notification.
- Unfollowing someone you do not follow: no error, counts unchanged.

---

### Task 1: Usernames in the database

**Files:**
- Create: `supabase/migrations/0110_identity_usernames.sql`
- Test: `supabase/tests/identity_usernames.sql`

**Interfaces:**
- Produces: `identity.profiles.username text` (nullable, unique on `lower(username)`); `identity.set_username(p_username text) returns text`; `identity.username_available(p_username text) returns boolean`; `identity.search_people(p_query text, p_limit int default 20) returns table(user_id uuid, name text, username text, avatar_url text, is_host boolean)`; `identity.on_signup()` now also assigns the username.

- [ ] **Step 1: Write `identity_usernames.sql` (pgTAP, `begin; select plan(N); ... rollback;`, users inserted into `auth.users` like `identity_notifications.sql`).** Tests, each named:
  - `username_too_short_is_invalid` (`'ab'`), `username_too_long_is_invalid` (21 chars), `username_bad_characters_invalid` (`'a b'`, `'a-b'`), `username_leading_dot_invalid`, `username_trailing_dot_invalid`, `username_double_dot_invalid`: `throws_ok(..., 'username_invalid')`.
  - `reserved_words_refused`: `'admin'` and `'Admin'` → `username_reserved`.
  - `phone_like_username_refused`: `'0123456789'` → `username_invalid`.
  - `set_username_normalises`: `set_username('  Mei_Tan ')` returns `'mei_tan'` and the profile row holds it.
  - `uniqueness_is_case_insensitive`: second user setting `'MEI_TAN'` → `username_taken`.
  - `own_name_again_is_not_taken`: same user sets `'mei_tan'` twice, no error.
  - `changing_frees_old_name`: after user A changes to `'mei2'`, user B can take `'mei_tan'`.
  - `username_available_true_false`: free name true, taken name false, invalid name false.
  - `signup_assigns_username`: a new `auth.users` row with name `'Mei Tan'` gets `username ~ '^meitan[0-9]{4}$'`; `backfill_leaves_no_null` checks `count(*) filter (where username is null)` is 0 for profiles that are not erased.
  - `search_needs_two_chars` (`'a'` → zero rows), `search_matches_username_prefix_and_name_word`, `search_excludes_caller`, `search_caps_results` (`p_limit => 2` with 3 matches → 2), `search_returns_only_safe_columns` (`array(select attname from pg_attribute ...)` is not needed: assert result column list equals the five declared via `function_returns` or by selecting `to_jsonb(r)` keys), `search_treats_percent_literally` (`'%%'` → 0 rows), `search_works_for_hosts_and_guests` (host row uses `host_name` and `avatar_url`, guest has null avatar), `search_skips_users_without_username`.
  - `search_needs_login`: as `anon`, `throws_ok(..., '42501')`; and `signed-out set_username` → `28000` `login_required`.
- [ ] **Step 2: Run `supabase db reset --no-seed && supabase test db supabase/tests/identity_usernames.sql`.** Expected: FAIL, column/function missing.
- [ ] **Step 3: Write the migration.**
  - `alter table identity.profiles add column username text; create unique index profiles_username_key on identity.profiles (lower(username));` plus a check constraint `username ~ '^[a-z0-9_]([a-z0-9_.]{1,18})[a-z0-9_]$' and username !~ '\.\.'`.
  - Internal `identity.auto_username(p_name text) returns text` (security definer, not granted): lowercase, strip everything not `[a-z0-9_]`, fall back to `'user'` when empty, cut to 16 characters, append 4 random digits, retry while taken.
  - Backfill: `update identity.profiles set username = identity.auto_username(name) where username is null and name is distinct from 'Deleted user'`.
  - `create or replace function identity.on_signup()` (same body as `0011`) plus the username from `auto_username`.
  - `set_username`: login check (`28000`/`login_required`), `btrim`+`lower`, format and `..` check → `username_invalid`, reserved list → `username_reserved`, `shared.contains_contact_info` → `username_invalid`, other holder (`lower(username) = x and user_id <> auth.uid()`) → `username_taken`, update, return saved. Catch `unique_violation` from a race and raise `username_taken`.
  - `username_available`: same validations without raising; returns false for invalid, reserved, or taken by someone else; true for your own current name.
  - `search_people`: login required; `length(btrim(p_query)) >= 2`; escape `\ % _` in the query and use `like ... escape '\'`; match `username like q || '%'` or `lower(display) like q || '%'` or `lower(display) like '% ' || q || '%'`; `display = coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest')`; exclude caller and null usernames; `order by username`; `limit least(p_limit, 50)`.
  - All new functions: `security definer set search_path = ''`, `revoke all ... from public`, `grant execute ... to authenticated` (`auto_username` none).
- [ ] **Step 4: Re-run the Step 2 command.** Expected: all pass.
- [ ] **Step 5: Commit** `feat(identity): usernames`.

### Task 2: Follows in the database

**Files:**
- Create: `supabase/migrations/0111_identity_follows.sql`
- Test: `supabase/tests/identity_follows.sql`

**Interfaces:**
- Consumes: Task 1 (`username`, `identity.notify`).
- Produces: table `identity.follows(follower_id, followee_id, created_at)`; `identity.follow(p_user_id uuid) returns void`; `identity.unfollow(p_user_id uuid) returns void`; `identity.follow_counts(p_user_id uuid) returns table(followers int, following int, i_follow boolean)` (anon and authenticated; `i_follow` false when signed out); `identity.list_followers(p_user_id uuid, p_limit int default 20, p_offset int default 0)` and `identity.list_following(...)` returning `(user_id, name, username, avatar_url, is_host)` (authenticated); `identity.person(p_user_id uuid) returns table(user_id, name, username, avatar_url, is_host)` (anon only gets hosts); `identity.erase_user` also removes the user's follows and nulls their username.

- [ ] **Step 1: Write `identity_follows.sql` tests:** `follow_creates_row_and_one_notification` (type `follow`, `ref_type 'user'`, `ref_id` = follower, title `'<name> started following you'`), `follow_is_idempotent_one_row_one_notification` (call twice), `no_self_follow` (error `cannot_follow_self`), `unfollow_removes`, `unfollow_when_not_following_is_silent`, `counts_are_right` (followers, following, `i_follow` true then false), `counts_work_signed_out` (anon: `i_follow` false), `follow_needs_login` (anon → `42501`), `search_and_lists_need_login`, `lists_return_safe_columns_and_page` (offset works), `person_returns_guest_only_when_signed_in` (anon gets host row, no guest row), `delete_auth_user_removes_follows`, `erase_user_removes_follows_and_username` (call `identity.erase_user` as superuser on a guest, then username null and no follow rows), `follow_unknown_user_errors` (`user_not_found`).
- [ ] **Step 2: Run `supabase db reset --no-seed && supabase test db supabase/tests/identity_follows.sql`.** Expected: FAIL, table missing.
- [ ] **Step 3: Write the migration.** `follows` with primary key `(follower_id, followee_id)`, `check (follower_id <> followee_id)`, both FKs to `identity.profiles (user_id) on delete cascade`, RLS on with an own-row select policy as `0010` does, `grant select` to authenticated. `follow` inserts with `on conflict do nothing` and notifies only when a row was inserted (`get diagnostics`/`returning`); notification name is the follower's display name (same `coalesce` as search). `list_*` order by `created_at desc`. `person`: `where user_id = p_user_id and username is not null and (is_host or auth.uid() is not null)`. Re-create `identity.erase_user` by copying its body from `0092_account_deletion.sql` and adding `delete from identity.follows where follower_id = p_user_id or followee_id = p_user_id;` and `username = null` in its final `update`. Keep the existing revoke/grant lines for it. Same security rules as Task 1.
- [ ] **Step 4: Run Step 2 command, then `tools/test_db.sh`.** Expected: new tests pass, whole suite and seed checks green (fix any older test the schema change breaks).
- [ ] **Step 5: Commit** `feat(identity): follows`.

### Task 3: People data layer and test fake

**Files:**
- Create: `app/lib/features/people/domain/person.dart`, `app/lib/features/people/data/people_repository.dart`, `app/test/helpers/fake_people.dart`
- Modify: `app/test/helpers/pump_app.dart` (new `FakePeople? people` parameter, override `peopleRepositoryProvider`)
- Test: `app/test/features/people/person_test.dart`

**Interfaces:**
- Produces: `class Person {String userId, name, username; String? avatarUrl; bool isHost; factory Person.fromJson(Map<String,dynamic>)}`; `class FollowCounts {int followers, following; bool iFollow}`; `class UsernameError implements Exception {String code; factory UsernameError.fromMessage(String); String get message}` (copy: `username_invalid` → "Use 3 to 20 letters, numbers, _ or . (not at the start or end, never two dots in a row)."; `username_reserved` → "That username is not available."; `username_taken` → "Someone already has that username."; anything else → "Could not save. Try again."); `abstract class PeopleRepository {Future<String?> myUsername(); Future<bool> available(String u); Future<String> setUsername(String u); Future<List<Person>> search(String q); Future<Person?> person(String id); Future<FollowCounts> counts(String id); Future<void> follow(String id); Future<void> unfollow(String id); Future<List<Person>> followers(String id, {int offset = 0}); Future<List<Person>> following(String id, {int offset = 0})}`; providers `peopleRepositoryProvider`, `myUsernameProvider` (`FutureProvider.autoDispose<String?>`), `followCountsProvider` and `personProvider` (`FutureProvider.autoDispose.family<_, String>`). `FakePeople` implements it with in-memory maps and records `followed`/`unfollowed` ids.

- [ ] **Step 1: Write `person_test.dart`:** `person_from_json_reads_all_fields`, `username_error_maps_each_code` (message containing each code → its copy), `username_error_unknown_falls_back`. Run `cd app && flutter test test/features/people/person_test.dart`. Expected: FAIL (file missing).
- [ ] **Step 2: Implement `person.dart`, then `people_repository.dart`.** Supabase impl uses `_db.schema('identity').rpc(...)` as `review_repository.dart` does; `myUsername` selects `username` from `identity.profiles` where `user_id` = current user; `setUsername`/`available` catch `PostgrestException` and throw `UsernameError.fromMessage(e.message)`; `counts` maps the single returned row. Write `fake_people.dart` and the `pump_app.dart` wiring.
- [ ] **Step 3: Run Step 1 command, then `flutter analyze` and `flutter test`.** Expected: pass, no analyzer issues.
- [ ] **Step 4: Commit** `feat(app): people repository`.

### Task 4: Username on Profile and the Edit username screen

**Files:**
- Create: `app/lib/features/people/presentation/edit_username_screen.dart`
- Modify: `app/lib/features/profile/presentation/profile_screen.dart` (the `@username` under the name key `profile-username`; rows "Edit username" → `/edit-username` and "Find people" → `/people`), `app/lib/core/router/app_router.dart` (routes `/edit-username`, `/people`)
- Test: `app/test/features/people/edit_username_test.dart`, add to `app/test/features/profile/profile_flow_test.dart`

**Interfaces:**
- Consumes: `PeopleRepository`, `UsernameError`, `myUsernameProvider`.
- Produces: `EditUsernameScreen` (key `edit-username-screen`; field key `username-field`; message key `username-status`; button key `username-save`); route `/edit-username`.

- [ ] **Step 1: Write tests.** Edit screen: `field_starts_with_current_username`, `typing_checks_availability_live` (shows "@x is available" for a free name, "Someone already has that username." for a taken one, after a short debounce `pump(300ms)`), `invalid_format_disables_save_without_asking_server` (`'ab'`, `'a..b'`, `'.ab'`), `save_disabled_while_unchanged_or_invalid`, `each_server_error_shows_its_message` (fake `setUsername` throws `UsernameError('username_taken'|'username_reserved'|'username_invalid')`), `save_pops_and_profile_shows_new_name`. Profile: `profile_shows_username_under_name` (`@meitan1234`), `profile_rows_open_edit_username_and_find_people`.
- [ ] **Step 2: Run both files.** Expected: FAIL.
- [ ] **Step 3: Implement.** Client-side format check mirrors the database rules so Save is disabled without a round trip; availability only asked for a valid, changed value; save invalidates `myUsernameProvider`.
- [ ] **Step 4: Run both files and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): edit username`.

### Task 5: Find people, person page, follow button and lists

**Files:**
- Create: `app/lib/features/people/presentation/find_people_screen.dart`, `person_screen.dart`, `follow_button.dart`, `follow_list_screen.dart`
- Modify: `app/lib/core/router/app_router.dart` (replace the Task 4 `/people` stub; add `/people/:id`, `/people/:id/followers`, `/people/:id/following`), `app/lib/features/auth/domain/auth_gate.dart` (`AuthReason.follow`), `app/lib/features/auth/presentation/sign_in_sheet.dart` (copy `('Sign in to follow', 'Follow people to keep up with what they host and join.')`)
- Test: `app/test/features/people/find_people_test.dart`, `follow_test.dart`

**Interfaces:**
- Consumes: Task 3 providers; `requireAuth(ref, context, AuthReason.follow)`.
- Produces: `FollowButton({required String userId})` (keys `follow-button`, label "Follow" / "Following"; hidden when `userId` is the caller); `FindPeopleScreen` (field key `people-search`, result rows key `person-<userId>`); `PersonScreen({required String userId})` for guests (a host id redirects with `context.pushReplacement('/host/$id')`); `FollowListScreen({required String userId, required bool followers})`.

- [ ] **Step 1: Write tests.** Find: `search_waits_for_two_characters`, `results_show_name_and_username`, `tapping_a_host_opens_host_page_and_a_guest_opens_person_page`, `no_results_message`. Follow: `follow_button_toggles_and_updates_count`, `signed_out_follow_opens_sign_in_sheet_with_follow_line` (text "Sign in to follow"), `double_tap_calls_follow_once` (button disabled while the call is in flight), `person_page_shows_counts_that_open_lists`, `lists_show_people_and_page_more`.
- [ ] **Step 2: Run both files.** Expected: FAIL.
- [ ] **Step 3: Implement.** Debounce search 300 ms; avatar is the host `avatarUrl` or the first letter in a circle as `host_public_screen.dart` does; `FollowButton` invalidates `followCountsProvider(userId)` after the call.
- [ ] **Step 4: Run both files and the whole `flutter test`.** Expected: pass.
- [ ] **Step 5: Commit** `feat(app): find people and follow`.

### Task 6: Host public page shows username, Follow and counts

**Files:**
- Modify: `app/lib/features/reviews/presentation/host_public_screen.dart` (under `host-name`: `@username` key `host-username`; `FollowButton(userId: hostId)`; two tappable counts keys `host-followers`, `host-following` → the Task 5 lists)
- Test: add to `app/test/features/reviews/review_flow_test.dart`

**Interfaces:**
- Consumes: `personProvider(hostId)` (username), `followCountsProvider(hostId)`, `FollowButton`.

- [ ] **Step 1: Write tests:** `host_page_shows_username_follow_button_and_counts`, `follow_updates_follower_count_on_host_page`, `signed_out_host_page_hides_nothing_but_follow_asks_to_sign_in`, `host_page_still_renders_when_people_calls_fail` (counts and username load errors must not blank the page). Run: expected FAIL.
- [ ] **Step 2: Implement** by watching the two providers with `.valueOrNull` so the existing page renders first.
- [ ] **Step 3: Run `flutter test test/features/reviews` then the whole suite.** Expected: pass.
- [ ] **Step 4: Commit** `feat(app): follow from host page`.

### Task 7: "Started following you" in Notifications

**Files:**
- Modify: `app/lib/features/notifications/domain/notification_labels.dart` (`'follow'` icon `Icons.person_add_alt`; `notifRoute`: `refType == 'user'` → `/people/$id`), comment in `notification.dart` listing the new type
- Test: add to the existing notification labels test under `app/test/features/notifications/`

- [ ] **Step 1: Write tests:** `follow_notification_has_person_icon`, `follow_notification_opens_person_page`. Run: expected FAIL.
- [ ] **Step 2: Implement** the two edits.
- [ ] **Step 3: Run `flutter test test/features/notifications` then the whole suite and `flutter analyze`.** Expected: pass.
- [ ] **Step 4: Commit** `feat(app): follow notification label`.

### Task 8: Device checks (no code)

- [ ] **Step 1: Local stack up** (`supabase start`, Docker running, `supabase db reset` with seed), app on `app/env/local.json`.
- [ ] **Step 2: iOS simulator first** (iPhone 17 Pro `3A69CF5F-EE4E-4E2E-8D38-202255D0402F`, mobile MCP tools): see @username on Profile, change it (taken, reserved, bad format, success), search a seeded host and a guest, follow and unfollow from the host page and the person page, check counts and lists, see the follow notification on the second account, signed-out Follow shows "Sign in to follow". Expected: every item works, no overflow or error screens.
- [ ] **Step 3: Android emulator only if Step 2 is clean** (`Pixel_10_Pro`, host at `10.0.2.2`): repeat the same walk.
- [ ] **Step 4: Report** feature list with test status per feature. Nothing pushed, no PR.
