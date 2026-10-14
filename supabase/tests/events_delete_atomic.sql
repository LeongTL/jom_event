begin;
select plan(7);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Pottery', 'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V');
insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen) values
  ('b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'confirmed', 'KLS-00001', 'Bob', '601', 3000),
  ('b2000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 1, 'confirmed', 'KLS-00002', 'Carol', '601', 3000);
insert into payments.payment_attempts (booking_id, reference, status, method, session_expires_at) values
  ('b1000000-0000-0000-0000-000000000001', 'R1', 'success', 'fpx', now()),
  ('b2000000-0000-0000-0000-000000000002', 'R2', 'success', 'fpx', now());
insert into payments.fee_snapshots (booking_id, gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen) values
  ('b1000000-0000-0000-0000-000000000001', 3000, 45, 300, 2655), ('b2000000-0000-0000-0000-000000000002', 3000, 45, 300, 2655);

-- the second guest's refund blows up halfway through the delete
create or replace function payments.run_refund(p_refund_id uuid) returns void language plpgsql as $$
begin
  if (select b.contact_name from payments.refunds r join bookings.bookings b on b.id = r.booking_id where r.id = p_refund_id) = 'Carol' then
    raise exception 'gateway_down';
  end if;
  update payments.refunds r set status = 'done', attempts = r.attempts + 1 where r.id = p_refund_id;
end $$;

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.delete_event('e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'gateway_down',
  'delete_is_one_transaction: the error reaches the host');
reset role;
select is((select status from events.events where id = 'e1000000-0000-0000-0000-000000000001'), 'published', 'the event stays published');
select is((select count(*)::int from bookings.bookings where status = 'confirmed'), 2, 'both bookings are still confirmed');
select is((select count(*)::int from payments.refunds), 0, 'no refund row survives, not even the first guest''s');
select is((select sum(host_receives_sen)::int from payments.fee_snapshots), 5310, 'the host''s earnings are untouched');
select is((select count(*)::int from identity.notifications where type = 'event_cancelled'), 0, 'nobody was told');
select is(bookings.seats_taken('e1000000-0000-0000-0000-000000000001'), 2, 'both seats are still taken');

select * from finish();
rollback;
