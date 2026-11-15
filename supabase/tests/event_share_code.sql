begin;
select plan(3);

insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000001', 'host@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into identity.hosts (user_id, host_name, area, status) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Mei', 'Bangsar', 'approved');
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, lat, lng, cancel_policy, accept_bookings, visibility, share_code) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Pub', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 3.1, 101.6, '24h', true, 'public', 'PUBCODE001'),
  ('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Priv', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 3.1, 101.6, '24h', true, 'private', 'PRVCODE002');

set local role anon;
select is((select share_code from events.event_detail('e1000000-0000-0000-0000-000000000001')), 'PUBCODE001', 'the event page carries its share code');
select is((select share_code from events.event_by_code('PRVCODE002')), 'PRVCODE002', 'and so does the page opened by code');
select is((select count(*)::int from events.event_detail('e2000000-0000-0000-0000-000000000002')), 1, 'the by-id page still works');
reset role;

select * from finish();
rollback;
