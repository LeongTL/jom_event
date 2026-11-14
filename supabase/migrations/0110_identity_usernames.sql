-- Usernames: a unique @name under every profile. Clients never write it directly; set_username is the write path.
-- Nullable on purpose: an erased account ("Deleted user") has none, so its name is free again.

alter table identity.profiles add column username text;
create unique index profiles_username_key on identity.profiles (lower(username));
alter table identity.profiles add constraint profiles_username_format
  check (username ~ '^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$' and username !~ '\.\.');

-- Internal: a free name for sign-up and the backfill (their name, cleaned, plus 4 digits). Not granted to clients.
create function identity.auto_username(p_name text) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  base text := left(coalesce(nullif(regexp_replace(lower(coalesce(p_name, '')), '[^a-z0-9_]', '', 'g'), ''), 'user'), 16);
  cand text;
begin
  loop
    cand := base || lpad(floor(random() * 10000)::int::text, 4, '0');
    exit when not exists (select 1 from identity.profiles p where lower(p.username) = cand);
  end loop;
  return cand;
end
$$;

update identity.profiles set username = identity.auto_username(name)
 where username is null and name is distinct from 'Deleted user';

create or replace function identity.on_signup() returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  full_name text := coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name');
begin
  insert into identity.profiles (user_id, name, phone, username)
  values (new.id, full_name, new.phone, identity.auto_username(full_name));
  insert into identity.notification_prefs (user_id) values (new.id);
  return new;
end
$$;

-- Internal: the one place that judges a username. Returns the cleaned name, or the error code as text prefixed "!".
create function identity.check_username(p_username text) returns text
language plpgsql stable set search_path = ''
as $$
declare
  u text := lower(btrim(coalesce(p_username, '')));
begin
  if u !~ '^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$' or u ~ '\.\.' then return '!username_invalid'; end if;
  if u = any (array['admin','jom','support','help','official','host','staff','moderator','system']) then
    return '!username_reserved';
  end if;
  if shared.contains_contact_info(u) then return '!username_invalid'; end if;
  return u;
end
$$;

create function identity.set_username(p_username text) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  u text;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  u := identity.check_username(p_username);
  if left(u, 1) = '!' then
    raise exception '%', substr(u, 2);
  end if;
  if exists (select 1 from identity.profiles p where lower(p.username) = u and p.user_id <> uid) then
    raise exception 'username_taken';
  end if;
  begin
    update identity.profiles p set username = u where p.user_id = uid;
  exception when unique_violation then
    raise exception 'username_taken'; -- someone took it between the check and the save
  end;
  return u;
end
$$;

create function identity.username_available(p_username text) returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  u text := identity.check_username(p_username);
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  return left(u, 1) <> '!'
     and not exists (select 1 from identity.profiles p where lower(p.username) = u and p.user_id <> auth.uid());
end
$$;

-- Matches the start of a username, or the start of the name or of a word in it. No phone, email or other columns.
create function identity.search_people(p_query text, p_limit int default 20)
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
             where p.username is not null and p.user_id <> auth.uid()) s
     where s.uname like q || '%' escape '\'
        or lower(s.display) like q || '%' escape '\'
        or lower(s.display) like '% ' || q || '%' escape '\'
     order by s.uname
     limit greatest(1, least(coalesce(p_limit, 20), 50));
end
$$;

revoke all on function identity.auto_username(text) from public;
revoke all on function identity.check_username(text) from public;
revoke all on function identity.set_username(text) from public;
revoke all on function identity.username_available(text) from public;
revoke all on function identity.search_people(text, int) from public;
grant execute on function identity.set_username(text) to authenticated;
grant execute on function identity.username_available(text) to authenticated;
grant execute on function identity.search_people(text, int) to authenticated;
