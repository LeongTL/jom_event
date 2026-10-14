-- Bookings module functions: the only write path. security definer + pinned search_path.

-- Seats in use for an event. A held or failed booking keeps its seats only while its hold lasts (so seats
-- free the moment a hold ends, without waiting for the expiry job); processing, confirmed and attended
-- bookings always keep theirs.
-- Replaces the Task 4 stub (same signature).
create or replace function bookings.seats_taken(event_id uuid) returns int
language sql stable security definer set search_path = ''
as $$
  select coalesce(sum(b.people), 0)::int
    from bookings.bookings b
   where b.event_id = seats_taken.event_id
     and (b.status in ('processing', 'confirmed', 'attended')
          or (b.status in ('held', 'payment_failed') and b.hold_expires_at > now()))
$$;

-- Internal: lets other modules (payments, policies) ask about a booking without reading the table.
create function bookings.booking_brief(p_booking_id uuid)
returns table (booking_id uuid, event_id uuid, attendee_id uuid, people int, status text, amount_sen int,
               hold_expires_at timestamptz, ticket_code text, contact_name text)
language sql stable security definer set search_path = ''
as $$
  select b.id, b.event_id, b.attendee_id, b.people, b.status, b.amount_sen, b.hold_expires_at, b.ticket_code, b.contact_name
    from bookings.bookings b
   where b.id = p_booking_id
$$;

create function bookings.owns_booking(p_booking_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from bookings.bookings b where b.id = p_booking_id and b.attendee_id = auth.uid())
$$;

-- Paid events are held for 15 minutes; free events are confirmed at once. The event row is locked first, so
-- two people taking the last seat give exactly one booking.
create function bookings.create_booking(p_event_id uuid, p_people int, p_name text, p_phone text)
returns bookings.bookings
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  ev events.events;
  paid boolean;
  b bookings.bookings;
  tries int := 0;
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
  paid := coalesce(ev.price_sen, 0) > 0;
  if paid and not ev.accept_bookings then
    raise exception 'bookings_closed';
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
              case when paid then now() + interval '15 minutes' end,
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
  return b;
end
$$;

-- Giving up an unpaid hold is always allowed. A confirmed booking can be cancelled until the cutoff copied
-- onto it (never when the host chose "no refunds"); paid ones are refunded.
create function bookings.cancel_booking(p_booking_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  b bookings.bookings;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select * into b from bookings.bookings x where x.id = p_booking_id for update;
  if not found or b.attendee_id <> uid then
    raise exception 'not_owner';
  end if;

  case b.status
    when 'held', 'payment_failed' then
      null;
    when 'confirmed' then
      if b.cancel_cutoff_at is null or now() > b.cancel_cutoff_at then
        raise exception 'cancel_not_allowed';
      end if;
    when 'processing' then
      raise exception 'payment_in_progress';
    else
      raise exception 'not_cancellable';
  end case;

  update bookings.bookings x set status = 'cancelled', cancelled_at = now() where x.id = b.id;
  if b.status = 'confirmed' and b.amount_sen > 0 then
    perform payments.refund_booking(b.id, 'guest_cancelled');
  end if;
end
$$;

-- Run every minute by pg_cron (Task 12). Frees the seats of holds that ran out.
create function bookings.expire_holds() returns int
language plpgsql security definer set search_path = ''
as $$
declare
  n int;
begin
  with u as (
    update bookings.bookings b set status = 'expired'
     where b.status in ('held', 'payment_failed') and b.hold_expires_at <= now()
    returning 1)
  select count(*)::int into n from u;
  return n;
end
$$;

-- State changes driven by the payment result. Internal: only payments calls these. Each returns the
-- booking's status afterwards and does nothing when the move is not allowed (results can arrive twice or late).
create function bookings.mark_processing(p_booking_id uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  s text;
begin
  update bookings.bookings b set status = 'processing'
   where b.id = p_booking_id and b.status in ('held', 'payment_failed');
  select b.status into s from bookings.bookings b where b.id = p_booking_id;
  return s;
end
$$;

create function bookings.mark_payment_failed(p_booking_id uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  s text;
begin
  update bookings.bookings b set status = 'payment_failed'
   where b.id = p_booking_id and b.status in ('held', 'processing');
  select b.status into s from bookings.bookings b where b.id = p_booking_id;
  return s;
end
$$;

-- Confirms a paid booking. A hold that already ran out is still confirmed if its seats are free; otherwise
-- the booking stays expired and the caller refunds. A booking whose event was deleted is cancelled.
create function bookings.mark_confirmed(p_booking_id uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  b bookings.bookings;
  ev events.events;
  lapsed boolean;
begin
  -- lock the event first (same order as create_booking), then the booking
  select x.* into b from bookings.bookings x where x.id = p_booking_id;
  if not found then
    raise exception 'booking_not_found';
  end if;
  ev := events.lock_for_booking(b.event_id);
  select x.* into b from bookings.bookings x where x.id = p_booking_id for update;

  if b.status in ('confirmed', 'attended') then
    return b.status;
  end if;
  if b.status not in ('held', 'processing', 'payment_failed', 'expired') then
    return b.status;
  end if;

  if ev.status <> 'published' then
    update bookings.bookings x set status = 'cancelled', cancelled_at = now() where x.id = b.id;
    return 'cancelled';
  end if;

  lapsed := b.status = 'expired' or (b.status in ('held', 'payment_failed') and b.hold_expires_at <= now());
  if lapsed and bookings.seats_taken(b.event_id) + b.people > ev.capacity then
    update bookings.bookings x set status = 'expired' where x.id = b.id;
    return 'expired';
  end if;

  update bookings.bookings x set status = 'confirmed', hold_expires_at = null where x.id = b.id;
  return 'confirmed';
end
$$;

-- My bookings with the event facts the list needs. upcoming = processing or confirmed for an event that has
-- not finished; past = everything that is over or cancelled. Held and expired checkouts are not bookings yet.
create function bookings.my_bookings(p_scope text)
returns table (booking_id uuid, event_id uuid, people int, status text, hold_expires_at timestamptz,
               ticket_code text, contact_name text, contact_phone text, cancel_cutoff_at timestamptz,
               amount_sen int, checked_in_at timestamptz, cancelled_at timestamptz, created_at timestamptz,
               event_title text, event_glyph text, event_color_a text, event_color_b text, event_area text,
               event_venue text, event_starts_at timestamptz, event_ends_at timestamptz, event_status text)
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
         ev.title, ev.glyph, ev.color_a, ev.color_b, ev.area, ev.venue, ev.starts_at, ev.ends_at, ev.status
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

-- For the host's dashboard: seats paid and checked in, only for events the caller hosts.
create function bookings.event_counts(event_ids uuid[])
returns table (event_id uuid, paid int, checked_in int)
language sql stable security definer set search_path = ''
as $$
  select e.id,
         coalesce(sum(b.people) filter (where b.status in ('confirmed', 'attended')), 0)::int,
         coalesce(sum(b.people) filter (where b.status = 'attended'), 0)::int
    from unnest(event_counts.event_ids) as e(id)
    left join bookings.bookings b on b.event_id = e.id
   where (select h.host_id from events.event_brief(e.id) h) = auth.uid()
   group by e.id
$$;

-- The host's guest list: paid guests only, with how they paid.
create function bookings.guest_list(event_id uuid)
returns table (booking_id uuid, guest_name text, people int, status text, ticket_code text, method text)
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
begin
  if (select h.host_id from events.event_brief(guest_list.event_id) h) is distinct from auth.uid() then
    raise exception 'not_owner';
  end if;
  return query
  select b.id, b.contact_name, b.people, b.status, b.ticket_code, payments.paid_method(b.id)
    from bookings.bookings b
   where b.event_id = guest_list.event_id and b.status in ('confirmed', 'attended', 'no_show')
   order by b.contact_name, b.created_at;
end
$$;

revoke all on function bookings.seats_taken(uuid) from public;
revoke all on function bookings.booking_brief(uuid) from public;
revoke all on function bookings.owns_booking(uuid) from public;
revoke all on function bookings.create_booking(uuid, int, text, text) from public;
revoke all on function bookings.cancel_booking(uuid) from public;
revoke all on function bookings.expire_holds() from public;
revoke all on function bookings.mark_processing(uuid) from public;
revoke all on function bookings.mark_payment_failed(uuid) from public;
revoke all on function bookings.mark_confirmed(uuid) from public;
revoke all on function bookings.my_bookings(text) from public;
revoke all on function bookings.event_counts(uuid[]) from public;
revoke all on function bookings.guest_list(uuid) from public;

grant execute on function bookings.owns_booking(uuid) to authenticated;
grant execute on function bookings.create_booking(uuid, int, text, text) to authenticated;
grant execute on function bookings.cancel_booking(uuid) to authenticated;
grant execute on function bookings.my_bookings(text) to authenticated;
grant execute on function bookings.event_counts(uuid[]) to authenticated;
grant execute on function bookings.guest_list(uuid) to authenticated;
