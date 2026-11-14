begin;
select plan(12);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
update identity.profiles set name = 'Bob Tan' where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'x', 'Mei', 'Maybank', '1'); end $$;
reset role;
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, accept_bookings, area, venue, lat, lng)
values ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'E', 'published', 3000, 5,
  now() + interval '3 days', now() + interval '3 days 2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6),
  ('e2000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Old', 'ended', 3000, 5,
  now() - interval '40 days', now() - interval '40 days' + interval '2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6),
  ('e3000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', 'Recent', 'ended', 3000, 5,
  now() - interval '5 days', now() - interval '5 days' + interval '2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6);
create function pg_temp.bk(n int, ev text, st text) returns void language sql as $$
  insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
  values (('b0000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, ev::uuid, 'bbbbbbbb-0000-0000-0000-000000000002', 1, st, 'KLS-0000' || n, 'Bob', '1', 3000)
$$;
select pg_temp.bk(1, 'e1000000-0000-0000-0000-000000000001', 'processing');
select pg_temp.bk(2, 'e1000000-0000-0000-0000-000000000001', 'expired');
select pg_temp.bk(3, 'e2000000-0000-0000-0000-000000000002', 'confirmed');
select pg_temp.bk(4, 'e3000000-0000-0000-0000-000000000003', 'confirmed');
insert into payments.receipts (id, booking_id, image_path, status, push_count, uploaded_at) values
  ('c0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001/a.jpg', 'pending', 1, now()),
  ('c0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002/a.jpg', 'late', 0, now() - interval '3 hours'),
  ('c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000003/a.jpg', 'accepted', 0, now() - interval '40 days'),
  ('c0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000004/a.jpg', 'accepted', 0, now() - interval '5 days');

create function pg_temp.at(mins int) returns void language sql as $$
  update payments.receipts set uploaded_at = now() - make_interval(mins => mins) where id = 'c0000000-0000-0000-0000-000000000001' $$;
create function pg_temp.reminders() returns int language sql as $$
  select count(*)::int from identity.notifications where type = 'receipt_reminder' $$;
create function pg_temp.chats() returns int language sql as $$ select count(*)::int from chat.messages $$;

select is(payments.run_receipt_reminders(), 0, 'nothing_is_due_right_after_the_upload');
select pg_temp.at(16);
select is(payments.run_receipt_reminders(), 1, 'second_push_is_sent_at_15_minutes');
select is(payments.run_receipt_reminders(), 0, 'a_stage_is_claimed_only_once');
select pg_temp.at(31);
select payments.run_receipt_reminders();
select is(pg_temp.reminders(), 2, 'third_push_is_sent_at_30_minutes');
select is(pg_temp.chats(), 0, 'no_chat_message_before_45_minutes');
select pg_temp.at(46);
select payments.run_receipt_reminders();
select is(pg_temp.chats(), 1, 'chat_message_is_posted_at_45_minutes');
select is((select chat_reminded from payments.receipts where id = 'c0000000-0000-0000-0000-000000000001'), true, 'chat_stage_is_recorded');
select is(payments.run_receipt_reminders(), 0, 'nothing_more_after_the_chat_message');
select is((select count(*)::int from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and ref_id = 'c0000000-0000-0000-0000-000000000002'), 0,
  'late_receipts_get_no_reminders');

-- a decided receipt is never reminded
update payments.receipts set push_count = 1, chat_reminded = false, status = 'accepted' where id = 'c0000000-0000-0000-0000-000000000001';
select is(payments.run_receipt_reminders(), 0, 'nothing_after_accept');

-- purge
select is((select string_agg(right(image_path, 7), ',') from payments.claim_expired_receipt_files()), '3/a.jpg', 'purge_claims_only_receipts_30_days_after_event_end');
select is((select count(*)::int from payments.receipts), 4, 'purge_leaves_the_rows');
select * from finish();
rollback;
