-- What a block does: the two cannot find or follow each other and cannot message; a thread between them leaves
-- both inboxes (it comes back on unblock). Same bodies as before plus the block checks.

create or replace function identity.search_people(p_query text, p_limit int default 20)
returns table (user_id uuid, name text, username text, avatar_url text, is_host boolean)
language plpgsql stable security definer set search_path = ''
as $$
declare
  q text := lower(btrim(coalesce(p_query, '')));
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if length(q) < 2 then
    return;
  end if;
  q := replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_');
  return query
    select s.uid, s.display, s.uname, s.avatar, s.host
      from (select p.user_id as uid,
                   coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest') as display,
                   p.username as uname, h.avatar_url as avatar, (h.user_id is not null) as host
              from identity.profiles p
              left join identity.hosts h on h.user_id = p.user_id
             where p.username is not null and p.user_id <> auth.uid()
               and not identity.is_blocked_between(auth.uid(), p.user_id)) s
     where s.uname like q || '%' escape '\'
        or lower(s.display) like q || '%' escape '\'
        or lower(s.display) like '% ' || q || '%' escape '\'
     order by s.uname
     limit greatest(1, least(coalesce(p_limit, 20), 50));
end
$$;

create or replace function identity.follow(p_user_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  added int;
  who text;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_user_id = uid then
    raise exception 'cannot_follow_self';
  end if;
  if not exists (select 1 from identity.profiles p where p.user_id = p_user_id and p.username is not null) then
    raise exception 'user_not_found';
  end if;
  if identity.is_blocked_between(uid, p_user_id) then
    raise exception 'blocked';
  end if;
  insert into identity.follows (follower_id, followee_id) values (uid, p_user_id) on conflict do nothing;
  get diagnostics added = row_count;
  if added = 1 then
    select coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest') into who
      from identity.profiles p left join identity.hosts h on h.user_id = p.user_id where p.user_id = uid;
    perform identity.notify(p_user_id, 'follow', 'user', uid, who || ' started following you', null);
  end if;
end
$$;

create or replace function chat.open_thread(p_host_id uuid, p_event_id uuid default null) returns uuid
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
  if identity.is_blocked_between(uid, p_host_id) then
    raise exception 'blocked';
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

create or replace function chat.send_message(p_thread_id uuid, p_body text) returns chat.messages
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
  if identity.is_blocked_between(t.attendee_id, t.host_id) then
    raise exception 'blocked';
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

create or replace function chat.my_threads()
returns table (thread_id uuid, other_name text, other_avatar text, last_body text, last_at timestamptz,
               unread boolean, event_title text, event_id uuid, event_categories text[])
language sql stable security definer set search_path = ''
as $$
  select t.id, p.name, p.avatar_url, lm.body, t.last_message_at,
         exists (select 1 from chat.messages m
                  where m.thread_id = t.id and m.sender_id <> auth.uid()
                    and m.created_at > coalesce((select r.read_at from chat.thread_reads r
                                                  where r.thread_id = t.id and r.user_id = auth.uid()), '-infinity')),
         (select e.title from events.event_brief(t.event_id) e),
         t.event_id,
         (select c.categories from events.cards(array[t.event_id]) c)
    from chat.threads t
   cross join lateral identity.chat_party(case when t.attendee_id = auth.uid() then t.host_id else t.attendee_id end) p
   cross join lateral (select m.body from chat.messages m where m.thread_id = t.id order by m.created_at desc limit 1) lm
   where auth.uid() in (t.attendee_id, t.host_id)
     and not identity.is_blocked_between(t.attendee_id, t.host_id)
   order by t.last_message_at desc
$$;

-- Same body as 0111, plus: an erased account leaves no blocks and no reports of its own.
create or replace function identity.erase_user(p_user_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if exists (select 1 from identity.hosts h where h.user_id = p_user_id) then
    if events.host_has_active_events(p_user_id) then
      raise exception 'host_has_active_events';
    end if;
    if payments.host_has_unpaid_payouts(p_user_id) then
      raise exception 'host_has_pending_payouts';
    end if;
    perform events.erase_host(p_user_id);
  end if;

  perform bookings.erase_user(p_user_id);
  perform chat.erase_user(p_user_id);

  delete from identity.saved_events s where s.user_id = p_user_id;
  delete from identity.notifications n where n.user_id = p_user_id;
  delete from identity.notification_prefs p where p.user_id = p_user_id;
  delete from identity.follows f where f.follower_id = p_user_id or f.followee_id = p_user_id;
  delete from identity.blocks b where b.blocker_id = p_user_id or b.blocked_id = p_user_id;
  delete from identity.reports r where r.reporter_id = p_user_id;
  delete from identity.hosts h where h.user_id = p_user_id;   -- payout account goes with it
  update identity.profiles p set name = 'Deleted user', phone = null, is_host = false, username = null where p.user_id = p_user_id;
end
$$;
