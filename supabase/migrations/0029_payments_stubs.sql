-- STUBS until Task 7 replaces them (create or replace, same signatures) with the real payments logic.
-- bookings.cancel_booking and bookings.guest_list already call these.
create function payments.refund_booking(p_booking_id uuid, p_reason text) returns void
language plpgsql
as $$ begin null; end $$;

create function payments.paid_method(p_booking_id uuid) returns text
language sql stable
as $$ select null::text $$;
