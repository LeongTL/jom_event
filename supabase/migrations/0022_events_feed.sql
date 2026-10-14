-- Home feed, time tabs, scoring and View all. All time maths is in Asia/Kuala_Lumpur, and p_now is
-- injectable so tests are deterministic. The functions run with the owner's rights (so signed-out visitors
-- need no access to bookings) and only ever read published events that have not finished.

-- Haversine, in kilometres. Null in, null out.
create function events.distance_km(lat1 float8, lng1 float8, lat2 float8, lng2 float8) returns float8
language sql immutable
as $$
  select 2 * 6371.0088 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)))
$$;

-- Internal: every published, unfinished event in a tab within p_km of the user, with its score.
-- Tabs: now = live or starting within 120 minutes; night = after that and before the next 04:00;
-- weekend = Saturday and Sunday of the current or coming weekend; all = everything upcoming or live.
-- A null location skips the distance filter and the distance penalty.
create function events.tab_rows(p_tab text, p_lat float8, p_lng float8, p_km int, p_now timestamptz)
returns table (event_id uuid, title text, glyph text, color_a text, color_b text, starts_at timestamptz,
               ends_at timestamptz, price_sen int, area text, distance_km float8, is_live boolean,
               spots_left int, score float8, categories text[])
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
declare
  kl constant text := 'Asia/Kuala_Lumpur';
  now_local timestamp := p_now at time zone kl;
  dow int := extract(isodow from now_local)::int;
  night_end timestamptz := (date_trunc('day', now_local - interval '4 hours') + interval '1 day 4 hours') at time zone kl;
  weekend_start_local timestamp := date_trunc('day', now_local)
    + (case when dow >= 6 then -(dow - 6) else 6 - dow end) * interval '1 day';
  weekend_start timestamptz := weekend_start_local at time zone kl;
  weekend_end timestamptz := (weekend_start_local + interval '2 days') at time zone kl;
begin
  if p_tab is null or p_tab not in ('now', 'night', 'weekend', 'all') then
    raise exception 'unknown_tab';
  end if;

  return query
  with base as (
    select e.*,
           case when p_lat is null or p_lng is null then null
                else events.distance_km(p_lat, p_lng, e.lat, e.lng) end as dist
      from events.events e
     where e.status = 'published' and e.ends_at > p_now
  ), scoped as (
    select b.*, (b.starts_at <= p_now) as live
      from base b
     where (b.dist is null or b.dist <= p_km)
       and case p_tab
             when 'now'     then b.starts_at <= p_now + interval '120 minutes'
             when 'night'   then b.starts_at >  p_now + interval '120 minutes' and b.starts_at < night_end
             when 'weekend' then b.starts_at >= weekend_start and b.starts_at < weekend_end
             else true
           end
  )
  select s.id, s.title, s.glyph, s.color_a, s.color_b, s.starts_at, s.ends_at, s.price_sen, s.area,
         s.dist, s.live,
         greatest(s.capacity - bookings.seats_taken(s.id), 0),
         (case when s.live then 3 else 0 end
          + case when not s.live and s.starts_at - p_now < interval '30 minutes' then 2 else 0 end
          + case when s.price_sen = 0 then 1 else 0 end)::float8
           - coalesce(s.dist, 0) * 0.35,
         s.categories
    from scoped s;
end
$$;

-- Home: at most 9 events for a tab, best score first.
create function events.feed(p_tab text, p_lat float8, p_lng float8, p_km int default 5, p_now timestamptz default now())
returns table (event_id uuid, title text, glyph text, color_a text, color_b text, starts_at timestamptz,
               ends_at timestamptz, price_sen int, area text, distance_km float8, is_live boolean,
               spots_left int, score float8)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_tab is null or p_tab not in ('now', 'night', 'weekend') then
    raise exception 'unknown_tab';
  end if;
  return query
  select r.event_id, r.title, r.glyph, r.color_a, r.color_b, r.starts_at, r.ends_at, r.price_sen, r.area,
         r.distance_km, r.is_live, r.spots_left, r.score
    from events.tab_rows(p_tab, p_lat, p_lng, p_km, p_now) r
   order by r.score desc, r.starts_at, r.event_id
   limit 9;
end
$$;

-- Tab badges: how many events each tab holds (not capped at 9).
create function events.tab_counts(p_lat float8, p_lng float8, p_km int default 5, p_now timestamptz default now())
returns table (tab text, n int)
language sql stable security definer set search_path = ''
as $$
  select t, (select count(*)::int from events.tab_rows(t, p_lat, p_lng, p_km, p_now))
    from unnest(array['now', 'night', 'weekend', 'all']) as t
$$;

-- View all: every upcoming or live event, soonest first, optionally for one category (or free).
-- Same columns as the feed plus categories, so the page can group events into sections.
create function events.list_all(p_lat float8, p_lng float8, p_category text default 'all', p_km int default 5,
                                p_now timestamptz default now())
returns table (event_id uuid, title text, glyph text, color_a text, color_b text, starts_at timestamptz,
               ends_at timestamptz, price_sen int, area text, distance_km float8, is_live boolean,
               spots_left int, score float8, categories text[])
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_category is null or p_category not in ('all', 'make', 'move', 'meet', 'free') then
    raise exception 'unknown_category';
  end if;
  return query
  select r.event_id, r.title, r.glyph, r.color_a, r.color_b, r.starts_at, r.ends_at, r.price_sen, r.area,
         r.distance_km, r.is_live, r.spots_left, r.score, r.categories
    from events.tab_rows('all', p_lat, p_lng, p_km, p_now) r
   where case p_category
           when 'all'  then true
           when 'free' then r.price_sen = 0
           else p_category = any (r.categories)
         end
   order by r.starts_at, r.event_id;
end
$$;

-- Hero line: "N happening now, N free, closest X km" for a tab.
create function events.hero_stats(p_tab text, p_lat float8, p_lng float8, p_km int default 5, p_now timestamptz default now())
returns table (total int, live int, free int, closest_km float8)
language sql stable security definer set search_path = ''
as $$
  select count(*)::int, (count(*) filter (where r.is_live))::int, (count(*) filter (where r.price_sen = 0))::int,
         min(r.distance_km)
    from events.tab_rows(p_tab, p_lat, p_lng, p_km, p_now) r
$$;

revoke all on function events.tab_rows(text, float8, float8, int, timestamptz) from public;
revoke all on function events.feed(text, float8, float8, int, timestamptz) from public;
revoke all on function events.tab_counts(float8, float8, int, timestamptz) from public;
revoke all on function events.list_all(float8, float8, text, int, timestamptz) from public;
revoke all on function events.hero_stats(text, float8, float8, int, timestamptz) from public;

grant execute on function events.distance_km(float8, float8, float8, float8) to anon, authenticated;
grant execute on function events.feed(text, float8, float8, int, timestamptz) to anon, authenticated;
grant execute on function events.tab_counts(float8, float8, int, timestamptz) to anon, authenticated;
grant execute on function events.list_all(float8, float8, text, int, timestamptz) to anon, authenticated;
grant execute on function events.hero_stats(text, float8, float8, int, timestamptz) to anon, authenticated;
