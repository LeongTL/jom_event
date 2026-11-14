begin;
select plan(16);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'host@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'guest@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'outsider@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into identity.hosts (user_id, host_name, area) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Host', 'Bangsar');

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue, lat, lng, cancel_policy, visibility, categories) values
  ('b1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Secret class', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 'V', 3.129, 101.671, '24h', 'private', array['make']),
  ('b2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Open class', 'published', 3000, 10,
   now() + interval '3 days', now() + interval '3 days 2 hours', 'Bangsar', 'V', 3.129, 101.671, '24h', 'public', array['make']),
  ('b3000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Past secret', 'ended', 3000, 10,
   now() - interval '3 days', now() - interval '3 days' + interval '2 hours', 'Bangsar', 'V', 3.129, 101.671, '24h', 'private', array['make']);
insert into events.events (id, host_id, title, visibility) values
  ('b4000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', 'Draft', 'private');
insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen) values
  ('0b100000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'confirmed', 'T-1', 'G', '601', 3000),
  ('0b200000-0000-0000-0000-000000000002', 'b2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'confirmed', 'T-2', 'G', '601', 3000),
  ('0b300000-0000-0000-0000-000000000003', 'b3000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'attended', 'T-3', 'G', '601', 3000);

-- opening by code (the codes are read as the superuser: anon cannot read a private row, only open it with the code)
select set_config('t.code1', (select share_code from events.events where id = 'b1000000-0000-0000-0000-000000000001'), true);
select set_config('t.code3', (select share_code from events.events where id = 'b3000000-0000-0000-0000-000000000003'), true);
select set_config('t.code4', (select share_code from events.events where id = 'b4000000-0000-0000-0000-000000000004'), true);
set local role anon;
select is((select visibility from events.event_by_code(current_setting('t.code1'))), 'private',
  'a visitor opens a private event with its code');
select is((select count(*)::int from events.event_by_code('nosuchcode1')), 0, 'an unknown code gives nothing');
select is((select count(*)::int from events.event_by_code(current_setting('t.code4'))), 0,
  'a draft cannot be opened by its code');
select is((select count(*)::int from events.event_by_code(current_setting('t.code3'))), 1,
  'an ended private event still opens by code');
reset role;

-- the guest who has a booking still has the event everywhere
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select visibility from events.event_detail('b1000000-0000-0000-0000-000000000001')), 'private', 'event_detail by id carries the visibility');
select is((select count(*)::int from bookings.my_bookings('upcoming') where event_id = 'b1000000-0000-0000-0000-000000000001'), 1,
  'Tickets still shows a private event');
select set_config('t.th', chat.open_thread('aaaaaaaa-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001')::text, true);
select chat.send_message(current_setting('t.th')::uuid, 'hello');
select is((select event_title from chat.my_threads() limit 1), 'Secret class', 'the chat thread carries the private event card');
select is(reviews.reviewable('0b300000-0000-0000-0000-000000000003'), true, 'a private ended event can still be reviewed');
reset role;

-- the booking brief (internal, used by receipts and reviews) still resolves a private event
select is((select count(*)::int from bookings.booking_brief('0b100000-0000-0000-0000-000000000001')), 1, 'the booking brief still resolves');

-- someone with only the link can save it
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is(identity.toggle_save('b1000000-0000-0000-0000-000000000001'), true, 'a private event can be saved');
select is((select count(*)::int from events.cards((select array_agg(event_id) from identity.saved_events)) ), 1, 'and Saved resolves it');
reset role;

-- the host changes visibility, also after a guest booked
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select events.update_event('b2000000-0000-0000-0000-000000000002', 'Open class', 'now private', 10, 'private');
select is((select visibility from events.host_events(null, 'b2000000-0000-0000-0000-000000000002')), 'private', 'visibility changed after guests joined');
select throws_ok($$select events.update_event('b2000000-0000-0000-0000-000000000002', 'Open class', 'x', 10, 'secret')$$, 'P0001', 'visibility_invalid',
  'only public or private');
select throws_ok($$select events.save_draft('{"title":"Bad","visibility":"secret"}'::jsonb)$$, 'P0001', 'visibility_invalid', 'save_draft rejects a bad value');
select set_config('t.draft', events.save_draft('{"title":"New thing","visibility":"private"}'::jsonb)::text, true);
select is((select visibility from events.host_events(null, current_setting('t.draft')::uuid)), 'private', 'save_draft stores visibility');
select matches((select share_code from events.host_events(null, 'b1000000-0000-0000-0000-000000000001')), '^[A-Za-z0-9]{10}$', 'the host reads the share code');
reset role;

select * from finish();
rollback;
