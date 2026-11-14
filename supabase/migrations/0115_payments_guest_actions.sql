-- Manual payment: guest side. Instructions, receipt upload, and a Tickets list that keeps held and expired bookings.

-- Tickets: an unexpired hold ("Pay now") and an expired booking ("Upload receipt late") also show while the event is ahead.
drop function bookings.my_bookings(text);
create function bookings.my_bookings(p_scope text)
returns table (booking_id uuid, event_id uuid, people int, status text, hold_expires_at timestamptz,
               ticket_code text, contact_name text, contact_phone text, cancel_cutoff_at timestamptz,
               amount_sen int, checked_in_at timestamptz, cancelled_at timestamptz, created_at timestamptz,
               event_title text, event_glyph text, event_color_a text, event_color_b text, event_area text,
               event_venue text, event_starts_at timestamptz, event_ends_at timestamptz, event_status text,
               payment_method text)
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
         ev.title, ev.glyph, ev.color_a, ev.color_b, ev.area, ev.venue, ev.starts_at, ev.ends_at, ev.status,
         case when b.amount_sen = 0 then 'free' else payments.paid_method(b.id) end
    from bookings.bookings b
   cross join lateral events.event_brief(b.event_id) ev
   where b.attendee_id = auth.uid()
     and case p_scope
           when 'upcoming' then ev.ends_at > now() and (
                  b.status in ('processing', 'confirmed')
                  or (ev.starts_at > now() and (b.status = 'expired'
                      or (b.status = 'held' and b.hold_expires_at > now()))))
           else b.status in ('confirmed', 'processing', 'attended', 'no_show', 'cancelled')
                and not (b.status in ('processing', 'confirmed') and ev.ends_at > now())
         end
   order by case when p_scope = 'upcoming' then ev.starts_at end asc,
            case when p_scope = 'past' then ev.starts_at end desc;
end
$$;

revoke all on function bookings.my_bookings(text) from public;
grant execute on function bookings.my_bookings(text) to authenticated;

create function payments.pay_instructions(p_booking_id uuid)
returns table (amount_sen int, reference text, qr_path text, bank text, account_holder text, account_number text,
               hold_expires_at timestamptz, status text)
language sql stable security definer set search_path = ''
as $$
  select b.amount_sen, b.ticket_code, a.duitnow_qr_path, a.bank, a.account_holder, a.account_number, b.hold_expires_at, b.status
    from bookings.bookings b
    join events.events e on e.id = b.event_id
    left join identity.host_payout_accounts a on a.user_id = e.host_id
   where b.id = p_booking_id and b.attendee_id = auth.uid() and b.status in ('held', 'processing', 'expired');
$$;

-- Tells the host a receipt is waiting (in-app and push).
create function shared.notify_host_receipt(p_receipt_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r payments.receipts;
  host uuid;
  who text;
begin
  select x.* into r from payments.receipts x where x.id = p_receipt_id;
  select e.host_id, b.contact_name into host, who
    from bookings.bookings b join events.events e on e.id = b.event_id where b.id = r.booking_id;
  perform identity.notify(host, case when r.status = 'late' then 'late_receipt' else 'receipt_submitted' end,
    'receipt', r.id,
    case when r.status = 'late' then 'Late receipt' else 'New receipt' end,
    who || ' uploaded a payment receipt');
  perform shared.send_push(host, case when r.status = 'late' then 'Late receipt' else 'New receipt' end,
    who || ' uploaded a payment receipt', 'receipt', r.id);
end
$$;
revoke all on function shared.notify_host_receipt(uuid) from public, anon, authenticated;

create function payments.submit_receipt(p_booking_id uuid, p_image_path text)
returns payments.receipts
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  b bookings.bookings;
  starts timestamptz;
  r payments.receipts;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select x.* into b from bookings.bookings x where x.id = p_booking_id for update;
  if not found or b.attendee_id <> uid then
    raise exception 'not_owner';
  end if;
  if b.status not in ('held', 'processing', 'expired') then
    raise exception 'not_payable';
  end if;
  if p_image_path is null or p_image_path not like p_booking_id::text || '/%' then
    raise exception 'bad_receipt_path';
  end if;
  select e.starts_at into starts from events.events e where e.id = b.event_id;
  if starts <= now() then
    raise exception 'event_started';
  end if;

  update payments.receipts x set status = 'replaced' where x.booking_id = b.id and x.status = 'pending';
  insert into payments.receipts (booking_id, image_path, status, push_count)
  values (b.id, p_image_path, case when b.status = 'expired' then 'late' else 'pending' end,
          case when b.status = 'expired' then 0 else 1 end)  -- the push at upload is the first of three
  returning * into r;
  if b.status = 'held' then
    update bookings.bookings x set status = 'processing', hold_expires_at = null where x.id = b.id;
  end if;
  perform shared.notify_host_receipt(r.id);
  return r;
end
$$;

revoke all on function payments.pay_instructions(uuid) from public;
revoke all on function payments.submit_receipt(uuid, text) from public;
grant execute on function payments.pay_instructions(uuid) to authenticated;
grant execute on function payments.submit_receipt(uuid, text) to authenticated;
