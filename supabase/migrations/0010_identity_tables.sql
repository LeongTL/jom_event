-- Identity module: who people are, host profiles, saved events, in-app notifications.
-- Clients only read these tables (own rows); every write goes through the functions in 0011.

create table identity.profiles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  name       text,
  phone      text,
  is_host    boolean not null default false,
  created_at timestamptz not null default now()
);

create table identity.hosts (
  user_id     uuid primary key references identity.profiles (user_id) on delete cascade,
  host_name   text not null,
  area        text not null,
  bio         text,
  avatar_url  text,
  ssm_number  text,
  verified_at timestamptz, -- set by hand in the dashboard after checking the payout account holder
  created_at  timestamptz not null default now()
);

create table identity.host_payout_accounts (
  user_id        uuid primary key references identity.hosts (user_id) on delete cascade,
  account_holder text not null,
  bank           text not null,
  account_number text not null
);

-- event_id has no foreign key: events is another module; toggle_save checks it through events.exists_published.
create table identity.saved_events (
  user_id    uuid not null references identity.profiles (user_id) on delete cascade,
  event_id   uuid not null,
  created_at timestamptz not null default now(),
  primary key (user_id, event_id)
);

create table identity.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references identity.profiles (user_id) on delete cascade,
  type       text not null,
  ref_type   text,
  ref_id     uuid,
  title      text not null,
  body       text,
  created_at timestamptz not null default now(),
  read_at    timestamptz
);

create table identity.notification_prefs (
  user_id         uuid primary key references identity.profiles (user_id) on delete cascade,
  chat            boolean not null default true,
  review_requests boolean not null default true
);

alter table identity.profiles             enable row level security;
alter table identity.hosts                enable row level security;
alter table identity.host_payout_accounts enable row level security;
alter table identity.saved_events         enable row level security;
alter table identity.notifications        enable row level security;
alter table identity.notification_prefs   enable row level security;

create policy own_row on identity.profiles             for select to authenticated using (user_id = (select auth.uid()));
create policy own_row on identity.hosts                for select to authenticated using (user_id = (select auth.uid()));
create policy own_row on identity.host_payout_accounts for select to authenticated using (user_id = (select auth.uid()));
create policy own_row on identity.saved_events         for select to authenticated using (user_id = (select auth.uid()));
create policy own_row on identity.notifications        for select to authenticated using (user_id = (select auth.uid()));
create policy own_row on identity.notification_prefs   for select to authenticated using (user_id = (select auth.uid()));

-- Read-only for clients: no insert/update/delete grants, so a direct write fails with "permission denied".
grant usage on schema identity to anon, authenticated;
grant select on identity.profiles, identity.hosts, identity.host_payout_accounts,
                identity.saved_events, identity.notifications, identity.notification_prefs
  to authenticated;

-- Public host profile for signed-out visitors. Runs with the owner's rights on purpose (so anon needs no
-- access to identity.hosts) and lists only safe columns: no ssm_number, verified_at or bank details.
create view identity.host_public as
  select user_id, host_name, area, bio, avatar_url, created_at as since
  from identity.hosts;

grant select on identity.host_public to anon, authenticated;
