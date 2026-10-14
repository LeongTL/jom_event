begin;
select plan(20);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),  -- host
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com');    -- another host
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-0000000000' || lpad(i::text, 2, '0'))::uuid, 'g' || i || '@example.com' from generate_series(10, 30) i;

create function pg_temp.ev(id uuid, price int) returns void language sql as $$
  insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                             accept_bookings, area, venue, lat, lng)
  values (id, 'aaaaaaaa-0000-0000-0000-000000000001', 'Event ' || left(id::text, 8), 'published', price, 40,
          now() - interval '3 hours', now() - interval '1 hour', '24h', true, 'Bangsar', 'V', 3.129, 101.671)
$$;
select pg_temp.ev('e1000000-0000-0000-0000-000000000001', 3000);   -- 12 paid guests and one refunded booking
select pg_temp.ev('e2000000-0000-0000-0000-000000000002', 3000);   -- three guests, nobody checks in
select pg_temp.ev('e3000000-0000-0000-0000-000000000003', 0);      -- free

create function pg_temp.bk(n int, ev uuid, st text, price int) returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid, ev,
          ('00000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid, 1, st,
          'KLS-' || lpad(n::text, 5, '0'), 'Guest ' || n, '6011', price);
  insert into payments.fee_snapshots (booking_id, gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen)
  select ('b0000000-0000-0000-0000-0000000000' || lpad(n::text, 2, '0'))::uuid, price, f.gateway_fee_sen, f.platform_fee_sen, f.host_receives_sen
    from payments.compute_fees(price) f where price > 0
$$;
-- e1: guests 10 to 21 (six attended, six not checked in) ...
select pg_temp.bk(n, 'e1000000-0000-0000-0000-000000000001', case when n <= 15 then 'attended' else 'confirmed' end, 3000)
  from generate_series(10, 21) n;
-- ... and guest 22, who cancelled and was refunded (refund_booking zeroes the snapshot)
select pg_temp.bk(22, 'e1000000-0000-0000-0000-000000000001', 'cancelled', 3000);
update payments.fee_snapshots set gross_sen = 0, gateway_fee_sen = 0, platform_fee_sen = 0, host_receives_sen = 0
 where booking_id = 'b0000000-0000-0000-0000-000000000022';
select pg_temp.bk(n, 'e2000000-0000-0000-0000-000000000002', 'confirmed', 3000) from generate_series(23, 25) n;
select pg_temp.bk(26, 'e3000000-0000-0000-0000-000000000003', 'confirmed', 0);

-- earnings: the design example, with the refunded booking left out
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select results_eq($$select gross_sen, gateway_fee_sen, platform_fee_sen, host_receives_sen
                      from payments.event_earnings('e1000000-0000-0000-0000-000000000001')$$,
  $$values (36000::bigint, 540::bigint, 3600::bigint, 31860::bigint)$$,
  'event_earnings: 12 x RM30 = 360.00 less 5.40 and 36.00 leaves 318.60 (the refunded booking is not counted)');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
select throws_ok($$select * from payments.event_earnings('e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_owner',
  'another host cannot see the earnings');
reset role;
set local role anon;
select throws_ok($$select * from payments.event_earnings('e1000000-0000-0000-0000-000000000001')$$, '42501', null,
  'signed-out visitors cannot see earnings');
reset role;

-- nothing is scheduled before the event is completed
select is((select count(*)::int from payments.payouts), 0, 'no payout before completion');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select events.complete_event('e1000000-0000-0000-0000-000000000001');
select events.complete_event('e2000000-0000-0000-0000-000000000002');
select events.complete_event('e3000000-0000-0000-0000-000000000003');
reset role;

select is((select amount_sen from payments.payouts where event_id = 'e1000000-0000-0000-0000-000000000001'), 31860,
  'payout_sums_only_non_refunded_paid_bookings: 12 x 2655 = 31860 sen = RM318.60');
select results_eq(
  $$select host_id, status, paid_at from payments.payouts where event_id = 'e1000000-0000-0000-0000-000000000001'$$,
  $$values ('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'scheduled', null::timestamptz)$$,
  'the payout belongs to the host and is scheduled');
select is((select due_at from payments.payouts where event_id = 'e1000000-0000-0000-0000-000000000001'),
  shared.add_working_days(now(), 3), 'payout_due_is_three_working_days_after_completion');
select ok((select due_at between now() + interval '3 days' and now() + interval '5 days'
              and extract(isodow from due_at at time zone 'Asia/Kuala_Lumpur') < 6
         from payments.payouts where event_id = 'e1000000-0000-0000-0000-000000000001'),
  'the due date is 3 to 5 calendar days away and lands on a KL weekday');

-- no one checked in, the event still pays and the guests are no-shows
select is((select amount_sen from payments.payouts where event_id = 'e2000000-0000-0000-0000-000000000002'), 7965,
  'event_with_no_check_ins_still_pays: 3 x 2655');
select is((select count(*)::int from bookings.bookings where event_id = 'e2000000-0000-0000-0000-000000000002' and status = 'no_show'),
  3, 'the three guests who did not come are no-shows');

-- a free event has nothing to pay out
select is((select count(*)::int from payments.payouts where event_id = 'e3000000-0000-0000-0000-000000000003'), 0,
  'a free event gets no payout row');
select is((select count(*)::int from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'payout'),
  2, 'the host is told about the two payouts, not the free event');
select matches((select body from identity.notifications where type = 'payout' and ref_id = 'e1000000-0000-0000-0000-000000000001'),
  'RM318\.60', 'the payout notice names the amount');

-- one payout per event, whatever calls it
select lives_ok($$select payments.schedule_payout('e1000000-0000-0000-0000-000000000001')$$, 'scheduling again is harmless');
select is((select count(*)::int from payments.payouts where event_id = 'e1000000-0000-0000-0000-000000000001'), 1, 'still one payout per event');

-- earnings keep counting no-shows after completion
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select host_receives_sen from payments.event_earnings('e2000000-0000-0000-0000-000000000002')), 7965::bigint,
  'earnings still count guests who did not show');

-- the host's summary
select results_eq($$select upcoming_sen, paid_sen from payments.host_payout_summary()$$,
  $$values (39825::bigint, 0::bigint)$$, 'host_payout_summary: upcoming = both scheduled payouts');
reset role;
update payments.payouts set status = 'paid', paid_at = now(), paid_ref = 'TRX1' where event_id = 'e1000000-0000-0000-0000-000000000001';
set local role authenticated;
select results_eq($$select upcoming_sen, paid_sen from payments.host_payout_summary()$$,
  $$values (7965::bigint, 31860::bigint)$$, 'a paid payout moves from upcoming to paid out');
select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
select results_eq($$select upcoming_sen, paid_sen from payments.host_payout_summary()$$,
  $$values (0::bigint, 0::bigint)$$, 'another host sees only their own totals');
select throws_ok($$select payments.schedule_payout('e1000000-0000-0000-0000-000000000001')$$, '42501', null,
  'clients cannot schedule payouts');
reset role;

select * from finish();
rollback;
