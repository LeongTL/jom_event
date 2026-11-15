-- Public or private events. A private event is hidden from every list and from the open read policy; it is opened
-- with its share code (events.event_by_code, 0115) or by id by the people who already have it. The code is random,
-- not the id, and is made when the event row is made.

-- 10 letters and digits from 122 random bits.
create function events.new_share_code() returns text
language sql volatile set search_path = ''
as $$
  select left(translate(encode(decode(replace(gen_random_uuid()::text, '-', ''), 'hex'), 'base64'), '+/=', 'xyz'), 10)
$$;
grant execute on function events.new_share_code() to authenticated, service_role;

-- the volatile default fills every existing row with its own code
alter table events.events
  add column visibility text not null default 'public' check (visibility in ('public', 'private')),
  add column share_code text not null default events.new_share_code(),
  add constraint events_share_code_key unique (share_code);

drop policy events_public on events.events;
create policy events_public on events.events for select to anon, authenticated
  using (status in ('published', 'ended') and visibility = 'public');
