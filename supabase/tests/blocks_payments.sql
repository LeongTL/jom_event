begin;
select plan(12);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
update identity.profiles set name = 'Bob Tan' where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
create function pg_temp.as_(uid text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || uid || '","role":"authenticated"}', true) $$;
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'x', 'Mei', 'Maybank', '1'); end $$;
reset role;
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, accept_bookings, area, venue, lat, lng)
values ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'E', 'published', 3000, 5,
  now() + interval '3 days', now() + interval '3 days 2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6);
insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
values ('b0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'processing', 'KLS-00001', 'Bob', '1', 3000);
insert into payments.receipts (id, booking_id, image_path, status, push_count, uploaded_at)
values ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b/a.jpg', 'pending', 3, now() - interval '50 minutes');

create function pg_temp.chat_rows() returns int language sql as $$ select count(*)::int from chat.messages $$;

-- A: the guest blocks the host while a receipt waits. Host actions on the receipt must still work.
select pg_temp.as_('bbbbbbbb-0000-0000-0000-000000000002');
set local role authenticated;
select identity.block_user('aaaaaaaa-0000-0000-0000-000000000001');
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
select lives_ok($$select payments.request_new_receipt('b0000000-0000-0000-0000-000000000001', 'Amount was short')$$,
  'host_can_ask_for_a_new_receipt_even_when_the_guest_blocked_them');
reset role;
select is((select status from bookings.bookings where id = 'b0000000-0000-0000-0000-000000000001'), 'held', 'the_booking_goes_back_to_held_so_the_guest_can_pay_again');
select is((select count(*)::int from chat.messages where body = 'Amount was short'), 1, 'the_ask_again_note_is_stored_in_the_thread');
select is((select count(*)::int from identity.notifications where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and type = 'receipt_requested'), 1,
  'the_guest_still_gets_the_notification_so_is_not_stuck');
select pg_temp.as_('bbbbbbbb-0000-0000-0000-000000000002');
set local role authenticated;
select is((select count(*)::int from chat.my_threads()), 0, 'a_blocked_host_thread_stays_hidden_from_the_guest_inbox');
select throws_ok($$select chat.send_message((select id from chat.threads limit 1), 'hi')$$, null, 'blocked', 'normal_messages_are_still_refused');
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
select throws_ok($$select chat.send_message((select id from chat.threads limit 1), 'hi')$$, null, 'blocked', 'normal_messages_are_refused_both_ways');
reset role;

-- A2: the host accepts a receipt of a guest who blocked them (no chat involved).
update bookings.bookings set status = 'processing' where id = 'b0000000-0000-0000-0000-000000000001';
update payments.receipts set status = 'pending' where id = 'c0000000-0000-0000-0000-000000000001';
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
select lives_ok($$select payments.accept_receipt('c0000000-0000-0000-0000-000000000001')$$, 'host_can_accept_the_receipt_of_a_guest_who_blocked_them');
reset role;

-- B: the host blocks the guest, then the guest's 45 minute reminder comes due. It must not speak to someone who blocked them.
update bookings.bookings set status = 'processing' where id = 'b0000000-0000-0000-0000-000000000001';
update payments.receipts set status = 'pending', chat_reminded = false, push_count = 3, uploaded_at = now() - interval '50 minutes' where id = 'c0000000-0000-0000-0000-000000000001';
select pg_temp.as_('bbbbbbbb-0000-0000-0000-000000000002');
set local role authenticated;
select identity.unblock_user('aaaaaaaa-0000-0000-0000-000000000001');
select pg_temp.as_('aaaaaaaa-0000-0000-0000-000000000001');
select identity.block_user('bbbbbbbb-0000-0000-0000-000000000002');
reset role;
select pg_temp.chat_rows() as before_rows \gset
select lives_ok($$select payments.run_receipt_reminders()$$, 'the_reminder_run_does_not_fail_on_a_blocked_pair');
select is(pg_temp.chat_rows(), :before_rows, 'no_reminder_chat_message_is_posted_to_a_host_who_blocked_the_guest');
select is((select chat_reminded from payments.receipts where id = 'c0000000-0000-0000-0000-000000000001'), true, 'the_reminder_is_still_marked_done_so_it_does_not_loop');
select is(payments.run_receipt_reminders(), 0, 'nothing_more_is_due_after_that');

select * from finish();
rollback;
