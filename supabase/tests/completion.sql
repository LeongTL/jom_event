begin;
select plan(21);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),  -- host
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),    -- attends
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com'),  -- no-show
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com'),   -- attends
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com');    -- another host

create function pg_temp.ev(id uuid, ends interval, st text default 'published') returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                             accept_bookings, area, venue, lat, lng)
  values (id, 'aaaaaaaa-0000-0000-0000-000000000001', 'Event ' || left(id::text, 8), st, 3000, 10,
          now() + ends - interval '2 hours', now() + ends, '24h', true, 'Bangsar', 'V', 3.129, 101.671)
$$;
select pg_temp.ev('e1000000-0000-0000-0000-000000000001', interval '-1 hour');                 -- over, within 24 h
select pg_temp.ev('e2000000-0000-0000-0000-000000000002', interval '2 hours');                 -- not over
select pg_temp.ev('e3000000-0000-0000-0000-000000000003', interval '-25 hours');               -- over 25 h ago
select pg_temp.ev('e4000000-0000-0000-0000-000000000004', interval '-23 hours');               -- over 23 h ago
select pg_temp.ev('e5000000-0000-0000-0000-000000000005', interval '-2 hours', 'cancelled');
select pg_temp.ev('e6000000-0000-0000-0000-000000000006', interval '-2 hours', 'draft');
select pg_temp.ev('e7000000-0000-0000-0000-000000000007', interval '-26 hours', 'ended');

create function pg_temp.bk(id uuid, ev uuid, who uuid, st text) returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values (id, ev, who, 1, st, 'KLS-' || left(id::text, 5), 'Guest', '6011', 3000);
  insert into payments.fee_snapshots (booking_id, gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen)
  select id, 3000, f.gateway_fee_sen, f.platform_fee_sen, f.host_receives_sen from payments.compute_fees(3000) f
$$;
select pg_temp.bk('b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'attended');
select pg_temp.bk('b2000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 'confirmed');
select pg_temp.bk('b3000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000004', 'attended');
select pg_temp.bk('b4000000-0000-0000-0000-000000000004', 'e3000000-0000-0000-0000-000000000003', 'bbbbbbbb-0000-0000-0000-000000000002', 'confirmed');
select pg_temp.bk('b5000000-0000-0000-0000-000000000005', 'e4000000-0000-0000-0000-000000000004', 'bbbbbbbb-0000-0000-0000-000000000002', 'confirmed');
select pg_temp.bk('b6000000-0000-0000-0000-000000000006', 'e2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'confirmed');

-- refused: too early, wrong person, wrong state
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.complete_event('e2000000-0000-0000-0000-000000000002')$$, 'P0001', 'event_not_over',
  'complete_before_end_is_refused');
select throws_ok($$select events.complete_event('e5000000-0000-0000-0000-000000000005')$$, 'P0001', 'not_completable',
  'a cancelled event cannot be completed');
select throws_ok($$select events.complete_event('e6000000-0000-0000-0000-000000000006')$$, 'P0001', 'not_completable',
  'a draft cannot be completed');
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
select throws_ok($$select events.complete_event('e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_owner',
  'only the host can complete');
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($$select events.complete_event('e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_owner',
  'a guest cannot complete');
reset role;
set local role anon;
select throws_ok($$select events.complete_event('e1000000-0000-0000-0000-000000000001')$$, '42501', null,
  'signed-out visitors cannot complete');
reset role;
select is((select status from events.events where id = 'e2000000-0000-0000-0000-000000000002'), 'published', 'a refused completion changes nothing');

-- the host completes
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select events.complete_event('e1000000-0000-0000-0000-000000000001');
reset role;
select is((select status from events.events where id = 'e1000000-0000-0000-0000-000000000001'), 'ended', 'completing ends the event');
select results_eq(
  $$select id, status from bookings.bookings where event_id = 'e1000000-0000-0000-0000-000000000001' order by id$$,
  $$values ('b1000000-0000-0000-0000-000000000001'::uuid, 'attended'), ('b2000000-0000-0000-0000-000000000002', 'no_show'),
           ('b3000000-0000-0000-0000-000000000003', 'attended')$$,
  'complete_marks_unchecked_as_no_show_and_keeps_attended');
select is((select count(*)::int from identity.notifications where type = 'review_request' and ref_id = 'e1000000-0000-0000-0000-000000000001'),
  2, 'completion_sends_review_request_only_to_attended_guests: two requests');
select is((select count(*)::int from identity.notifications where type = 'review_request' and user_id = 'cccccccc-0000-0000-0000-000000000003'),
  0, 'the no-show gets no review request');
select is((select count(*)::int from identity.notifications where type = 'payout' and user_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  1, 'the host gets a payout notice');

-- completing twice changes nothing
create temp table before_second as
  select (select count(*) from identity.notifications) as notes, (select count(*) from payments.payouts) as payouts,
         (select string_agg(id::text || status, ',' order by id) from bookings.bookings) as states;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$select events.complete_event('e1000000-0000-0000-0000-000000000001')$$, 'complete_twice_changes_nothing: no error');
reset role;
select results_eq(
  $$select (select count(*) from identity.notifications), (select count(*) from payments.payouts),
           (select string_agg(id::text || status, ',' order by id) from bookings.bookings)$$,
  $$select notes, payouts, states from before_second$$, 'a second completion adds no notices, payouts or state changes');

-- the 24-hour job
set local role authenticated;
select throws_ok($$select events.auto_complete()$$, '42501', null, 'auto_complete is not callable by clients');
reset role;
select is(events.auto_complete(), 1, 'auto_complete_picks_only_events_ended_more_than_24h_ago');
select is((select status from events.events where id = 'e3000000-0000-0000-0000-000000000003'), 'ended', 'the 25-hour-old event is completed');
select is((select status from events.events where id = 'e4000000-0000-0000-0000-000000000004'), 'published', 'the 23-hour-old event is not yet completed by the job');
select is((select status from bookings.bookings where id = 'b4000000-0000-0000-0000-000000000004'), 'no_show', 'the job marks no-shows too');
select is((select status from events.events where id = 'e2000000-0000-0000-0000-000000000002'), 'published', 'an event that has not ended is left alone');
select is(events.auto_complete(), 0, 'running the job again finds nothing');

select * from finish();
rollback;
