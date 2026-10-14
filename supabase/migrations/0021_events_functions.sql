-- Events module functions: the only write path. security definer + pinned search_path.

create function events.exists_published(event_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from events.events e where e.id = exists_published.event_id and e.status = 'published')
$$;

create function events.is_bookable(e events.events) returns boolean
language sql immutable
as $$ select e.accept_bookings and coalesce(e.price_sen, 0) > 0 $$;

create function events.has_guests(event_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select bookings.seats_taken(has_guests.event_id) > 0 $$;

-- Raises when a draft cannot go live (or a live event was edited into an invalid state).
create function events.assert_publishable(e events.events, check_future boolean) returns void
language plpgsql set search_path = ''
as $$
begin
  if coalesce(btrim(e.title), '') = '' or coalesce(btrim(e.venue), '') = '' or e.area is null
     or e.starts_at is null or e.ends_at is null or e.capacity is null or e.price_sen is null then
    raise exception 'event_incomplete';
  end if;
  if e.ends_at <= e.starts_at then
    raise exception 'invalid_times';
  end if;
  if check_future and e.starts_at <= now() then
    raise exception 'starts_in_past';
  end if;
end
$$;

-- Creates a draft (no id in the payload) or edits one of the caller's events (id in the payload).
-- Payload keys are the editable columns; status, host_id and created_at in the payload are ignored.
-- A published event keeps being valid, locks date/venue/price/policy/categories/switch/area once guests
-- have joined, and never goes below the seats already sold.
create function events.save_draft(payload jsonb) returns uuid
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
                               cancel_policy, accept_bookings, source_url)
    values (uid, n.title, n.description, n.glyph, n.color_a, n.color_b, n.poster_url, n.categories,
            n.area, n.venue, n.lat, n.lng, n.starts_at, n.ends_at, n.capacity, n.price_sen,
            n.cancel_policy, n.accept_bookings, n.source_url)
    returning id into eid;
  else
    update events.events e
       set title = n.title, description = n.description, glyph = n.glyph, color_a = n.color_a,
           color_b = n.color_b, poster_url = n.poster_url, categories = n.categories, area = n.area,
           venue = n.venue, lat = n.lat, lng = n.lng, starts_at = n.starts_at, ends_at = n.ends_at,
           capacity = n.capacity, price_sen = n.price_sen, cancel_policy = n.cancel_policy,
           accept_bookings = n.accept_bookings, source_url = n.source_url
     where e.id = eid;
  end if;
  return eid;
end
$$;

create function events.publish(event_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  cur events.events;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select * into cur from events.events e where e.id = publish.event_id for update;
  if not found or cur.host_id <> uid then
    raise exception 'not_owner';
  end if;
  if cur.status <> 'draft' then
    raise exception 'not_a_draft';
  end if;
  perform events.assert_publishable(cur, true);

  -- pins and distance need coordinates; the host picks an area, so use its centre unless given
  update events.events e
     set status = 'published',
         lat = coalesce(e.lat, (select a.lat from events.areas a where a.name = e.area)),
         lng = coalesce(e.lng, (select a.lng from events.areas a where a.name = e.area))
   where e.id = cur.id;
end
$$;

-- The limited edit after publishing: title, description and spots only.
create function events.update_event(event_id uuid, title text, description text, capacity int) returns void
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

  update events.events e
     set title = update_event.title, description = update_event.description, capacity = update_event.capacity
   where e.id = cur.id;
end
$$;

revoke all on function events.exists_published(uuid) from public;
revoke all on function events.has_guests(uuid) from public;
revoke all on function events.assert_publishable(events.events, boolean) from public;
revoke all on function events.save_draft(jsonb) from public;
revoke all on function events.publish(uuid) from public;
revoke all on function events.update_event(uuid, text, text, int) from public;

grant execute on function events.save_draft(jsonb) to authenticated;
grant execute on function events.publish(uuid) to authenticated;
grant execute on function events.update_event(uuid, text, text, int) to authenticated;
grant execute on function events.is_bookable(events.events) to anon, authenticated;
