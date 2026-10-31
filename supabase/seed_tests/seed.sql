-- Checks on the development seed (supabase/seed.sql). They live outside supabase/tests because the main suite
-- needs an empty database: run these with
--   supabase db reset && supabase test db supabase/seed_tests
-- The seed's times are relative to when it was loaded, so the Night and Weekend checks take the clock into account.
begin;
select plan(19);

select is((select count(*)::int from events.events), 87, 'seed_has_87_events');
select is((select count(*)::int from identity.hosts), 20, 'seed_has_20_hosts');
select is((select count(*)::int from events.areas), 6, 'seed_has_6_areas');
select is((select count(*)::int from identity.profiles where is_host), 20, 'every seed host has a host profile');
select is((select count(*)::int from identity.host_payout_accounts), 20, 'every seed host has a payout account');
select ok((select count(*) filter (where verified_at is not null) between 5 and 19 from identity.hosts), 'some hosts are verified and some are not');

select is((select count(*)::int from events.events where status <> 'published'), 0, 'every seed event is published');
select is((select count(*)::int from events.events where ends_at <= now()), 0, 'no seed event is already over');
select is((select count(*)::int from events.events where host_id not in (select user_id from identity.hosts)), 0, 'every event belongs to a seed host');
select is((select count(distinct host_id)::int from events.events), 20, 'every host has at least one event');
select is((select count(distinct area)::int from events.events), 6, 'events are spread over all six areas');

select is((select count(*)::int from events.events
            where shared.contains_contact_info(title) or shared.contains_contact_info(coalesce(description, ''))
               or shared.contains_contact_info(coalesce(venue, ''))), 0, 'seed_events_all_pass_contact_filter');

select ok((select count(*) filter (where price_sen = 0) between 15 and 45 and count(*) filter (where price_sen > 0) > 30 from events.events),
  'a mix of free and paid events');
select is((select string_agg(cancel_policy || '=' || n, ', ' order by cancel_policy) from (
            select cancel_policy, count(*) n from events.events where cancel_policy in ('none', '7d') group by 1) q),
  '7d=1, none=1', 'one event with a 7 day policy and one with no refunds');
select is((select count(distinct c)::int from events.events, unnest(categories) c), 3, 'make, move and meet are all used');

-- the Home tabs, from Bangsar with the default radius widened to all of KL
select is((select n from events.tab_counts(3.129, 101.671, 50) where tab = 'all'), 87, 'View all shows all 87 events');
select is((select n from events.tab_counts(3.129, 101.671, 50) where tab = 'now'), 11, 'the Now tab has 11 events, whatever the time');

-- Night only exists between 2 hours from now and 04:00, so the seed fills it only when that window is open. On a Saturday or
-- Sunday the weekend events that start later the same day are inside the window too (up to 22 more).
select ok((select case when extract(isodow from now() at time zone 'Asia/Kuala_Lumpur') < 6 then n = want else n between want and want + 22 end
             from events.tab_counts(3.129, 101.671, 50) t,
                  lateral (select case when ((date_trunc('day', (now() at time zone 'Asia/Kuala_Lumpur') - interval '4 hours') + interval '1 day 4 hours')
                                             at time zone 'Asia/Kuala_Lumpur') - (now() + interval '130 minutes') >= interval '60 minutes' then 8 else 0 end as want) w
            where t.tab = 'night'),
  'the Night tab has its 8 events whenever its window is open (plus weekend events starting later the same day)');
-- Weekend holds the 22 weekend events, plus any Now or Night event that starts inside the weekend window. On a Friday the
-- Night events after midnight are already Saturday (up to 8 of them); on Saturday or Sunday the Now and Night events count
-- too, while the weekend events already started are gone. So: a weekday has at least all 22 and at most 22 + 8, and a
-- weekend day anything up to 22 + 8 + 11.
select ok((select case when extract(isodow from now() at time zone 'Asia/Kuala_Lumpur') < 6 then n between 22 and 30 else n between 0 and 41 end
             from events.tab_counts(3.129, 101.671, 50) where tab = 'weekend'),
  'the Weekend tab has the 22 weekend events (plus any Now or Night event that starts inside the weekend window)');

select * from finish();
rollback;
