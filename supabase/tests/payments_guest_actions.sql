begin;
select plan(14);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  perform identity.apply_host('Mei Studio', 'Bangsar', 'Pottery', 'Mei Ling', 'Maybank', '1122334455');
  perform identity.save_payment_details('Mei Ling', 'Maybank', '1122334455', 'aaaaaaaa-0000-0000-0000-000000000001/qr.jpg');
end $$;
reset role;

create function pg_temp.ev(n int, starts_in interval) returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, accept_bookings, area, venue, lat, lng)
  values (('e0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'aaaaaaaa-0000-0000-0000-000000000001', 'E' || n, 'published',
          3000, 5, now() + starts_in, now() + starts_in + interval '2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6)
$$;
create function pg_temp.bk(n int, uid uuid, st text, hold interval default null, ev int default 1) returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, ('e0000000-0000-0000-0000-' || lpad(ev::text, 12, '0'))::uuid,
          uid, 1, st, case when hold is null then null else now() + hold end, 'KLS-0000' || n, 'B', '1', 3000)
$$;
create function pg_temp.bid(n int) returns uuid language sql as $$ select ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
select pg_temp.ev(1, interval '3 days');
select pg_temp.ev(2, interval '-1 hour');
select pg_temp.bk(1, 'bbbbbbbb-0000-0000-0000-000000000002', 'held', interval '1 hour');
select pg_temp.bk(2, 'bbbbbbbb-0000-0000-0000-000000000002', 'processing');
select pg_temp.bk(3, 'bbbbbbbb-0000-0000-0000-000000000002', 'expired', interval '-1 hour');
select pg_temp.bk(4, 'bbbbbbbb-0000-0000-0000-000000000002', 'confirmed');
select pg_temp.bk(5, 'bbbbbbbb-0000-0000-0000-000000000002', 'cancelled');
select pg_temp.bk(6, 'cccccccc-0000-0000-0000-000000000003', 'held', interval '1 hour');
select pg_temp.bk(7, 'bbbbbbbb-0000-0000-0000-000000000002', 'held', interval '1 hour', 2);

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select results_eq($$select amount_sen, reference, qr_path, bank, account_holder, account_number, status from payments.pay_instructions(pg_temp.bid(1))$$,
  $$values (3000, 'KLS-00001', 'aaaaaaaa-0000-0000-0000-000000000001/qr.jpg', 'Maybank', 'Mei Ling', '1122334455', 'held')$$,
  'pay_instructions_returns_amount_reference_and_host_details_to_attendee');
select is((select count(*)::int from payments.pay_instructions(pg_temp.bid(6))), 0, 'pay_instructions_empty_for_other_users');
select is((select count(*)::int from payments.pay_instructions(pg_temp.bid(4))) + (select count(*)::int from payments.pay_instructions(pg_temp.bid(5))), 0,
  'pay_instructions_empty_when_confirmed_or_cancelled');

-- held -> processing
select payments.submit_receipt(pg_temp.bid(1), pg_temp.bid(1) || '/a.jpg');
reset role;
select results_eq($$select status, hold_expires_at from bookings.bookings where id = pg_temp.bid(1)$$,
  $$values ('processing', null::timestamptz)$$, 'submit_from_held_moves_to_processing_and_clears_hold');
select is((select count(*)::int from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'receipt_submitted'), 1,
  'submit_notifies_host_once_per_submit');

-- processing again: older one replaced
set local role authenticated;
select payments.submit_receipt(pg_temp.bid(1), pg_temp.bid(1) || '/b.jpg');
reset role;
select results_eq($$select image_path like '%/a.jpg', status from payments.receipts where booking_id = pg_temp.bid(1) order by uploaded_at, image_path$$,
  $$values (true, 'replaced'), (false, 'pending')$$, 'submit_from_processing_replaces_older_pending_receipt');

-- expired: late receipt, booking stays expired
set local role authenticated;
select payments.submit_receipt(pg_temp.bid(3), pg_temp.bid(3) || '/a.jpg');
reset role;
select results_eq($$select b.status, r.status from bookings.bookings b join payments.receipts r on r.booking_id = b.id where b.id = pg_temp.bid(3)$$,
  $$values ('expired', 'late')$$, 'submit_from_expired_stores_late_receipt_and_keeps_booking_expired');
select is((select count(*)::int from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'late_receipt'), 1,
  'late_receipt_notifies_host');

set local role authenticated;
select throws_ok($$select payments.submit_receipt(pg_temp.bid(4), pg_temp.bid(4) || '/a.jpg')$$, 'P0001', 'not_payable', 'submit_on_confirmed_refused');
select throws_ok($$select payments.submit_receipt(pg_temp.bid(5), pg_temp.bid(5) || '/a.jpg')$$, 'P0001', 'not_payable', 'submit_on_cancelled_refused');
select throws_ok($$select payments.submit_receipt(pg_temp.bid(6), pg_temp.bid(6) || '/a.jpg')$$, 'P0001', 'not_owner', 'submit_on_foreign_booking_refused');
select throws_ok($$select payments.submit_receipt(pg_temp.bid(1), 'elsewhere/a.jpg')$$, 'P0001', 'bad_receipt_path', 'submit_rejects_path_outside_own_booking_folder');
select throws_ok($$select payments.submit_receipt(pg_temp.bid(7), pg_temp.bid(7) || '/a.jpg')$$, 'P0001', 'event_started', 'submit_after_event_started_refused');

select is((select string_agg(ticket_code, ',' order by ticket_code) from bookings.my_bookings('upcoming')), 'KLS-00001,KLS-00002,KLS-00003,KLS-00004',
  'my_bookings_lists_held_and_expired_for_future_events_not_cancelled');
select * from finish();
rollback;
