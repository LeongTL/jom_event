begin;
select plan(33);

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com', '{"full_name":"Alice Host"}'),   -- host of e1, e2
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com',   '{"full_name":"Bob Tan"}'),      -- attended
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com', '{"full_name":"Carol Lim"}'),    -- no-show
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com',  '{"full_name":"Dave"}'),         -- attended, event not completed
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com',   null),                           -- attended, no name
  ('ffffffff-0000-0000-0000-000000000006', 'fay@example.com',   '{"full_name":"Fay Wong"}'),     -- attended
  ('99999999-0000-0000-0000-000000000009', 'host2@example.com', '{"full_name":"Host Two"}');     -- a host nobody reviewed

create function pg_temp.ev(id uuid, host uuid, st text) returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                             accept_bookings, area, venue, lat, lng)
  values (id, host, 'Event ' || left(id::text, 8), st, 3000, 20, now() - interval '3 hours', now() - interval '1 hour',
          '24h', true, 'Bangsar', 'V', 3.129, 101.671)
$$;
select pg_temp.ev('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'ended');
select pg_temp.ev('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'published');   -- over, not completed yet
select pg_temp.ev('e3000000-0000-0000-0000-000000000003', '99999999-0000-0000-0000-000000000009', 'ended');

create function pg_temp.bk(n int, ev uuid, who uuid, st text) returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid, ev, who, 1, st,
          'KLS-' || lpad(n::text, 5, '0'), 'G', '601', 3000)
$$;
select pg_temp.bk(1, 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'attended');
select pg_temp.bk(2, 'e1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 'no_show');
select pg_temp.bk(3, 'e2000000-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000004', 'attended');
select pg_temp.bk(4, 'e1000000-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000005', 'attended');
select pg_temp.bk(5, 'e1000000-0000-0000-0000-000000000001', 'ffffffff-0000-0000-0000-000000000006', 'attended');
select pg_temp.bk(6, 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'cancelled');

-- helpers
select is(bookings.is_attended('b0000000-0000-0000-0000-000000000001'), true, 'is_attended: an attended booking');
select is(bookings.is_attended('b0000000-0000-0000-0000-000000000002'), false, 'is_attended: a no-show');
select is(events.is_ended('e1000000-0000-0000-0000-000000000001'), true, 'is_ended: a completed event');
select is(events.is_ended('e2000000-0000-0000-0000-000000000002'), false, 'is_ended: over but not completed');

-- bob reviews
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is(reviews.reviewable('b0000000-0000-0000-0000-000000000001'), true, 'reviewable: attended and the event is completed');
select is(reviews.reviewable('b0000000-0000-0000-0000-000000000006'), false, 'reviewable: a cancelled booking');
select set_config('t.r1', reviews.submit_review('b0000000-0000-0000-0000-000000000001', 5,
  array['friendly_host', 'good_value', 'good_value'], '  Lovely evening, great teacher  ')::text, true);
reset role;
select results_eq($$select booking_id, event_id, host_id, attendee_id, stars, tags, body from reviews.reviews where id = current_setting('t.r1')::uuid$$,
  $$values ('b0000000-0000-0000-0000-000000000001'::uuid, 'e1000000-0000-0000-0000-000000000001'::uuid,
            'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'bbbbbbbb-0000-0000-0000-000000000002'::uuid, 5,
            array['friendly_host', 'good_value'], 'Lovely evening, great teacher')$$,
  'attended_guest_can_review_once (tags deduped, text trimmed, host and event taken from the booking)');

set local role authenticated;
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000001', 4, '{}', null)$$, 'P0001', 'already_reviewed',
  'second_review_for_same_booking_raises');
select is(reviews.reviewable('b0000000-0000-0000-0000-000000000001'), true, 'reviewable is about eligibility, not whether a review exists');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000006', 4, '{}', null)$$, 'P0001', 'not_attended',
  'a cancelled booking cannot be reviewed');
reset role;

-- carol (no-show), dave (event not completed), someone else's booking
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000002', 5, '{}', null)$$, 'P0001', 'not_attended',
  'no_show_cannot_review');
select is(reviews.reviewable('b0000000-0000-0000-0000-000000000002'), false, 'reviewable: false for a no-show');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 5, '{}', null)$$, 'P0001', 'not_owner',
  'another_users_booking_cannot_be_reviewed');
reset role;
select set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000003', 5, '{}', null)$$, 'P0001', 'event_not_completed',
  'review_before_event_completed_raises');
select is(reviews.reviewable('b0000000-0000-0000-0000-000000000003'), false, 'reviewable: false until the event is completed');
reset role;

-- validation, with eve (attended, no name)
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 0, '{}', null)$$, 'P0001', 'stars_out_of_range', 'stars_outside_1_to_5_raise: 0');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 6, '{}', null)$$, 'P0001', 'stars_out_of_range', 'stars 6');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', null, '{}', null)$$, 'P0001', 'stars_out_of_range', 'stars null');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 4, array['friendly_host', 'rude'], null)$$, 'P0001', 'unknown_tag',
  'unknown_tag_raises');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 4, '{}', 'call me 0123456789')$$, 'P0001', 'contact_info_not_allowed',
  'body_with_contact_info_is_rejected: phone');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 4, '{}', 'dm me at wa.me/60123456789')$$, 'P0001', 'contact_info_not_allowed',
  'body with a wa.me link');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 4, '{}', repeat('a', 1001))$$, 'P0001', 'body_too_long',
  'a review over 1000 characters');
select is((select count(*)::int from reviews.reviews where attendee_id = 'eeeeeeee-0000-0000-0000-000000000005'), 0, 'rejected reviews leave nothing behind');
select lives_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000004', 4, null, '   ')$$, 'tags and text are optional');
reset role;
select results_eq($$select tags, body from reviews.reviews where attendee_id = 'eeeeeeee-0000-0000-0000-000000000005'$$,
  $$values ('{}'::text[], null::text)$$, 'missing tags become an empty list and blank text becomes null');

-- fay gives 4 stars: ratings 5, 4, 4
select set_config('request.jwt.claims', '{"sub":"ffffffff-0000-0000-0000-000000000006","role":"authenticated"}', true);
set local role authenticated;
select reviews.submit_review('b0000000-0000-0000-0000-000000000005', 4, array['clean_venue'], 'Nice venue');
select results_eq($$select id from reviews.my_reviews()$$, $$select id from reviews.reviews where attendee_id = 'ffffffff-0000-0000-0000-000000000006'$$,
  'my_reviews lists only my own');
reset role;

-- public reading
set local role anon;
select results_eq($$select average, count from reviews.host_rating where host_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values (4.3::numeric, 3)$$, 'host_rating_averages_to_one_decimal (5, 4, 4 gives 4.3 from 3 reviews)');
select is((select count(*)::int from reviews.host_rating where host_id = '99999999-0000-0000-0000-000000000009'), 0,
  'a host nobody reviewed has no rating row');
select results_eq($$select attendee_first_name, stars, body from reviews.host_reviews('aaaaaaaa-0000-0000-0000-000000000001') order by stars desc, attendee_first_name$$,
  $$values ('Bob'::text, 5, 'Lovely evening, great teacher'::text), ('Fay', 4, 'Nice venue'), ('Guest', 4, null)$$,
  'anon_can_read_host_reviews: first names only, a guest with no name shows as Guest');
select is((select count(*)::int from reviews.host_reviews('aaaaaaaa-0000-0000-0000-000000000001', 2)), 2, 'host_reviews respects the limit');
select throws_ok($$select * from reviews.reviews$$, '42501', null, 'anon_cannot_read_attendee_ids: the table itself is closed to visitors');
select throws_ok($$select reviews.submit_review('b0000000-0000-0000-0000-000000000001', 5, '{}', null)$$, '42501', null, 'signed-out visitors cannot review');
reset role;

set local role authenticated;
select throws_ok($$insert into reviews.reviews (booking_id, event_id, host_id, attendee_id, stars) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 5)$$,
  '42501', null, 'clients cannot write reviews directly');
reset role;

select * from finish();
rollback;
