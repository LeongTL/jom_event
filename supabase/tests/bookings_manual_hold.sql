begin;
select plan(9);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');

create function pg_temp.ev(n int, starts_in interval, cap int default 5) returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                             accept_bookings, area, venue, lat, lng)
  values (('e0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'aaaaaaaa-0000-0000-0000-000000000001', 'E' || n, 'published',
          3000, cap, now() + starts_in, now() + starts_in + interval '2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6)
$$;
create function pg_temp.eid(n int) returns uuid language sql as $$ select ('e0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
select pg_temp.ev(1, interval '3 days');
select pg_temp.ev(2, interval '70 minutes');
select pg_temp.ev(3, interval '61 minutes');
select pg_temp.ev(4, interval '59 minutes');
select pg_temp.ev(5, interval '3 days');
select pg_temp.ev(6, interval '3 days');
select pg_temp.ev(7, interval '3 days');
select pg_temp.ev(8, interval '3 days', 1);

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.far', (bookings.create_booking(pg_temp.eid(1), 1, 'Bob', '601')).hold_expires_at::text, true);
select set_config('t.near', (bookings.create_booking(pg_temp.eid(2), 1, 'Bob', '601')).hold_expires_at::text, true);
select set_config('t.min', (bookings.create_booking(pg_temp.eid(3), 1, 'Bob', '601')).hold_expires_at::text, true);
select is(current_setting('t.far')::timestamptz, now() + interval '1 hour', 'far_event_hold_is_one_hour');
select is(current_setting('t.near')::timestamptz, now() + interval '40 minutes', 'near_event_hold_is_start_minus_30_minutes');
select is(current_setting('t.min')::timestamptz, now() + interval '31 minutes', 'event_one_hour_away_still_gets_31_minutes');
select throws_ok($$select bookings.create_booking(pg_temp.eid(4), 1, 'Bob', '601')$$, 'P0001', 'bookings_closed', 'closed_one_hour_before_start');
reset role;

-- cooldown: an expired hold with no receipt blocks the same event for 30 minutes
create function pg_temp.exp(n int, uid uuid, ago interval, st text default 'expired') returns uuid language sql as $$
  insert into bookings.bookings (event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
  values (pg_temp.eid(n), uid, 1, st, now() - ago, 'KLS-' || lpad(n::text, 5, '1'), 'B', '1', 3000) returning id
$$;
select pg_temp.exp(5, 'bbbbbbbb-0000-0000-0000-000000000002', interval '10 minutes');
select pg_temp.exp(6, 'bbbbbbbb-0000-0000-0000-000000000002', interval '31 minutes');
select pg_temp.exp(7, 'bbbbbbbb-0000-0000-0000-000000000002', interval '10 minutes', 'cancelled');
select pg_temp.exp(8, 'bbbbbbbb-0000-0000-0000-000000000002', interval '10 minutes');
set local role authenticated;
select throws_ok($$select bookings.create_booking(pg_temp.eid(5), 1, 'Bob', '601')$$, 'P0001', 'cooldown_active', 'cooldown_blocks_for_30_minutes_after_expiry_with_no_receipt');
select lives_ok($$select bookings.create_booking(pg_temp.eid(6), 1, 'Bob', '601')$$, 'cooldown_ends_after_30_minutes');
select lives_ok($$select bookings.create_booking(pg_temp.eid(7), 1, 'Bob', '601')$$, 'cooldown_not_applied_after_own_cancel');
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
select lives_ok($$select bookings.create_booking(pg_temp.eid(5), 1, 'Carol', '602')$$, 'cooldown_is_per_user');
reset role;
-- a late receipt lifts the cooldown
insert into payments.receipts (booking_id, image_path, status)
  select id, 'x/y.jpg', 'late' from bookings.bookings where event_id = pg_temp.eid(8);
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$select bookings.create_booking(pg_temp.eid(8), 1, 'Bob', '601')$$, 'cooldown_not_applied_when_a_late_receipt_exists');
select * from finish();
rollback;
