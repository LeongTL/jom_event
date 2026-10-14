begin;
select plan(10);

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, area, venue)
select ('e0000000-0000-0000-0000-00000000000' || n)::uuid, 'aaaaaaaa-0000-0000-0000-000000000001', 'Event ' || n,
       'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', p, 'Bangsar', 'V'
  from (values (1, '24h'), (2, '48h'), (3, '7d'), (4, 'none')) as t(n, p);

select is(events.cancel_cutoff('e0000000-0000-0000-0000-000000000001'), '2030-01-09 20:00+08'::timestamptz, 'cancel_cutoff 24h is a day before the start');
select is(events.cancel_cutoff('e0000000-0000-0000-0000-000000000002'), '2030-01-08 20:00+08'::timestamptz, 'cancel_cutoff 48h is two days before');
select is(events.cancel_cutoff('e0000000-0000-0000-0000-000000000003'), '2030-01-03 20:00+08'::timestamptz, 'cancel_cutoff 7d is a week before');
select is(events.cancel_cutoff('e0000000-0000-0000-0000-000000000004'), null, 'cancel_cutoff none is null (no refunds)');

select is((select (events.lock_for_booking('e0000000-0000-0000-0000-000000000002')).capacity), 10, 'lock_for_booking returns the event row');
select throws_ok($$select events.lock_for_booking('e0000000-0000-0000-0000-0000000000ff')$$, 'P0001', 'event_not_found',
  'lock_for_booking raises for an unknown event');
select results_eq(
  $$select host_id, title, status, price_sen, capacity from events.event_brief('e0000000-0000-0000-0000-000000000001')$$,
  $$values ('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'Event 1', 'published', 3000, 10)$$,
  'event_brief returns the facts bookings and payments need');

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select events.lock_for_booking('e0000000-0000-0000-0000-000000000001')$$, '42501', null, 'lock_for_booking is not callable by clients');
select throws_ok($$select events.cancel_cutoff('e0000000-0000-0000-0000-000000000001')$$, '42501', null, 'cancel_cutoff is not callable by clients');
select throws_ok($$select * from events.event_brief('e0000000-0000-0000-0000-000000000001')$$, '42501', null, 'event_brief is not callable by clients');
reset role;

select * from finish();
rollback;
