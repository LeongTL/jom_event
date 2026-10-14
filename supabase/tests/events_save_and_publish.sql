begin;
select plan(23);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
update identity.profiles set is_host = true
 where user_id in ('aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003');

select set_config('t.base', jsonb_build_object(
  'title', 'Pottery night', 'description', 'Bring a mat to the studio',
  'glyph', '🏺', 'color_a', '#ff7a59', 'color_b', '#ffb199',
  'categories', jsonb_build_array('make'), 'area', 'Bangsar', 'venue', 'Studio 3, Jalan Telawi',
  'starts_at', now() + interval '3 days', 'ends_at', now() + interval '3 days 3 hours',
  'capacity', 12, 'price_sen', 3000, 'cancel_policy', '48h', 'accept_bookings', true)::text, true);

-- alice (host) saves a draft
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.eid', events.save_draft(current_setting('t.base')::jsonb)::text, true);
reset role;
select results_eq(
  $$select status, host_id from events.events where id = current_setting('t.eid')::uuid$$,
  $$values ('draft', 'aaaaaaaa-0000-0000-0000-000000000001'::uuid)$$,
  'save_draft creates a draft owned by the caller');

set local role authenticated;
select set_config('t.eid2', events.save_draft(current_setting('t.base')::jsonb
  || '{"status":"published","host_id":"bbbbbbbb-0000-0000-0000-000000000002"}')::text, true);
reset role;
select results_eq(
  $$select status, host_id from events.events where id = current_setting('t.eid2')::uuid$$,
  $$values ('draft', 'aaaaaaaa-0000-0000-0000-000000000001'::uuid)$$,
  'save_draft ignores status and host_id in the payload');

set local role authenticated;
select throws_ok($$select events.save_draft(current_setting('t.base')::jsonb - 'title')$$,
  'P0001', 'title_required', 'save_draft_requires_a_title');
select throws_ok($$select events.save_draft(current_setting('t.base')::jsonb || '{"description":"call me on 012-345 6789"}')$$,
  'P0001', 'contact_info_not_allowed', 'description_with_phone_number_is_rejected');
select throws_ok($$select events.save_draft(current_setting('t.base')::jsonb || '{"title":"DM @mei.studio"}')$$,
  'P0001', 'contact_info_not_allowed', 'title_with_a_handle_is_rejected');
select throws_ok(format($$select events.save_draft(current_setting('t.base')::jsonb || '{"capacity":%s}')$$, c),
  'P0001', 'capacity_out_of_range', 'capacity ' || c || ' is rejected')
  from unnest(array[0, 41]) as c;

-- publish needs every field
select throws_ok(
  format($$select events.publish(events.save_draft(%L::jsonb))$$, (current_setting('t.base')::jsonb - f)::text),
  'P0001', 'event_incomplete', 'publish_requires_' || f)
  from unnest(array['venue', 'area', 'starts_at', 'ends_at', 'capacity', 'price_sen']) as f;
select throws_ok(
  format($$select events.publish(events.save_draft(%L::jsonb))$$,
    (current_setting('t.base')::jsonb || jsonb_build_object('ends_at', now() + interval '2 days'))::text),
  'P0001', 'invalid_times', 'publish_requires_end_after_start');
select throws_ok(
  format($$select events.publish(events.save_draft(%L::jsonb))$$,
    (current_setting('t.base')::jsonb || jsonb_build_object(
      'starts_at', now() - interval '1 day', 'ends_at', now() - interval '21 hours'))::text),
  'P0001', 'starts_in_past', 'publish_requires_a_future_start');

-- publish, then again
select events.publish(current_setting('t.eid')::uuid);
reset role;
select is((select status from events.events where id = current_setting('t.eid')::uuid), 'published',
  'publish_moves_a_draft_to_published');
select ok((select lat is not null and lng is not null from events.events where id = current_setting('t.eid')::uuid),
  'publish_fills_coordinates_from_the_area_centre');
set local role authenticated;
select throws_ok($$select events.publish(current_setting('t.eid')::uuid)$$,
  'P0001', 'not_a_draft', 'publish_twice_raises');
reset role;

-- who may call what
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.save_draft(current_setting('t.base')::jsonb)$$,
  'P0001', 'not_a_host', 'save_draft_requires_a_host');
reset role;

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.save_draft(current_setting('t.base')::jsonb || jsonb_build_object('id', current_setting('t.eid')))$$,
  'P0001', 'not_owner', 'only_owner_host_can_edit_with_save_draft');
select throws_ok($$select events.publish(current_setting('t.eid2')::uuid)$$,
  'P0001', 'not_owner', 'only_owner_host_can_publish');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select events.save_draft('{"title":"x"}')$$, '42501', null, 'save_draft_requires_login');
select throws_ok($$select events.publish('eeeeeeee-0000-0000-0000-000000000001')$$, '42501', null, 'publish_requires_login');
reset role;

select * from finish();
rollback;
