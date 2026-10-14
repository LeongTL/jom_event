-- Identity module functions. security definer + pinned search_path: they are the only write path.

-- Every new auth user gets a profile and notification prefs.
create function identity.on_signup() returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into identity.profiles (user_id, name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    new.phone
  );
  insert into identity.notification_prefs (user_id) values (new.id);
  return new;
end
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function identity.on_signup();

create function identity.update_profile(name text, phone text) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  update identity.profiles p
     set name = update_profile.name, phone = update_profile.phone
   where p.user_id = auth.uid();
end
$$;

-- Applying again updates the details but never touches verified_at.
create function identity.apply_host(
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

  update identity.profiles p set is_host = true where p.user_id = uid;

  insert into identity.hosts (user_id, host_name, area, bio, ssm_number)
  values (uid, apply_host.host_name, apply_host.area, apply_host.bio, apply_host.ssm_number)
  on conflict (user_id) do update
    set host_name = excluded.host_name, area = excluded.area,
        bio = excluded.bio, ssm_number = excluded.ssm_number;

  insert into identity.host_payout_accounts (user_id, account_holder, bank, account_number)
  values (uid, apply_host.account_holder, apply_host.bank, apply_host.account_number)
  on conflict (user_id) do update
    set account_holder = excluded.account_holder, bank = excluded.bank,
        account_number = excluded.account_number;
end
$$;

-- Returns the new state: true = saved, false = unsaved. Only saving checks that the event is published,
-- so a saved event that has since ended can still be removed.
create function identity.toggle_save(event_id uuid) returns boolean
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;

  delete from identity.saved_events s
   where s.user_id = uid and s.event_id = toggle_save.event_id;
  if found then
    return false;
  end if;

  if not events.exists_published(toggle_save.event_id) then
    raise exception 'event_not_found';
  end if;
  insert into identity.saved_events (user_id, event_id)
  values (uid, toggle_save.event_id)
  on conflict do nothing;
  return true;
end
$$;

-- Internal: called by other modules' functions, never by clients. Chat and review-request notices respect
-- the user's switches; booking, payment, event_cancelled and payout notices are always written.
create function identity.notify(
  user_id uuid, type text, ref_type text, ref_id uuid, title text, body text
) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if notify.type = 'chat_message' and not coalesce(
       (select p.chat from identity.notification_prefs p where p.user_id = notify.user_id), true) then
    return;
  end if;
  if notify.type = 'review_request' and not coalesce(
       (select p.review_requests from identity.notification_prefs p where p.user_id = notify.user_id), true) then
    return;
  end if;
  insert into identity.notifications (user_id, type, ref_type, ref_id, title, body)
  values (notify.user_id, notify.type, notify.ref_type, notify.ref_id, notify.title, notify.body);
end
$$;

create function identity.mark_read(ids uuid[]) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update identity.notifications n set read_at = now()
   where n.user_id = auth.uid() and n.id = any (mark_read.ids) and n.read_at is null;
end
$$;

-- security invoker: row-level security already limits this to the caller's rows.
create function identity.unread_count() returns int
language sql stable set search_path = ''
as $$
  select count(*)::int from identity.notifications n
   where n.user_id = (select auth.uid()) and n.read_at is null
$$;

revoke all on function identity.on_signup() from public;
revoke all on function identity.update_profile(text, text) from public;
revoke all on function identity.apply_host(text, text, text, text, text, text, text) from public;
revoke all on function identity.toggle_save(uuid) from public;
revoke all on function identity.notify(uuid, text, text, uuid, text, text) from public, anon, authenticated;
revoke all on function identity.mark_read(uuid[]) from public;
revoke all on function identity.unread_count() from public;

grant execute on function identity.update_profile(text, text) to authenticated;
grant execute on function identity.apply_host(text, text, text, text, text, text, text) to authenticated;
grant execute on function identity.toggle_save(uuid) to authenticated;
grant execute on function identity.mark_read(uuid[]) to authenticated;
grant execute on function identity.unread_count() to authenticated;
