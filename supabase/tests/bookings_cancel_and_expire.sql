begin;
select plan(15);

insert into auth.users (id, email) values
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');

-- postgres-only helper: a booking in any state
create function pg_temp.bk(n int, status text, hold interval default null, amount int default 3000, cutoff interval default null)
returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name,
                                 contact_phone, amount_sen, cancel_cutoff_at)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
          ('f0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
          'bbbbbbbb-0000-0000-0000-000000000002', 1, status,
          case when hold is null then null else now() + hold end, 'KLS-' || lpad(n::text, 5, '0'), 'Bob', '601', amount,
          case when cutoff is null then null else now() + cutoff end)
$$;
select pg_temp.bk(1, 'confirmed',      null, 3000, interval '1 day');   -- inside the window
select pg_temp.bk(2, 'confirmed',      null, 3000, interval '-1 hour'); -- window closed
select pg_temp.bk(3, 'confirmed',      null, 3000, null);               -- no-refund event
select pg_temp.bk(4, 'confirmed',      null, 0,    interval '1 day');   -- free
select pg_temp.bk(5, 'held',           interval '10 minutes');
select pg_temp.bk(6, 'payment_failed', interval '5 minutes');
select pg_temp.bk(7, 'processing',     interval '-1 minute');
select pg_temp.bk(8, 'attended');
select pg_temp.bk(9, 'cancelled');

-- stand-in for the Task 7 refund: records who was refunded and why
create or replace function payments.refund_booking(p_booking_id uuid, p_reason text) returns void language plpgsql as $$
begin
  perform set_config('test.refunds', coalesce(current_setting('test.refunds', true), '') || right(p_booking_id::text, 2) || ':' || p_reason || ';', true);
end $$;

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;

do $$ begin perform bookings.cancel_booking('b0000000-0000-0000-0000-000000000001'); end $$;
reset role;
select results_eq(
  $$select status, cancelled_at is not null from bookings.bookings where id = 'b0000000-0000-0000-0000-000000000001'$$,
  $$values ('cancelled', true)$$, 'cancel_before_cutoff_marks_it_cancelled');
select is(current_setting('test.refunds', true), '01:guest_cancelled;', 'cancel_before_cutoff_creates_a_refund');
select is(bookings.seats_taken('f0000000-0000-0000-0000-000000000001'), 0, 'cancel_before_cutoff_frees_the_seat');

set local role authenticated;
select throws_ok($$select bookings.cancel_booking('b0000000-0000-0000-0000-000000000002')$$, 'P0001', 'cancel_not_allowed', 'cancel_after_cutoff_is_refused');
select throws_ok($$select bookings.cancel_booking('b0000000-0000-0000-0000-000000000003')$$, 'P0001', 'cancel_not_allowed', 'cancel_with_policy_none_is_refused');

do $$ begin
  perform bookings.cancel_booking('b0000000-0000-0000-0000-000000000004');
  perform bookings.cancel_booking('b0000000-0000-0000-0000-000000000005');
  perform bookings.cancel_booking('b0000000-0000-0000-0000-000000000006');
end $$;
reset role;
select is((select string_agg(right(id::text, 2) || '=' || status, ',' order by id) from bookings.bookings
            where id in ('b0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000006')),
  '04=cancelled,05=cancelled,06=cancelled', 'a free booking and an unpaid hold are released (giving up)');
select is(current_setting('test.refunds', true), '01:guest_cancelled;', 'free and unpaid cancellations create no refund');

set local role authenticated;
select throws_ok($$select bookings.cancel_booking('b0000000-0000-0000-0000-000000000007')$$, 'P0001', 'payment_in_progress', 'a processing booking cannot be cancelled');
select throws_ok($$select bookings.cancel_booking('b0000000-0000-0000-0000-000000000008')$$, 'P0001', 'not_cancellable', 'an attended booking cannot be cancelled');
select throws_ok($$select bookings.cancel_booking('b0000000-0000-0000-0000-000000000009')$$, 'P0001', 'not_cancellable', 'a cancelled booking cannot be cancelled again');
reset role;

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select bookings.cancel_booking('b0000000-0000-0000-0000-000000000002')$$, 'P0001', 'not_owner', 'only the attendee can cancel');
select throws_ok($$select bookings.expire_holds()$$, '42501', null, 'clients cannot run expire_holds');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select bookings.cancel_booking('b0000000-0000-0000-0000-000000000002')$$, '42501', null, 'cancel_booking_requires_login');
reset role;

-- expire_holds only touches held and payment_failed bookings past their deadline
select pg_temp.bk(11, 'held',           interval '-1 minute');
select pg_temp.bk(12, 'held',           interval '5 minutes');
select pg_temp.bk(13, 'payment_failed', interval '-1 minute');
select pg_temp.bk(14, 'payment_failed', interval '5 minutes');
select pg_temp.bk(15, 'processing',     interval '-1 minute');
select pg_temp.bk(16, 'confirmed');
select is(bookings.expire_holds(), 2, 'expire_holds reports how many it expired');
select is((select string_agg(right(id::text, 2) || '=' || status, ',' order by id) from bookings.bookings where id >= 'b0000000-0000-0000-0000-000000000011'),
  '11=expired,12=held,13=expired,14=payment_failed,15=processing,16=confirmed',
  'expire_holds_expires_only_held_and_payment_failed_past_deadline');

select * from finish();
rollback;
