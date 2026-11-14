-- Manual payment: remind the host while a receipt waits, and delete receipt files 30 days after the event.
-- Timeline from the upload: push (sent at upload, push_count 1), push at +15 min (2), push at +30 min (3),
-- then one chat message at +45 min. Each run moves a receipt one stage; nothing runs once it is decided.

create function payments.run_receipt_reminders() returns int
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
      perform chat.post_system_message(chat.ensure_thread(guest_id, host, event_id), guest_id,
                                       'My payment receipt is waiting for your confirmation.');
      perform shared.send_push(host, guest, 'My payment receipt is waiting for your confirmation.', 'receipt', r.id);
    end if;
    n := n + 1;
  end loop;
  return n;
end
$$;

-- Hands the receipt-purge function the files to delete and marks them, so each is handed out once.
create function payments.claim_expired_receipt_files() returns table (receipt_id uuid, image_path text)
language sql security definer set search_path = ''
as $$
  update payments.receipts r set file_purged = true
   from bookings.bookings b, events.events e
   where b.id = r.booking_id and e.id = b.event_id and not r.file_purged
     and e.ends_at < now() - interval '30 days'
  returning r.id, r.image_path;
$$;

create function shared.call_receipt_purge() returns void
language plpgsql security definer set search_path = ''
as $$
declare
  base_url text;
  service_key text;
begin
  select s.decrypted_secret into base_url from vault.decrypted_secrets s where s.name = 'functions_url';
  select s.decrypted_secret into service_key from vault.decrypted_secrets s where s.name = 'service_role_key';
  if base_url is null or service_key is null then
    return;
  end if;
  perform net.http_post(url := base_url || '/receipt-purge',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || service_key),
    body := '{}'::jsonb);
exception when others then
  raise warning 'receipt purge not queued: %', sqlerrm;
end
$$;

revoke all on function payments.run_receipt_reminders() from public, anon, authenticated;
revoke all on function payments.claim_expired_receipt_files() from public, anon, authenticated;
revoke all on function shared.call_receipt_purge() from public, anon, authenticated;
grant execute on function payments.claim_expired_receipt_files() to service_role;

select cron.schedule('receipt-reminders', '* * * * *', 'select payments.run_receipt_reminders()');
select cron.schedule('receipt-purge', '17 3 * * *', 'select shared.call_receipt_purge()');
