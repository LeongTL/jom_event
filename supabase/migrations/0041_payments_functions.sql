-- Payments module functions. security definer + pinned search_path: the only write path.

-- Fees on a gross amount, in whole sen, rounded half up. The 1.5% gateway fee is illustrative until a
-- real gateway is chosen. 36000 gives 540, 3600 and 31860.
create function payments.compute_fees(gross_sen int)
returns table (gateway_fee_sen int, platform_fee_sen int, host_receives_sen int)
language sql immutable
as $$
  select f.g, f.p, compute_fees.gross_sen - f.g - f.p
    from (select ((compute_fees.gross_sen::bigint * 15 + 500) / 1000)::int as g,
                 ((compute_fees.gross_sen::bigint * 10 + 50) / 100)::int as p) f
$$;

-- Opens a gateway session for a held or failed booking. An unexpired session is reused; a session never
-- outlives the hold.
create function payments.start_payment(p_booking_id uuid)
returns table (attempt_id uuid, reference text, amount_sen int, expires_at timestamptz)
language plpgsql security definer set search_path = ''
as $$
#variable_conflict use_column
declare
  uid uuid := auth.uid();
  br record;
  a record;
  new_id uuid;
  ref text;
  exp timestamptz;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select * into br from bookings.booking_brief(p_booking_id);
  if not found or br.attendee_id <> uid then
    raise exception 'not_owner';
  end if;
  if br.amount_sen <= 0 then
    raise exception 'nothing_to_pay';
  end if;
  if br.status not in ('held', 'payment_failed') then
    raise exception 'not_payable';
  end if;
  if br.hold_expires_at is null or br.hold_expires_at <= now() then
    raise exception 'hold_expired';
  end if;

  select x.id, x.reference, x.session_expires_at into a
    from payments.payment_attempts x
   where x.booking_id = p_booking_id and x.status = 'created' and x.session_expires_at > now()
   order by x.created_at desc limit 1;
  if found then
    return query select a.id, a.reference, br.amount_sen, a.session_expires_at;
    return;
  end if;

  ref := br.ticket_code || '-' || upper(substr(md5(gen_random_uuid()::text), 1, 8));
  exp := least(now() + interval '10 minutes', br.hold_expires_at);
  insert into payments.payment_attempts (booking_id, reference, session_expires_at)
  values (p_booking_id, ref, exp)
  returning id into new_id;
  return query select new_id, ref, br.amount_sen, exp;
end
$$;

-- Mock gateway: settles a refund at once. shortcut: with a real gateway, refund_booking keeps writing
-- 'requested' and an edge function calls PaymentProvider.refund and marks it done or failed; this function
-- is the one place to swap, and retry_failed_refunds re-runs failed ones.
create function payments.run_refund(p_refund_id uuid) returns void
language sql security definer set search_path = ''
as $$
  update payments.refunds r
     set status = 'done', provider_ref = 'mock-' || r.id::text, attempts = r.attempts + 1
   where r.id = p_refund_id and r.status in ('requested', 'failed')
$$;

-- Refunds money that was actually received, in full, once per booking. Free bookings and bookings that
-- were never paid are a no-op. Replaces the Task 6 stub.
create or replace function payments.refund_booking(p_booking_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  br record;
  rid uuid;
begin
  select * into br from bookings.booking_brief(p_booking_id);
  if not found or br.amount_sen <= 0 then
    return;
  end if;
  if not exists (select 1 from payments.payment_attempts a where a.booking_id = p_booking_id and a.status = 'success') then
    return;
  end if;

  insert into payments.refunds (booking_id, amount_sen, reason)
  values (p_booking_id, br.amount_sen, p_reason)
  on conflict (booking_id) do nothing
  returning id into rid;
  if rid is null then
    return;
  end if;

  update payments.fee_snapshots f
     set gross_sen = 0, gateway_fee_sen = 0, platform_fee_sen = 0, host_receives_sen = 0
   where f.booking_id = p_booking_id;
  perform payments.run_refund(rid);
end
$$;

-- Run every 10 minutes by pg_cron (Task 12): failed refunds are tried again, up to 5 attempts.
create function payments.retry_failed_refunds() returns int
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n int := 0;
begin
  for r in select x.id from payments.refunds x where x.status = 'failed' and x.attempts < 5 for update skip locked loop
    perform payments.run_refund(r.id);
    n := n + 1;
  end loop;
  return n;
end
$$;

-- The gateway webhook's entry point (service_role only). The booking is decided here, never by the app
-- screen. Safe to call twice: a success is final, a failure can still be followed by a success, and a
-- repeated result changes nothing.
create function payments.apply_gateway_result(p_attempt_id uuid, p_outcome text, p_method text) returns text
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
  else
    -- the hold ran out and the seats are gone, or the booking/event was cancelled: give the money back
    perform payments.refund_booking(a.booking_id, 'late_payment');
  end if;
  return res;
end
$$;

-- How the guest paid, for the host's guest list. Replaces the Task 6 stub.
create or replace function payments.paid_method(p_booking_id uuid) returns text
language sql stable security definer set search_path = ''
as $$
  select a.method from payments.payment_attempts a
   where a.booking_id = p_booking_id and a.status = 'success'
   order by a.created_at desc limit 1
$$;

-- For the mock gateway function: whose attempt is this?
create function payments.attempt_info(p_attempt_id uuid) returns table (reference text, attendee_id uuid, status text)
language sql stable security definer set search_path = ''
as $$
  select a.reference, b.attendee_id, a.status
    from payments.payment_attempts a
    cross join lateral bookings.booking_brief(a.booking_id) b
   where a.id = p_attempt_id
$$;

create function payments.claim_webhook_delivery(p_delivery_id text) returns boolean
language plpgsql security definer set search_path = ''
as $$
begin
  insert into payments.webhook_deliveries (delivery_id) values (p_delivery_id) on conflict do nothing;
  return found;
end
$$;

create function payments.release_webhook_delivery(p_delivery_id text) returns boolean
language plpgsql security definer set search_path = ''
as $$
begin
  delete from payments.webhook_deliveries d where d.delivery_id = p_delivery_id;
  return found;
end
$$;

revoke all on function payments.compute_fees(int) from public;
revoke all on function payments.start_payment(uuid) from public;
revoke all on function payments.run_refund(uuid) from public;
revoke all on function payments.refund_booking(uuid, text) from public;
revoke all on function payments.retry_failed_refunds() from public;
revoke all on function payments.apply_gateway_result(uuid, text, text) from public;
revoke all on function payments.paid_method(uuid) from public;
revoke all on function payments.attempt_info(uuid) from public;
revoke all on function payments.claim_webhook_delivery(text) from public;
revoke all on function payments.release_webhook_delivery(text) from public;

grant execute on function payments.start_payment(uuid) to authenticated;
grant execute on function payments.apply_gateway_result(uuid, text, text) to service_role;
grant execute on function payments.attempt_info(uuid) to service_role;
grant execute on function payments.claim_webhook_delivery(text) to service_role;
grant execute on function payments.release_webhook_delivery(text) to service_role;
