-- Internal helper for other modules (events checks the caller is a host without reading identity tables).
create function identity.is_host(p_user_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from identity.profiles p where p.user_id = is_host.p_user_id and p.is_host)
$$;

revoke all on function identity.is_host(uuid) from public;
