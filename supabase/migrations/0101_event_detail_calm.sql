-- Calm event page: the detail also carries the poster, how many people are going (a number, never who), whether
-- the host has the tick and how many events the host has run.
drop function events.event_detail(uuid, float8, float8);

create function events.event_detail(p_event_id uuid, p_lat float8 default null, p_lng float8 default null)
returns table (event_id uuid, host_id uuid, host_name text, rating_avg numeric, rating_count int, title text,
               description text, venue text, glyph text, color_a text, color_b text, starts_at timestamptz,
               ends_at timestamptz, price_sen int, area text, lat float8, lng float8, distance_km float8,
               is_live boolean, is_ended boolean, spots_left int, categories text[], cancel_policy text,
               source_url text, is_bookable boolean, poster_url text, going int, host_verified boolean,
               host_event_count int)
language sql stable security definer set search_path = ''
as $$
  select e.id, e.host_id, h.host_name, r.average, coalesce(r.count, 0), e.title, e.description, e.venue, e.glyph,
         e.color_a, e.color_b, e.starts_at, e.ends_at, coalesce(e.price_sen, 0), e.area, e.lat, e.lng,
         case when p_lat is null or p_lng is null or e.lat is null then null
              else events.distance_km(p_lat, p_lng, e.lat, e.lng) end,
         e.status = 'published' and e.starts_at <= now() and e.ends_at > now(),
         e.status = 'ended',
         greatest(coalesce(e.capacity, 0) - bookings.seats_taken(e.id), 0),
         e.categories, e.cancel_policy, e.source_url, events.is_bookable(e),
         e.poster_url, bookings.going_count(e.id), h.verified_at is not null, events.host_event_count(e.host_id)
    from events.events e
    left join identity.hosts h on h.user_id = e.host_id
    left join reviews.host_rating r on r.host_id = e.host_id
   where e.id = p_event_id and e.status in ('published', 'ended')
$$;

revoke all on function events.event_detail(uuid, float8, float8) from public;
grant execute on function events.event_detail(uuid, float8, float8) to anon, authenticated;
