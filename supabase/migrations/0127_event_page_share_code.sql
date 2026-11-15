-- The event page carries its share code, so the share button can build the link without a second call.
alter type events.event_page add attribute share_code text;

create or replace function events.event_detail(p_event_id uuid, p_lat float8 default null, p_lng float8 default null)
returns setof events.event_page
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
         e.poster_url, bookings.going_count(e.id), h.verified_at is not null, events.host_event_count(e.host_id), e.visibility,
         e.share_code
    from events.events e
    left join identity.hosts h on h.user_id = e.host_id
    left join reviews.host_rating r on r.host_id = e.host_id
   where e.id = p_event_id and e.status in ('published', 'ended')
$$;
