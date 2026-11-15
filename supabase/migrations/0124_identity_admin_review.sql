-- Platform admins approve, reject and suspend hosts. The admin role is given by hand in the database (insert a row into
-- identity.admins): no function inserts into it. Every decision is written to identity.admin_actions, which only the
-- database owner can write to, so the log of who did what and when cannot be edited from the app.
create table identity.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- no foreign keys: the record outlives the people in it
create table identity.admin_actions (
  id             uuid primary key default gen_random_uuid(),
  admin_id       uuid not null,
  action         text not null check (action in ('approve', 'reject', 'suspend', 'unsuspend')),
  target_user_id uuid not null,
  reason         text,
  created_at     timestamptz not null default now()
);

alter table identity.admins enable row level security;
alter table identity.admin_actions enable row level security;
revoke all on identity.admins, identity.admin_actions from public, anon, authenticated;

create function identity.is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from identity.admins a where a.user_id = auth.uid()) $$;

create function identity.require_admin() returns void
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if not identity.is_admin() then
    raise exception 'not_admin';
  end if;
end
$$;

-- decision: approve (pending or rejected) | reject (pending, with a reason) | suspend (approved) | unsuspend (suspended)
create function identity.admin_review_host(p_user_id uuid, p_decision text, p_reason text default null)
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  admin uuid := auth.uid();
  cur text;
  reason text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  perform identity.require_admin();
  if p_decision not in ('approve', 'reject', 'suspend', 'unsuspend') then
    raise exception 'bad_decision';
  end if;
  if p_decision in ('reject', 'suspend') and reason is null then
    raise exception 'reason_required';
  end if;
  select h.status into cur from identity.hosts h where h.user_id = p_user_id for update;
  if cur is null
     or (p_decision = 'approve' and cur not in ('pending', 'rejected'))
     or (p_decision = 'reject' and cur <> 'pending')
     or (p_decision = 'suspend' and cur <> 'approved')
     or (p_decision = 'unsuspend' and cur <> 'suspended') then
    raise exception 'bad_state';
  end if;

  update identity.hosts h
     set status = case p_decision when 'approve' then 'approved' when 'reject' then 'rejected'
                                  when 'suspend' then 'suspended' else 'approved' end,
         reviewed_by = admin, reviewed_at = now(),
         reject_reason = case when p_decision = 'reject' then reason else null end
   where h.user_id = p_user_id;
  update identity.profiles p set is_host = (p_decision in ('approve', 'unsuspend')) where p.user_id = p_user_id;

  insert into identity.admin_actions (admin_id, action, target_user_id, reason)
  values (admin, p_decision, p_user_id, reason);

  if p_decision = 'approve' then
    perform identity.notify(p_user_id, 'host_approved', null, null, 'You are approved as an Event owner',
                            'Switch to Host mode from your profile to create events.');
  elsif p_decision = 'reject' then
    perform identity.notify(p_user_id, 'host_rejected', null, null, 'Your host application was not approved', reason);
  elsif p_decision = 'suspend' then
    perform identity.notify(p_user_id, 'host_suspended', null, null, 'Your host access is paused',
                            'Contact support if you have questions.');
  end if;
end
$$;

create function identity.pending_hosts()
returns table (user_id uuid, host_name text, area text, created_at timestamptz)
language plpgsql stable security definer set search_path = ''
as $$
begin
  perform identity.require_admin();
  return query select h.user_id, h.host_name, h.area, h.created_at
                 from identity.hosts h where h.status = 'pending' order by h.created_at;
end
$$;

create function identity.host_application(p_user_id uuid)
returns table (host_name text, area text, bio text, ssm_number text, account_holder text, bank text,
               account_number text, qr_path text, status text, reject_reason text)
language plpgsql stable security definer set search_path = ''
as $$
begin
  perform identity.require_admin();
  return query select h.host_name, h.area, h.bio, h.ssm_number, a.account_holder, a.bank, a.account_number,
                      a.duitnow_qr_path, h.status, h.reject_reason
                 from identity.hosts h left join identity.host_payout_accounts a on a.user_id = h.user_id
                where h.user_id = p_user_id;
end
$$;

revoke all on function identity.require_admin() from public, anon, authenticated;
revoke all on function identity.is_admin() from public;
revoke all on function identity.admin_review_host(uuid, text, text) from public;
revoke all on function identity.pending_hosts() from public;
revoke all on function identity.host_application(uuid) from public;
grant execute on function identity.is_admin() to authenticated;
grant execute on function identity.admin_review_host(uuid, text, text) to authenticated;
grant execute on function identity.pending_hosts() to authenticated;
grant execute on function identity.host_application(uuid) to authenticated;
