begin;
select plan(18);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
update identity.profiles set is_host = true where user_id in
  ('aaaaaaaa-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003');
insert into identity.hosts (user_id, host_name, area, verified_at) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice Studio', 'Bangsar', now()),
  ('cccccccc-0000-0000-0000-000000000003', 'Carol Crew', 'KLCC', null);

create function pg_temp.ev(n int, t text, host text, s text, e text, price int default 3000, cats text[] default '{make}',
                           st text default 'published', lat float8 default 3.1290, lng float8 default 101.6710,
                           area text default 'Bangsar') returns void language sql as $$
  insert into events.events (id, host_id, title, starts_at, ends_at, price_sen, lat, lng, categories, status, capacity,
                             area, venue, cancel_policy)
  values (('e0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, host::uuid, t, s::timestamptz, e::timestamptz,
          price, lat, lng, cats, st, 10, area, 'V', '48h')
$$;
create function pg_temp.bk(n int, ev int, who uuid, status text, people int, amount int default 3000) returns void
language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, ('e0000000-0000-0000-0000-' || lpad(ev::text, 12, '0'))::uuid,
          who, people, status, 'KLS-' || lpad(n::text, 5, '0'), 'Bob', '601', amount)
$$;

-- now = Wed 14 Oct 2026 15:00 KL
select set_config('t.now', '2026-10-14 15:00+08', true);
select pg_temp.ev(1, 'Sunrise Run', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-14 19:00+08', '2026-10-14 21:00+08', 0, '{move}');
select pg_temp.ev(2, 'Clay Night', 'cccccccc-0000-0000-0000-000000000003', '2026-10-14 20:00+08', '2026-10-14 22:00+08', 5000, '{make,meet}', area => 'KLCC');
select pg_temp.ev(3, 'Next week', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-21 19:00+08', '2026-10-21 21:00+08');
select pg_temp.ev(4, 'Promo 100% off_sale', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-15 19:00+08', '2026-10-15 21:00+08');
select pg_temp.ev(5, 'Old one', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-01 19:00+08', '2026-10-01 21:00+08', st => 'ended');
select pg_temp.ev(6, 'A draft', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-16 19:00+08', '2026-10-16 21:00+08', st => 'draft');
select pg_temp.ev(7, 'Far away', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-14 19:00+08', '2026-10-14 21:00+08', lat => 5.4, lng => 100.3);

select pg_temp.bk(1, 1, 'bbbbbbbb-0000-0000-0000-000000000002', 'confirmed', 2);
select pg_temp.bk(2, 1, 'cccccccc-0000-0000-0000-000000000003', 'attended', 1);
select pg_temp.bk(3, 1, 'cccccccc-0000-0000-0000-000000000003', 'held', 1);
select pg_temp.bk(4, 1, 'cccccccc-0000-0000-0000-000000000003', 'cancelled', 1);
select pg_temp.bk(5, 1, 'cccccccc-0000-0000-0000-000000000003', 'expired', 1);

create function pg_temp.q(p text default null, c text default 'all') returns text language sql as $$
  select string_agg(title, ',' order by title) from events.list_all(3.1290, 101.6710, c, 5, current_setting('t.now')::timestamptz, p)
$$;

select is((select host_name || '|' || host_verified || '|' || going || '|' || cancel_policy || '|' || lat::text from events.feed('night', 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz) where title = 'Sunrise Run'),
  'Alice Studio|true|3|48h|3.129', 'feed_rows_carry_host_name_cancel_policy_going_and_coordinates');
select is((select host_verified from events.list_all(3.1290, 101.6710, 'all', 5, current_setting('t.now')::timestamptz) where title = 'Clay Night'),
  false, 'host_verified_is_false_until_verified_at_is_set');
select is(bookings.going_count('e0000000-0000-0000-0000-000000000001'), 3,
  'going_counts_people_in_confirmed_and_attended_only (2 + 1; held, cancelled, expired count 0)');
select is((select count(*)::int from pg_attribute where attrelid = 'events.event_card'::regtype::text::regclass::oid
           and attname ~ 'attendee|user_id'), 0, 'going_returns_a_number_and_no_attendee_ids');
select is(pg_temp.q('SUNRISE'), 'Sunrise Run', 'list_all_query_matches_title_case_insensitively');
select is(pg_temp.q('alice'), 'Next week,Promo 100% off_sale,Sunrise Run', 'list_all_query_matches_host_name');
select is(pg_temp.q('klcc'), 'Clay Night', 'list_all_query_matches_area');
select is(pg_temp.q('%'), 'Promo 100% off_sale', 'list_all_query_percent_sign_matches_only_a_title_that_has_one');
select is(pg_temp.q('_'), 'Promo 100% off_sale', 'list_all_query_underscore_is_literal');
select is(pg_temp.q('run', 'move'), 'Sunrise Run', 'list_all_category_and_query_combine_with_and');
select is(pg_temp.q('run', 'make'), null, 'list_all_category_and_query_combine_with_and (no overlap)');

select is((select string_agg(title, ',' order by title) from events.map_pins(3.1290, 101.6710, 5, 'all', false, current_setting('t.now')::timestamptz)),
  'Clay Night,Next week,Promo 100% off_sale,Sunrise Run', 'map_pins_stay_within_the_radius');
select is((select string_agg(title, ',' order by title) from events.map_pins(3.1290, 101.6710, 5, 'all', true, current_setting('t.now')::timestamptz)),
  'Clay Night,Sunrise Run', 'map_pins_tonight_excludes_later_days');
select is((select string_agg(title, ',' order by title) from events.map_pins(3.1290, 101.6710, 5, 'meet', false, current_setting('t.now')::timestamptz)),
  'Clay Night', 'map_pins_category_matches_any_of_the_event_categories');

do $$ begin
  for i in 100..140 loop
    perform pg_temp.ev(i, 'bulk ' || i, 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-14 19:00+08', '2026-10-14 21:00+08');
  end loop;
end $$;
select is((select count(*)::int from events.map_pins(3.1290, 101.6710, 5, 'all', false, current_setting('t.now')::timestamptz)), 30,
  'map_pins_returns_at_most_30');

select is((select string_agg(title, ',' order by title) from events.cards(
    array['e0000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000005',
          'e0000000-0000-0000-0000-000000000006']::uuid[])),
  'Old one,Sunrise Run', 'cards_returns_only_requested_published_or_ended_ids');
select is((select lat::text from events.cards(array['e0000000-0000-0000-0000-000000000007']::uuid[], 1.0, 1.0)),
  '5.4', 'lat_lng_are_the_events_not_the_callers');
select is(events.host_event_count('aaaaaaaa-0000-0000-0000-000000000001'), 46, 'host_event_count_ignores_drafts_and_cancelled');

select * from finish();
rollback;
