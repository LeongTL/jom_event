-- Private events leave every list: Home, View all, search and the map all read events.tab_rows; the public host
-- page lists only public events and the host's "events hosted" number counts only public ones. Cards for a known id
-- (tickets, Saved) are untouched, so people who have a private event still see it.

create or replace function events.tab_rows(p_tab text, p_lat float8, p_lng float8, p_km int, p_now timestamptz)
returns setof events.event_card
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
     where e.status = 'published' and e.visibility = 'public' and e.ends_at > p_now
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
  select s.id, s.title, s.description, s.glyph, s.color_a, s.color_b, s.poster_url, s.categories, s.starts_at,
         s.ends_at, s.price_sen, s.cancel_policy, s.area, s.lat, s.lng, s.host_id, h.host_name,
         coalesce(h.verified, false), s.dist, s.live,
         greatest(s.capacity - bookings.seats_taken(s.id), 0), bookings.going_count(s.id),
         (case when s.live then 3 else 0 end
          + case when not s.live and s.starts_at - p_now < interval '30 minutes' then 2 else 0 end
          + case when s.price_sen = 0 then 1 else 0 end)::float8
           - coalesce(s.dist, 0) * 0.35
    from scoped s
    left join lateral identity.host_cards(array[s.host_id]) h on true;
end
$$;

create or replace function events.host_event_count(p_host_id uuid) returns int
language sql stable security definer set search_path = ''
as $$
  select count(*)::int from events.events e
   where e.host_id = p_host_id and e.status in ('published', 'ended') and e.visibility = 'public'
$$;

create or replace function events.host_page(p_host_id uuid, p_now timestamptz default now())
returns table (host_name text, area text, bio text, since timestamptz, verified boolean, guests int, upcoming uuid[])
language sql stable security definer set search_path = ''
as $$
  select hp.host_name, hp.area, hp.bio, hp.since, c.verified,
         (select coalesce(sum(bookings.going_count(e.id)), 0)::int
            from events.events e where e.host_id = p_host_id and e.status in ('published', 'ended')),
         coalesce((select array_agg(e.id order by e.starts_at, e.id)
                     from events.events e
                    where e.host_id = p_host_id and e.status = 'published' and e.visibility = 'public' and e.starts_at > p_now), '{}')
    from identity.host_public hp
    join identity.host_cards(array[p_host_id]) c on c.user_id = hp.user_id
   where hp.user_id = p_host_id
$$;

