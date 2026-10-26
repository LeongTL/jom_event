-- Calm design: one card shape for Home, View all, the map and tickets. Host name/tick, the going count and the
-- coordinates now ride along with every event, plus search, map pins and a lookup by id. Host data comes from
-- identity and the going count from bookings, always through their functions.

create function identity.host_cards(p_ids uuid[])
returns table (user_id uuid, host_name text, verified boolean)
language sql stable security definer set search_path = ''
as $$
  select h.user_id, h.host_name, h.verified_at is not null
    from identity.hosts h
   where h.user_id = any (p_ids)
$$;

-- People (not bookings) who are in: a number only, never who.
create function bookings.going_count(p_event_id uuid) returns int
language sql stable security definer set search_path = ''
as $$
  select coalesce(sum(b.people), 0)::int
    from bookings.bookings b
   where b.event_id = p_event_id and b.status in ('confirmed', 'attended')
$$;

create function events.host_event_count(p_host_id uuid) returns int
language sql stable security definer set search_path = ''
as $$
  select count(*)::int from events.events e where e.host_id = p_host_id and e.status in ('published', 'ended')
$$;

create type events.event_card as (
  event_id uuid, title text, description text, glyph text, color_a text, color_b text, poster_url text,
  categories text[], starts_at timestamptz, ends_at timestamptz, price_sen int, cancel_policy text, area text,
  lat float8, lng float8, host_id uuid, host_name text, host_verified boolean, distance_km float8,
  is_live boolean, spots_left int, going int, score float8);

drop function events.feed(text, float8, float8, int, timestamptz);
drop function events.list_all(float8, float8, text, int, timestamptz);
drop function events.tab_rows(text, float8, float8, int, timestamptz);

create function events.tab_rows(p_tab text, p_lat float8, p_lng float8, p_km int, p_now timestamptz)
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

-- Home: at most 9 events for a tab, best score first.
create function events.feed(p_tab text, p_lat float8, p_lng float8, p_km int default 5, p_now timestamptz default now())
returns setof events.event_card
language plpgsql stable security definer set search_path = ''
as $$
begin
  if p_tab is null or p_tab not in ('now', 'night', 'weekend') then
    raise exception 'unknown_tab';
  end if;
  return query
  select * from events.tab_rows(p_tab, p_lat, p_lng, p_km, p_now) r
   order by r.score desc, r.starts_at, r.event_id
   limit 9;
end
$$;

-- View all: every upcoming or live event, soonest first, for a category and/or a search text. The text matches
-- title, host name or area, ignoring case; % and _ in it are taken literally.
create function events.list_all(p_lat float8, p_lng float8, p_category text default 'all', p_km int default 5,
                                p_now timestamptz default now(), p_query text default null)
returns setof events.event_card
language plpgsql stable security definer set search_path = ''
as $$
declare
  pat text := '%' || replace(replace(replace(coalesce(trim(p_query), ''), '\', '\\'), '%', '\%'), '_', '\_') || '%';
begin
  if p_category is null or p_category not in ('all', 'make', 'move', 'meet', 'free') then
    raise exception 'unknown_category';
  end if;
  return query
  select * from events.tab_rows('all', p_lat, p_lng, p_km, p_now) r
   where case p_category
           when 'all'  then true
           when 'free' then r.price_sen = 0
           else p_category = any (r.categories)
         end
     and (r.title ilike pat or r.host_name ilike pat or r.area ilike pat)
   order by r.starts_at, r.event_id;
end
$$;

-- Map: at most 30 pins within p_km, best score first. p_tonight keeps events starting before the next 04:00.
create function events.map_pins(p_lat float8, p_lng float8, p_km int default 5, p_category text default 'all',
                                p_tonight boolean default false, p_now timestamptz default now())
returns setof events.event_card
language plpgsql stable security definer set search_path = ''
as $$
declare
  night_end timestamptz := (date_trunc('day', (p_now at time zone 'Asia/Kuala_Lumpur') - interval '4 hours')
                            + interval '1 day 4 hours') at time zone 'Asia/Kuala_Lumpur';
begin
  if p_category is null or p_category not in ('all', 'make', 'move', 'meet', 'free') then
    raise exception 'unknown_category';
  end if;
  return query
  select * from events.tab_rows('all', p_lat, p_lng, p_km, p_now) r
   where case p_category
           when 'all'  then true
           when 'free' then r.price_sen = 0
           else p_category = any (r.categories)
         end
     and (not p_tonight or r.starts_at < night_end)
   order by r.score desc, r.starts_at, r.event_id
   limit 30;
end
$$;

-- Cards for known ids (tickets of past events included): published or ended only. Score is not meaningful here.
create function events.cards(p_ids uuid[], p_lat float8 default null, p_lng float8 default null,
                             p_now timestamptz default now())
returns setof events.event_card
language sql stable security definer set search_path = ''
as $$
  select e.id, e.title, e.description, e.glyph, e.color_a, e.color_b, e.poster_url, e.categories, e.starts_at,
         e.ends_at, e.price_sen, e.cancel_policy, e.area, e.lat, e.lng, e.host_id, h.host_name,
         coalesce(h.verified, false),
         case when p_lat is null or p_lng is null or e.lat is null then null
              else events.distance_km(p_lat, p_lng, e.lat, e.lng) end,
         e.status = 'published' and e.starts_at <= p_now and e.ends_at > p_now,
         greatest(e.capacity - bookings.seats_taken(e.id), 0), bookings.going_count(e.id), 0::float8
    from events.events e
    left join lateral identity.host_cards(array[e.host_id]) h on true
   where e.id = any (p_ids) and e.status in ('published', 'ended')
$$;

-- Tickets also need how the guest paid: replaces my_bookings (same columns plus payment_method).
drop function bookings.my_bookings(text);
create function bookings.my_bookings(p_scope text)
returns table (booking_id uuid, event_id uuid, people int, status text, hold_expires_at timestamptz,
               ticket_code text, contact_name text, contact_phone text, cancel_cutoff_at timestamptz,
               amount_sen int, checked_in_at timestamptz, cancelled_at timestamptz, created_at timestamptz,
               event_title text, event_glyph text, event_color_a text, event_color_b text, event_area text,
               event_venue text, event_starts_at timestamptz, event_ends_at timestamptz, event_status text,
               payment_method text)
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_scope is null or p_scope not in ('upcoming', 'past') then
    raise exception 'unknown_scope';
  end if;
  return query
  select b.id, b.event_id, b.people, b.status, b.hold_expires_at, b.ticket_code, b.contact_name, b.contact_phone,
         b.cancel_cutoff_at, b.amount_sen, b.checked_in_at, b.cancelled_at, b.created_at,
         ev.title, ev.glyph, ev.color_a, ev.color_b, ev.area, ev.venue, ev.starts_at, ev.ends_at, ev.status,
         case when b.amount_sen = 0 then 'free' else payments.paid_method(b.id) end
    from bookings.bookings b
   cross join lateral events.event_brief(b.event_id) ev
   where b.attendee_id = auth.uid()
     and case p_scope
           when 'upcoming' then b.status in ('processing', 'confirmed') and ev.ends_at > now()
           else b.status in ('confirmed', 'processing', 'attended', 'no_show', 'cancelled')
                and not (b.status in ('processing', 'confirmed') and ev.ends_at > now())
         end
   order by case when p_scope = 'upcoming' then ev.starts_at end asc,
            case when p_scope = 'past' then ev.starts_at end desc;
end
$$;

revoke all on function identity.host_cards(uuid[]) from public;
revoke all on function bookings.going_count(uuid) from public;
revoke all on function events.host_event_count(uuid) from public;
revoke all on function events.tab_rows(text, float8, float8, int, timestamptz) from public;
revoke all on function events.feed(text, float8, float8, int, timestamptz) from public;
revoke all on function events.list_all(float8, float8, text, int, timestamptz, text) from public;
revoke all on function events.map_pins(float8, float8, int, text, boolean, timestamptz) from public;
revoke all on function events.cards(uuid[], float8, float8, timestamptz) from public;
revoke all on function bookings.my_bookings(text) from public;

grant execute on function events.host_event_count(uuid) to anon, authenticated;
grant execute on function events.feed(text, float8, float8, int, timestamptz) to anon, authenticated;
grant execute on function events.list_all(float8, float8, text, int, timestamptz, text) to anon, authenticated;
grant execute on function events.map_pins(float8, float8, int, text, boolean, timestamptz) to anon, authenticated;
grant execute on function events.cards(uuid[], float8, float8, timestamptz) to anon, authenticated;
grant execute on function bookings.my_bookings(text) to authenticated;
