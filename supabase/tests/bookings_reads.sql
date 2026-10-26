begin;
select plan(13);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';

insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Future event', 'published', 3000, 20, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V'),
  ('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Past event',   'ended',     3000, 20, '2020-01-10 20:00+08', '2020-01-10 22:00+08', 'Bangsar', 'V');

create function pg_temp.bk(n int, ev text, who uuid, status text, people int default 1, name text default 'Guest') returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen, checked_in_at)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, ev::uuid, who, people, status,
          'KLS-' || lpad(n::text, 5, '0'), name, '601', 3000 * people, case when status = 'attended' then now() end)
$$;
select pg_temp.bk(1, 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'confirmed', 2, 'Bob');
select pg_temp.bk(2, 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'processing', 1, 'Bob');
select pg_temp.bk(3, 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'held', 1, 'Bob');
select pg_temp.bk(4, 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 'cancelled', 1, 'Bob');
select pg_temp.bk(5, 'e2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'attended', 1, 'Bob');
select pg_temp.bk(6, 'e2000000-0000-0000-0000-000000000002', 'bbbbbbbb-0000-0000-0000-000000000002', 'no_show', 1, 'Bob');
select pg_temp.bk(7, 'e1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 'confirmed', 1, 'Carol');
select pg_temp.bk(8, 'e1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 'expired', 1, 'Carol');
select pg_temp.bk(9, 'e1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 'attended', 1, 'Carol');

-- Bob
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from bookings.bookings), 6, 'user_sees_only_own_bookings');
select is((select string_agg(ticket_code, ',' order by starts_at_sort, ticket_code) from (
    select ticket_code, event_starts_at as starts_at_sort from bookings.my_bookings('upcoming')) q),
  'KLS-00001,KLS-00002', 'my_bookings upcoming: confirmed and processing, not held or cancelled');
select is((select string_agg(ticket_code, ',' order by ticket_code) from bookings.my_bookings('past')),
  'KLS-00004,KLS-00005,KLS-00006', 'my_bookings past: cancelled, attended and no_show');
select is((select event_title from bookings.my_bookings('upcoming') limit 1), 'Future event', 'my_bookings carries the event title');
select throws_ok($$select * from bookings.my_bookings('someday')$$, 'P0001', 'unknown_scope', 'my_bookings rejects an unknown scope');
select throws_ok($$insert into bookings.bookings (event_id, attendee_id, people, ticket_code, contact_name, contact_phone, amount_sen)
                    values ('e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'KLS-77777', 'x', 'y', 0)$$,
  '42501', null, 'clients_cannot_write_bookings_directly');
select throws_ok($$select bookings.mark_confirmed('b0000000-0000-0000-0000-000000000003')$$, '42501', null, 'clients cannot call mark_confirmed');
select throws_ok($$select * from bookings.guest_list('e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_owner', 'guest_list_only_for_event_host');
select is((select count(*)::int from bookings.event_counts(array['e1000000-0000-0000-0000-000000000001']::uuid[])), 0,
  'event_counts returns nothing for events the caller does not host');
reset role;

-- Alice, the host
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select results_eq(
  $$select guest_name, people, status, ticket_code from bookings.guest_list('e1000000-0000-0000-0000-000000000001') order by ticket_code$$,
  $$values ('Bob', 2, 'confirmed', 'KLS-00001'), ('Carol', 1, 'confirmed', 'KLS-00007'), ('Carol', 1, 'attended', 'KLS-00009')$$,
  'guest_list shows paid guests only, not held, processing, cancelled or expired');
select results_eq(
  $$select event_id, paid, checked_in from bookings.event_counts(array['e1000000-0000-0000-0000-000000000001', 'e2000000-0000-0000-0000-000000000002']::uuid[]) order by event_id$$,
  $$values ('e1000000-0000-0000-0000-000000000001'::uuid, 4, 1), ('e2000000-0000-0000-0000-000000000002'::uuid, 1, 1)$$,
  'event_counts counts seats paid and checked in for the host events');
reset role;

-- Carol sees hers, and the host cannot read bookings rows directly
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from bookings.bookings), 3, 'another user sees only their own rows too');
reset role;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from bookings.bookings), 0, 'the host reads guests through guest_list, not the table');
reset role;

select * from finish();
rollback;
