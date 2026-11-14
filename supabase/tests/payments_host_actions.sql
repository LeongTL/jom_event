begin;
select plan(19);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com'),
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com');
update identity.profiles set name = 'Bob Tan' where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
update identity.profiles set name = 'Carol Lim' where user_id = 'cccccccc-0000-0000-0000-000000000003';
create function pg_temp.as_(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || uid || '","role":"authenticated"}', true) $$;
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'x', 'Mei', 'Maybank', '1'); end $$;
reset role;
select pg_temp.as_('dddddddd-0000-0000-0000-000000000004');
set local role authenticated;
do $$ begin perform identity.apply_host('Dave', 'Bangsar', 'x', 'Dave', 'Maybank', '2'); end $$;
reset role;

create function pg_temp.ev(n int, starts_in interval, cap int default 5, st text default 'published') returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, accept_bookings, area, venue, lat, lng)
  values (('e0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'aaaaaaaa-0000-0000-0000-000000000001', 'E' || n, st,
          3000, cap, now() + starts_in, now() + starts_in + interval '2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6)
$$;
create function pg_temp.eid(n int) returns uuid language sql as $$ select ('e0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.bid(n int) returns uuid language sql as $$ select ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.bk(n int, uid uuid, st text, ev int default 1, hold interval default null) returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
  values (pg_temp.bid(n), pg_temp.eid(ev), uid, 1, st, case when hold is null then null else now() + hold end, 'KLS-0000' || n, 'B', '1', 3000)
$$;
create function pg_temp.rc(n int, st text default 'pending') returns void language sql as $$
  insert into payments.receipts (id, booking_id, image_path, status)
  values (('c0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, pg_temp.bid(n), pg_temp.bid(n) || '/a.jpg', st)
$$;
create function pg_temp.rid(n int) returns uuid language sql as $$ select ('c0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
select pg_temp.ev(1, interval '3 days', 8);
select pg_temp.ev(2, interval '3 days', 1);
select pg_temp.ev(3, interval '3 days', 5, 'cancelled');
select pg_temp.ev(4, interval '30 minutes');
select pg_temp.bk(1, 'bbbbbbbb-0000-0000-0000-000000000002', 'processing'); select pg_temp.rc(1);
select pg_temp.bk(2, 'bbbbbbbb-0000-0000-0000-000000000002', 'processing'); select pg_temp.rc(2);
select pg_temp.bk(3, 'cccccccc-0000-0000-0000-000000000003', 'expired', 1, interval '-1 hour'); select pg_temp.rc(3, 'late');
select pg_temp.bk(4, 'cccccccc-0000-0000-0000-000000000003', 'processing', 3); select pg_temp.rc(4);
select pg_temp.bk(5, 'bbbbbbbb-0000-0000-0000-000000000002', 'processing', 4); select pg_temp.rc(5);
select pg_temp.bk(6, 'bbbbbbbb-0000-0000-0000-000000000002', 'confirmed');
select pg_temp.bk(7, 'dddddddd-0000-0000-0000-000000000004', 'confirmed', 2);  -- fills the 1-seat event

-- host reads
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
select is((select string_agg(distinct status, ',') from payments.pending_receipts()), 'late,pending', 'pending_receipts_lists_pending_and_late');
select results_eq($$select guest_name, amount_sen from payments.pending_receipts(pg_temp.eid(1)) where booking_id = pg_temp.bid(1)$$,
  $$values ('Bob Tan', 3000)$$, 'pending_receipts_carry_guest_and_amount');
select pg_temp.as_('dddddddd-0000-0000-0000-000000000004');
select is((select count(*)::int from payments.pending_receipts()), 0, 'pending_receipts_empty_for_other_host');
select throws_ok($$select payments.accept_receipt(pg_temp.rid(1))$$, 'P0001', 'not_host', 'accept_refused_for_other_host');
select throws_ok($$select payments.request_new_receipt(pg_temp.bid(1), 'again')$$, 'P0001', 'not_host', 'request_new_receipt_refused_for_other_host');
select throws_ok($$select payments.record_refund(pg_temp.bid(6), 'x')$$, 'P0001', 'not_host', 'record_refund_refused_for_other_host');
select throws_ok($$select payments.assign_seat(pg_temp.eid(1), 'bbbbbbbb-0000-0000-0000-000000000002', 1, null, false)$$, 'P0001', 'not_host', 'assign_seat_refused_for_other_host_event');

-- accept
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
select payments.accept_receipt(pg_temp.rid(1));
select payments.accept_receipt(pg_temp.rid(1));
select throws_ok($$select payments.accept_receipt(pg_temp.rid(4))$$, 'P0001', 'event_not_available', 'accept_refused_when_event_cancelled');
reset role;
select results_eq($$select b.status, r.status from bookings.bookings b join payments.receipts r on r.booking_id = b.id where b.id = pg_temp.bid(1)$$,
  $$values ('confirmed', 'accepted')$$, 'accept_confirms_booking_and_marks_receipt_accepted_twice_is_fine');
select is((select count(*)::int from identity.notifications where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and type = 'receipt_accepted'), 1,
  'accept_notifies_guest_once');

-- ask again
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
select payments.request_new_receipt(pg_temp.bid(2), 'Amount was short');
select throws_ok($$select payments.request_new_receipt(pg_temp.bid(5), 'again')$$, 'P0001', 'bookings_closed', 'request_new_receipt_refused_inside_last_hour');
reset role;
select results_eq($$select b.status, b.hold_expires_at, r.status from bookings.bookings b join payments.receipts r on r.booking_id = b.id where b.id = pg_temp.bid(2)$$,
  $$values ('held', now() + interval '1 hour', 'replaced')$$, 'request_new_receipt_returns_to_held_with_fresh_hold_and_replaces_receipt');
select is((select m.body from chat.messages m join chat.threads t on t.id = m.thread_id
            where t.attendee_id = 'bbbbbbbb-0000-0000-0000-000000000002' and t.host_id = 'aaaaaaaa-0000-0000-0000-000000000001' limit 1),
  'Amount was short', 'request_new_receipt_posts_note_in_chat');

-- assign seat
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('t.new', payments.assign_seat(pg_temp.eid(1), 'dddddddd-0000-0000-0000-000000000004', 2, null, false)::text, true);
select set_config('t.late', payments.assign_seat(pg_temp.eid(1), 'cccccccc-0000-0000-0000-000000000003', 1, pg_temp.rid(3), false)::text, true);
select throws_ok($$select payments.assign_seat(pg_temp.eid(2), 'cccccccc-0000-0000-0000-000000000003', 1, null, false)$$, 'P0001', 'event_full', 'assign_seat_refuses_full_event_unless_over_capacity_allowed');
select lives_ok($$select payments.assign_seat(pg_temp.eid(2), 'cccccccc-0000-0000-0000-000000000003', 1, null, true)$$, 'assign_seat_over_capacity_when_allowed');
reset role;
select results_eq($$select status, amount_sen, people from bookings.bookings where id = current_setting('t.new')::uuid$$,
  $$values ('confirmed', 6000, 2)$$, 'assign_seat_creates_confirmed_booking_for_user_with_no_order');
select results_eq($$select b.status, r.status from bookings.bookings b, payments.receipts r where b.id = pg_temp.bid(3) and r.id = pg_temp.rid(3)$$,
  $$values ('confirmed', 'accepted')$$, 'assign_seat_confirms_expired_booking_and_links_late_receipt');

-- refund
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
select payments.record_refund(pg_temp.bid(6), 'Refunded by bank transfer');
reset role;
select results_eq($$select status, refund_note from bookings.bookings where id = pg_temp.bid(6)$$,
  $$values ('cancelled', 'Refunded by bank transfer')$$, 'record_refund_cancels_and_keeps_note');

set local role authenticated;
select throws_ok($$select chat.post_system_message(gen_random_uuid(), 'aaaaaaaa-0000-0000-0000-000000000001', 'hi')$$, '42501', null, 'post_system_message_not_callable_by_clients');
select * from finish();
rollback;
