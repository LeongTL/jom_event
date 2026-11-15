-- Free events are Save-only listings: create_booking refuses them, and the host reads how many people saved one.
-- Bookings made before this stay valid (confirmed, in Tickets).

create function events.host_of(p_event_id uuid) returns uuid
language sql stable security definer set search_path = ''
as $$ select e.host_id from events.events e where e.id = p_event_id $$;

-- Only the event's host may ask; everyone else gets not_host.
create function identity.saves_count(p_event_id uuid) returns int
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null or events.host_of(p_event_id) is distinct from auth.uid() then
    raise exception 'not_host';
  end if;
  return (select count(*)::int from identity.saved_events s where s.event_id = p_event_id);
end
$$;

create or replace function bookings.create_booking(p_event_id uuid, p_people int, p_name text, p_phone text)
returns bookings.bookings
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  ev events.events;
  paid boolean;
  b bookings.bookings;
  tries int := 0;
  cool int;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_people is null or p_people not between 1 and 2 then
    raise exception 'people_out_of_range';
  end if;
  if coalesce(btrim(p_name), '') = '' or coalesce(btrim(p_phone), '') = '' then
    raise exception 'contact_required';
  end if;

  ev := events.lock_for_booking(p_event_id);
  if ev.status <> 'published' then
    raise exception 'event_not_available';
  end if;
  if ev.starts_at <= now() then
    raise exception 'event_started';
  end if;
  if coalesce(ev.price_sen, 0) = 0 then
    raise exception 'free_event_no_booking';  -- a free event is a listing: Save, Directions, no ticket
  end if;
  paid := coalesce(ev.price_sen, 0) > 0;
  if paid and not ev.accept_bookings then
    raise exception 'bookings_closed';
  end if;
  if paid and now() > ev.starts_at - interval '1 hour' then
    raise exception 'bookings_closed';
  end if;
  if paid then
    -- cooldown: a hold of theirs ran out with no receipt in the last 30 minutes
    select greatest(extract(epoch from x.hold_expires_at + interval '30 minutes' - now())::int, 1) into cool
      from bookings.bookings x
     where x.event_id = p_event_id and x.attendee_id = uid and x.status = 'expired'
       and x.hold_expires_at > now() - interval '30 minutes'
       and not exists (select 1 from payments.receipts r where r.booking_id = x.id)
     order by x.hold_expires_at desc limit 1;
    if cool is not null then
      raise exception 'cooldown_active' using hint = cool::text;
    end if;
  end if;
  if bookings.seats_taken(p_event_id) + p_people > ev.capacity then
    raise exception 'sold_out';
  end if;

  loop
    tries := tries + 1;
    begin
      insert into bookings.bookings (event_id, attendee_id, people, status, hold_expires_at, ticket_code,
                                     contact_name, contact_phone, cancel_cutoff_at, amount_sen)
      values (p_event_id, uid, p_people,
              case when paid then 'held' else 'confirmed' end,
              case when paid then now() + greatest(interval '15 minutes', least(interval '1 hour', ev.starts_at - interval '30 minutes' - now())) end,
              'KLS-' || lpad(floor(random() * 100000)::int::text, 5, '0'),
              btrim(p_name), btrim(p_phone),
              case when paid then events.cancel_cutoff(p_event_id) else ev.starts_at end,
              coalesce(ev.price_sen, 0) * p_people)
      returning * into b;
      exit;
    exception when unique_violation then
      if tries >= 10 then
        raise;
      end if;
    end;
  end loop;
  if not paid then
    perform shared.send_receipt(b.id);  -- free: confirmed already, so the receipt goes now
  end if;
  return b;
end
$$;

drop function events.host_events(text, uuid);

create function events.host_events(p_status text default null, p_event_id uuid default null)
returns table (
  id uuid, title text, description text, glyph text, color_a text, color_b text, poster_url text,
  categories text[], area text, venue text, starts_at timestamptz, ends_at timestamptz, capacity int,
  price_sen int, cancel_policy text, accept_bookings boolean, status text, seats_sold int, saves int)
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
         case when coalesce(e.price_sen, 0) = 0 or not e.accept_bookings then identity.saves_count(e.id) end
    from events.events e
   where e.host_id = auth.uid()
     and (p_status is null or e.status = p_status)
     and (p_event_id is null or e.id = p_event_id)
   order by case when e.status = 'published' then e.starts_at end asc,
            case when e.status <> 'published' then coalesce(e.starts_at, e.created_at) end desc;
end
$$;


revoke all on function events.host_of(uuid) from public, anon, authenticated;
revoke all on function identity.saves_count(uuid) from public, anon;
revoke all on function events.host_events(text, uuid) from public, anon, authenticated;
grant execute on function identity.saves_count(uuid) to authenticated;
grant execute on function events.host_events(text, uuid) to authenticated;
