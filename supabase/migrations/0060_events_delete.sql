-- Deleting an event: allowed until it starts. Every live booking is cancelled, paid ones are refunded in full
-- whatever the host's policy says, and every guest is told, all in one transaction.

-- Internal: does anyone hold a booking row (of any status) for this event?
create function bookings.has_bookings(p_event_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from bookings.bookings b where b.event_id = p_event_id) $$;

-- Internal: cancels every live booking and says what each one was. held / payment_failed / processing have
-- not (yet) paid for sure; confirmed / attended have. Expired and cancelled bookings are left alone.
create function bookings.cancel_all_for_event(p_event_id uuid) returns table (booking_id uuid, was_status text)
language plpgsql security definer set search_path = ''
as $$
begin
  return query
  with old as (
    select b.id, b.status from bookings.bookings b
     where b.event_id = p_event_id and b.status in ('held', 'payment_failed', 'processing', 'confirmed', 'attended')
       for update),
  u as (
    update bookings.bookings x set status = 'cancelled', cancelled_at = now()
      from old where x.id = old.id
    returning x.id, old.status as was)
  select u.id, u.was from u;
end
$$;

-- Internal: a deleted event leaves nobody's Saved list.
create function identity.forget_event(p_event_id uuid) returns void
language sql security definer set search_path = ''
as $$ delete from identity.saved_events s where s.event_id = p_event_id $$;

-- Host only. A draft, or an event nobody ever booked, is simply removed. Otherwise it is marked cancelled and
-- the result says how many guests were refunded and how many unpaid bookings were released. A payment that
-- arrives later for a cancelled booking is refunded by payments.apply_gateway_result (Task 7).
create function events.delete_event(p_event_id uuid) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  e events.events;
  r record;
  br record;
  refunded int := 0;
  released int := 0;
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  e := events.lock_for_booking(p_event_id);
  if e.host_id <> auth.uid() then
    raise exception 'not_owner';
  end if;
  if e.status not in ('draft', 'published') then
    raise exception 'not_deletable';
  end if;
  if e.status = 'published' and e.starts_at <= now() then
    raise exception 'event_started';
  end if;

  if not bookings.has_bookings(p_event_id) then
    delete from events.events x where x.id = p_event_id;
    perform identity.forget_event(p_event_id);
    return jsonb_build_object('refunded', 0, 'released', 0);
  end if;

  update events.events x set status = 'cancelled' where x.id = p_event_id;
  for r in select * from bookings.cancel_all_for_event(p_event_id) loop
    select * into br from bookings.booking_brief(r.booking_id);
    if r.was_status in ('confirmed', 'attended') then
      if br.amount_sen > 0 then
        perform payments.refund_booking(r.booking_id, 'event_cancelled');
        refunded := refunded + 1;
      end if;
      perform identity.notify(br.attendee_id, 'event_cancelled', 'event', p_event_id, e.title || ' was cancelled',
        case when br.amount_sen > 0 then 'The host cancelled it. You are refunded in full (3 to 7 working days).'
             else 'The host cancelled it.' end);
    else
      released := released + 1;
      if r.was_status = 'processing' then
        perform identity.notify(br.attendee_id, 'event_cancelled', 'event', p_event_id, e.title || ' was cancelled',
          'The host cancelled it. If you were charged, the money goes back automatically.');
      end if;
    end if;
  end loop;
  return jsonb_build_object('refunded', refunded, 'released', released);
end
$$;

revoke all on function bookings.has_bookings(uuid) from public, anon, authenticated;
revoke all on function bookings.cancel_all_for_event(uuid) from public, anon, authenticated;
revoke all on function identity.forget_event(uuid) from public, anon, authenticated;
revoke all on function events.delete_event(uuid) from public, anon, authenticated;
grant execute on function events.delete_event(uuid) to authenticated;
