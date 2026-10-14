-- Events: completing an event, by the host or by the 24-hour job.

-- Internal: the one place an event is closed. Locks the event, so it cannot cross a scan, a tick or a booking.
-- Returns false when the event is not live (already ended, cancelled, draft).
create function events.finish_event(p_event_id uuid) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  e events.events;
  g uuid;
begin
  e := events.lock_for_booking(p_event_id);
  if e.status <> 'published' then
    return false;
  end if;
  update events.events x set status = 'ended' where x.id = p_event_id;
  perform bookings.mark_no_shows(p_event_id);
  perform payments.schedule_payout(p_event_id);
  for g in select * from bookings.attended_attendees(p_event_id) loop
    perform identity.notify(g, 'review_request', 'event', p_event_id,
                            'How was ' || e.title || '?', 'Tell others what it was like.');
  end loop;
  return true;
end
$$;

-- "Mark as completed": host only, and not before the event is over. Completing twice changes nothing.
create function events.complete_event(p_event_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  e events.events;
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  e := events.lock_for_booking(p_event_id);
  if e.host_id <> auth.uid() then
    raise exception 'not_owner';
  end if;
  if e.status = 'ended' then
    return;
  end if;
  if e.status <> 'published' then
    raise exception 'not_completable';
  end if;
  if now() < e.ends_at then
    raise exception 'event_not_over';
  end if;
  perform events.finish_event(p_event_id);
end
$$;

-- Run every 15 minutes by pg_cron (Task 12): completes published events that ended over 24 hours ago.
create function events.auto_complete() returns int
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n int := 0;
begin
  for r in select x.id from events.events x
            where x.status = 'published' and x.ends_at < now() - interval '24 hours'
            order by x.ends_at loop
    if events.finish_event(r.id) then
      n := n + 1;
    end if;
  end loop;
  return n;
end
$$;

revoke all on function events.finish_event(uuid) from public, anon, authenticated;
revoke all on function events.complete_event(uuid) from public, anon, authenticated;
revoke all on function events.auto_complete() from public, anon, authenticated;

grant execute on function events.complete_event(uuid) to authenticated;
grant execute on function events.auto_complete() to service_role;
