-- Manual payment: host side. Review receipts, ask for a new one, assign a seat by hand, record a refund done outside the app.

alter table bookings.bookings add column refund_note text;

-- Chat: write in a guest/host thread on the system's behalf. Callable by the service role only.
create function chat.ensure_thread(p_attendee uuid, p_host uuid, p_event uuid) returns uuid
language sql security definer set search_path = ''
as $$
  insert into chat.threads (attendee_id, host_id, event_id) values (p_attendee, p_host, p_event)
  on conflict (attendee_id, host_id) do update set event_id = coalesce(excluded.event_id, chat.threads.event_id)
  returning id
$$;

create function chat.post_system_message(p_thread_id uuid, p_sender_id uuid, p_body text) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  t chat.threads;
  ts timestamptz := clock_timestamp();
begin
  select x.* into t from chat.threads x where x.id = p_thread_id;
  if not found or p_sender_id not in (t.attendee_id, t.host_id) then
    raise exception 'not_participant';
  end if;
  insert into chat.messages (thread_id, sender_id, body, created_at) values (t.id, p_sender_id, left(btrim(p_body), 1000), ts);
  update chat.threads x set last_message_at = ts where x.id = t.id;
  insert into chat.thread_reads (thread_id, user_id, read_at) values (t.id, p_sender_id, ts)
  on conflict (thread_id, user_id) do update set read_at = excluded.read_at;
  perform identity.notify(case when p_sender_id = t.attendee_id then t.host_id else t.attendee_id end,
                          'chat_message', 'thread', t.id, (select p.name from identity.chat_party(p_sender_id) p), left(btrim(p_body), 80));
end
$$;
revoke all on function chat.ensure_thread(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function chat.post_system_message(uuid, uuid, text) from public, anon, authenticated;
grant execute on function chat.ensure_thread(uuid, uuid, uuid) to service_role;
grant execute on function chat.post_system_message(uuid, uuid, text) to service_role;

create function payments.pending_receipts(p_event_id uuid default null)
returns table (receipt_id uuid, booking_id uuid, event_id uuid, event_title text, guest_id uuid, guest_name text,
               guest_username text, amount_sen int, image_path text, status text, uploaded_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select r.id, b.id, e.id, e.title, b.attendee_id, coalesce(p.name, b.contact_name), p.username, b.amount_sen,
         r.image_path, r.status, r.uploaded_at
    from payments.receipts r
    join bookings.bookings b on b.id = r.booking_id
    join events.events e on e.id = b.event_id
    left join identity.profiles p on p.user_id = b.attendee_id
   where e.host_id = auth.uid() and r.status in ('pending', 'late')
     and (p_event_id is null or e.id = p_event_id)
   order by r.uploaded_at;
$$;

create function payments.accept_receipt(p_receipt_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  r payments.receipts;
  b bookings.bookings;
  outcome text;
begin
  select x.* into r from payments.receipts x where x.id = p_receipt_id;
  if not found or not payments.is_host_of_booking(r.booking_id) then
    raise exception 'not_host';
  end if;
  if r.status = 'accepted' then
    return;
  end if;
  if r.status <> 'pending' then
    raise exception 'not_pending';
  end if;
  outcome := bookings.mark_confirmed(r.booking_id);
  if outcome <> 'confirmed' then
    raise exception 'event_not_available';
  end if;
  update payments.receipts x set status = 'accepted', decided_by = auth.uid(), decided_at = now() where x.id = r.id;
  select x.* into b from bookings.bookings x where x.id = r.booking_id;
  perform identity.notify(b.attendee_id, 'receipt_accepted', 'booking', b.id, 'Payment confirmed', 'Your ticket is ready');
  perform shared.send_receipt(b.id);
end
$$;

create function payments.request_new_receipt(p_booking_id uuid, p_note text) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  b bookings.bookings;
  ev events.events;
  note text := coalesce(nullif(btrim(p_note), ''), 'Please upload your receipt again');
begin
  if not payments.is_host_of_booking(p_booking_id) then
    raise exception 'not_host';
  end if;
  select x.* into b from bookings.bookings x where x.id = p_booking_id for update;
  if b.status <> 'processing' then
    raise exception 'not_payable';
  end if;
  select x.* into ev from events.events x where x.id = b.event_id;
  if now() > ev.starts_at - interval '1 hour' then
    raise exception 'bookings_closed';
  end if;
  if shared.contains_contact_info(note) then
    raise exception 'contact_info_not_allowed';
  end if;
  update payments.receipts x set status = 'replaced', decided_by = auth.uid(), decided_at = now()
   where x.booking_id = b.id and x.status = 'pending';
  update bookings.bookings x
     set status = 'held',
         hold_expires_at = now() + greatest(interval '15 minutes', least(interval '1 hour', ev.starts_at - interval '30 minutes' - now()))
   where x.id = b.id;
  perform chat.post_system_message(chat.ensure_thread(b.attendee_id, ev.host_id, ev.id), ev.host_id, note);
  perform identity.notify(b.attendee_id, 'receipt_requested', 'booking', b.id, 'Please upload your receipt again', note);
end
$$;

create function payments.assign_seat(p_event_id uuid, p_user_id uuid, p_people int, p_receipt_id uuid, p_allow_over_capacity boolean)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  ev events.events;
  b bookings.bookings;
  prof identity.profiles;
  tries int := 0;
  has_booking boolean;
  need int;
begin
  select x.* into ev from events.events x where x.id = p_event_id;
  if not found or ev.host_id <> auth.uid() then
    raise exception 'not_host';
  end if;
  select x.* into prof from identity.profiles x where x.user_id = p_user_id;
  if not found then
    raise exception 'user_not_found';
  end if;
  if p_people is null or p_people not between 1 and 2 then
    raise exception 'people_out_of_range';
  end if;
  ev := events.lock_for_booking(p_event_id);
  if ev.status <> 'published' then
    raise exception 'event_not_available';
  end if;

  select x.* into b from bookings.bookings x
   where x.event_id = p_event_id and x.attendee_id = p_user_id
     and x.status in ('confirmed', 'attended', 'held', 'processing', 'payment_failed', 'expired')
   order by x.created_at desc limit 1 for update;
  if found and b.status in ('confirmed', 'attended') then
    return b.id;
  end if;
  has_booking := found;
  if not has_booking or b.status = 'expired' then
    need := p_people;
    if has_booking then
      need := b.people;
    end if;
    if bookings.seats_taken(p_event_id) + need > ev.capacity and not coalesce(p_allow_over_capacity, false) then
      raise exception 'event_full';
    end if;
  end if;

  if has_booking then
    update bookings.bookings x set status = 'confirmed', hold_expires_at = null where x.id = b.id;
  else
    loop
      tries := tries + 1;
      begin
        insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone,
                                       cancel_cutoff_at, amount_sen)
        values (p_event_id, p_user_id, p_people, 'confirmed', 'KLS-' || lpad(floor(random() * 100000)::int::text, 5, '0'),
                coalesce(prof.name, 'Guest'), coalesce(prof.phone, '-'), events.cancel_cutoff(p_event_id),
                coalesce(ev.price_sen, 0) * p_people)
        returning * into b;
        exit;
      exception when unique_violation then
        if tries >= 10 then raise; end if;
      end;
    end loop;
  end if;

  if p_receipt_id is not null then
    update payments.receipts x set status = 'accepted', decided_by = auth.uid(), decided_at = now()
     where x.id = p_receipt_id and x.status in ('pending', 'late')
       and exists (select 1 from bookings.bookings o where o.id = x.booking_id and o.attendee_id = p_user_id);
  end if;
  perform identity.notify(p_user_id, 'seat_assigned', 'booking', b.id, 'You have a seat', ev.title);
  perform shared.send_receipt(b.id);
  return b.id;
end
$$;

create function payments.record_refund(p_booking_id uuid, p_note text) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  b bookings.bookings;
begin
  if not payments.is_host_of_booking(p_booking_id) then
    raise exception 'not_host';
  end if;
  select x.* into b from bookings.bookings x where x.id = p_booking_id for update;
  if b.status not in ('confirmed', 'expired') then
    raise exception 'not_refundable';
  end if;
  update bookings.bookings x set status = 'cancelled', cancelled_at = now(), refund_note = nullif(btrim(p_note), '')
   where x.id = b.id;
end
$$;

revoke all on function payments.pending_receipts(uuid) from public;
revoke all on function payments.accept_receipt(uuid) from public;
revoke all on function payments.request_new_receipt(uuid, text) from public;
revoke all on function payments.assign_seat(uuid, uuid, int, uuid, boolean) from public;
revoke all on function payments.record_refund(uuid, text) from public;
grant execute on function payments.pending_receipts(uuid) to authenticated;
grant execute on function payments.accept_receipt(uuid) to authenticated;
grant execute on function payments.request_new_receipt(uuid, text) to authenticated;
grant execute on function payments.assign_seat(uuid, uuid, int, uuid, boolean) to authenticated;
grant execute on function payments.record_refund(uuid, text) to authenticated;
