begin;
select plan(33);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue) values
  ('e0000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Pottery night', 'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V'),
  ('e0000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Roomy night',   'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V'),
  ('e0000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Full night',    'published', 3000, 1,  '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V');

-- a booking with one gateway attempt
create function pg_temp.bk(n int, ev int, status text, hold interval, people int default 1, amount int default 3000,
                           who uuid default 'bbbbbbbb-0000-0000-0000-000000000002') returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, ('e0000000-0000-0000-0000-' || lpad(ev::text, 12, '0'))::uuid,
          who, people, status, case when hold is null then null else now() + hold end, 'KLS-' || lpad(n::text, 5, '0'), 'Bob', '601', amount);
  insert into payments.payment_attempts (id, booking_id, reference, session_expires_at)
  values (('a0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
          'KLS-' || lpad(n::text, 5, '0') || '-REF', now() + interval '10 minutes')
$$;
create function pg_temp.att(n int) returns uuid language sql as $$ select ('a0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.bst(n int) returns text language sql as $$ select status from bookings.bookings where id = ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;

select pg_temp.bk(1, 1, 'held',    interval '10 minutes', 2, 6000);   -- the happy path
select pg_temp.bk(2, 1, 'held',    interval '9 minutes');             -- fails, then succeeds
select pg_temp.bk(3, 1, 'held',    interval '9 minutes');             -- pending, then succeeds
select pg_temp.bk(4, 1, 'held',    interval '9 minutes');             -- pending twice
select pg_temp.bk(5, 2, 'expired', interval '-5 minutes');            -- late success, room left
select pg_temp.bk(6, 3, 'expired', interval '-5 minutes');            -- late success, event full
insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values ('e0000000-0000-0000-0000-000000000003', 'cccccccc-0000-0000-0000-000000000003', 1, 'confirmed', 'KLS-99996', 'Carol', '602', 3000);
select pg_temp.bk(7, 1, 'cancelled', null);                           -- event or guest cancelled meanwhile

-- ===== success =====
select is(payments.apply_gateway_result(pg_temp.att(1), 'success', 'fpx'), 'confirmed', 'success_confirms_booking');
select is((select hold_expires_at from bookings.bookings where id = 'b0000000-0000-0000-0000-000000000001'), null, 'a confirmed booking has no hold');
select results_eq($$select gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen from payments.fee_snapshots where booking_id = 'b0000000-0000-0000-0000-000000000001'$$,
  $$values (6000, 90, 600, 5310)$$, 'success_saves_fee_snapshot (RM60: 0.90 gateway, 6.00 platform, 53.10 to the host)');
select is((select count(*)::int from identity.notifications where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and type = 'payment' and ref_id = 'b0000000-0000-0000-0000-000000000001'),
  1, 'success_notifies_the_attendee');
select results_eq($$select type, ref_type, ref_id from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values ('booking', 'event', 'e0000000-0000-0000-0000-000000000001'::uuid)$$, 'success_notifies_the_host');
select results_eq($$select status, method from payments.payment_attempts where id = 'a0000000-0000-0000-0000-000000000001'$$,
  $$values ('success', 'fpx')$$, 'the attempt records its result and method');
select is(payments.paid_method('b0000000-0000-0000-0000-000000000001'), 'fpx', 'paid_method says how the guest paid');

select is(payments.apply_gateway_result(pg_temp.att(1), 'success', 'fpx'), 'confirmed', 'second_identical_result_returns_the_same_status');
select is((select count(*)::int from identity.notifications where type in ('payment', 'booking')) || '/' ||
          (select count(*)::int from payments.fee_snapshots where booking_id = 'b0000000-0000-0000-0000-000000000001'),
  '2/1', 'second_identical_result_changes_nothing (no new notification or snapshot)');
select is(payments.apply_gateway_result(pg_temp.att(1), 'failed', 'fpx'), 'confirmed', 'a failure arriving after a success is ignored');

-- ===== failure, pending, retries =====
select is(payments.apply_gateway_result(pg_temp.att(2), 'failed', 'card'), 'payment_failed', 'failed_sets_payment_failed');
select is((select hold_expires_at from bookings.bookings where id = 'b0000000-0000-0000-0000-000000000002'), now() + interval '9 minutes',
  'failed_keeps_the_remaining_hold_time');
select is(payments.apply_gateway_result(pg_temp.att(2), 'success', 'card'), 'confirmed', 'a success that follows a failure confirms the booking');

select is(payments.apply_gateway_result(pg_temp.att(3), 'pending', 'fpx'), 'processing', 'pending_sets_processing');
select is(payments.apply_gateway_result(pg_temp.att(3), 'success', 'fpx'), 'confirmed', 'processing then success confirms');
select is(payments.apply_gateway_result(pg_temp.att(4), 'pending', 'fpx') || '/' || payments.apply_gateway_result(pg_temp.att(4), 'pending', 'fpx'),
  'processing/processing', 'a repeated pending changes nothing');

-- ===== success after the hold ran out =====
select is(payments.apply_gateway_result(pg_temp.att(5), 'success', 'fpx'), 'confirmed', 'success_after_hold_expired_confirms_if_seats_free');
select is((select count(*)::int from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000005'), 0, 'a late success that is confirmed is not refunded');
select is(payments.apply_gateway_result(pg_temp.att(6), 'success', 'fpx'), 'expired', 'success_after_hold_expired_leaves_it_expired_if_the_event_is_full');
select results_eq($$select amount_sen, reason, status from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000006'$$,
  $$values (3000, 'late_payment', 'done')$$, '... and refunds the guest automatically');
select is((select count(*)::int from payments.fee_snapshots where booking_id = 'b0000000-0000-0000-0000-000000000006'), 0, 'a refunded late payment leaves no fee snapshot to pay out');
select is(payments.apply_gateway_result(pg_temp.att(7), 'success', 'fpx'), 'cancelled', 'a success for a cancelled booking never confirms it');
select is((select count(*)::int from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000007'), 1, '... and the guest is refunded');

-- ===== bad input and who may call =====
select throws_ok($$select payments.apply_gateway_result('a0000000-0000-0000-0000-000000000001', 'maybe', 'x')$$, 'P0001', 'unknown_outcome', 'an unknown outcome is rejected');
select throws_ok($$select payments.apply_gateway_result('a0000000-0000-0000-0000-0000000000ff', 'success', 'x')$$, 'P0001', 'attempt_not_found', 'an unknown attempt is rejected');
select results_eq($$select reference, attendee_id, status from payments.attempt_info('a0000000-0000-0000-0000-000000000001')$$,
  $$values ('KLS-00001-REF', 'bbbbbbbb-0000-0000-0000-000000000002'::uuid, 'success')$$, 'attempt_info tells the gateway who the attempt belongs to');
select is(payments.claim_webhook_delivery('d1') || '/' || payments.claim_webhook_delivery('d1'), 'true/false', 'a webhook delivery can only be claimed once');
select is((select payments.release_webhook_delivery('d1')) || '/' || payments.claim_webhook_delivery('d1'), 'true/true', 'a released delivery can be claimed again (retry after an error)');

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select payments.apply_gateway_result('a0000000-0000-0000-0000-000000000001', 'success', 'x')$$, '42501', null, 'users_cannot_apply_gateway_results');
select is((select count(*)::int from payments.payment_attempts), 7, 'an attendee reads their own attempts');
select throws_ok($$select raw from payments.payment_attempts$$, '42501', null, 'the raw gateway payload is not readable by clients');
select throws_ok($$update payments.payment_attempts set status = 'success'$$, '42501', null, 'users_cannot_write_payment_attempts_or_refunds');
reset role;

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from payments.payment_attempts), 0, 'another user sees none of those attempts');
reset role;

select * from finish();
rollback;
