begin;
select plan(13);

insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
                                          ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into identity.hosts (user_id, host_name, area) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Alice Studio', 'Bangsar');

insert into events.events (id, host_id, title, description, venue, status, price_sen, capacity, starts_at, ends_at, area, lat, lng,
                           cancel_policy, source_url, accept_bookings) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Paid yoga', 'Stretch', 'Deck 5', 'published', 3000, 10,
   '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 3.1290, 101.6710, '48h', null, true),
  ('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Free jam', 'Bring a mat', 'Park', 'published', 0, 10,
   '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 3.1290, 101.6710, 'none', 'https://instagram.com/p/x', true),
  ('e3000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Secret draft', null, null, 'draft', 3000, 10,
   null, null, null, null, null, '24h', null, true);
update events.events set poster_url = 'https://example.com/p.jpg' where id = 'e1000000-0000-0000-0000-000000000001';
insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen) values
  ('e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'confirmed', 'T-1', 'Bob', '601', 6000),
  ('e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'confirmed', 'T-2', 'Bob', '601', 6000);
insert into reviews.reviews (booking_id, event_id, host_id, attendee_id, stars) values
  (gen_random_uuid(), 'e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 5),
  (gen_random_uuid(), 'e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 4);

set local role anon;
select is((select title from events.event_detail('e1000000-0000-0000-0000-000000000001', 3.1290, 101.6710)), 'Paid yoga', 'a visitor can read a published event');
select is((select spots_left from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), 6, 'spots_left subtracts the seats taken');
select is((select host_name from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), 'Alice Studio', 'it names the host');
select is((select (rating_avg, rating_count)::text from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), '(4.5,2)', 'it carries the host rating');
select is((select round(distance_km::numeric, 1) from events.event_detail('e1000000-0000-0000-0000-000000000001', 3.1290, 101.6710)), 0.0, 'distance is measured from the given point');
select ok((select distance_km is null from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), 'no point, no distance');
select is((select source_url from events.event_detail('e2000000-0000-0000-0000-000000000002', null, null)), 'https://instagram.com/p/x', 'a free event carries its source link');
select is((select count(*)::int from events.event_detail('e3000000-0000-0000-0000-000000000003', null, null)), 0, 'a draft is invisible');
select is((select count(*)::int from events.event_detail(gen_random_uuid(), null, null)), 0, 'an unknown id gives no row');
select is((select going from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), 4, 'going counts people, not bookings');
select is((select host_event_count from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), 2, 'it counts the host''s published events, not the draft');
select is((select poster_url from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), 'https://example.com/p.jpg', 'it carries the poster');
select is((select host_verified from events.event_detail('e1000000-0000-0000-0000-000000000001', null, null)), false, 'an unverified host has no tick');
reset role;

select * from finish();
rollback;
