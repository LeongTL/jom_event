begin;
select plan(5);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),  -- host
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com'),    -- another host
  ('00000000-0000-0000-0000-000000000010', 'g10@example.com'),
  ('00000000-0000-0000-0000-000000000011', 'g11@example.com'),
  ('00000000-0000-0000-0000-000000000012', 'g12@example.com');
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy,
                           accept_bookings, area, venue, lat, lng)
values ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Yoga', 'published', 3000, 40,
        now() + interval '1 day', now() + interval '1 day 2 hours', '24h', true, 'Bangsar', 'V', 3.129, 101.671);
insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen) values
  ('b0000000-0000-0000-0000-000000000010', 'e1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000010', 2, 'attended',  'KLS-00010', 'Aina Rahman', '6011', 6000),
  ('b0000000-0000-0000-0000-000000000011', 'e1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000011', 1, 'confirmed', 'KLS-00011', 'Daniel Tan',  '6011', 3000),
  ('b0000000-0000-0000-0000-000000000012', 'e1000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 1, 'cancelled', 'KLS-00012', 'Gone Away',   '6011', 3000);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select results_eq($$select guest_name, people, ticket_code, checked_in from bookings.event_guests('e1000000-0000-0000-0000-000000000001') order by ticket_code$$,
  $$values ('Aina Rahman'::text, 2, 'KLS-00010'::text, true), ('Daniel Tan', 1, 'KLS-00011', false)$$,
  'the host sees paid guests with name, people, code and whether they are checked in; cancelled bookings are left out');
select is((select booking_id from bookings.event_guests('e1000000-0000-0000-0000-000000000001') where ticket_code = 'KLS-00011'),
  'b0000000-0000-0000-0000-000000000011'::uuid, 'each row carries the booking id the manual tick needs');

select set_config('request.jwt.claims', '{"sub":"eeeeeeee-0000-0000-0000-000000000005","role":"authenticated"}', true);
select throws_ok($$select * from bookings.event_guests('e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_owner',
  'another host cannot list the guests');
reset role;
set local role anon;
select throws_ok($$select * from bookings.event_guests('e1000000-0000-0000-0000-000000000001')$$, '42501', null,
  'signed-out visitors cannot list guests');
reset role;
select has_function('bookings', 'event_guests', array['uuid'], 'bookings.event_guests exists');

select * from finish();
rollback;
