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
