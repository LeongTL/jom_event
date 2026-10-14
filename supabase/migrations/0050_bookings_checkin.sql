-- Bookings: the ticket QR token, check-in by scan or by list, and the helpers completion needs.

-- The signing key lives in Vault, never in a table clients can read. Created once; db reset makes a new one.
select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'ticket_secret', 'HMAC key for ticket QR tokens')
 where not exists (select 1 from vault.decrypted_secrets s where s.name = 'ticket_secret');

create function bookings.sign_ticket(p_booking_id uuid) returns text
language sql stable security definer set search_path = ''
as $$
  select p_booking_id::text || '.' ||
         encode(extensions.hmac(p_booking_id::text,
                                (select s.decrypted_secret from vault.decrypted_secrets s where s.name = 'ticket_secret'),
                                'sha256'), 'hex')
$$;

-- The QR on the guest's ticket: <booking_id>.<hmac>. Only the booking's owner can fetch it.
create function bookings.ticket_token(p_booking_id uuid) returns text
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if not exists (select 1 from bookings.bookings b where b.id = p_booking_id and b.attendee_id = auth.uid()) then
    raise exception 'not_owner';
  end if;
  return bookings.sign_ticket(p_booking_id);
end
$$;

-- The host scans a ticket. The event row is locked first (same order as booking and completion), so a scan and
-- "Mark as completed" cannot cross. Answers: checked_in, already (with the original time), wrong_event,
-- not_confirmed (cancelled, unpaid, expired, no-show) or invalid (forged or garbled).
create function bookings.check_in(p_event_id uuid, p_token text) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  bid uuid;
  sig text;
  expected text;
  key text;
  b bookings.bookings;
  res text;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if (select h.host_id from events.event_brief(p_event_id) h) is distinct from uid then
    raise exception 'not_owner';
  end if;

  if p_token is null or p_token !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.[0-9a-f]{64}$' then
    return jsonb_build_object('result', 'invalid');
  end if;
  bid := split_part(p_token, '.', 1)::uuid;
  sig := split_part(p_token, '.', 2);
  expected := split_part(bookings.sign_ticket(bid), '.', 2);
  key := (select s.decrypted_secret from vault.decrypted_secrets s where s.name = 'ticket_secret');
  -- compare the two signatures through a second HMAC so the check does not stop at the first wrong digit
  if extensions.hmac(sig, key, 'sha256') <> extensions.hmac(expected, key, 'sha256') then
    return jsonb_build_object('result', 'invalid');
  end if;

  perform events.lock_for_booking(p_event_id);
  select x.* into b from bookings.bookings x where x.id = bid for update;
  if not found then
    return jsonb_build_object('result', 'invalid');
  end if;
  if b.event_id <> p_event_id then
    return jsonb_build_object('result', 'wrong_event');
  end if;

  if b.status = 'confirmed' then
    update bookings.bookings x set status = 'attended', checked_in_at = now() where x.id = b.id returning * into b;
    res := 'checked_in';
  elsif b.status = 'attended' then
    res := 'already';
  else
    res := 'not_confirmed';
  end if;
  return jsonb_build_object('result', res, 'guest_name', b.contact_name, 'people', b.people,
                            'ticket_code', b.ticket_code, 'at', b.checked_in_at);
end
$$;

-- The manual list: tick sets attended, untick returns to confirmed. Frozen once the event is completed.
create function bookings.set_checked_in(p_booking_id uuid, p_value boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  b bookings.bookings;
  ev events.events;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select x.* into b from bookings.bookings x where x.id = p_booking_id;
  if not found then
    raise exception 'not_owner';
  end if;
  ev := events.lock_for_booking(b.event_id);
  if ev.host_id <> uid then
    raise exception 'not_owner';
  end if;
  if ev.status = 'ended' then
    raise exception 'event_completed';
  end if;

  select x.* into b from bookings.bookings x where x.id = p_booking_id for update;
  if p_value then
    if b.status = 'confirmed' then
      update bookings.bookings x set status = 'attended', checked_in_at = now() where x.id = b.id;
    elsif b.status <> 'attended' then
      raise exception 'not_confirmed';
    end if;
  elsif b.status = 'attended' then
    update bookings.bookings x set status = 'confirmed', checked_in_at = null where x.id = b.id;
  end if;
end
$$;

-- Internal, for completion: confirmed guests who never checked in become no-shows (no refund, no review).
create function bookings.mark_no_shows(p_event_id uuid) returns int
language plpgsql security definer set search_path = ''
as $$
declare
  n int;
begin
  with u as (
    update bookings.bookings b set status = 'no_show'
     where b.event_id = p_event_id and b.status = 'confirmed'
    returning 1)
  select count(*)::int into n from u;
  return n;
end
$$;

-- Internal: who attended (one row per person), for review requests.
create function bookings.attended_attendees(p_event_id uuid) returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select distinct b.attendee_id from bookings.bookings b where b.event_id = p_event_id and b.status = 'attended'
$$;

-- Internal: the bookings whose money the host keeps. A no-show paid for the seat, so it counts; a refunded
-- booking is cancelled (and its fee snapshot is zeroed), so it does not.
create function bookings.settled_booking_ids(p_event_id uuid) returns setof uuid
language sql stable security definer set search_path = ''
as $$
  select b.id from bookings.bookings b
   where b.event_id = p_event_id and b.status in ('confirmed', 'attended', 'no_show')
$$;

revoke all on function bookings.sign_ticket(uuid) from public;
revoke all on function bookings.ticket_token(uuid) from public;
revoke all on function bookings.check_in(uuid, text) from public;
revoke all on function bookings.set_checked_in(uuid, boolean) from public;
revoke all on function bookings.mark_no_shows(uuid) from public;
revoke all on function bookings.attended_attendees(uuid) from public;
revoke all on function bookings.settled_booking_ids(uuid) from public;

grant execute on function bookings.ticket_token(uuid) to authenticated;
grant execute on function bookings.check_in(uuid, text) to authenticated;
grant execute on function bookings.set_checked_in(uuid, boolean) to authenticated;
