-- Indexes for the 1000 user load run (the k6 scripts in tools/loadtest). Checked against the local database;
-- re-measure on the hosted project before adding more. identity.profiles (lower(username)) and
-- identity.follows (followee_id, ...) already have indexes.
create index bookings_event_status_idx on bookings.bookings (event_id, status);
create index events_listing_idx on events.events (status, starts_at, visibility);
create index receipts_booking_status_idx on payments.receipts (booking_id, status);
drop index payments.receipts_booking_idx;
