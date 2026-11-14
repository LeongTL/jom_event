-- Open a private event by its code, and edit visibility. event_by_code is the only way to learn a private event's id;
-- after that the id works in event_detail, toggle_save, create_booking and the chat as for any event. event_detail
-- now says whether the event is private (the page's tag) and shares its row shape with event_by_code; the host
-- reads visibility and the share code in host_events.

create type events.event_page as (event_id uuid, host_id uuid, host_name text, rating_avg numeric, rating_count int, title text,
               description text, venue text, glyph text, color_a text, color_b text, starts_at timestamptz,
               ends_at timestamptz, price_sen int, area text, lat float8, lng float8, distance_km float8,
               is_live boolean, is_ended boolean, spots_left int, categories text[], cancel_policy text,
               source_url text, is_bookable boolean, poster_url text, going int, host_verified boolean,
               host_event_count int, visibility text);

drop function events.event_detail(uuid, float8, float8);

create function events.event_detail(p_event_id uuid, p_lat float8 default null, p_lng float8 default null)
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
         e.poster_url, bookings.going_count(e.id), h.verified_at is not null, events.host_event_count(e.host_id), e.visibility
    from events.events e
    left join identity.hosts h on h.user_id = e.host_id
    left join reviews.host_rating r on r.host_id = e.host_id
   where e.id = p_event_id and e.status in ('published', 'ended')
$$;

create function events.event_by_code(p_code text, p_lat float8 default null, p_lng float8 default null)
returns setof events.event_page
language sql stable security definer set search_path = ''
as $$
  select d.*
    from events.events e
   cross join lateral events.event_detail(e.id, p_lat, p_lng) d
   where e.share_code = p_code and e.status in ('published', 'ended')
$$;

create or replace function events.save_draft(payload jsonb) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  eid uuid := nullif(payload ->> 'id', '')::uuid;
  is_new boolean := (nullif(payload ->> 'id', '') is null);
  cur events.events;
  n events.events;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if not identity.is_host(uid) then
    raise exception 'not_a_host';
  end if;

  if not is_new then
    select * into cur from events.events e where e.id = eid for update;
    if not found or cur.host_id <> uid then
      raise exception 'not_owner';
    end if;
    if cur.status not in ('draft', 'published') then
      raise exception 'event_closed';
    end if;
    n := jsonb_populate_record(cur, payload - array['id', 'host_id', 'status', 'created_at']);
  else
    n := jsonb_populate_record(null::events.events, payload - array['id', 'host_id', 'status', 'created_at']);
    n.categories := coalesce(n.categories, '{}');
    n.cancel_policy := coalesce(n.cancel_policy, '24h');
    n.accept_bookings := coalesce(n.accept_bookings, true);
  end if;
  n.visibility := coalesce(n.visibility, 'public');
  if n.visibility not in ('public', 'private') then
    raise exception 'visibility_invalid';
  end if;

  if coalesce(btrim(n.title), '') = '' then
    raise exception 'title_required';
  end if;
  if shared.contains_contact_info(n.title) or shared.contains_contact_info(n.description) then
    raise exception 'contact_info_not_allowed';
  end if;
  if n.capacity is not null and n.capacity not between 1 and 40 then
    raise exception 'capacity_out_of_range';
  end if;

  if not is_new and cur.status = 'published' then
    if events.has_guests(cur.id) then
      if (n.starts_at, n.ends_at, n.venue, n.area, n.lat, n.lng, n.categories, n.price_sen, n.accept_bookings, n.cancel_policy)
         is distinct from
         (cur.starts_at, cur.ends_at, cur.venue, cur.area, cur.lat, cur.lng, cur.categories, cur.price_sen, cur.accept_bookings, cur.cancel_policy) then
        raise exception 'locked_after_guests';
      end if;
      if n.capacity < bookings.seats_taken(cur.id) then
        raise exception 'capacity_below_seats_sold';
      end if;
    end if;
    perform events.assert_publishable(n, n.starts_at is distinct from cur.starts_at);
  end if;

  if is_new then
    insert into events.events (host_id, title, description, glyph, color_a, color_b, poster_url, categories,
                               area, venue, lat, lng, starts_at, ends_at, capacity, price_sen,
                               cancel_policy, accept_bookings, source_url, visibility)
    values (uid, n.title, n.description, n.glyph, n.color_a, n.color_b, n.poster_url, n.categories,
            n.area, n.venue, n.lat, n.lng, n.starts_at, n.ends_at, n.capacity, n.price_sen,
            n.cancel_policy, n.accept_bookings, n.source_url, n.visibility)
    returning id into eid;
  else
    update events.events e
       set title = n.title, description = n.description, glyph = n.glyph, color_a = n.color_a,
           color_b = n.color_b, poster_url = n.poster_url, categories = n.categories, area = n.area,
           venue = n.venue, lat = n.lat, lng = n.lng, starts_at = n.starts_at, ends_at = n.ends_at,
           capacity = n.capacity, price_sen = n.price_sen, cancel_policy = n.cancel_policy,
           accept_bookings = n.accept_bookings, source_url = n.source_url, visibility = n.visibility
     where e.id = eid;
  end if;
  return eid;
end
$$;

drop function events.update_event(uuid, text, text, int);

create function events.update_event(event_id uuid, title text, description text, capacity int,
                                    p_visibility text default null) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  cur events.events;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select * into cur from events.events e where e.id = update_event.event_id for update;
  if not found or cur.host_id <> uid then
    raise exception 'not_owner';
  end if;
  if cur.status not in ('draft', 'published') then
    raise exception 'event_closed';
  end if;
  if coalesce(btrim(update_event.title), '') = '' then
    raise exception 'title_required';
  end if;
  if shared.contains_contact_info(update_event.title) or shared.contains_contact_info(update_event.description) then
    raise exception 'contact_info_not_allowed';
  end if;
  if update_event.capacity is null or update_event.capacity not between 1 and 40 then
    raise exception 'capacity_out_of_range';
  end if;
  if update_event.capacity < bookings.seats_taken(cur.id) then
    raise exception 'capacity_below_seats_sold';
  end if;

  if p_visibility is not null and p_visibility not in ('public', 'private') then
    raise exception 'visibility_invalid';
  end if;

  update events.events e
     set title = update_event.title, description = update_event.description, capacity = update_event.capacity,
         visibility = coalesce(p_visibility, e.visibility)
   where e.id = cur.id;
end
$$;

drop function events.host_events(text, uuid);

create function events.host_events(p_status text default null, p_event_id uuid default null)
returns table (
  id uuid, title text, description text, glyph text, color_a text, color_b text, poster_url text,
  categories text[], area text, venue text, starts_at timestamptz, ends_at timestamptz, capacity int,
  price_sen int, cancel_policy text, accept_bookings boolean, status text, seats_sold int, saves int,
  visibility text, share_code text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  return query
  select e.id, e.title, e.description, e.glyph, e.color_a, e.color_b, e.poster_url, e.categories, e.area, e.venue,
         e.starts_at, e.ends_at, e.capacity, e.price_sen, e.cancel_policy, e.accept_bookings, e.status,
         bookings.seats_taken(e.id),
         case when coalesce(e.price_sen, 0) = 0 or not e.accept_bookings then identity.saves_count(e.id) end,
         e.visibility, e.share_code
    from events.events e
   where e.host_id = auth.uid()
     and (p_status is null or e.status = p_status)
     and (p_event_id is null or e.id = p_event_id)
   order by case when e.status = 'published' then e.starts_at end asc,
            case when e.status <> 'published' then coalesce(e.starts_at, e.created_at) end desc;
end
$$;

revoke all on function events.event_detail(uuid, float8, float8) from public;
revoke all on function events.event_by_code(text, float8, float8) from public;
revoke all on function events.update_event(uuid, text, text, int, text) from public;
revoke all on function events.host_events(text, uuid) from public, anon, authenticated;
grant execute on function events.event_detail(uuid, float8, float8) to anon, authenticated;
grant execute on function events.event_by_code(text, float8, float8) to anon, authenticated;
grant execute on function events.update_event(uuid, text, text, int, text) to authenticated;
grant execute on function events.host_events(text, uuid) to authenticated;
