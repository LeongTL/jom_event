-- In-app account deletion (PDPA). The delete-account edge function calls identity.erase_user (service role
-- only) and then removes the sign-in account. Each module erases its own data; identity coordinates, in one
-- transaction, so a refusal changes nothing.

-- The profile outlives the sign-in account as an anonymous "Deleted user": reviews, bookings and payment
-- records keep pointing at someone, and the chat list can still show who a message was from.
alter table identity.profiles drop constraint if exists profiles_user_id_fkey;

-- events: a host may not leave while a published event still has guests (it has not been completed, so
-- the guests have not been served and the host's payout is not scheduled yet).
create function events.host_has_active_events(p_host_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from events.events e
                  where e.host_id = p_host_id and e.status = 'published' and bookings.seats_taken(e.id) > 0)
$$;

-- events: what is left of a leaving host's events. Drafts go; published events with no guests are cancelled
-- (they stay as rows so old bookings still show a title); finished events are untouched.
create function events.erase_host(p_host_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  delete from events.events e where e.host_id = p_host_id and e.status = 'draft';
  update events.events e set status = 'cancelled'
   where e.host_id = p_host_id and e.status = 'published';
end
$$;

-- payments: a host who is still owed money cannot delete their bank details.
create function payments.host_has_unpaid_payouts(p_host_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from payments.payouts p where p.host_id = p_host_id and p.status = 'scheduled') $$;

-- bookings: money records stay (with the name and phone blanked); an unpaid hold is released so its seats
-- free up. A payment that is still in flight is left to finish.
create function bookings.erase_user(p_user_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  update bookings.bookings b set status = 'cancelled', cancelled_at = now()
   where b.attendee_id = p_user_id and b.status in ('held', 'payment_failed');
  update bookings.bookings b set contact_name = 'Deleted user', contact_phone = ''
   where b.attendee_id = p_user_id;
end
$$;

-- chat: their messages and read markers go, then any conversation left with no messages.
create function chat.erase_user(p_user_id uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  delete from chat.messages m where m.sender_id = p_user_id;
  delete from chat.thread_reads r where r.user_id = p_user_id;
  delete from chat.threads t
   where (t.attendee_id = p_user_id or t.host_id = p_user_id)
     and not exists (select 1 from chat.messages m where m.thread_id = t.id);
end
$$;

create function identity.erase_user(p_user_id uuid) returns void
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
  delete from identity.hosts h where h.user_id = p_user_id;   -- payout account goes with it
  update identity.profiles p set name = 'Deleted user', phone = null, is_host = false where p.user_id = p_user_id;
end
$$;

revoke all on function events.host_has_active_events(uuid) from public;
revoke all on function events.erase_host(uuid) from public;
revoke all on function payments.host_has_unpaid_payouts(uuid) from public;
revoke all on function bookings.erase_user(uuid) from public;
revoke all on function chat.erase_user(uuid) from public;
revoke all on function identity.erase_user(uuid) from public;
-- the edge function reaches identity as the service role, which needs the schema as well as the function
grant usage on schema identity to service_role;
grant execute on function identity.erase_user(uuid) to service_role;
