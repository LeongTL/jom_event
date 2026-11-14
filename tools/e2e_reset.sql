-- Clears what an end-to-end run leaves behind: the test-OTP user (+60123456789) and every e2e-* user, with
-- their events, bookings and chat. Run before each journey so a rerun starts clean.
do $$
declare
  u uuid;
begin
  for u in select id from auth.users where phone = '60123456789' or email like 'e2e-%@example.com' loop
    update payments.payouts set status = 'paid' where host_id = u;
    update events.events set status = 'ended' where host_id = u and status in ('draft', 'published');
    perform identity.erase_user(u);
    delete from auth.users where id = u;
  end loop;
end
$$;

-- Test scaffolding, never a migration: paid bookings close an hour before the start, so a journey books early and
-- then pulls the event to the door with this (service role only).
create or replace function public.e2e_start_event_in(p_event_id uuid, p_seconds int)
returns void language sql security definer set search_path = '' as $$
  update events.events
     set starts_at = now() + make_interval(secs => p_seconds),
         ends_at = now() + make_interval(secs => p_seconds + 5)
   where id = p_event_id;
$$;
revoke all on function public.e2e_start_event_in(uuid, int) from public, anon, authenticated;
grant execute on function public.e2e_start_event_in(uuid, int) to service_role;
