-- Host registration: a host row has a status, and only an approved host has profiles.is_host (so identity.is_host,
-- and every events function that asks it, keep meaning "approved host").
alter table identity.hosts
  add column status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'suspended')),
  add column reviewed_by uuid,
  add column reviewed_at timestamptz,
  add column reject_reason text;

-- hosts that exist today keep working
update identity.hosts h set status = 'approved'
 where exists (select 1 from identity.profiles p where p.user_id = h.user_id and p.is_host);

-- Applying creates or updates the host row as pending and does not make anyone a host. An approved or suspended host
-- who saves their details again keeps their status; a rejected one goes back to pending.
create or replace function identity.apply_host(
  host_name text, area text, bio text,
  account_holder text, bank text, account_number text,
  ssm_number text default null
) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if coalesce(btrim(apply_host.host_name), '') = '' or coalesce(btrim(apply_host.area), '') = ''
     or coalesce(btrim(apply_host.account_holder), '') = '' or coalesce(btrim(apply_host.bank), '') = ''
     or coalesce(btrim(apply_host.account_number), '') = '' then
    raise exception 'details_required';
  end if;

  insert into identity.hosts (user_id, host_name, area, bio, ssm_number)
  values (uid, apply_host.host_name, apply_host.area, apply_host.bio, apply_host.ssm_number)
  on conflict (user_id) do update
    set host_name = excluded.host_name, area = excluded.area,
        bio = excluded.bio, ssm_number = excluded.ssm_number,
        status = case when identity.hosts.status = 'rejected' then 'pending' else identity.hosts.status end,
        reject_reason = case when identity.hosts.status = 'rejected' then null else identity.hosts.reject_reason end;

  insert into identity.host_payout_accounts (user_id, account_holder, bank, account_number)
  values (uid, apply_host.account_holder, apply_host.bank, apply_host.account_number)
  on conflict (user_id) do update
    set account_holder = excluded.account_holder, bank = excluded.bank,
        account_number = excluded.account_number;
end
$$;

-- none | pending | approved | rejected | suspended, with the reason a rejection gave. Signed out is none.
create function identity.my_host_status() returns table (status text, reason text)
language sql stable security definer set search_path = ''
as $$
  select coalesce((select h.status from identity.hosts h where h.user_id = auth.uid()), 'none'),
         (select h.reject_reason from identity.hosts h where h.user_id = auth.uid() and h.status = 'rejected')
$$;

revoke all on function identity.my_host_status() from public;
grant execute on function identity.my_host_status() to anon, authenticated;
