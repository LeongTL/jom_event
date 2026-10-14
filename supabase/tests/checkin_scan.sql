begin;
select plan(30);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),  -- host of e1 and e2
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com'),
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com');   -- another host

create function pg_temp.ev(id uuid, host uuid, price int) returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                             accept_bookings, area, venue, lat, lng)
  values (id, host, 'Event ' || left(id::text, 8), 'published', price, 10,
          '2030-01-10 20:00+08', '2030-01-10 22:00+08', '48h', true, 'Bangsar', 'V', 3.129, 101.671)
$$;
select pg_temp.ev('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 0);
select pg_temp.ev('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 0);
select pg_temp.ev('e3000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 3000);

-- bob joins e1, carol joins e2, dave joins e1 and cancels, bob holds a paid seat on e3
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.bob', (bookings.create_booking('e1000000-0000-0000-0000-000000000001', 2, 'Bob Tan', '60111111111')).id::text, true);
select set_config('t.bobheld', (bookings.create_booking('e3000000-0000-0000-0000-000000000003', 1, 'Bob Tan', '60111111111')).id::text, true);
select set_config('t.bobtoken', bookings.ticket_token(current_setting('t.bob')::uuid), true);
select set_config('t.heldtoken', bookings.ticket_token(current_setting('t.bobheld')::uuid), true);
reset role;

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.carol', (bookings.create_booking('e2000000-0000-0000-0000-000000000002', 1, 'Carol', '60122222222')).id::text, true);
select set_config('t.caroltoken', bookings.ticket_token(current_setting('t.carol')::uuid), true);
reset role;

select set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.dave', (bookings.create_booking('e1000000-0000-0000-0000-000000000001', 1, 'Dave', '60133333333')).id::text, true);
select bookings.cancel_booking(current_setting('t.dave')::uuid);
select set_config('t.davetoken', bookings.ticket_token(current_setting('t.dave')::uuid), true);
reset role;

select matches(current_setting('t.bobtoken'), '^[0-9a-f-]{36}\.[0-9a-f]{64}$', 'ticket_token_is_booking_id_dot_hmac_sha256_hex');
select is(split_part(current_setting('t.bobtoken'), '.', 1), current_setting('t.bob'), 'the token names its booking');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is(bookings.ticket_token(current_setting('t.bob')::uuid), current_setting('t.bobtoken'), 'the token is stable');
reset role;
select is((select count(*)::int from vault.secrets where name = 'ticket_secret'), 1, 'the signing secret lives in vault');

-- the host scans
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r1', bookings.check_in('e1000000-0000-0000-0000-000000000001', current_setting('t.bobtoken'))::text, true);
reset role;

select is(current_setting('t.r1')::jsonb ->> 'result', 'checked_in', 'check_in_marks_attended: result');
select is(current_setting('t.r1')::jsonb ->> 'guest_name', 'Bob Tan', 'check_in returns the guest name');
select is((current_setting('t.r1')::jsonb ->> 'people')::int, 2, 'check_in returns the party size');
select matches(current_setting('t.r1')::jsonb ->> 'ticket_code', '^KLS-[0-9]{5}$', 'check_in returns the ticket code');
select results_eq(
  $$select status, checked_in_at is not null from bookings.bookings where id = current_setting('t.bob')::uuid$$,
  $$values ('attended', true)$$, 'check_in_marks_attended_and_returns_guest_name');

-- scanned again: the original time comes back and nothing changes
update bookings.bookings set checked_in_at = '2030-01-10 09:02+08' where id = current_setting('t.bob')::uuid;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r2', bookings.check_in('e1000000-0000-0000-0000-000000000001', current_setting('t.bobtoken'))::text, true);
reset role;
select is(current_setting('t.r2')::jsonb ->> 'result', 'already', 'second scan says already');
select is((current_setting('t.r2')::jsonb ->> 'at')::timestamptz, '2030-01-10 09:02+08'::timestamptz,
  'second_scan_returns_already_with_original_time');
select is((select checked_in_at from bookings.bookings where id = current_setting('t.bob')::uuid),
  '2030-01-10 09:02+08'::timestamptz, 'the second scan did not move the check-in time');

-- a ticket for another event
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r3', bookings.check_in('e1000000-0000-0000-0000-000000000001', current_setting('t.caroltoken'))::text, true);
reset role;
select is(current_setting('t.r3')::jsonb ->> 'result', 'wrong_event', 'ticket_for_other_event_returns_wrong_event');
select is(current_setting('t.r3')::jsonb ->> 'guest_name', null, 'a wrong-event scan does not reveal the guest');
select is((select status from bookings.bookings where id = current_setting('t.carol')::uuid), 'confirmed',
  'a wrong-event scan changes nothing');

-- cancelled, unpaid (held) and expired bookings
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r4', bookings.check_in('e1000000-0000-0000-0000-000000000001', current_setting('t.davetoken'))::text, true);
select set_config('t.r5', bookings.check_in('e3000000-0000-0000-0000-000000000003', current_setting('t.heldtoken'))::text, true);
reset role;
update bookings.bookings set status = 'expired' where id = current_setting('t.bobheld')::uuid;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r6', bookings.check_in('e3000000-0000-0000-0000-000000000003', current_setting('t.heldtoken'))::text, true);
reset role;
select is(current_setting('t.r4')::jsonb ->> 'result', 'not_confirmed', 'a cancelled booking is not confirmed');
select is(current_setting('t.r5')::jsonb ->> 'result', 'not_confirmed', 'an unpaid (held) booking is not confirmed');
select is(current_setting('t.r6')::jsonb ->> 'result', 'not_confirmed', 'cancelled_unpaid_or_expired_booking_returns_not_confirmed');
select is((select status from bookings.bookings where id = current_setting('t.dave')::uuid), 'cancelled', 'a refused scan leaves the booking as it was');

-- forged tokens
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is(bookings.check_in('e2000000-0000-0000-0000-000000000002',
    current_setting('t.carol') || '.' || repeat('0', 64)) ->> 'result', 'invalid', 'tampered_token_returns_invalid: wrong signature');
select is(bookings.check_in('e2000000-0000-0000-0000-000000000002',
    left(current_setting('t.caroltoken'), 40) || 'ffff' || substr(current_setting('t.caroltoken'), 45)) ->> 'result',
    'invalid', 'a token with edited signature digits is invalid');
select is(bookings.check_in('e2000000-0000-0000-0000-000000000002', 'not a token') ->> 'result', 'invalid', 'garbage is invalid');
select is(bookings.check_in('e2000000-0000-0000-0000-000000000002', null) ->> 'result', 'invalid', 'null is invalid');
reset role;
select is((select status from bookings.bookings where id = current_setting('t.carol')::uuid), 'confirmed', 'a forged scan does not check anyone in');

-- only the host of this event may scan, and only the owner may fetch a ticket
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select bookings.check_in('e2000000-0000-0000-0000-000000000002', current_setting('t.caroltoken'))$$,
  'P0001', 'not_owner', 'only_the_events_host_can_check_in: another host');
select throws_ok($$select bookings.check_in('e1000000-0000-0000-0000-000000000001', current_setting('t.bobtoken'))$$,
  'P0001', 'not_owner', 'a host of other events cannot scan this one');
select throws_ok($$select bookings.ticket_token(current_setting('t.carol')::uuid)$$, 'P0001', 'not_owner',
  'a stranger cannot fetch someone else''s ticket');
select throws_ok($$select secret from vault.secrets$$, '42501', null, 'clients cannot read the signing secret');
reset role;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($$select bookings.check_in('e1000000-0000-0000-0000-000000000001', current_setting('t.bobtoken'))$$,
  'P0001', 'not_owner', 'a guest cannot scan, not even their own ticket');
reset role;
set local role anon;
select throws_ok($$select bookings.check_in('e1000000-0000-0000-0000-000000000001', current_setting('t.bobtoken'))$$,
  '42501', null, 'signed-out visitors cannot call check_in');
reset role;

select * from finish();
rollback;
