begin;
select plan(14);

insert into auth.users (id, email) values
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');

create function pg_temp.bk(n int, status text, hold interval, people int default 1, amount int default 3000,
                           who uuid default 'bbbbbbbb-0000-0000-0000-000000000002') returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'e0000000-0000-0000-0000-000000000001', who, people, status,
          case when hold is null then null else now() + hold end, 'KLS-' || lpad(n::text, 5, '0'), 'Bob', '601', amount)
$$;
create function pg_temp.bid(n int) returns uuid language sql as $$ select ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;

select pg_temp.bk(1, 'held',           interval '12 minutes', 2, 6000);
select pg_temp.bk(2, 'held',           interval '-1 minute');
select pg_temp.bk(3, 'confirmed',      null);
select pg_temp.bk(4, 'processing',     interval '-1 minute');
select pg_temp.bk(5, 'payment_failed', interval '5 minutes');
select pg_temp.bk(6, 'held',           interval '5 minutes', 1, 0);
select pg_temp.bk(7, 'held',           interval '3 minutes');
select pg_temp.bk(8, 'held',           interval '5 minutes', 1, 3000, 'cccccccc-0000-0000-0000-000000000003');
insert into payments.payment_attempts (booking_id, reference, status, session_expires_at)
  values (pg_temp.bid(5), 'KLS-00005-OLD00000', 'failed', now() + interval '5 minutes'); -- failed, though its session has not run out

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.a1', (select attempt_id::text from payments.start_payment(pg_temp.bid(1))), true);
select set_config('t.a1ref', (select reference from payments.start_payment(pg_temp.bid(1))), true);
select matches(current_setting('t.a1ref'), '^KLS-00001-[0-9A-F]{8}$', 'start_payment makes a reference from the ticket code');
select is((select amount_sen from payments.start_payment(pg_temp.bid(1))), 6000, 'start_payment charges the booking amount');
select is((select expires_at from payments.start_payment(pg_temp.bid(1))), now() + interval '10 minutes', 'the gateway session lasts about 10 minutes');
select is((select expires_at from payments.start_payment(pg_temp.bid(7))), now() + interval '3 minutes', 'the session never outlives the hold');
select is((select attempt_id::text from payments.start_payment(pg_temp.bid(1))), current_setting('t.a1'), 'start_payment_reuses_unexpired_attempt');
select is((select count(*)::int from payments.payment_attempts where booking_id = pg_temp.bid(1)), 1, 'reusing leaves one attempt row');
select isnt((select attempt_id::text from payments.start_payment(pg_temp.bid(5))), null, 'a failed payment can be retried');
select is((select count(*)::int from payments.payment_attempts where booking_id = pg_temp.bid(5)), 2, 'a retry after failure is a new attempt');
select throws_ok($$select * from payments.start_payment('b0000000-0000-0000-0000-000000000002')$$, 'P0001', 'hold_expired', 'start_payment_refuses_expired_booking');
select throws_ok($$select * from payments.start_payment('b0000000-0000-0000-0000-000000000003')$$, 'P0001', 'not_payable', 'start_payment_refuses_confirmed_booking');
select throws_ok($$select * from payments.start_payment('b0000000-0000-0000-0000-000000000006')$$, 'P0001', 'nothing_to_pay', 'a free booking has nothing to pay');
select throws_ok($$select * from payments.start_payment('b0000000-0000-0000-0000-000000000008')$$, 'P0001', 'not_owner', 'only the attendee can pay');
select throws_ok($$insert into payments.payment_attempts (booking_id, reference, session_expires_at)
  values ('b0000000-0000-0000-0000-000000000001', 'X', now())$$, '42501', null, 'users_cannot_write_payment_attempts');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select * from payments.start_payment('b0000000-0000-0000-0000-000000000001')$$, '42501', null, 'start_payment_requires_login');
reset role;

select * from finish();
rollback;
