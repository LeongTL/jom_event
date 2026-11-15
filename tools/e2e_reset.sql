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

-- Test scaffolding, never a migration: the app can never make an admin or flip a flag, so a journey does it here
-- (service role only). e2e_reset above removes the admin with the e2e-* user it belongs to.
create or replace function public.e2e_make_admin(p_user_id uuid)
returns void language sql security definer set search_path = '' as $$
  insert into identity.admins (user_id) values (p_user_id) on conflict do nothing;
$$;
revoke all on function public.e2e_make_admin(uuid) from public, anon, authenticated;
grant execute on function public.e2e_make_admin(uuid) to service_role;

-- Admin functions need a two-factor session (aal2), which a script cannot sign in with. A journey runs the real function
-- as the given admin with an aal2 token here instead (service role only, local database only), so its checks, log row
-- and notifications are the real ones.
create or replace function public.e2e_review_host(p_admin uuid, p_user_id uuid, p_decision text, p_reason text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_admin, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  perform identity.admin_review_host(p_user_id, p_decision, p_reason);
end
$$;
revoke all on function public.e2e_review_host(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.e2e_review_host(uuid, uuid, text, text) to service_role;

create or replace function public.e2e_set_flag(p_key text, p_value jsonb)
returns void language sql security definer set search_path = '' as $$
  update app.flags set value = p_value where key = p_key;
$$;
revoke all on function public.e2e_set_flag(text, jsonb) from public, anon, authenticated;
grant execute on function public.e2e_set_flag(text, jsonb) to service_role;

-- a journey that switched the entrance off must not leave it off
select public.e2e_set_flag('host_entry_enabled', 'true');
