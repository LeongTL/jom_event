-- Manual payment: the host's payment details are a DuitNow QR image, bank details, or both.
alter table identity.host_payout_accounts
  add column duitnow_qr_path text,
  alter column account_holder drop not null,
  alter column bank drop not null,
  alter column account_number drop not null,
  add constraint payment_details_present check (
    duitnow_qr_path is not null or (account_holder is not null and bank is not null and account_number is not null));

create function identity.save_payment_details(p_holder text, p_bank text, p_number text, p_qr_path text)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  h text := nullif(btrim(p_holder), '');
  b text := nullif(btrim(p_bank), '');
  n text := nullif(btrim(p_number), '');
  q text := nullif(btrim(p_qr_path), '');
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if not identity.is_host(uid) then
    raise exception 'not_a_host';
  end if;
  if q is null and (h is null or b is null or n is null) then
    raise exception 'payment_details_required';
  end if;
  insert into identity.host_payout_accounts (user_id, account_holder, bank, account_number, duitnow_qr_path)
  values (uid, h, b, n, q)
  on conflict (user_id) do update
    set account_holder = excluded.account_holder, bank = excluded.bank,
        account_number = excluded.account_number, duitnow_qr_path = excluded.duitnow_qr_path;
end
$$;
revoke all on function identity.save_payment_details(text, text, text, text) from public;
grant execute on function identity.save_payment_details(text, text, text, text) to authenticated;

-- A guest may see a host's QR only while they hold or wait on a booking of that host's events.
create function payments.guest_sees_qr(p_host uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from bookings.bookings b join events.events e on e.id = b.event_id
    where e.host_id = p_host and b.attendee_id = auth.uid() and b.status in ('held', 'processing', 'expired'));
$$;
revoke all on function payments.guest_sees_qr(uuid) from public;
grant execute on function payments.guest_sees_qr(uuid) to authenticated;

insert into storage.buckets (id, name, public) values ('payment-qr', 'payment-qr', false);

create policy payment_qr_host_all on storage.objects for all to authenticated
  using (bucket_id = 'payment-qr' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'payment-qr' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy payment_qr_guest_read on storage.objects for select to authenticated
  using (bucket_id = 'payment-qr' and payments.guest_sees_qr(((storage.foldername(name))[1])::uuid));
