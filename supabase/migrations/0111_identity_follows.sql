-- Following: one person follows another (guest or host). Clients read their own follow rows; every write
-- goes through follow / unfollow. A follow notifies the person followed, in the app only.

create table identity.follows (
  follower_id uuid not null references identity.profiles (user_id) on delete cascade,
  followee_id uuid not null references identity.profiles (user_id) on delete cascade,
  created_at  timestamptz not null default clock_timestamp(), -- not now(): two follows in one transaction still order
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create index follows_followee_idx on identity.follows (followee_id, created_at desc);

alter table identity.follows enable row level security;
create policy own_row on identity.follows for select to authenticated using (follower_id = (select auth.uid()));
grant select on identity.follows to authenticated;

create function identity.follow(p_user_id uuid) returns void
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
  insert into identity.follows (follower_id, followee_id) values (uid, p_user_id) on conflict do nothing;
  get diagnostics added = row_count;
  if added = 1 then -- only a new follow notifies, so a double tap says nothing twice
    select coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest') into who
      from identity.profiles p left join identity.hosts h on h.user_id = p.user_id where p.user_id = uid;
    perform identity.notify(p_user_id, 'follow', 'user', uid, who || ' started following you', null);
  end if;
end
$$;

create function identity.unfollow(p_user_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  delete from identity.follows f where f.follower_id = auth.uid() and f.followee_id = p_user_id;
end
$$;

-- Numbers only, so signed-out visitors may read them on a host page.
create function identity.follow_counts(p_user_id uuid)
returns table (followers int, following int, i_follow boolean)
language sql stable security definer set search_path = ''
as $$
  select (select count(*)::int from identity.follows f where f.followee_id = p_user_id),
         (select count(*)::int from identity.follows f where f.follower_id = p_user_id),
         exists (select 1 from identity.follows f where f.follower_id = auth.uid() and f.followee_id = p_user_id)
$$;

create function identity.list_followers(p_user_id uuid, p_limit int default 20, p_offset int default 0)
returns table (user_id uuid, name text, username text, avatar_url text, is_host boolean)
language sql stable security definer set search_path = ''
as $$
  select p.user_id, coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest'), p.username, h.avatar_url, (h.user_id is not null)
    from identity.follows f
    join identity.profiles p on p.user_id = f.follower_id
    left join identity.hosts h on h.user_id = p.user_id
   where f.followee_id = p_user_id and p.username is not null
   order by f.created_at desc, p.user_id
   limit greatest(1, least(coalesce(p_limit, 20), 50)) offset greatest(coalesce(p_offset, 0), 0)
$$;

create function identity.list_following(p_user_id uuid, p_limit int default 20, p_offset int default 0)
returns table (user_id uuid, name text, username text, avatar_url text, is_host boolean)
language sql stable security definer set search_path = ''
as $$
  select p.user_id, coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest'), p.username, h.avatar_url, (h.user_id is not null)
    from identity.follows f
    join identity.profiles p on p.user_id = f.followee_id
    left join identity.hosts h on h.user_id = p.user_id
   where f.follower_id = p_user_id and p.username is not null
   order by f.created_at desc, p.user_id
   limit greatest(1, least(coalesce(p_limit, 20), 50)) offset greatest(coalesce(p_offset, 0), 0)
$$;

-- One person for a profile page. Signed-out visitors get hosts only (the public host page); guests need sign-in.
create function identity.person(p_user_id uuid)
returns table (user_id uuid, name text, username text, avatar_url text, is_host boolean)
language sql stable security definer set search_path = ''
as $$
  select p.user_id, coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest'), p.username, h.avatar_url, (h.user_id is not null)
    from identity.profiles p
    left join identity.hosts h on h.user_id = p.user_id
   where p.user_id = p_user_id and p.username is not null
     and (h.user_id is not null or auth.uid() is not null)
$$;

-- Same body as 0092, plus: an erased account leaves no follows and gives its username back.
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
  delete from identity.hosts h where h.user_id = p_user_id;   -- payout account goes with it
  update identity.profiles p set name = 'Deleted user', phone = null, is_host = false, username = null where p.user_id = p_user_id;
end
$$;

revoke all on function identity.follow(uuid) from public;
revoke all on function identity.unfollow(uuid) from public;
revoke all on function identity.follow_counts(uuid) from public;
revoke all on function identity.list_followers(uuid, int, int) from public;
revoke all on function identity.list_following(uuid, int, int) from public;
revoke all on function identity.person(uuid) from public;
grant execute on function identity.follow(uuid), identity.unfollow(uuid),
  identity.list_followers(uuid, int, int), identity.list_following(uuid, int, int) to authenticated;
grant execute on function identity.follow_counts(uuid), identity.person(uuid) to anon, authenticated;
