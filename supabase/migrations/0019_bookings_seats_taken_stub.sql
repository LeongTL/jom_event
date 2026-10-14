-- STUB until Task 6: replaced there (create or replace, same signature) by the real count of seats in
-- held, processing and confirmed bookings. Until then no event has guests.
create function bookings.seats_taken(event_id uuid) returns int
language sql stable
as $$ select 0 $$;
