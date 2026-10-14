begin;
select plan(11);

create temp table cases (n int, status text, hold interval, people int, expected int, label text);
insert into cases values
  (1,  'held',           interval '10 minutes', 1, 1, 'a held booking with a live hold takes its seat'),
  (2,  'held',           interval '-1 minute',  1, 0, 'a held booking whose hold ran out takes no seat'),
  (3,  'payment_failed', interval '5 minutes',  1, 1, 'a failed payment keeps its seat while the hold lasts'),
  (4,  'payment_failed', interval '-1 minute',  1, 0, 'a failed payment frees its seat when the hold ends'),
  (5,  'processing',     interval '-5 minutes', 1, 1, 'a processing booking keeps its seat until the webhook decides'),
  (6,  'confirmed',      null,                  1, 1, 'a confirmed booking takes its seat'),
  (7,  'attended',       null,                  1, 1, 'an attended booking still takes its seat'),
  (8,  'cancelled',      null,                  1, 0, 'a cancelled booking takes no seat'),
  (9,  'expired',        null,                  1, 0, 'an expired booking takes no seat'),
  (10, 'no_show',        null,                  1, 0, 'a no-show takes no seat'),
  (11, 'confirmed',      null,                  2, 2, 'two people take two seats');

insert into bookings.bookings (event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
select ('f0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'bbbbbbbb-0000-0000-0000-000000000002', people, status,
       case when hold is null then null else now() + hold end, 'KLS-' || lpad(n::text, 5, '0'), 'n', 'p', 0
  from cases;

select is(bookings.seats_taken(('f0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid), expected,
          'held_confirmed_processing_count_as_seats_but_expired_cancelled_failed_do_not: ' || label)
  from cases order by n;

select * from finish();
rollback;
