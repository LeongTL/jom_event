begin;
select plan(15);

-- one event per case so seat counts never interfere; capacity 2
create function pg_temp.case_(n int, status text, hold interval default null, cap int default 2, ev_status text default 'published')
returns void language plpgsql as $$
declare eid uuid := ('c0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid;
begin
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue)
  values (eid, 'aaaaaaaa-0000-0000-0000-000000000001', 'E' || n, ev_status, 3000, cap, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V');
  insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, eid, 'bbbbbbbb-0000-0000-0000-000000000002', 1, status,
          case when hold is null then null else now() + hold end, 'KLS-' || lpad(n::text, 5, '0'), 'Bob', '601', 3000);
end $$;
create function pg_temp.bid(n int) returns uuid language sql as $$ select ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid $$;
create function pg_temp.st(n int) returns text language sql as $$ select status from bookings.bookings where id = pg_temp.bid(n) $$;

select pg_temp.case_(1, 'held', interval '10 minutes');
select pg_temp.case_(2, 'payment_failed', interval '5 minutes');
select pg_temp.case_(3, 'processing', interval '-1 minute');
select pg_temp.case_(4, 'confirmed');
select pg_temp.case_(5, 'expired', interval '-5 minutes');                 -- late success, seat free
select pg_temp.case_(6, 'expired', interval '-5 minutes', 1);               -- late success, event full...
insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values ('c0000000-0000-0000-0000-000000000006', 'cccccccc-0000-0000-0000-000000000003', 1, 'confirmed', 'KLS-99996', 'Carol', '602', 3000);
select pg_temp.case_(7, 'held', interval '-1 minute', 1);                  -- lapsed hold not yet swept, event full
insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values ('c0000000-0000-0000-0000-000000000007', 'cccccccc-0000-0000-0000-000000000003', 1, 'confirmed', 'KLS-99997', 'Carol', '602', 3000);
select pg_temp.case_(8, 'cancelled');
select pg_temp.case_(9, 'processing', interval '-1 minute', 2, 'cancelled'); -- event deleted meanwhile
select pg_temp.case_(10, 'held', interval '-1 minute');                      -- lapsed hold, seat still free

-- mark_processing
select is(bookings.mark_processing(pg_temp.bid(1)), 'processing', 'mark_processing: held becomes processing');
select is(bookings.mark_processing(pg_temp.bid(1)), 'processing', 'mark_processing: doing it again changes nothing');
select is(bookings.mark_processing(pg_temp.bid(2)), 'processing', 'mark_processing: a failed payment retried becomes processing');

-- mark_payment_failed keeps the hold time
select pg_temp.case_(11, 'held', interval '9 minutes');
select is(bookings.mark_payment_failed(pg_temp.bid(11)), 'payment_failed', 'mark_payment_failed: held becomes payment_failed');
select is((select hold_expires_at from bookings.bookings where id = pg_temp.bid(11)), now() + interval '9 minutes',
  'failed_sets_payment_failed_and_keeps_hold_time');
select is(bookings.mark_payment_failed(pg_temp.bid(3)), 'payment_failed', 'mark_payment_failed: processing becomes payment_failed');
select is(bookings.mark_payment_failed(pg_temp.bid(4)), 'confirmed', 'mark_payment_failed: a confirmed booking is left alone');

-- mark_confirmed
select is(bookings.mark_confirmed(pg_temp.bid(11)), 'confirmed', 'mark_confirmed: a failed payment that later succeeds is confirmed');
select is((select hold_expires_at from bookings.bookings where id = pg_temp.bid(11)), null, 'mark_confirmed clears the hold');
select is(bookings.mark_confirmed(pg_temp.bid(4)), 'confirmed', 'mark_confirmed: confirming twice changes nothing');
select is(bookings.mark_confirmed(pg_temp.bid(5)), 'confirmed', 'success_after_hold_expired_confirms_if_seats_free');
select is(bookings.mark_confirmed(pg_temp.bid(6)), 'expired', 'success_after_hold_expired_is_not_confirmed_if_the_event_is_full');
select is(bookings.mark_confirmed(pg_temp.bid(7)) || '/' || pg_temp.st(7), 'expired/expired', 'a lapsed hold with no free seat becomes expired');
select is(bookings.mark_confirmed(pg_temp.bid(10)), 'confirmed', 'a lapsed hold with a free seat is still confirmed');
select is(bookings.mark_confirmed(pg_temp.bid(8)) || '/' || bookings.mark_confirmed(pg_temp.bid(9)) || '/' || pg_temp.st(9),
  'cancelled/cancelled/cancelled', 'a cancelled booking, or one whose event was deleted, is never confirmed');

select * from finish();
rollback;
