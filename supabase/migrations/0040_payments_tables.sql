-- Payments module. Clients can read their own attempts and refunds and a host their own payouts;
-- every write goes through the functions in 0041 (the gateway webhook runs as service_role).
-- booking_id, host_id and event_id have no foreign keys: those belong to other modules.

create table payments.payment_attempts (
  id                 uuid primary key default gen_random_uuid(),
  booking_id         uuid not null,
  reference          text not null unique,
  method             text,
  status             text not null default 'created' check (status in ('created', 'success', 'failed', 'pending')),
  session_expires_at timestamptz not null,
  raw                jsonb,
  created_at         timestamptz not null default now()
);

-- One refund per booking, so asking twice cannot pay a guest twice.
create table payments.refunds (
  id           uuid primary key default gen_random_uuid(),
  booking_id   uuid not null unique,
  amount_sen   int not null check (amount_sen >= 0),
  reason       text not null,
  status       text not null default 'requested' check (status in ('requested', 'done', 'failed')),
  provider_ref text,
  attempts     int not null default 0,
  created_at   timestamptz not null default now()
);

-- What a paid booking earns the host, saved per booking so old bookings never change when rates do.
-- A refund zeroes the row, so sums over it only ever count money the host keeps.
create table payments.fee_snapshots (
  booking_id        uuid primary key,
  gross_sen         int not null,
  gateway_fee_sen   int not null,
  platform_fee_sen  int not null,
  host_receives_sen int not null
);

create table payments.payouts (
  id         uuid primary key default gen_random_uuid(),
  host_id    uuid not null,
  event_id   uuid not null unique,
  amount_sen int not null,
  status     text not null default 'scheduled' check (status in ('scheduled', 'paid')),
  due_at     timestamptz not null,
  paid_ref   text,
  paid_at    timestamptz
);

-- Webhook deliveries already handled, so a gateway retry of the same delivery is not applied twice.
create table payments.webhook_deliveries (
  delivery_id text primary key,
  received_at timestamptz not null default now()
);

alter table payments.payment_attempts  enable row level security;
alter table payments.refunds           enable row level security;
alter table payments.fee_snapshots     enable row level security;
alter table payments.payouts           enable row level security;
alter table payments.webhook_deliveries enable row level security;

create policy own_attempts on payments.payment_attempts for select to authenticated
  using (bookings.owns_booking(booking_id));
create policy own_refunds on payments.refunds for select to authenticated
  using (bookings.owns_booking(booking_id));
create policy own_payouts on payments.payouts for select to authenticated
  using (host_id = (select auth.uid()));

grant usage on schema payments to authenticated, service_role;
-- the raw gateway payload stays server-side
grant select (id, booking_id, reference, method, status, session_expires_at, created_at)
  on payments.payment_attempts to authenticated;
grant select on payments.refunds, payments.payouts to authenticated;
