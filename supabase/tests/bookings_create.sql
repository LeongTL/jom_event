begin;
select plan(21);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com'),
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com');

create function pg_temp.ev(id uuid, price int, cap int, starts text, policy text default '48h',
                           st text default 'published', accept boolean default true) returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                             accept_bookings, area, venue, lat, lng)
  values (id, 'aaaaaaaa-0000-0000-0000-000000000001', 'Event ' || left(id::text, 8), st, price, cap,
          starts::timestamptz, starts::timestamptz + interval '2 hours', policy, accept, 'Bangsar', 'V', 3.129, 101.671)
$$;
select pg_temp.ev('e1000000-0000-0000-0000-000000000001', 3000, 3, '2030-01-10 20:00+08');              -- paid, 3 seats, 48h
select pg_temp.ev('e2000000-0000-0000-0000-000000000002', 0,    5, '2030-01-10 20:00+08', '24h');       -- free
select pg_temp.ev('e3000000-0000-0000-0000-000000000003', 3000, 5, '2020-01-10 20:00+08');              -- already started
select pg_temp.ev('e4000000-0000-0000-0000-000000000004', 3000, 5, '2030-01-10 20:00+08', st => 'draft');
select pg_temp.ev('e5000000-0000-0000-0000-000000000005', 3000, 5, '2030-01-10 20:00+08', st => 'ended');
select pg_temp.ev('e6000000-0000-0000-0000-000000000006', 3000, 5, '2030-01-10 20:00+08', accept => false);
select pg_temp.ev('e7000000-0000-0000-0000-000000000007', 3000, 5, '2030-01-10 20:00+08', 'none');

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.bob', (bookings.create_booking('e1000000-0000-0000-0000-000000000001', 1, 'Bob', '60111111111')).id::text, true);
select set_config('t.bobfree', (bookings.create_booking('e2000000-0000-0000-0000-000000000002', 2, 'Bob', '60111111111')).id::text, true);
select set_config('t.bobnone', (bookings.create_booking('e7000000-0000-0000-0000-000000000007', 1, 'Bob', '60111111111')).id::text, true);
reset role;

select results_eq(
  $$select status, people, amount_sen, hold_expires_at, contact_name, contact_phone, attendee_id from bookings.bookings where id = current_setting('t.bob')::uuid$$,
  $$values ('held', 1, 3000, now() + interval '15 minutes', 'Bob', '60111111111', 'bbbbbbbb-0000-0000-0000-000000000002'::uuid)$$,
  'paid_booking_is_held_for_15_minutes');
select is((select cancel_cutoff_at from bookings.bookings where id = current_setting('t.bob')::uuid),
  '2030-01-08 20:00+08'::timestamptz, 'a paid booking copies the host cancellation cutoff (48h before)');
select results_eq(
  $$select status, hold_expires_at, amount_sen, cancel_cutoff_at from bookings.bookings where id = current_setting('t.bobfree')::uuid$$,
  $$values ('confirmed', null::timestamptz, 0, '2030-01-10 20:00+08'::timestamptz)$$,
  'free_booking_is_confirmed_immediately_with_no_hold (cancel until the start)');
select is((select cancel_cutoff_at from bookings.bookings where id = current_setting('t.bobnone')::uuid), null,
  'a no-refund event gives the booking no cutoff');
select matches((select ticket_code from bookings.bookings where id = current_setting('t.bob')::uuid), '^KLS-[0-9]{5}$',
  'ticket_code_is_formatted_like_KLS-48111');
select throws_ok(
  $$insert into bookings.bookings (event_id, attendee_id, people, ticket_code, contact_name, contact_phone, amount_sen)
    select event_id, attendee_id, 1, ticket_code, 'x', 'y', 0 from bookings.bookings where id = current_setting('t.bob')::uuid$$,
  '23505', null, 'ticket_code_is_unique');

-- the host's policy is copied, so editing the event later does not move it
update events.events set cancel_policy = 'none', starts_at = starts_at + interval '30 days'
 where id = 'e1000000-0000-0000-0000-000000000001';
select is((select cancel_cutoff_at from bookings.bookings where id = current_setting('t.bob')::uuid),
  '2030-01-08 20:00+08'::timestamptz, 'cancel_cutoff_is_copied_so_later_event_changes_do_not_move_it');
update events.events set cancel_policy = '48h', starts_at = starts_at - interval '30 days'
 where id = 'e1000000-0000-0000-0000-000000000001';

-- seats: bob holds 1 of 3; carol takes 2 for the last two; dave is told it is sold out
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.carol', (bookings.create_booking('e1000000-0000-0000-0000-000000000001', 2, 'Carol', '60122222222')).id::text, true);
reset role;
select is((select amount_sen from bookings.bookings where id = current_setting('t.carol')::uuid), 6000, 'amount is price times people');
select is(bookings.seats_taken('e1000000-0000-0000-0000-000000000001'), 3, 'seats_taken counts held seats');

select set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select bookings.create_booking('e1000000-0000-0000-0000-000000000001', 1, 'Dave', '60133333333')$$,
  'P0001', 'sold_out', 'two_users_taking_last_seat_give_exactly_one_booking (the second is sold out)');
reset role;
select is((select count(*)::int from bookings.bookings where event_id = 'e1000000-0000-0000-0000-000000000001'), 2,
  'the sold-out attempt left no booking behind');

-- a booking that is cancelled frees its seats at once
update bookings.bookings set status = 'cancelled' where id = current_setting('t.carol')::uuid;
select is(bookings.seats_taken('e1000000-0000-0000-0000-000000000001'), 1, 'a cancelled booking frees its seats');
set local role authenticated;
select lives_ok($$select bookings.create_booking('e1000000-0000-0000-0000-000000000001', 2, 'Dave', '60133333333')$$,
  'the freed seats can be booked');
reset role;

-- refusals
set local role authenticated;
select throws_ok($$select bookings.create_booking('e1000000-0000-0000-0000-000000000001', 0, 'Dave', '601')$$, 'P0001', 'people_out_of_range', 'people_must_be_1_or_2 (0)');
select throws_ok($$select bookings.create_booking('e2000000-0000-0000-0000-000000000002', 3, 'Dave', '601')$$, 'P0001', 'people_out_of_range', 'people_must_be_1_or_2 (3)');
select throws_ok($$select bookings.create_booking('e3000000-0000-0000-0000-000000000003', 1, 'Dave', '601')$$, 'P0001', 'event_started', 'cannot_book_a_started_event');
select throws_ok($$select bookings.create_booking('e4000000-0000-0000-0000-000000000004', 1, 'Dave', '601')$$, 'P0001', 'event_not_available', 'cannot_book_a_draft_event');
select throws_ok($$select bookings.create_booking('e5000000-0000-0000-0000-000000000005', 1, 'Dave', '601')$$, 'P0001', 'event_not_available', 'cannot_book_an_ended_event');
select throws_ok($$select bookings.create_booking('e6000000-0000-0000-0000-000000000006', 1, 'Dave', '601')$$, 'P0001', 'bookings_closed', 'cannot_book_a_paid_event_with_bookings_switched_off');
select throws_ok($$select bookings.create_booking('e2000000-0000-0000-0000-000000000002', 1, '  ', '601')$$, 'P0001', 'contact_required', 'a name and phone are required');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select bookings.create_booking('e2000000-0000-0000-0000-000000000002', 1, 'x', 'y')$$, '42501', null, 'create_booking_requires_login');
reset role;

select * from finish();
rollback;
