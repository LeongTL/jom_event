begin;
select plan(23);

-- alice: a host with an event that has guests. bob: a guest. carol: a host who can leave. dave: a host owed money.
insert into auth.users (id, email) values
  ('eeeeeeee-0000-0000-0000-000000000005', 'erin@example.com'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com'),
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com');
update identity.profiles set name = 'Bob Tan', phone = '60111111111' where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
update identity.profiles set is_host = true where user_id in
  ('aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-000000000004');
insert into identity.hosts (user_id, host_name, area) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice Studio', 'Bangsar'),
  ('cccccccc-0000-0000-0000-000000000003', 'Carol Crafts', 'PJ'),
  ('dddddddd-0000-0000-0000-000000000004', 'Dave Dance', 'KLCC');
insert into identity.host_payout_accounts values
  ('cccccccc-0000-0000-0000-000000000003', 'Carol', 'Maybank', '111'),
  ('dddddddd-0000-0000-0000-000000000004', 'Dave', 'CIMB', '222');

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Alice yoga',   'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V'),
  ('e2000000-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000003', 'Carol future', 'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'PJ', 'V'),
  ('e3000000-0000-0000-0000-000000000003', 'cccccccc-0000-0000-0000-000000000003', 'Carol draft',  'draft',     3000, 10, null, null, null, null),
  ('e4000000-0000-0000-0000-000000000004', 'cccccccc-0000-0000-0000-000000000003', 'Carol past',    'ended',     3000, 10, '2020-01-10 20:00+08', '2020-01-10 22:00+08', 'PJ', 'V'),
  ('e5000000-0000-0000-0000-000000000005', 'dddddddd-0000-0000-0000-000000000004', 'Dave past',     'ended',     3000, 10, '2020-01-10 20:00+08', '2020-01-10 22:00+08', 'KLCC', 'V');
insert into payments.payouts (host_id, event_id, amount_sen, status, due_at) values
  ('cccccccc-0000-0000-0000-000000000003', 'e4000000-0000-0000-0000-000000000004', 2655, 'paid',      now()),
  ('dddddddd-0000-0000-0000-000000000004', 'e5000000-0000-0000-0000-000000000005', 2655, 'scheduled', now() + interval '3 days');

-- bob: saved events, notices, bookings in every state, chat with alice, a review
insert into identity.saved_events (user_id, event_id) values ('bbbbbbbb-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001');
insert into identity.notifications (user_id, type, title) values ('bbbbbbbb-0000-0000-0000-000000000002', 'booking', 'You are in');
insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen) values
  ('b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'confirmed', null, 'KLS-00001', 'Bob Tan', '60111111111', 6000),
  ('b2000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'held', now() + interval '10 minutes', 'KLS-00002', 'Bob Tan', '60111111111', 3000),
  ('b3000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'processing', now() + interval '5 minutes', 'KLS-00003', 'Bob Tan', '60111111111', 3000),
  ('b4000000-0000-0000-0000-000000000004', 'e4000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'attended', null, 'KLS-00004', 'Bob Tan', '60111111111', 3000);
insert into payments.payment_attempts (booking_id, reference, status, method, session_expires_at)
  values ('b1000000-0000-0000-0000-000000000001', 'KLS-00001-REF', 'success', 'fpx', now());
insert into reviews.reviews (booking_id, event_id, host_id, attendee_id, stars, body) values
  ('b4000000-0000-0000-0000-000000000004', 'e4000000-0000-0000-0000-000000000004', 'cccccccc-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 5, 'Great');
insert into chat.threads (id, attendee_id, host_id, last_message_at) values
  ('c1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', now()),
  ('c2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000003', now());
insert into chat.messages (thread_id, sender_id, body) values
  ('c1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'Is it beginner friendly?'),
  ('c1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Yes, all welcome'),
  ('c2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'Hello Carol');
insert into chat.thread_reads values ('c1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', now());

-- ===== hosts who cannot leave yet: nothing may change =====
select throws_ok($$select identity.erase_user('aaaaaaaa-0000-0000-0000-000000000001')$$, 'P0001', 'host_has_active_events',
  'a host with a published event that has guests is refused');
select is((select count(*)::int from identity.hosts where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 1, '... and keeps their host profile');
select throws_ok($$select identity.erase_user('dddddddd-0000-0000-0000-000000000004')$$, 'P0001', 'host_has_pending_payouts',
  'a host who is still owed a payout is refused');

-- ===== a guest leaves =====
select lives_ok($$select identity.erase_user('bbbbbbbb-0000-0000-0000-000000000002')$$, 'a guest can be erased');
select is((select count(*)::int from identity.saved_events where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 0, 'saved events are deleted');
select is((select count(*)::int from identity.notifications where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 0, 'notifications are deleted');
select is((select count(*)::int from identity.notification_prefs where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 0, 'notification switches are deleted');
select results_eq($$select name, phone, is_host from identity.profiles where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'$$,
  $$values ('Deleted user', null::text, false)$$, 'the profile stays as an anonymous "Deleted user"');
select results_eq($$select contact_name, contact_phone, status, amount_sen from bookings.bookings where id = 'b1000000-0000-0000-0000-000000000001'$$,
  $$values ('Deleted user', '', 'confirmed', 6000)$$, 'a paid booking is kept as a money record with the guest name blanked');
select results_eq($$select status, cancelled_at is not null from bookings.bookings where id = 'b2000000-0000-0000-0000-000000000002'$$,
  $$values ('cancelled', true)$$, 'an unpaid hold is released');
select is((select status from bookings.bookings where id = 'b3000000-0000-0000-0000-000000000003'), 'processing', 'a payment still in flight is left alone');
select is((select count(*)::int from payments.payment_attempts where booking_id = 'b1000000-0000-0000-0000-000000000001'), 1, 'payment records are kept');
select is((select count(*)::int from reviews.reviews where attendee_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 1, 'their review is kept for the host rating');
select is((select count(*)::int from chat.messages where sender_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 0, 'messages they sent are deleted');
select is((select string_agg(id::text, ',') from chat.threads), 'c1000000-0000-0000-0000-000000000001',
  'a conversation left with no messages is deleted, one with replies stays');
select is((select count(*)::int from chat.thread_reads where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 0, 'their read markers are deleted');
select lives_ok($$select identity.erase_user('bbbbbbbb-0000-0000-0000-000000000002')$$, 'erasing twice is harmless');

-- ===== a host with nothing outstanding leaves =====
select lives_ok($$select identity.erase_user('cccccccc-0000-0000-0000-000000000003')$$, 'a host with no guests and no payout owing can be erased');
select results_eq(
  $$select (select count(*)::int from identity.hosts where user_id = 'cccccccc-0000-0000-0000-000000000003'),
           (select count(*)::int from identity.host_payout_accounts where user_id = 'cccccccc-0000-0000-0000-000000000003')$$,
  $$values (0, 0)$$, 'the host profile and bank details are deleted');
select is((select string_agg(title || '=' || status, ', ' order by title) from events.events where host_id = 'cccccccc-0000-0000-0000-000000000003'),
  'Carol future=cancelled, Carol past=ended', 'their future event is cancelled, a draft is removed, a finished one is kept');

-- ===== the profile outlives the auth user, and clients cannot do any of this =====
delete from auth.users where id = 'bbbbbbbb-0000-0000-0000-000000000002';
select is((select count(*)::int from identity.profiles where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 1,
  'deleting the sign-in account does not delete the anonymised profile');

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select identity.erase_user('aaaaaaaa-0000-0000-0000-000000000001')$$, '42501', null, 'clients cannot erase accounts');
reset role;

-- the delete-account edge function calls it as the service role (not as the database owner)
set local role service_role;
select lives_ok($$select identity.erase_user('eeeeeeee-0000-0000-0000-000000000005')$$, 'the service role, which the edge function uses, can erase an account');
reset role;

select * from finish();
rollback;
