begin;
select plan(11);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');

insert into events.events (id, host_id, title, status, price_sen, accept_bookings) values
  ('eeeeeeee-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000001', 'A draft',     'draft',     3000, true),
  ('eeeeeeee-0000-0000-0000-00000000000b', 'aaaaaaaa-0000-0000-0000-000000000001', 'B published', 'published', 3000, true),
  ('eeeeeeee-0000-0000-0000-00000000000c', 'aaaaaaaa-0000-0000-0000-000000000001', 'C ended',     'ended',     3000, true),
  ('eeeeeeee-0000-0000-0000-00000000000d', 'aaaaaaaa-0000-0000-0000-000000000001', 'D cancelled', 'cancelled', 3000, true),
  ('eeeeeeee-0000-0000-0000-00000000000e', 'cccccccc-0000-0000-0000-000000000003', 'E carol draft', 'draft',   3000, true),
  ('eeeeeeee-0000-0000-0000-00000000000f', 'aaaaaaaa-0000-0000-0000-000000000001', 'F free',      'published', 0,    true),
  ('eeeeeeee-0000-0000-0000-000000000010', 'aaaaaaaa-0000-0000-0000-000000000001', 'G switch off', 'published', 3000, false);

select is((select count(*)::int from events.events), 7, 'fixture: seven events exist');

select is(
  (select array_agg(e.title order by e.title) from events.events e
    where e.id = 'eeeeeeee-0000-0000-0000-00000000000b' and events.exists_published(e.id)),
  array['B published'], 'exists_published_is_true_for_a_published_event');
select is(
  (select array_agg(e.title order by e.title) from events.events e
    where e.title in ('A draft', 'C ended', 'D cancelled') and events.exists_published(e.id)),
  null, 'exists_published_is_false_for_draft_ended_and_cancelled');

select ok(events.is_bookable((select e from events.events e where e.title = 'B published')), 'is_bookable_true_for_paid_with_switch_on');
select ok(not events.is_bookable((select e from events.events e where e.title = 'F free')), 'is_bookable_false_for_free');
select ok(not events.is_bookable((select e from events.events e where e.title = 'G switch off')), 'is_bookable_false_when_switched_off');

select is((select array_agg(name order by name) from events.areas),
  array['Bangsar','Bukit Bintang','KLCC','Mid Valley','PJ','Sri Hartamas'], 'six areas are seeded');

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is((select array_agg(title order by title) from events.events),
  array['B published','C ended','F free','G switch off'],
  'anon_reads_published_and_ended_only');
reset role;

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select array_agg(title order by title) from events.events),
  array['A draft','B published','C ended','D cancelled','F free','G switch off'],
  'a host also reads their own drafts and cancelled events, not other hosts drafts');
select throws_ok($$insert into events.events (host_id, title) values ('aaaaaaaa-0000-0000-0000-000000000001', 'x')$$,
  '42501', null, 'clients_cannot_insert_events_directly');
select throws_ok($$update events.events set price_sen = 1$$, '42501', null, 'clients_cannot_update_events_directly');
reset role;

select * from finish();
rollback;
