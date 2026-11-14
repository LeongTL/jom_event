begin;
select plan(8);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'host@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'guest@example.com');

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, lat, lng, visibility) values
  ('a1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Open class', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 3.129, 101.671, 'public'),
  ('a2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Secret class', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 3.129, 101.671, 'private');
insert into events.events (id, host_id, title) values ('a3000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Draft');

select matches((select share_code from events.events where id = 'a1000000-0000-0000-0000-000000000001'), '^[A-Za-z0-9]{10}$', 'a share code is 10 letters and digits');
select is((select count(distinct share_code)::int from events.events), 3, 'every event has its own code');
select throws_ok($$update events.events set share_code = (select share_code from events.events where id = 'a1000000-0000-0000-0000-000000000001') where id = 'a2000000-0000-0000-0000-000000000002'$$,
  '23505', null, 'a code cannot repeat');
select is((select visibility from events.events where id = 'a3000000-0000-0000-0000-000000000003'), 'public', 'an event is public by default');
select throws_ok($$update events.events set visibility = 'secret' where id = 'a3000000-0000-0000-0000-000000000003'$$,
  '23514', null, 'visibility is public or private');

set local role anon;
select is((select count(*)::int from events.events where id in ('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000002')), 1,
  'a visitor reads the public event only');
reset role;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select title from events.events where id in ('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000002')), 'Open class',
  'another signed-in user does not read the private one either');
reset role;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from events.events where id in ('a1000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000002')), 2,
  'the host reads both');
reset role;

select * from finish();
rollback;
