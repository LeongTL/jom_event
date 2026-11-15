-- Block and report. A block is one row, read only by the blocker. A report is private to admins.
-- Writes go through the functions below; clients have no table grants on reports.

create table identity.blocks (
  blocker_id uuid not null references identity.profiles (user_id) on delete cascade,
  blocked_id uuid not null references identity.profiles (user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocks_blocked_idx on identity.blocks (blocked_id);

alter table identity.blocks enable row level security;
create policy own_blocks on identity.blocks for select to authenticated using (blocker_id = (select auth.uid()));
grant select on identity.blocks to authenticated;

create table identity.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null,
  target_type text not null check (target_type in ('user', 'event', 'message')),
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'harassment', 'scam', 'fake_event', 'other')),
  note text check (char_length(note) <= 500),
  status text not null default 'open',
  created_at timestamptz not null default now()
);
create index reports_open_idx on identity.reports (created_at desc) where status = 'open';
alter table identity.reports enable row level security;
revoke all on identity.reports from public, anon, authenticated;

-- Internal: true when either has blocked the other.
create function identity.is_blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from identity.blocks x
                  where (x.blocker_id = a and x.blocked_id = b) or (x.blocker_id = b and x.blocked_id = a))
$$;

-- Blocking removes the follows in both directions. Doing it twice changes nothing.
create function identity.block_user(p_user_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_user_id = uid then
    raise exception 'cannot_block_self';
  end if;
  if not exists (select 1 from identity.profiles p where p.user_id = p_user_id) then
    raise exception 'user_not_found';
  end if;
  insert into identity.blocks (blocker_id, blocked_id) values (uid, p_user_id) on conflict do nothing;
  delete from identity.follows f
   where (f.follower_id = uid and f.followee_id = p_user_id) or (f.follower_id = p_user_id and f.followee_id = uid);
end
$$;

create function identity.unblock_user(p_user_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  delete from identity.blocks b where b.blocker_id = auth.uid() and b.blocked_id = p_user_id;
end
$$;

create function identity.my_blocks()
returns table (user_id uuid, name text, username text, avatar_url text, blocked_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select b.blocked_id, coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest'), p.username, h.avatar_url, b.created_at
    from identity.blocks b
    join identity.profiles p on p.user_id = b.blocked_id
    left join identity.hosts h on h.user_id = b.blocked_id
   where b.blocker_id = auth.uid()
   order by b.created_at desc
$$;

-- A report about a person, a published or ended event, or a chat message the reporter took part in.
create function identity.report(p_target_type text, p_target_id uuid, p_reason text, p_note text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_target_type is null or p_target_type not in ('user', 'event', 'message') then
    raise exception 'bad_target';
  end if;
  if p_reason is null or p_reason not in ('spam', 'harassment', 'scam', 'fake_event', 'other') then
    raise exception 'bad_reason';
  end if;
  if p_target_type = 'user' and not exists (select 1 from identity.profiles p where p.user_id = p_target_id) then
    raise exception 'user_not_found';
  end if;
  if p_target_type = 'event' and not exists (select 1 from events.event_brief(p_target_id) b where b.status in ('published', 'ended')) then
    raise exception 'event_not_found';
  end if;
  if p_target_type = 'message' and not exists (
       select 1 from chat.messages m join chat.threads t on t.id = m.thread_id
        where m.id = p_target_id and uid in (t.attendee_id, t.host_id)) then
    raise exception 'not_participant';
  end if;
  insert into identity.reports (reporter_id, target_type, target_id, reason, note)
  values (uid, p_target_type, p_target_id, p_reason, nullif(btrim(p_note), ''));
end
$$;

create function identity.open_reports()
returns table (id uuid, reporter_id uuid, target_type text, target_id uuid, reason text, note text, created_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  perform identity.require_admin();
  return query select r.id, r.reporter_id, r.target_type, r.target_id, r.reason, r.note, r.created_at
                 from identity.reports r where r.status = 'open' order by r.created_at desc;
end
$$;

revoke all on function identity.is_blocked_between(uuid, uuid) from public, anon, authenticated;
revoke all on function identity.block_user(uuid) from public, anon;
revoke all on function identity.unblock_user(uuid) from public, anon;
revoke all on function identity.my_blocks() from public, anon;
revoke all on function identity.report(text, uuid, text, text) from public, anon;
revoke all on function identity.open_reports() from public, anon;
grant execute on function identity.block_user(uuid), identity.unblock_user(uuid), identity.my_blocks(),
  identity.report(text, uuid, text, text), identity.open_reports() to authenticated;
