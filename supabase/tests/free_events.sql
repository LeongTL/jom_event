begin;
select plan(8);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'host@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'guest1@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'guest2@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into identity.hosts (user_id, host_name, area) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Host', 'Bangsar');

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, lat, lng,
                           cancel_policy, accept_bookings) values
  ('f1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Free walk', 'published', 0, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 3.129, 101.671, '24h', true),
  ('f2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Paid class', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 3.129, 101.671, '24h', true);
-- a booking made before free events became Save-only stays valid
insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values ('f1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 1, 'confirmed', 'T-OLD', 'G2', '601', 0);

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select bookings.create_booking('f1000000-0000-0000-0000-000000000001', 1, 'G1', '601')$$,
  'P0001', 'free_event_no_booking', 'a free event cannot be booked');
select lives_ok($$select bookings.create_booking('f2000000-0000-0000-0000-000000000002', 1, 'G1', '601')$$,
  'a paid event still can');
select identity.toggle_save('f1000000-0000-0000-0000-000000000001');
select throws_ok($$select identity.saves_count('f1000000-0000-0000-0000-000000000001')$$,
  'P0001', 'not_host', 'a guest cannot read the saves count');

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
select is((select count(*)::int from bookings.my_bookings('upcoming') where event_id = 'f1000000-0000-0000-0000-000000000001'), 1,
  'an old confirmed free booking is still in Tickets');
select identity.toggle_save('f1000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is(identity.saves_count('f1000000-0000-0000-0000-000000000001'), 2, 'the host sees how many saved');
select is((select saves from events.host_events(null, 'f1000000-0000-0000-0000-000000000001')), 2, 'host_events carries saves for a free event');
select is((select saves from events.host_events(null, 'f2000000-0000-0000-0000-000000000002')), null, 'and null for a paid one');

reset role;
set local role anon;
select throws_ok($$select identity.saves_count('f1000000-0000-0000-0000-000000000001')$$,
  null, null, 'anon cannot read the saves count');
reset role;

select * from finish();
rollback;
