-- The two notification switches (new chat messages, review requests). Clients cannot write the prefs table, so
-- the Notifications screen saves both through this function. It writes only the caller's own row, and creates
-- it if sign-up never did.
create function identity.set_notification_prefs(p_chat boolean, p_review_requests boolean) returns void
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if p_chat is null or p_review_requests is null then
    raise exception 'prefs_required';
  end if;
  insert into identity.notification_prefs (user_id, chat, review_requests)
  values (uid, p_chat, p_review_requests)
  on conflict (user_id) do update set chat = excluded.chat, review_requests = excluded.review_requests;
end
$$;

revoke all on function identity.set_notification_prefs(boolean, boolean) from public;
grant execute on function identity.set_notification_prefs(boolean, boolean) to authenticated;
