-- Bookings module: one table. Clients read their own rows; every write goes through the functions in 0031.
-- event_id and attendee_id have no foreign keys: events and identity are other modules.
create table bookings.bookings (
  id               uuid primary key default gen_random_uuid(),
  event_id         uuid not null,
  attendee_id      uuid not null,
  people           int not null check (people between 1 and 2),
  status           text not null default 'held' check (status in
                     ('held', 'processing', 'confirmed', 'attended', 'payment_failed', 'cancelled', 'expired', 'no_show')),
  hold_expires_at  timestamptz,
  ticket_code      text not null unique,
  contact_name     text not null,
  contact_phone    text not null,
  cancel_cutoff_at timestamptz,  -- copied from the host's policy when the booking is made; null = no refund
  amount_sen       int not null check (amount_sen >= 0),
  checked_in_at    timestamptz,
  cancelled_at     timestamptz,
  created_at       timestamptz not null default now()
);

alter table bookings.bookings enable row level security;
create policy own_bookings on bookings.bookings for select to authenticated
  using (attendee_id = (select auth.uid()));

grant usage on schema bookings to authenticated;
grant select on bookings.bookings to authenticated;
