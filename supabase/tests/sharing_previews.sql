begin;
select plan(17);

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'host@example.com', '{"full_name":"Mei Host"}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'guest@example.com', '{"full_name":"Guest Gus"}'),
  ('cccccccc-0000-0000-0000-000000000003', 'pending@example.com', '{"full_name":"Pending Pat"}');
update identity.profiles set username = 'meihost' where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
update identity.profiles set username = 'gusgus' where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
update identity.profiles set username = 'patpat' where user_id = 'cccccccc-0000-0000-0000-000000000003';
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into identity.hosts (user_id, host_name, area, status, avatar_url) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Mei Studio', 'Bangsar', 'approved', 'https://img.invalid/mei.jpg'),
  ('cccccccc-0000-0000-0000-000000000003', 'Pat Pottery', 'PJ', 'pending', null);

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue, poster_url,
                           lat, lng, cancel_policy, accept_bookings, visibility, share_code) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Public class', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 'Deck 5', 'https://img.invalid/p.jpg', 3.1, 101.6, '24h', true, 'public', 'PUBCODE001'),
  ('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Secret supper', 'published', 0, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 'Hidden', null, 3.1, 101.6, '24h', true, 'private', 'PRVCODE002'),
  ('e3000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'A draft', 'draft', 3000, 10,
   null, null, null, null, null, null, null, '24h', true, 'public', 'DRFCODE003'),
  ('e4000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'Called off', 'cancelled', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 'Deck 5', null, 3.1, 101.6, '24h', true, 'public', 'CNLCODE004'),
  ('e5000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'Done', 'ended', 3000, 10,
   now() - interval '3 days', now() - interval '3 days' + interval '2 hours', 'Bangsar', 'Deck 5', null, 3.1, 101.6, '24h', true, 'public', 'ENDCODE005');

set local role anon;
select results_eq($$select title, area, venue, price_sen, poster_url, host_name, status, is_private from events.share_preview('PUBCODE001')$$,
  $$values ('Public class', 'Bangsar', 'Deck 5', 3000, 'https://img.invalid/p.jpg', 'Mei Studio', 'published', false)$$,
  'anon previews a public event');
select results_eq($$select title, price_sen, is_private from events.share_preview('PRVCODE002')$$,
  $$values ('Secret supper', 0, true)$$, 'and a private one, free, marked private');
select is((select count(*)::int from events.share_preview('DRFCODE003')), 0, 'a draft has no preview');
select is((select count(*)::int from events.share_preview('CNLCODE004')), 0, 'a cancelled event has no preview');
select is((select status from events.share_preview('ENDCODE005')), 'ended', 'an ended event still previews');
select is((select count(*)::int from events.share_preview('NOSUCHCODE')), 0, 'an unknown code has none');
select is((select count(*)::int from events.share_preview('')), 0, 'an empty code has none');
select is((select count(*)::int from events.share_preview(null)), 0, 'a null code has none');
reset role;

select is((select pronargs from pg_proc where oid = 'events.share_preview(text)'::regprocedure), 1::smallint, 'one argument');

-- person_preview: hosts for anyone, guests only for a signed-in caller
set local role anon;
select results_eq($$select name, username, is_host, area, avatar_url from identity.person_preview('meihost')$$,
  $$values ('Mei Studio', 'meihost', true, 'Bangsar', 'https://img.invalid/mei.jpg')$$, 'anon previews an approved host');
select is((select count(*)::int from identity.person_preview('gusgus')), 0, 'anon gets no preview of a guest');
select is((select count(*)::int from identity.person_preview('patpat')), 0, 'a pending applicant is not a host and is a guest to anon');
select is(identity.user_id_by_username('MeiHost'), 'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'username lookup is case-insensitive');
select is(identity.user_id_by_username('gusgus'), null, 'anon cannot resolve a guest');
select is(identity.user_id_by_username('nobody'), null, 'unknown name is null');
reset role;

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select results_eq($$select name, is_host, area from identity.person_preview('gusgus')$$,
  $$values ('Guest Gus', false, null::text)$$, 'a signed-in caller previews a guest, no area');
select is(identity.user_id_by_username('gusgus'), 'bbbbbbbb-0000-0000-0000-000000000002'::uuid, 'and resolves the name');
reset role;

select * from finish();
rollback;
