-- Push: one row per phone a person signed in on. A token belongs to the latest user of the device.
create table identity.device_tokens (
  user_id    uuid not null references identity.profiles (user_id) on delete cascade,
  token      text primary key,
  platform   text not null check (platform in ('ios', 'android')),
  updated_at timestamptz not null default now()
);
create index device_tokens_user_idx on identity.device_tokens (user_id);
alter table identity.device_tokens enable row level security;  -- no policy: only the functions below touch it

create function identity.register_device_token(p_token text, p_platform text) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_platform is null or p_platform not in ('ios', 'android') then
    raise exception 'bad_platform';
  end if;
  if coalesce(btrim(p_token), '') = '' then
    raise exception 'token_required';
  end if;
  insert into identity.device_tokens (user_id, token, platform) values (uid, btrim(p_token), p_platform)
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end
$$;

create function identity.device_tokens_of(p_user_id uuid) returns text[]
language sql stable security definer set search_path = ''
as $$ select coalesce(array_agg(t.token), '{}') from identity.device_tokens t where t.user_id = p_user_id $$;

create function identity.remove_device_token(p_token text) returns void
language sql security definer set search_path = ''
as $$ delete from identity.device_tokens where token = p_token $$;

-- Queues one push through the send-push function. Never raises: a missing secret or token must not break the caller.
create function shared.send_push(p_user_id uuid, p_title text, p_body text, p_ref_type text, p_ref_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  base_url text;
  service_key text;
begin
  select s.decrypted_secret into base_url from vault.decrypted_secrets s where s.name = 'functions_url';
  select s.decrypted_secret into service_key from vault.decrypted_secrets s where s.name = 'service_role_key';
  if base_url is null or service_key is null
     or not exists (select 1 from identity.device_tokens t where t.user_id = p_user_id) then
    return;
  end if;
  perform net.http_post(
    url := base_url || '/send-push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || service_key),
    body := jsonb_build_object('userId', p_user_id, 'title', p_title, 'body', p_body,
                               'data', jsonb_build_object('refType', p_ref_type, 'refId', p_ref_id)));
exception when others then
  raise warning 'push not queued for user %: %', p_user_id, sqlerrm;
end
$$;

revoke all on function identity.register_device_token(text, text) from public;
revoke all on function identity.device_tokens_of(uuid) from public, anon, authenticated;
revoke all on function identity.remove_device_token(text) from public, anon, authenticated;
revoke all on function shared.send_push(uuid, text, text, text, uuid) from public, anon, authenticated;
grant execute on function identity.register_device_token(text, text) to authenticated;
grant execute on function identity.device_tokens_of(uuid) to service_role;
grant execute on function identity.remove_device_token(text) to service_role;
