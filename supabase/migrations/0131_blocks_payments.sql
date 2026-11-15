-- Block and manual payments. A block must never leave a guest stuck on a pending receipt:
--  * messages the system posts for the host (ask for a new receipt) still go through, and the guest is told by notification and push
--    even though the thread is hidden from a guest who blocked that host;
--  * the guest's own 45 minute chat reminder is not posted across a block, in either direction.

create or replace function payments.run_receipt_reminders() returns int
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
  n int := 0;
  stage int;
  guest text;
  host uuid;
  guest_id uuid;
  event_id uuid;
begin
  for r in
    select x.id, x.booking_id, x.push_count, x.chat_reminded, x.uploaded_at
      from payments.receipts x join bookings.bookings b on b.id = x.booking_id
     where x.status = 'pending' and b.status = 'processing' and not x.chat_reminded
       and ((x.push_count in (1, 2) and now() >= x.uploaded_at + make_interval(mins => 15 * x.push_count))
         or (x.push_count = 3 and now() >= x.uploaded_at + interval '45 minutes'))
     order by x.uploaded_at
       for update of x skip locked
  loop
    select e.host_id, b.attendee_id, b.contact_name, e.id into host, guest_id, guest, event_id
      from bookings.bookings b join events.events e on e.id = b.event_id where b.id = r.booking_id;
    if r.push_count < 3 then
      update payments.receipts x set push_count = x.push_count + 1 where x.id = r.id;
      perform identity.notify(host, 'receipt_reminder', 'receipt', r.id, 'Receipt still waiting',
                              guest || ' is waiting for you to confirm payment');
      perform shared.send_push(host, 'Receipt still waiting', guest || ' is waiting for you to confirm payment', 'receipt', r.id);
    else
      update payments.receipts x set chat_reminded = true where x.id = r.id;
      -- This message speaks for the guest, so it is not posted once either side has blocked the other.
      -- The stage is still marked done so it does not come round again.
      if not identity.is_blocked_between(guest_id, host) then
        perform chat.post_system_message(chat.ensure_thread(guest_id, host, event_id), guest_id,
                                         'My payment receipt is waiting for your confirmation.');
        perform shared.send_push(host, guest, 'My payment receipt is waiting for your confirmation.', 'receipt', r.id);
      end if;
    end if;
    n := n + 1;
  end loop;
  return n;
end
$$;
