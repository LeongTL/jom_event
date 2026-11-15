begin;
select plan(14);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
insert into auth.users (id, phone) values ('dddddddd-0000-0000-0000-000000000004', '60123456789');   -- phone sign-in, no email
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue, cancel_policy) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Free yoga',    'published', 0,    20, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'The Deck', '24h'),
  ('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Pottery night', 'published', 3000, 20, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'Clay & Co', '48h');

-- a guest books a paid seat and the gateway reports success (run as the superuser; the caller comes from the claims)
create function pg_temp.pay(ev uuid, ppl int, nm text) returns text language plpgsql as $$
declare b bookings.bookings; att uuid;
begin
  b := bookings.create_booking(ev, ppl, nm, '601');
  select attempt_id into att from payments.start_payment(b.id);
  perform payments.apply_gateway_result(att, 'success', 'fpx');
  return b.id::text;
end $$;

create function pg_temp.queued() returns int language sql as $$
  select count(*)::int from net.http_request_queue where url like '%/receipt-email' $$;
create function pg_temp.last_body() returns jsonb language sql as $$
  select convert_from(body, 'UTF8')::jsonb from net.http_request_queue where url like '%/receipt-email' order by id desc limit 1 $$;

-- ===== receipts are off until the function URL and key are stored in Vault =====
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select set_config('t.cfg', pg_temp.pay('e2000000-0000-0000-0000-000000000002', 1, 'Bob'), true);
select is((select status from bookings.bookings where id = current_setting('t.cfg')::uuid), 'confirmed', 'a paid join works with receipts not configured');
select is(pg_temp.queued(), 0, 'send_receipt_does_nothing_until_it_is_configured');

select vault.create_secret('http://functions.test/functions/v1', 'functions_url');
select vault.create_secret('service-key', 'service_role_key');

-- ===== a paid join queues one receipt =====
select set_config('t.free', pg_temp.pay('e2000000-0000-0000-0000-000000000002', 2, 'Bob Tan'), true);
select is(pg_temp.queued(), 1, 'paid_join_queues_one_receipt');
select results_eq(
  $$select url, headers ->> 'Authorization' from net.http_request_queue where url like '%/receipt-email'$$,
  $$values ('http://functions.test/functions/v1/receipt-email', 'Bearer service-key')$$,
  'the receipt goes to the receipt-email function with the service key');
select results_eq(
  $$select b ->> 'bookingId', b ->> 'email', b ->> 'name', b ->> 'eventTitle', b ->> 'venue', (b ->> 'people')::int, (b ->> 'amountSen')::int
      from (select pg_temp.last_body() as b) q$$,
  $$values (current_setting('t.free'), 'bob@example.com', 'Bob Tan', 'Pottery night', 'Clay & Co', 2, 6000)$$,
  'the receipt carries what the email needs');
select is((select pg_temp.last_body() ->> 'ticketCode' ~ '^KLS-[0-9]{5}$'), true, 'and the ticket code');

-- a guest who signed in with a phone has no email: the receipt is still queued, with a null address
select set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-000000000004","role":"authenticated"}', true);
select pg_temp.pay('e2000000-0000-0000-0000-000000000002', 1, 'Dave');
select is((select pg_temp.last_body() -> 'email'), 'null'::jsonb, 'a phone-only guest gets a receipt with no email address');

-- ===== a paid booking: no receipt while held or failed, one when the payment succeeds =====
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select set_config('t.paid', (bookings.create_booking('e2000000-0000-0000-0000-000000000002', 2, 'Bob Tan', '601')).id::text, true);
select set_config('t.att', (select attempt_id::text from payments.start_payment(current_setting('t.paid')::uuid)), true);
reset role;
select is(pg_temp.queued(), 2, 'a held booking sends no receipt');
select payments.apply_gateway_result(current_setting('t.att')::uuid, 'failed', 'card');
select is(pg_temp.queued(), 2, 'a failed payment sends no receipt');
select payments.apply_gateway_result(current_setting('t.att')::uuid, 'success', 'fpx');
select is(pg_temp.queued(), 3, 'paid_success_queues_a_receipt');
select results_eq(
  $$select b ->> 'eventTitle', (b ->> 'amountSen')::int, b ->> 'bookingId' from (select pg_temp.last_body() as b) q$$,
  $$values ('Pottery night', 6000, current_setting('t.paid'))$$, 'the paid receipt shows the amount');
select payments.apply_gateway_result(current_setting('t.att')::uuid, 'success', 'fpx');
select is(pg_temp.queued(), 3, 'a repeated success does not send a second receipt');

-- ===== a receipt problem must never undo a booking =====
create or replace function identity.email_of(p_user_id uuid) returns text language plpgsql as $$ begin raise exception 'boom'; end $$;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select set_config('t.fail', pg_temp.pay('e2000000-0000-0000-0000-000000000002', 1, 'Bob'), true);
select is((select status from bookings.bookings where id = current_setting('t.fail')::uuid), 'confirmed', 'receipt_failure_never_breaks_the_booking');
set local role authenticated;
select throws_ok($$select shared.send_receipt('e1000000-0000-0000-0000-000000000001')$$, '42501', null, 'clients cannot trigger receipts');
reset role;

select * from finish();
rollback;
