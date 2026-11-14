-- Manual payment: one row per receipt image a guest uploads for a booking.
create table payments.receipts (
  id            uuid primary key default gen_random_uuid(),
  booking_id    uuid not null references bookings.bookings (id),
  image_path    text not null,
  status        text not null default 'pending' check (status in ('pending', 'accepted', 'replaced', 'late')),
  note          text,
  uploaded_at   timestamptz not null default now(),
  decided_by    uuid,
  decided_at    timestamptz,
  push_count    int not null default 0,
  chat_reminded boolean not null default false,
  file_purged   boolean not null default false
);
create index receipts_booking_idx on payments.receipts (booking_id);
create index receipts_pending_idx on payments.receipts (uploaded_at) where status = 'pending';

alter table payments.receipts enable row level security;
create policy own_receipts on payments.receipts for select to authenticated
  using (exists (select 1 from bookings.bookings b where b.id = booking_id and b.attendee_id = (select auth.uid())));
grant select on payments.receipts to authenticated;

create function payments.is_host_of_booking(p_booking uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from bookings.bookings b join events.events e on e.id = b.event_id
                  where b.id = p_booking and e.host_id = auth.uid());
$$;
revoke all on function payments.is_host_of_booking(uuid) from public;
grant execute on function payments.is_host_of_booking(uuid) to authenticated;

create function payments.is_attendee_of_booking(p_booking uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from bookings.bookings b where b.id = p_booking and b.attendee_id = auth.uid());
$$;
revoke all on function payments.is_attendee_of_booking(uuid) from public;
grant execute on function payments.is_attendee_of_booking(uuid) to authenticated;

insert into storage.buckets (id, name, public) values ('receipts', 'receipts', false);

-- Folder is the booking id: the guest writes and reads it, the event's host reads it.
create policy receipts_attendee_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and payments.is_attendee_of_booking(((storage.foldername(name))[1])::uuid));
create policy receipts_read on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and (payments.is_attendee_of_booking(((storage.foldername(name))[1])::uuid)
                                     or payments.is_host_of_booking(((storage.foldername(name))[1])::uuid)));
