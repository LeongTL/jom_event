begin;
select plan(8);

insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
                                          ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into identity.hosts (user_id, host_name, area, bio, verified_at)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice Studio', 'Bangsar', 'Pilates and pottery', now());

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, lat, lng, cancel_policy, accept_bookings) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Later', 'published', 3000, 10,
   '2030-01-12 10:00+08', '2030-01-12 12:00+08', 'Bangsar', 3.129, 101.671, '24h', true),
  ('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Sooner', 'published', 0, 10,
   '2030-01-11 10:00+08', '2030-01-11 12:00+08', 'Bangsar', 3.129, 101.671, '24h', true),
  ('e3000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Past', 'ended', 3000, 10,
   '2030-01-05 10:00+08', '2030-01-05 12:00+08', 'Bangsar', 3.129, 101.671, '24h', true),
  ('e4000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'Draft', 'draft', 3000, 10,
   null, null, null, null, null, '24h', true);
insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen) values
  ('e3000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'attended', 'T-1', 'Bob', '601', 6000),
  ('e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'confirmed', 'T-2', 'Bob', '601', 3000),
  ('e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'cancelled', 'T-3', 'Bob', '601', 3000);

set local role anon;
select is((select host_name from events.host_page('aaaaaaaa-0000-0000-0000-000000000001', '2030-01-09 14:00+08')), 'Alice Studio', 'a visitor reads the host name');
select is((select area || '/' || bio from events.host_page('aaaaaaaa-0000-0000-0000-000000000001', '2030-01-09 14:00+08')), 'Bangsar/Pilates and pottery', 'area and bio');
select is((select verified from events.host_page('aaaaaaaa-0000-0000-0000-000000000001', '2030-01-09 14:00+08')), true, 'the tick');
select is((select guests from events.host_page('aaaaaaaa-0000-0000-0000-000000000001', '2030-01-09 14:00+08')), 3, 'guests count people who are in, not cancelled ones');
select is((select upcoming from events.host_page('aaaaaaaa-0000-0000-0000-000000000001', '2030-01-09 14:00+08')),
          array['e2000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001']::uuid[], 'upcoming: published, not started, soonest first, no draft or past');
select is((select count(*)::int from events.host_page('bbbbbbbb-0000-0000-0000-000000000002', '2030-01-09 14:00+08')), 0, 'a non-host gives no row');
select is((select count(*)::int from events.host_page(gen_random_uuid(), '2030-01-09 14:00+08')), 0, 'an unknown id gives no row');
select ok((select since is not null from events.host_page('aaaaaaaa-0000-0000-0000-000000000001', '2030-01-09 14:00+08')), 'hosting since');
reset role;

select * from finish();
rollback;
