-- Chat: one thread per guest and host, text only. Clients read what they take part in; every write goes
-- through the functions below. attendee_id, host_id and event_id have no foreign keys: other modules.

create table chat.threads (
  id              uuid primary key default gen_random_uuid(),
  attendee_id     uuid not null,
  host_id         uuid not null,
  event_id        uuid,  -- the event the guest asked about (the latest one)
  last_message_at timestamptz,
  created_at      timestamptz not null default now(),
  unique (attendee_id, host_id),
  check (attendee_id <> host_id)
);

create table chat.messages (
  id         uuid primary key default gen_random_uuid(),
  thread_id  uuid not null references chat.threads (id) on delete cascade,
  sender_id  uuid not null,
  body       text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default clock_timestamp()
);
create index messages_thread_idx on chat.messages (thread_id, created_at desc);

create table chat.thread_reads (
  thread_id uuid not null references chat.threads (id) on delete cascade,
  user_id   uuid not null,
  read_at   timestamptz not null,
  primary key (thread_id, user_id)
);

alter table chat.threads      enable row level security;
alter table chat.messages     enable row level security;
alter table chat.thread_reads enable row level security;

create policy participants on chat.threads for select to authenticated
  using ((select auth.uid()) in (attendee_id, host_id));
create policy participants on chat.messages for select to authenticated
  using (exists (select 1 from chat.threads t
                  where t.id = thread_id and (select auth.uid()) in (t.attendee_id, t.host_id)));
create policy own_reads on chat.thread_reads for select to authenticated
  using (user_id = (select auth.uid()));

grant usage on schema chat to authenticated;
grant select on chat.threads, chat.messages, chat.thread_reads to authenticated;

-- Internal: how someone appears to the other side of a chat (a host by their host name and avatar).
create function identity.chat_party(p_user_id uuid) returns table (name text, avatar_url text)
language sql stable security definer set search_path = ''
as $$
  select coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest'), h.avatar_url
    from identity.profiles p
    left join identity.hosts h on h.user_id = p.user_id
   where p.user_id = p_user_id
$$;

-- A guest opens (or reopens) their thread with a host, no booking needed. Asking about another event of the
-- same host moves the thread's event.
create function chat.open_thread(p_host_id uuid, p_event_id uuid default null) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  event_host uuid;
  tid uuid;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_host_id = uid then
    raise exception 'cannot_message_self';
  end if;
  if not identity.is_host(p_host_id) then
    raise exception 'not_a_host';
  end if;
  if p_event_id is not null then
    select b.host_id into event_host from events.event_brief(p_event_id) b;
    if not found then
      raise exception 'event_not_found';
    end if;
    if event_host <> p_host_id then
      raise exception 'event_host_mismatch';
    end if;
  end if;
  insert into chat.threads (attendee_id, host_id, event_id)
  values (uid, p_host_id, p_event_id)
  on conflict (attendee_id, host_id) do update set event_id = coalesce(excluded.event_id, chat.threads.event_id)
  returning id into tid;
  return tid;
end
$$;

-- Either side sends text (1 to 1000 characters, no phone numbers or handles). The other side gets a notice
-- unless they turned chat notices off (identity.notify checks that).
create function chat.send_message(p_thread_id uuid, p_body text) returns chat.messages
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  t chat.threads;
  text_body text := btrim(p_body);
  ts timestamptz := clock_timestamp();
  m chat.messages;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select x.* into t from chat.threads x where x.id = p_thread_id;
  if not found or uid not in (t.attendee_id, t.host_id) then
    raise exception 'not_participant';
  end if;
  if text_body is null or text_body = '' then
    raise exception 'message_empty';
  end if;
  if char_length(text_body) > 1000 then
    raise exception 'message_too_long';
  end if;
  if shared.contains_contact_info(text_body) then
    raise exception 'contact_info_not_allowed';
  end if;

  insert into chat.messages (thread_id, sender_id, body, created_at) values (t.id, uid, text_body, ts) returning * into m;
  update chat.threads x set last_message_at = ts where x.id = t.id;
  insert into chat.thread_reads (thread_id, user_id, read_at) values (t.id, uid, ts)
  on conflict (thread_id, user_id) do update set read_at = excluded.read_at;
  perform identity.notify(case when uid = t.attendee_id then t.host_id else t.attendee_id end,
                          'chat_message', 'thread', t.id, (select p.name from identity.chat_party(uid) p), left(text_body, 80));
  return m;
end
$$;

create function chat.mark_thread_read(p_thread_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if not exists (select 1 from chat.threads t where t.id = p_thread_id and uid in (t.attendee_id, t.host_id)) then
    raise exception 'not_participant';
  end if;
  insert into chat.thread_reads (thread_id, user_id, read_at) values (p_thread_id, uid, clock_timestamp())
  on conflict (thread_id, user_id) do update set read_at = excluded.read_at;
end
$$;

-- The inbox: my threads that have at least one message, newest first. unread = the other side wrote after I
-- last read (my own messages are never unread).
create function chat.my_threads()
returns table (thread_id uuid, other_name text, other_avatar text, last_body text, last_at timestamptz,
               unread boolean, event_title text)
language sql stable security definer set search_path = ''
as $$
  select t.id, p.name, p.avatar_url, lm.body, t.last_message_at,
         exists (select 1 from chat.messages m
                  where m.thread_id = t.id and m.sender_id <> auth.uid()
                    and m.created_at > coalesce((select r.read_at from chat.thread_reads r
                                                  where r.thread_id = t.id and r.user_id = auth.uid()), '-infinity')),
         (select e.title from events.event_brief(t.event_id) e)
    from chat.threads t
   cross join lateral identity.chat_party(case when t.attendee_id = auth.uid() then t.host_id else t.attendee_id end) p
   cross join lateral (select m.body from chat.messages m where m.thread_id = t.id order by m.created_at desc limit 1) lm
   where auth.uid() in (t.attendee_id, t.host_id)
   order by t.last_message_at desc
$$;

-- The badge on the Chat tab: how many threads have something unread.
create function chat.unread_total() returns int
language sql stable security definer set search_path = ''
as $$ select count(*)::int from chat.my_threads() x where x.unread $$;

revoke all on function identity.chat_party(uuid) from public, anon, authenticated;
revoke all on function chat.open_thread(uuid, uuid) from public, anon, authenticated;
revoke all on function chat.send_message(uuid, text) from public, anon, authenticated;
revoke all on function chat.mark_thread_read(uuid) from public, anon, authenticated;
revoke all on function chat.my_threads() from public, anon, authenticated;
revoke all on function chat.unread_total() from public, anon, authenticated;

grant execute on function chat.open_thread(uuid, uuid) to authenticated;
grant execute on function chat.send_message(uuid, text) to authenticated;
grant execute on function chat.mark_thread_read(uuid) to authenticated;
grant execute on function chat.my_threads() to authenticated;
grant execute on function chat.unread_total() to authenticated;

-- Realtime: new messages and notifications reach the app live (row-level security still decides who sees what).
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'chat' and tablename = 'messages') then
      alter publication supabase_realtime add table chat.messages;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'identity' and tablename = 'notifications') then
      alter publication supabase_realtime add table identity.notifications;
    end if;
  end if;
end $$;
