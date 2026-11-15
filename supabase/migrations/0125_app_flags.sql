-- Feature flags, changed by hand in the database (see docs/release/staging.md). The app reads them at start and on resume.
create schema if not exists app;
grant usage on schema app to anon, authenticated;

create table app.flags (
  key   text primary key,
  value jsonb not null
);
alter table app.flags enable row level security;
revoke all on app.flags from public, anon, authenticated;

-- host_entry_enabled: whether this app shows the host entrance at all (so the host side can move to its own app later)
insert into app.flags (key, value) values ('host_entry_enabled', 'true');

create function app.get_flags() returns table (key text, value jsonb)
language sql stable security definer set search_path = ''
as $$ select f.key, f.value from app.flags f $$;

revoke all on function app.get_flags() from public;
grant execute on function app.get_flags() to anon, authenticated;
