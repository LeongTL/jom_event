-- Events module: areas and events. Clients only read; every write goes through the functions in 0021.

create table events.areas (
  name text primary key,
  lat  float8 not null,
  lng  float8 not null
);

insert into events.areas (name, lat, lng) values
  ('Bangsar',       3.1290, 101.6710),
  ('KLCC',          3.1579, 101.7116),
  ('PJ',            3.1073, 101.6067),
  ('Sri Hartamas',  3.1634, 101.6500),
  ('Mid Valley',    3.1177, 101.6770),
  ('Bukit Bintang', 3.1466, 101.7107);

-- host_id has no foreign key: identity is another module (save_draft checks it with identity.is_host).
-- Drafts may be incomplete, so most columns are nullable; events.publish checks the rest.
create table events.events (
  id              uuid primary key default gen_random_uuid(),
  host_id         uuid not null,
  title           text not null,
  description     text,
  glyph           text,
  color_a         text,
  color_b         text,
  poster_url      text,
  categories      text[] not null default '{}' check (categories <@ array['make','move','meet','other']),
  area            text references events.areas (name),
  venue           text,
  lat             float8,
  lng             float8,
  starts_at       timestamptz,
  ends_at         timestamptz,
  capacity        int check (capacity between 1 and 40),
  price_sen       int check (price_sen >= 0),
  cancel_policy   text not null default '24h' check (cancel_policy in ('24h', '48h', '7d', 'none')),
  accept_bookings boolean not null default true,
  source_url      text,
  status          text not null default 'draft' check (status in ('draft', 'published', 'ended', 'cancelled')),
  created_at      timestamptz not null default now()
);

alter table events.areas  enable row level security;
alter table events.events enable row level security;

create policy areas_public on events.areas for select to anon, authenticated using (true);
create policy events_public on events.events for select to anon, authenticated
  using (status in ('published', 'ended'));
create policy events_own on events.events for select to authenticated
  using (host_id = (select auth.uid()));

grant usage on schema events to anon, authenticated;
grant select on events.areas, events.events to anon, authenticated;
