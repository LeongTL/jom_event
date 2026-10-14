-- What the bookings and payments modules need from events, through functions only (module boundary).
-- Internal: not callable by clients.

-- Locks the event row until the end of the transaction, so two people taking the last seat are serialised.
create function events.lock_for_booking(event_id uuid) returns events.events
language plpgsql security definer set search_path = ''
as $$
declare
  e events.events;
begin
  select * into e from events.events x where x.id = lock_for_booking.event_id for update;
  if not found then
    raise exception 'event_not_found';
  end if;
  return e;
end
$$;

-- The last moment a guest may cancel for a refund, from the host's policy; null means no refunds.
create function events.cancel_cutoff(event_id uuid) returns timestamptz
language sql stable security definer set search_path = ''
as $$
  select case e.cancel_policy
           when '24h' then e.starts_at - interval '24 hours'
           when '48h' then e.starts_at - interval '48 hours'
           when '7d'  then e.starts_at - interval '7 days'
         end
    from events.events e
   where e.id = cancel_cutoff.event_id
$$;

create function events.event_brief(event_id uuid)
returns table (host_id uuid, title text, glyph text, color_a text, color_b text, area text, venue text,
               starts_at timestamptz, ends_at timestamptz, status text, price_sen int, capacity int)
language sql stable security definer set search_path = ''
as $$
  select e.host_id, e.title, e.glyph, e.color_a, e.color_b, e.area, e.venue, e.starts_at, e.ends_at,
         e.status, e.price_sen, e.capacity
    from events.events e
   where e.id = event_brief.event_id
$$;

revoke all on function events.lock_for_booking(uuid) from public;
revoke all on function events.cancel_cutoff(uuid) from public;
revoke all on function events.event_brief(uuid) from public;
