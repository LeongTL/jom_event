begin;
select plan(28);

-- Fixture helper (postgres only): a published event at the given place, 10 spots.
create function pg_temp.ev(t text, s text, e text, price int default 3000, lat float8 default 3.1290,
                           lng float8 default 101.6710, cats text[] default '{make}', st text default 'published')
returns void language sql as $$
  insert into events.events (host_id, title, starts_at, ends_at, price_sen, lat, lng, categories, status,
                             capacity, area, venue, cancel_policy)
  values ('aaaaaaaa-0000-0000-0000-000000000001', t, s::timestamptz, e::timestamptz, price, lat, lng, cats, st,
          10, 'Bangsar', 'V', '24h')
$$;

-- ===== the week of Wed 14 Oct 2026, 15:00 in Kuala Lumpur; the user stands in Bangsar =====
select pg_temp.ev('live',      '2026-10-14 14:00+08', '2026-10-14 17:00+08');
select pg_temp.ev('soon',      '2026-10-14 15:20+08', '2026-10-14 16:20+08');
select pg_temp.ev('in90',      '2026-10-14 16:30+08', '2026-10-14 18:00+08');
select pg_temp.ev('evening',   '2026-10-14 19:00+08', '2026-10-14 21:00+08');
select pg_temp.ev('late',      '2026-10-15 01:30+08', '2026-10-15 03:30+08');
select pg_temp.ev('tomorrow',  '2026-10-15 10:00+08', '2026-10-15 12:00+08');
select pg_temp.ev('friday',    '2026-10-16 11:00+08', '2026-10-16 13:00+08');
select pg_temp.ev('saturday',  '2026-10-17 11:00+08', '2026-10-17 13:00+08');
select pg_temp.ev('sunday',    '2026-10-18 11:00+08', '2026-10-18 13:00+08');
select pg_temp.ev('monday',    '2026-10-19 11:00+08', '2026-10-19 13:00+08');
select pg_temp.ev('x_ended',   '2026-10-14 15:30+08', '2026-10-14 16:30+08', st => 'ended');
select pg_temp.ev('x_cancel',  '2026-10-14 15:40+08', '2026-10-14 16:40+08', st => 'cancelled');
select pg_temp.ev('x_draft',   '2026-10-14 16:00+08', '2026-10-14 17:00+08', st => 'draft');
select pg_temp.ev('x_over',    '2026-10-14 12:00+08', '2026-10-14 14:00+08');   -- published but already over

select set_config('t.now', '2026-10-14 15:00+08', true);

select is((select string_agg(title, ',' order by title) from events.feed('now', 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)),
  'in90,live,soon', 'now_tab_has_live_and_next_120_minutes');
select is((select string_agg(title, ',' order by title) from events.feed('night', 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)),
  'evening,late', 'night_excludes_events_in_now_window');
select is((select string_agg(title, ',' order by title) from events.feed('weekend', 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)),
  'saturday,sunday', 'weekend_includes_saturday_and_sunday_only');
select is((select count(*)::int from (
    select title from events.feed('now', 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)
    union all select title from events.feed('night', 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)
    union all select title from events.feed('weekend', 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)
    union all select title from events.list_all(3.1290, 101.6710, 'all', 5, current_setting('t.now')::timestamptz)
  ) q where title like 'x\_%'), 0,
  'ended_cancelled_draft_and_over_events_are_in_no_tab');

-- the tab an event lands in follows Asia/Kuala_Lumpur, not the session zone
select set_config('t.tabs', (
  select string_agg(tab || ':' || ids, ';' order by tab) from (
    select t as tab, (select string_agg(title, ',' order by title)
                        from events.feed(t, 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)) as ids
      from unnest(array['now', 'night', 'weekend']) t) q), true);
set local timezone = 'America/New_York';
select is((select string_agg(tab || ':' || ids, ';' order by tab) from (
    select t as tab, (select string_agg(title, ',' order by title)
                        from events.feed(t, 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)) as ids
      from unnest(array['now', 'night', 'weekend']) t) q), current_setting('t.tabs'),
  'tabs_ignore_session_time_zone (New York)');
set local timezone = 'Asia/Tokyo';
select is((select string_agg(tab || ':' || ids, ';' order by tab) from (
    select t as tab, (select string_agg(title, ',' order by title)
                        from events.feed(t, 3.1290, 101.6710, 5, current_setting('t.now')::timestamptz)) as ids
      from unnest(array['now', 'night', 'weekend']) t) q), current_setting('t.tabs'),
  'tabs_ignore_session_time_zone (Tokyo)');
set local timezone = 'UTC';

select is((select string_agg(title, ',' order by title) from events.feed('night', 3.1290, 101.6710, 5, '2026-10-14 23:00+08')),
  'late', 'event_at_01_30_belongs_to_tonight_at_23_00');

select results_eq(
  $$select tab, n from events.tab_counts(3.1290, 101.6710, 5, '2026-10-14 15:00+08') order by tab$$,
  $$values ('all', 10), ('night', 2), ('now', 3), ('weekend', 2)$$,
  'tab_counts counts every event in each tab, not just the top 9');
select results_eq(
  $$select title from events.list_all(3.1290, 101.6710, 'all', 5, '2026-10-14 15:00+08')$$,
  $$values ('live'), ('soon'), ('in90'), ('evening'), ('late'), ('tomorrow'), ('friday'), ('saturday'), ('sunday'), ('monday')$$,
  'list_all_includes_every_upcoming_and_live_event_soonest_first');

-- ===== Saturday evening: a Saturday-night event is Night and Weekend =====
select pg_temp.ev('sat_morning', '2026-10-17 09:00+08', '2026-10-17 10:00+08');
select pg_temp.ev('sat_night',   '2026-10-17 21:00+08', '2026-10-17 23:30+08');
select is((select string_agg(title, ',' order by title) from events.feed('night', 3.1290, 101.6710, 5, '2026-10-17 17:00+08')),
  'sat_night', 'night_on_saturday_has_the_saturday_night_event');
select is((select string_agg(title, ',' order by title) from events.feed('weekend', 3.1290, 101.6710, 5, '2026-10-17 17:00+08')),
  'sat_night,sunday', 'saturday_night_event_is_in_night_and_weekend');

-- ===== Sunday noon: only what is left of this weekend =====
select pg_temp.ev('sun_evening', '2026-10-18 18:00+08', '2026-10-18 20:00+08');
select pg_temp.ev('next_sat',    '2026-10-24 11:00+08', '2026-10-24 13:00+08');
select is((select string_agg(title, ',' order by title) from events.feed('weekend', 3.1290, 101.6710, 5, '2026-10-18 12:00+08')),
  'sun_evening,sunday', 'weekend_on_sunday_shows_only_what_is_left');

-- ===== distance =====
select is(round(events.distance_km(0, 0, 1, 0)::numeric, 1), 111.2, 'distance_km: one degree of latitude is about 111.2 km');
select is(events.distance_km(3.129, 101.671, 3.129, 101.671), 0::float8, 'distance_km: same point is 0');
select is(events.distance_km(null, 101.671, 3.129, 101.671), null, 'distance_km: unknown location gives null');

-- ===== scoring and the top 9 (Mon 1 Mar 2027, 10:00) =====
select pg_temp.ev('T' || lpad(i::text, 2, '0'), '2027-03-01 11:00+08', '2027-03-01 12:00+08',
                   lat => 3.1290 + 0.01 * i)
  from generate_series(0, 11) i;
select results_eq(
  $$select title from events.feed('now', 3.1290, 101.6710, 50, '2027-03-01 10:00+08')$$,
  $$values ('T00'), ('T01'), ('T02'), ('T03'), ('T04'), ('T05'), ('T06'), ('T07'), ('T08')$$,
  'feed_returns_top_9_by_score (nearest first when all else is equal)');

select pg_temp.ev('s_live_free',  '2027-04-01 09:00+08', '2027-04-01 12:00+08', price => 0);
select pg_temp.ev('s_soon_paid',  '2027-04-01 10:10+08', '2027-04-01 11:00+08');
select pg_temp.ev('s_soon_free',  '2027-04-01 10:20+08', '2027-04-01 11:00+08', price => 0);
select pg_temp.ev('s_later_paid', '2027-04-01 11:30+08', '2027-04-01 12:30+08');
select pg_temp.ev('s_far',        '2027-04-01 11:30+08', '2027-04-01 12:30+08', lat => 3.2190);
select results_eq(
  $$select title, round(score::numeric, 4) from events.feed('now', 3.1290, 101.6710, 50, '2027-04-01 10:00+08') order by title$$,
  $$values ('s_far', round((-0.35 * events.distance_km(3.1290, 101.6710, 3.2190, 101.6710))::numeric, 4)),
           ('s_later_paid', 0.0000), ('s_live_free', 4.0000), ('s_soon_free', 3.0000), ('s_soon_paid', 2.0000)$$,
  'score_matches_formula (live +3, under 30 min +2, free +1, minus 0.35 per km)');

-- ===== radius, empty, no location (Sat 1 May 2027) =====
select pg_temp.ev('near', '2027-05-01 11:00+08', '2027-05-01 12:00+08', lat => 3.1290 + 0.027);
select pg_temp.ev('far',  '2027-05-01 11:00+08', '2027-05-01 12:00+08', lat => 3.1290 + 0.072);
select is((select string_agg(title, ',' order by title) from events.feed('now', 3.1290, 101.6710, 5, '2027-05-01 10:00+08')),
  'near', 'radius_filters_events (5 km)');
select is((select string_agg(title, ',' order by title) from events.feed('now', 3.1290, 101.6710, 10, '2027-05-01 10:00+08')),
  'far,near', 'radius_filters_events (10 km)');
select is((select string_agg(title, ',' order by title) from events.feed('now', null, null, 5, '2027-05-01 10:00+08')),
  'far,near', 'feed_without_location_ignores_distance');
select is((select count(*)::int from events.feed('now', 3.1290, 101.6710, 5, '2030-01-01 10:00+08')), 0,
  'feed_empty_returns_zero_rows');

-- ===== hero stats (Tue 1 Jun 2027) =====
select pg_temp.ev('h_live_free', '2027-06-01 09:00+08', '2027-06-01 12:00+08', price => 0);
select pg_temp.ev('h_live_paid', '2027-06-01 09:30+08', '2027-06-01 12:00+08');
select pg_temp.ev('h_soon_free', '2027-06-01 10:30+08', '2027-06-01 11:30+08', price => 0);
select pg_temp.ev('h_soon_far',  '2027-06-01 10:30+08', '2027-06-01 11:30+08', lat => 3.1290 + 0.036);
select results_eq(
  $$select total, live, free, round(closest_km::numeric, 3) from events.hero_stats('now', 3.1290, 101.6710, 5, '2027-06-01 10:00+08')$$,
  $$values (4, 2, 2, 0.000)$$,
  'hero_stats_counts_total_live_free_and_closest');

-- ===== view all categories (Thu 1 Jul 2027) =====
select pg_temp.ev('c_free',  '2027-07-01 20:00+08', '2027-07-01 21:00+08', price => 0, cats => '{meet}');
select pg_temp.ev('c_paid',  '2027-07-01 20:00+08', '2027-07-01 21:00+08', cats => '{move}');
select pg_temp.ev('c_both',  '2027-07-01 20:00+08', '2027-07-01 21:00+08', cats => '{make,meet}');
select is((select string_agg(title, ',' order by title) from events.list_all(3.1290, 101.6710, 'free', 5, '2027-07-01 10:00+08')),
  'c_free', 'list_all_free_filter_uses_price_zero');
select is((select string_agg(title, ',' order by title) from events.list_all(3.1290, 101.6710, 'make', 5, '2027-07-01 10:00+08')),
  'c_both', 'event_with_two_categories_appears_in_make');
select is((select string_agg(title, ',' order by title) from events.list_all(3.1290, 101.6710, 'meet', 5, '2027-07-01 10:00+08')),
  'c_both,c_free', 'event_with_two_categories_appears_in_meet_too');
select throws_ok($$select * from events.list_all(3.1290, 101.6710, 'cooking', 5, now())$$, 'P0001', 'unknown_category',
  'list_all_rejects_an_unknown_category');
select throws_ok($$select * from events.feed('later', 3.1290, 101.6710, 5, now())$$, 'P0001', 'unknown_tab',
  'feed_rejects_an_unknown_tab');

-- signed-out visitors can read the feed
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is((select count(*)::int from events.feed('now', 3.1290, 101.6710, 5, '2026-10-14 15:00+08')), 3, 'anon_can_read_the_feed');
reset role;

select * from finish();
rollback;
