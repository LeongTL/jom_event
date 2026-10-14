begin;
select plan(3);

insert into events.events (host_id, title, starts_at, ends_at, price_sen, lat, lng, status, capacity, area, venue)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'spots', '2027-03-01 11:00+08', '2027-03-01 12:00+08', 3000,
        3.1290, 101.6710, 'published', 10, 'Bangsar', 'V');

-- STUB until Task 6 defines the real bookings.seats_taken: delete these two lines then, and sell seats
-- through real bookings instead.
create or replace function bookings.seats_taken(event_id uuid) returns int language sql
  as $$ select coalesce(nullif(current_setting('test.seats', true), '')::int, 0) $$;

select is((select spots_left from events.feed('now', 3.1290, 101.6710, 5, '2027-03-01 10:00+08')), 10, 'spots_left is the capacity when nothing is sold');
select set_config('test.seats', '4', true);
select is((select spots_left from events.feed('now', 3.1290, 101.6710, 5, '2027-03-01 10:00+08')), 6, 'spots_left subtracts the seats taken');
select set_config('test.seats', '12', true);
select is((select spots_left from events.feed('now', 3.1290, 101.6710, 5, '2027-03-01 10:00+08')), 0, 'spots_left never goes below zero');

select * from finish();
rollback;
