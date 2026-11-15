begin;
select plan(4);

select has_index('bookings', 'bookings', 'bookings_event_status_idx', array['event_id', 'status'], 'bookings_by_event_and_status');
select has_index('events', 'events', 'events_listing_idx', array['status', 'starts_at', 'visibility'], 'events_by_status_start_and_visibility');
select has_index('payments', 'receipts', 'receipts_booking_status_idx', array['booking_id', 'status'], 'receipts_by_booking_and_status');
select hasnt_index('payments', 'receipts', 'receipts_booking_idx', 'the_old_booking_only_index_is_covered_by_the_new_one');

select * from finish();
rollback;
