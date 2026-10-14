begin;
select plan(3);

insert into events.events (host_id, title, starts_at, ends_at, price_sen, lat, lng, status, capacity, area, venue)
values ('aaaaaaaa-0000-0000-0000-000000000001', 'spots', '2027-03-01 11:00+08', '2027-03-01 12:00+08', 3000,
        3.1290, 101.6710, 'published', 10, 'Bangsar', 'V');

-- Sells seats through real bookings (postgres only): n seats as bookings of two people.
create function pg_temp.sell(eid uuid, n int) returns void language sql as $$
  insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  select eid, 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'confirmed', 'T-' || gen_random_uuid()::text, 'Guest', '601', 0
    from generate_series(1, n / 2) g
$$;

select is((select spots_left from events.feed('now', 3.1290, 101.6710, 5, '2027-03-01 10:00+08')), 10, 'spots_left is the capacity when nothing is sold');
select pg_temp.sell((select id from events.events where title = 'spots'), 4);
select is((select spots_left from events.feed('now', 3.1290, 101.6710, 5, '2027-03-01 10:00+08')), 6, 'spots_left subtracts the seats taken');
select pg_temp.sell((select id from events.events where title = 'spots'), 8);
select is((select spots_left from events.feed('now', 3.1290, 101.6710, 5, '2027-03-01 10:00+08')), 0, 'spots_left never goes below zero');

select * from finish();
rollback;
