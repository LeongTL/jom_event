begin;
select plan(36);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),  -- host
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com');    -- another host
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid, 'g' || i || '@example.com' from generate_series(10, 40) i;

create function pg_temp.ev(id uuid, price int, st text default 'published', starts timestamptz default '2030-01-10 20:00+08') returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                             accept_bookings, area, venue, lat, lng)
  values (id, 'aaaaaaaa-0000-0000-0000-000000000001', 'Event ' || left(id::text, 8), st, price, 40, starts, starts + interval '2 hours',
          '24h', true, 'Bangsar', 'V', 3.129, 101.671)
$$;
select pg_temp.ev('e1000000-0000-0000-0000-000000000001', 3000);                                  -- 12 paid guests
select pg_temp.ev('e2000000-0000-0000-0000-000000000002', 3000);                                  -- mid-payment guests
select pg_temp.ev('e3000000-0000-0000-0000-000000000003', 3000, 'published', now() - interval '1 hour');  -- already started
select pg_temp.ev('e4000000-0000-0000-0000-000000000004', 3000);                                  -- no bookings
select pg_temp.ev('e5000000-0000-0000-0000-000000000005', 0);                                     -- free, two guests
select pg_temp.ev('ea000000-0000-0000-0000-00000000000a', 3000);                                  -- untouched control
select pg_temp.ev('e6000000-0000-0000-0000-000000000006', 3000);                                  -- only history (expired, cancelled)
select pg_temp.ev('e7000000-0000-0000-0000-000000000007', 3000, 'ended', now() - interval '3 days');
select pg_temp.ev('e8000000-0000-0000-0000-000000000008', 3000, 'cancelled');
insert into events.events (id, host_id, title, status) values
  ('e9000000-0000-0000-0000-000000000009', 'aaaaaaaa-0000-0000-0000-000000000001', 'A draft', 'draft');

-- booking n of an event, with an attempt (a successful one when paid) and a fee snapshot
create function pg_temp.bk(n int, ev uuid, st text, amount int, attempt text default null) returns void language plpgsql as $$
declare bid uuid := ('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid;
begin
  insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
  values (bid, ev, ('00000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid, 1, st,
          case when st in ('held', 'payment_failed') then now() + interval '10 minutes' end,
          'KLS-' || lpad(n::text, 5, '0'), 'Guest ' || n, '601', amount);
  if attempt is not null then
    insert into payments.payment_attempts (id, booking_id, reference, status, method, session_expires_at)
    values (('a0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, bid, 'REF-' || n, attempt, 'fpx', now() + interval '10 minutes');
  end if;
  if attempt = 'success' then
    insert into payments.fee_snapshots (booking_id, gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen)
    select bid, amount, f.gateway_fee_sen, f.platform_fee_sen, f.host_receives_sen from payments.compute_fees(amount) f;
  end if;
end $$;
select pg_temp.bk(n, 'e1000000-0000-0000-0000-000000000001', 'confirmed', 3000, 'success') from generate_series(10, 21) n;
select pg_temp.bk(22, 'e2000000-0000-0000-0000-000000000002', 'held', 3000, 'created');
select pg_temp.bk(23, 'e2000000-0000-0000-0000-000000000002', 'processing', 3000, 'pending');
select pg_temp.bk(24, 'e2000000-0000-0000-0000-000000000002', 'payment_failed', 3000, 'failed');
select pg_temp.bk(25, 'e2000000-0000-0000-0000-000000000002', 'confirmed', 3000, 'success');
select pg_temp.bk(26, 'e2000000-0000-0000-0000-000000000002', 'attended', 3000, 'success');
select pg_temp.bk(27, 'e3000000-0000-0000-0000-000000000003', 'confirmed', 3000, 'success');
select pg_temp.bk(28, 'e5000000-0000-0000-0000-000000000005', 'confirmed', 0);
select pg_temp.bk(29, 'e5000000-0000-0000-0000-000000000005', 'confirmed', 0);
select pg_temp.bk(30, 'e6000000-0000-0000-0000-000000000006', 'expired', 3000, 'failed');
select pg_temp.bk(31, 'e6000000-0000-0000-0000-000000000006', 'cancelled', 3000, 'created');

-- who may delete
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.delete_event('e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_owner',
  'delete_by_non_host_is_refused');
reset role;
set local role anon;
select throws_ok($$select events.delete_event('e1000000-0000-0000-0000-000000000001')$$, '42501', null,
  'signed-out visitors cannot delete');
reset role;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.delete_event('e3000000-0000-0000-0000-000000000003')$$, 'P0001', 'event_started',
  'delete_after_start_is_refused');
select throws_ok($$select events.delete_event('e7000000-0000-0000-0000-000000000007')$$, 'P0001', 'not_deletable',
  'an ended event cannot be deleted');
select throws_ok($$select events.delete_event('e8000000-0000-0000-0000-000000000008')$$, 'P0001', 'not_deletable',
  'an already cancelled event cannot be deleted again');
select throws_ok($$select bookings.cancel_all_for_event('e1000000-0000-0000-0000-000000000001')$$, '42501', null,
  'clients cannot call cancel_all_for_event directly');
reset role;
select is((select count(*)::int from bookings.bookings where event_id in ('e1000000-0000-0000-0000-000000000001', 'e3000000-0000-0000-0000-000000000003') and status <> 'confirmed'), 0,
  'refused deletes change nothing');

-- 12 paid guests: all refunded in full and told
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r1', events.delete_event('e1000000-0000-0000-0000-000000000001')::text, true);
reset role;
select is(current_setting('t.r1')::jsonb, '{"refunded": 12, "released": 0}'::jsonb, 'delete_event reports 12 refunded and none released');
select is((select status from events.events where id = 'e1000000-0000-0000-0000-000000000001'), 'cancelled', 'the event is marked cancelled');
select results_eq($$select count(*)::int, sum(r.amount_sen)::int, count(distinct r.reason)::int, min(r.status)
                      from payments.refunds r join bookings.bookings b on b.id = r.booking_id
                     where b.event_id = 'e1000000-0000-0000-0000-000000000001'$$,
  $$values (12, 36000, 1, 'done')$$, 'delete_with_12_paid_bookings_refunds_all_12_in_full (RM360 in total)');
select is((select count(*)::int from bookings.bookings where event_id = 'e1000000-0000-0000-0000-000000000001' and status = 'cancelled'), 12,
  'every booking is cancelled');
select is((select count(*)::int from identity.notifications where type = 'event_cancelled' and ref_id = 'e1000000-0000-0000-0000-000000000001'
             and title like '%was cancelled'), 12, 'and notifies each: 12 notices whose title ends "was cancelled"');
select is((select sum(host_receives_sen)::int from payments.fee_snapshots f join bookings.bookings b on b.id = f.booking_id
            where b.event_id = 'e1000000-0000-0000-0000-000000000001'), 0, 'the host keeps nothing from a deleted event');
select is(bookings.seats_taken('e1000000-0000-0000-0000-000000000001'), 0, 'the seats are free again');

-- mid-payment guests
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r2', events.delete_event('e2000000-0000-0000-0000-000000000002')::text, true);
reset role;
select is(current_setting('t.r2')::jsonb, '{"refunded": 2, "released": 3}'::jsonb,
  'confirmed and attended guests are refunded; held, processing and failed bookings are released');
select results_eq($$select id, status from bookings.bookings where event_id = 'e2000000-0000-0000-0000-000000000002' order by id$$,
  $$values ('b0000000-0000-0000-0000-000000000022'::uuid, 'cancelled'), ('b0000000-0000-0000-0000-000000000023', 'cancelled'),
           ('b0000000-0000-0000-0000-000000000024', 'cancelled'), ('b0000000-0000-0000-0000-000000000025', 'cancelled'),
           ('b0000000-0000-0000-0000-000000000026', 'cancelled')$$, 'every live booking ends up cancelled');
select is((select count(*)::int from payments.refunds r join bookings.bookings b on b.id = r.booking_id where b.event_id = 'e2000000-0000-0000-0000-000000000002'),
  2, 'held_bookings_are_released_without_refund: only the two paid bookings have refunds');
select is((select count(*)::int from identity.notifications where ref_id = 'e2000000-0000-0000-0000-000000000002' and type = 'event_cancelled'
             and user_id in ('00000000-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000024')), 0,
  'someone who had not paid is not told a booking was cancelled');

-- a success that arrives after the delete
select is(payments.apply_gateway_result('a0000000-0000-0000-0000-000000000023', 'success', 'fpx'), 'cancelled',
  'processing_booking_is_cancelled_and_a_late_success_webhook_is_refunded: the booking stays cancelled');
select results_eq($$select amount_sen, status from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000023'$$,
  $$values (3000, 'done')$$, 'and the late payment is refunded in full');
select is(payments.apply_gateway_result('a0000000-0000-0000-0000-000000000022', 'success', 'card'), 'cancelled',
  'success_arriving_after_delete_never_confirms_the_booking (a held booking)');
select is((select status from bookings.bookings where id = 'b0000000-0000-0000-0000-000000000022'), 'cancelled', 'it is still cancelled');
select is((select count(*)::int from payments.refunds where booking_id = 'b0000000-0000-0000-0000-000000000022'), 1, 'and refunded');
select is((select count(*)::int from payments.fee_snapshots where booking_id in ('b0000000-0000-0000-0000-000000000022', 'b0000000-0000-0000-0000-000000000023')),
  0, 'a late payment on a deleted event earns the host nothing');

-- free guests, no bookings, history only, drafts
insert into identity.saved_events (user_id, event_id) values ('00000000-0000-0000-0000-000000000010', 'e4000000-0000-0000-0000-000000000004');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.r3', events.delete_event('e5000000-0000-0000-0000-000000000005')::text, true);
select set_config('t.r4', events.delete_event('e4000000-0000-0000-0000-000000000004')::text, true);
select set_config('t.r5', events.delete_event('e9000000-0000-0000-0000-000000000009')::text, true);
select set_config('t.r6', events.delete_event('e6000000-0000-0000-0000-000000000006')::text, true);
reset role;
select is(current_setting('t.r3')::jsonb, '{"refunded": 0, "released": 0}'::jsonb, 'free guests are cancelled with nothing to refund');
select is((select count(*)::int from identity.notifications where type = 'event_cancelled' and ref_id = 'e5000000-0000-0000-0000-000000000005'), 2,
  'but they are still told');
select is(current_setting('t.r4')::jsonb, '{"refunded": 0, "released": 0}'::jsonb, 'delete_with_no_bookings_removes_it_without_refunds');
select is((select count(*)::int from events.events where id in ('e4000000-0000-0000-0000-000000000004', 'e9000000-0000-0000-0000-000000000009')), 0,
  'an event with no bookings, and a draft, are removed outright');
select is((select count(*)::int from identity.saved_events where event_id = 'e4000000-0000-0000-0000-000000000004'), 0,
  'a removed event leaves everyone''s Saved list');
select is((select status from events.events where id = 'e6000000-0000-0000-0000-000000000006'), 'cancelled',
  'an event with only past bookings keeps its history and is marked cancelled');
select is((select string_agg(status, ',' order by id) from bookings.bookings where event_id = 'e6000000-0000-0000-0000-000000000006'), 'expired,cancelled',
  'expired and cancelled bookings are left as they were');

-- gone from the app
select is((select count(*)::int from events.feed('now', 3.129, 101.671, 50, '2030-01-10 19:00+08') where event_id in
  ('e1000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000002', 'e5000000-0000-0000-0000-000000000005')), 0,
  'cancelled_event_disappears_from_feed');
select is((select count(*)::int from events.feed('now', 3.129, 101.671, 50, '2030-01-10 19:00+08') where event_id = 'ea000000-0000-0000-0000-00000000000a'), 1,
  'while an untouched event is still listed (the feed query works)');
select is((select count(*)::int from events.list_all(3.129, 101.671, 'all', 50, '2030-01-10 19:00+08') where event_id in
  ('e1000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000002', 'e5000000-0000-0000-0000-000000000005')), 0,
  'and from View all');

-- failed refunds are retried up to 5 attempts
update payments.refunds set status = 'failed', attempts = 4 where booking_id = 'b0000000-0000-0000-0000-000000000010';
update payments.refunds set status = 'failed', attempts = 5 where booking_id = 'b0000000-0000-0000-0000-000000000011';
select is(payments.retry_failed_refunds(), 1, 'retry_failed_refunds_picks_up_failed_rows_up_to_5_attempts: one retried');
select results_eq($$select booking_id, status, attempts from payments.refunds where booking_id in
  ('b0000000-0000-0000-0000-000000000010', 'b0000000-0000-0000-0000-000000000011') order by booking_id$$,
  $$values ('b0000000-0000-0000-0000-000000000010'::uuid, 'done', 5), ('b0000000-0000-0000-0000-000000000011', 'failed', 5)$$,
  'the 4-attempt row is done; the 5-attempt row is left for a person');

select * from finish();
rollback;
