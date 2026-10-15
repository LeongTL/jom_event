-- Receipts: when a booking is confirmed (a free join, or a paid booking whose payment succeeded) the database
-- queues a call to the receipt-email edge function through pg_net. The call is only queued once the function
-- URL and the service key are stored in Vault ('functions_url', 'service_role_key'), so nothing is sent from a
-- fresh database or from CI. pg_net queues the request with the transaction: if the booking rolls back,
-- no receipt goes out.
create extension if not exists pg_net with schema extensions;

-- Internal: the sign-in email of a user, or null for someone who signed in with a phone number.
create function identity.email_of(p_user_id uuid) returns text
language sql stable security definer set search_path = ''
as $$ select u.email::text from auth.users u where u.id = p_user_id $$;

-- Internal: queue the receipt for a confirmed booking. Never raises: a receipt problem must not undo a booking.
create function shared.send_receipt(p_booking_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  base_url text;
  service_key text;
  br record;
  ev record;
begin
  select s.decrypted_secret into base_url from vault.decrypted_secrets s where s.name = 'functions_url';
  select s.decrypted_secret into service_key from vault.decrypted_secrets s where s.name = 'service_role_key';
  if base_url is null or service_key is null then
    return;
  end if;

  select * into br from bookings.booking_brief(p_booking_id);
  select * into ev from events.event_brief(br.event_id);
  perform net.http_post(
    url := base_url || '/receipt-email',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || service_key),
    body := jsonb_build_object(
      'bookingId', p_booking_id,
      'email', identity.email_of(br.attendee_id),
      'name', br.contact_name,
      'eventTitle', ev.title,
      'startsAt', ev.starts_at,
      'venue', ev.venue,
      'people', br.people,
      'amountSen', br.amount_sen,
      'ticketCode', br.ticket_code));
exception when others then
  raise warning 'receipt not queued for booking %: %', p_booking_id, sqlerrm;
end
$$;

revoke all on function identity.email_of(uuid) from public;
revoke all on function shared.send_receipt(uuid) from public;

-- The two places a booking becomes confirmed now queue a receipt. Everything else in both functions is
-- unchanged from 0031 and 0041 (create or replace keeps their grants).

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
  if not paid then
    perform shared.send_receipt(b.id);  -- free: confirmed already, so the receipt goes now
  end if;
  return b;
end
$$;

create or replace function payments.apply_gateway_result(p_attempt_id uuid, p_outcome text, p_method text) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  a payments.payment_attempts;
  br record;
  ev record;
  res text;
begin
  if p_outcome is null or p_outcome not in ('success', 'failed', 'pending') then
    raise exception 'unknown_outcome';
  end if;
  select * into a from payments.payment_attempts x where x.id = p_attempt_id for update;
  if not found then
    raise exception 'attempt_not_found';
  end if;
  select * into br from bookings.booking_brief(a.booking_id);

  if a.status = 'success' or a.status = p_outcome or (a.status = 'failed' and p_outcome <> 'success') then
    return br.status;
  end if;
  update payments.payment_attempts x
     set status = p_outcome, method = coalesce(p_method, x.method)
   where x.id = a.id;

  if p_outcome = 'pending' then
    return bookings.mark_processing(a.booking_id);
  elsif p_outcome = 'failed' then
    return bookings.mark_payment_failed(a.booking_id);
  end if;

  res := bookings.mark_confirmed(a.booking_id);
  if res = 'confirmed' then
    insert into payments.fee_snapshots (booking_id, gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen)
    select a.booking_id, br.amount_sen, f.gateway_fee_sen, f.platform_fee_sen, f.host_receives_sen
      from payments.compute_fees(br.amount_sen) f
    on conflict (booking_id) do nothing;

    select * into ev from events.event_brief(br.event_id);
    perform identity.notify(br.attendee_id, 'payment', 'booking', a.booking_id,
                            'Payment received', 'You''re in: ' || ev.title);
    perform identity.notify(ev.host_id, 'booking', 'event', br.event_id, 'New booking',
                            br.contact_name || ' joined ' || ev.title || ' (' || br.people || case when br.people = 1 then ' spot)' else ' spots)' end);
    perform shared.send_receipt(a.booking_id);
  else
    -- the hold ran out and the seats are gone, or the booking/event was cancelled: give the money back
    perform payments.refund_booking(a.booking_id, 'late_payment');
  end if;
  return res;
end
$$;
