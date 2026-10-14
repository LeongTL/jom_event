begin;
select plan(24);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
update identity.profiles set is_host = true;

-- Sells seats through real bookings (postgres only): n seats as bookings of two people.
create function pg_temp.sell(eid uuid, n int) returns void language sql as $$
  insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  select eid, 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'confirmed', 'T-' || gen_random_uuid()::text, 'Guest', '601', 0
    from generate_series(1, n / 2) g
$$;

select set_config('t.base', jsonb_build_object(
  'title', 'Pottery night', 'description', 'Bring a mat to the studio',
  'categories', jsonb_build_array('make'), 'area', 'Bangsar', 'venue', 'Studio 3, Jalan Telawi',
  'starts_at', now() + interval '3 days', 'ends_at', now() + interval '3 days 3 hours',
  'capacity', 12, 'price_sen', 3000, 'cancel_policy', '48h', 'accept_bookings', true)::text, true);

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

-- a draft changes freely
select set_config('t.draft', events.save_draft(current_setting('t.base')::jsonb)::text, true);
select events.save_draft(jsonb_build_object('id', current_setting('t.draft'),
  'price_sen', 5000, 'venue', 'Another place', 'starts_at', now() + interval '5 days', 'ends_at', now() + interval '5 days 2 hours'));
reset role;
select results_eq(
  $$select price_sen, venue from events.events where id = current_setting('t.draft')::uuid$$,
  $$values (5000, 'Another place')$$,
  'draft_can_change_price_and_date_freely');

-- a published event with no guests can still change them
set local role authenticated;
select set_config('t.eid', events.save_draft(current_setting('t.base')::jsonb)::text, true);
select events.publish(current_setting('t.eid')::uuid);
select events.save_draft(jsonb_build_object('id', current_setting('t.eid'), 'price_sen', 4000, 'venue', 'Moved'));
reset role;
select results_eq(
  $$select price_sen, venue from events.events where id = current_setting('t.eid')::uuid$$,
  $$values (4000, 'Moved')$$,
  'published_event_without_guests_can_still_change_price');

-- blanking a required field on a published event is refused
set local role authenticated;
select throws_ok($$select events.save_draft(jsonb_build_object('id', current_setting('t.eid'), 'venue', null))$$,
  'P0001', 'event_incomplete', 'published_event_cannot_lose_a_required_field');

-- once guests have joined, date, venue, price, policy, categories, switch and area are locked
reset role;
select pg_temp.sell(current_setting('t.eid')::uuid, 12);
set local role authenticated;
select throws_ok(
  format($$select events.save_draft(jsonb_build_object('id', current_setting('t.eid')) || %L::jsonb)$$, c.v),
  'P0001', 'locked_after_guests', 'published_event_with_guests_rejects_change_of_' || c.f)
  from (values
    ('price_sen',       '{"price_sen": 100}'),
    ('starts_at',       jsonb_build_object('starts_at', now() + interval '9 days')::text),
    ('ends_at',         jsonb_build_object('ends_at', now() + interval '9 days')::text),
    ('venue',           '{"venue": "Elsewhere"}'),
    ('cancel_policy',   '{"cancel_policy": "none"}'),
    ('categories',      '{"categories": ["move"]}'),
    ('accept_bookings', '{"accept_bookings": false}'),
    ('area',            '{"area": "KLCC"}')
  ) as c(f, v);

-- ... but the same values re-sent are fine, and title, description and spots still change
select events.save_draft(jsonb_build_object('id', current_setting('t.eid'), 'price_sen', 4000, 'venue', 'Moved',
  'title', 'Pottery night v2', 'description', 'New description', 'capacity', 15));
reset role;
select results_eq(
  $$select title, description, capacity from events.events where id = current_setting('t.eid')::uuid$$,
  $$values ('Pottery night v2', 'New description', 15)$$,
  'with guests, locked fields can be re-sent unchanged and title, description, spots still change');
set local role authenticated;
select throws_ok($$select events.save_draft(jsonb_build_object('id', current_setting('t.eid'), 'capacity', 11))$$,
  'P0001', 'capacity_below_seats_sold', 'save_draft_rejects_capacity_below_seats_sold');

-- update_event: the limited edit
select events.update_event(current_setting('t.eid')::uuid, 'Pottery night v3', 'Third description', 20);
reset role;
select results_eq(
  $$select title, description, capacity, price_sen, venue from events.events where id = current_setting('t.eid')::uuid$$,
  $$values ('Pottery night v3', 'Third description', 20, 4000, 'Moved')$$,
  'update_event_changes_only_title_description_capacity_after_publish');
set local role authenticated;
select throws_ok($$select events.update_event(current_setting('t.eid')::uuid, 't', 'd', 11)$$,
  'P0001', 'capacity_below_seats_sold', 'update_event_rejects_capacity_below_seats_sold');
select lives_ok($$select events.update_event(current_setting('t.eid')::uuid, 't', 'd', 12)$$,
  'update_event_accepts_capacity_equal_to_seats_sold');
select throws_ok(format($$select events.update_event(current_setting('t.eid')::uuid, 't', 'd', %s)$$, c),
  'P0001', 'capacity_out_of_range', 'update_event_rejects_capacity_' || c)
  from unnest(array[0, 41]) as c;
select throws_ok($$select events.update_event(current_setting('t.eid')::uuid, 't', 'ring 012 345 6789', 12)$$,
  'P0001', 'contact_info_not_allowed', 'update_event_rejects_contact_info');
reset role;

select ok(events.has_guests(current_setting('t.eid')::uuid), 'has_guests_is_true_when_seats_are_taken');
delete from bookings.bookings;
select ok(not events.has_guests(current_setting('t.eid')::uuid), 'has_guests_is_false_with_no_seats_taken');

-- other hosts and closed events
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.update_event(current_setting('t.eid')::uuid, 'hijack', 'd', 12)$$,
  'P0001', 'not_owner', 'update_event_by_another_host_is_refused');
reset role;

update events.events set status = 'ended' where id = current_setting('t.eid')::uuid;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.update_event(current_setting('t.eid')::uuid, 't', 'd', 12)$$,
  'P0001', 'event_closed', 'update_event_on_an_ended_event_is_refused');
select throws_ok($$select events.save_draft(jsonb_build_object('id', current_setting('t.eid'), 'title', 'x'))$$,
  'P0001', 'event_closed', 'save_draft_on_an_ended_event_is_refused');
reset role;

select * from finish();
rollback;
