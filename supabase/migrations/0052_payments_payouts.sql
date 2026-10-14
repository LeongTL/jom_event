-- Payments: scheduling the host's payout once an event is completed, and what the host sees.

-- Internal. One payout per event: the host's share of every booking that was paid and not refunded, due 3
-- working days after completion. No row (and no notice) when there is nothing to pay.
create function payments.schedule_payout(p_event_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  host uuid := (select h.host_id from events.event_brief(p_event_id) h);
  amt int;
  due timestamptz := shared.add_working_days(now(), 3);
  pid uuid;
begin
  select coalesce(sum(f.host_receives_sen), 0)::int into amt
    from bookings.settled_booking_ids(p_event_id) s
    join payments.fee_snapshots f on f.booking_id = s;
  if host is null or amt <= 0 then
    return;
  end if;
  insert into payments.payouts (host_id, event_id, amount_sen, due_at)
  values (host, p_event_id, amt, due)
  on conflict (event_id) do nothing
  returning id into pid;
  if pid is null then
    return;
  end if;
  perform identity.notify(host, 'payout', 'event', p_event_id, 'Payout scheduled',
    'RM' || to_char(amt / 100.0, 'FM999999990.00') || ' arrives by '
         || to_char(due at time zone 'Asia/Kuala_Lumpur', 'FMDy DD Mon') || '.');
end
$$;

-- The Payouts screen header: scheduled and paid totals for the signed-in host.
create function payments.host_payout_summary() returns table (upcoming_sen bigint, paid_sen bigint)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  return query
  select coalesce(sum(p.amount_sen) filter (where p.status = 'scheduled'), 0)::bigint,
         coalesce(sum(p.amount_sen) filter (where p.status = 'paid'), 0)::bigint
    from payments.payouts p
   where p.host_id = auth.uid();
end
$$;

-- One event's money, for its host: gross, fees and what the host receives. Refunded bookings are zeroed, no-shows
-- still count (they paid).
create function payments.event_earnings(p_event_id uuid)
returns table (gross_sen bigint, gateway_fee_sen bigint, platform_fee_sen bigint, host_receives_sen bigint)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if (select h.host_id from events.event_brief(p_event_id) h) is distinct from auth.uid() then
    raise exception 'not_owner';
  end if;
  return query
  select coalesce(sum(f.gross_sen), 0)::bigint, coalesce(sum(f.gateway_fee_sen), 0)::bigint,
         coalesce(sum(f.platform_fee_sen), 0)::bigint, coalesce(sum(f.host_receives_sen), 0)::bigint
    from bookings.settled_booking_ids(p_event_id) s
    join payments.fee_snapshots f on f.booking_id = s;
end
$$;

revoke all on function payments.schedule_payout(uuid) from public;
revoke all on function payments.host_payout_summary() from public;
revoke all on function payments.event_earnings(uuid) from public;

grant execute on function payments.host_payout_summary() to authenticated;
grant execute on function payments.event_earnings(uuid) to authenticated;
