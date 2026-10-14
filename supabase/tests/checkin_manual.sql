begin;
select plan(13);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),  -- host
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com');    -- another host

-- an event that started 3 hours ago and finished 1 hour ago
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                           accept_bookings, area, venue, lat, lng)
values ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Run club', 'published', 3000, 10,
        now() - interval '3 hours', now() - interval '1 hour', '24h', true, 'Bangsar', 'V', 3.129, 101.671);

insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen) values
  ('b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'confirmed', 'KLS-00001', 'Bob', '6011', 3000),
  ('b2000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'cancelled', 'KLS-00002', 'Bob', '6011', 3000),
  ('b3000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'held', 'KLS-00003', 'Bob', '6011', 3000);

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', true);
reset role;
select results_eq(
  $$select status, checked_in_at is not null from bookings.bookings where id = 'b1000000-0000-0000-0000-000000000001'$$,
  $$values ('attended', true)$$, 'ticking a confirmed guest sets attended with a time');

set local role authenticated;
select lives_ok($$select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', true)$$, 'ticking twice is harmless');
select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', false);
reset role;
select results_eq(
  $$select status, checked_in_at from bookings.bookings where id = 'b1000000-0000-0000-0000-000000000001'$$,
  $$values ('confirmed', null::timestamptz)$$, 'manual_toggle_can_untick_until_completed: unticking returns it to confirmed');

set local role authenticated;
select throws_ok($$select bookings.set_checked_in('b2000000-0000-0000-0000-000000000002', true)$$, 'P0001', 'not_confirmed',
  'a cancelled booking cannot be ticked');
select throws_ok($$select bookings.set_checked_in('b3000000-0000-0000-0000-000000000003', true)$$, 'P0001', 'not_confirmed',
  'an unpaid booking cannot be ticked');
select lives_ok($$select bookings.set_checked_in('b3000000-0000-0000-0000-000000000003', false)$$,
  'unticking a guest who is not checked in is a no-op');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
select throws_ok($$select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', true)$$, 'P0001', 'not_owner',
  'another host cannot tick guests');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($$select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', true)$$, 'P0001', 'not_owner',
  'a guest cannot tick themselves');
reset role;
set local role anon;
select throws_ok($$select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', true)$$, '42501', null,
  'signed-out visitors cannot tick');
reset role;

-- once the event is completed the list is frozen
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', true);
select events.complete_event('e1000000-0000-0000-0000-000000000001');
select throws_ok($$select bookings.set_checked_in('b1000000-0000-0000-0000-000000000001', false)$$, 'P0001', 'event_completed',
  'unticking after completion is refused');
select throws_ok($$select bookings.set_checked_in('b3000000-0000-0000-0000-000000000003', true)$$, 'P0001', 'event_completed',
  'ticking after completion is refused');
reset role;
select is((select status from bookings.bookings where id = 'b1000000-0000-0000-0000-000000000001'), 'attended',
  'a completed event keeps its attended guests');
select is((select count(*)::int from bookings.bookings where event_id = 'e1000000-0000-0000-0000-000000000001' and status = 'no_show'), 0,
  'only confirmed guests become no-shows (cancelled and unpaid stay as they were)');

select * from finish();
rollback;
