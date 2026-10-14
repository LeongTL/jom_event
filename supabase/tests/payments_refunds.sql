begin;
select plan(10);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue) values
  ('e0000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Pottery night', 'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V');

-- a booking, optionally paid (a successful attempt plus its fee snapshot)
create function pg_temp.bk(n int, amount int, paid boolean, cutoff interval default null) returns void language plpgsql as $$
declare bid uuid := ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid;
begin
  insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen, cancel_cutoff_at)
  values (bid, 'e0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'confirmed',
          'KLS-' || lpad(n::text, 5, '0'), 'Bob', '601', amount, case when cutoff is null then null else now() + cutoff end);
  insert into payments.payment_attempts (booking_id, reference, status, method, session_expires_at)
  values (bid, 'KLS-' || lpad(n::text, 5, '0') || '-REF', case when paid then 'success' else 'created' end, 'fpx', now());
  if paid then
    insert into payments.fee_snapshots (booking_id, gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen)
    select bid, amount, f.gateway_fee_sen, f.platform_fee_sen, f.host_receives_sen from payments.compute_fees(amount) f;
  end if;
end $$;
select pg_temp.bk(1, 6000, true);
select pg_temp.bk(2, 0, false);        -- free
select pg_temp.bk(3, 3000, false);     -- never paid
select pg_temp.bk(4, 3000, true, interval '1 day');

select payments.refund_booking('b0000000-0000-0000-0000-000000000001', 'guest_cancelled');
select results_eq($$select amount_sen, reason, status from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000001'$$,
  $$values (6000, 'guest_cancelled', 'done')$$, 'refund_booking_creates_a_refund_for_the_amount_paid');
select matches((select provider_ref from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000001'), '^mock-',
  'the mock gateway settles it and gives a provider reference');
select payments.refund_booking('b0000000-0000-0000-0000-000000000001', 'guest_cancelled');
select is((select count(*)::int from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000001'), 1,
  'refund_booking_is_idempotent (one refund row per booking)');
select results_eq($$select gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen from payments.fee_snapshots where booking_id = 'b0000000-0000-0000-0000-000000000001'$$,
  $$values (0, 0, 0, 0)$$, 'a refunded booking no longer counts towards the host payout');

select payments.refund_booking('b0000000-0000-0000-0000-000000000002', 'guest_cancelled');
select payments.refund_booking('b0000000-0000-0000-0000-000000000003', 'guest_cancelled');
select is((select count(*)::int from payments.refunds where booking_id in ('b0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000003')), 0,
  'a free booking, or one that was never paid, is not refunded');

-- failed refunds are retried, up to 5 attempts
insert into payments.refunds (booking_id, amount_sen, reason, status, attempts) values
  ('b1000000-0000-0000-0000-000000000001', 3000, 'guest_cancelled', 'failed', 2),
  ('b1000000-0000-0000-0000-000000000002', 3000, 'guest_cancelled', 'failed', 5),
  ('b1000000-0000-0000-0000-000000000003', 3000, 'guest_cancelled', 'done',   1);
select is(payments.retry_failed_refunds(), 1, 'retry_failed_refunds_picks_up_failed_rows_up_to_5_attempts');
select is((select string_agg(right(booking_id::text, 1) || '=' || status || '/' || attempts, ',' order by booking_id) from payments.refunds
            where booking_id::text like 'b1000000%'),
  '1=done/3,2=failed/5,3=done/1', 'a retried refund is settled; one that used all 5 attempts is left alone');

-- a guest cancelling inside the window gets their money back
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
do $$ begin perform bookings.cancel_booking('b0000000-0000-0000-0000-000000000004'); end $$;
reset role;
select results_eq($$select b.status, r.amount_sen, r.reason, r.status from bookings.bookings b join payments.refunds r on r.booking_id = b.id where b.id = 'b0000000-0000-0000-0000-000000000004'$$,
  $$values ('cancelled', 3000, 'guest_cancelled', 'done')$$, 'cancel_booking_refunds_a_paid_booking_inside_the_window');

set local role authenticated;
select throws_ok($$select payments.refund_booking('b0000000-0000-0000-0000-000000000001', 'x')$$, '42501', null, 'clients cannot refund');
select throws_ok($$select payments.retry_failed_refunds()$$, '42501', null, 'clients cannot retry refunds');
reset role;

select * from finish();
rollback;
