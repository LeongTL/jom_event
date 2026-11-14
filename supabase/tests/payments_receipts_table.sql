begin;
select plan(7);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, accept_bookings, area, venue, lat, lng)
values ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'E', 'published', 3000, 5,
  '2030-01-10 20:00+08', '2030-01-10 22:00+08', '48h', true, 'Bangsar', 'V', 3.1, 101.6);
insert into bookings.bookings (id, event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen) values
  ('b0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'processing', 'KLS-00001', 'B', '1', 3000),
  ('b0000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 1, 'processing', 'KLS-00002', 'C', '1', 3000);
insert into payments.receipts (booking_id, image_path) values
  ('b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001/a.jpg'),
  ('b0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002/a.jpg');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is((select count(*)::int from payments.receipts), 1, 'attendee_reads_only_own_receipts');
select throws_ok($$insert into payments.receipts (booking_id, image_path) values ('b0000000-0000-0000-0000-000000000001', 'x')$$, '42501', null, 'clients_cannot_insert_rows');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((select count(*)::int from payments.receipts), 0, 'host_cannot_select_receipts_table_directly');
reset role;

select throws_ok($$update payments.receipts set status = 'weird'$$, '23514', null, 'status_check_rejects_unknown_value');

insert into storage.objects (bucket_id, name, owner) values
  ('receipts', 'b0000000-0000-0000-0000-000000000001/a.jpg', 'bbbbbbbb-0000-0000-0000-000000000002');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select lives_ok($$insert into storage.objects (bucket_id, name, owner) values ('receipts', 'b0000000-0000-0000-0000-000000000001/b.jpg', 'bbbbbbbb-0000-0000-0000-000000000002')$$,
  'attendee_can_upload_to_own_booking_folder');
select throws_ok($$insert into storage.objects (bucket_id, name, owner) values ('receipts', 'b0000000-0000-0000-0000-000000000002/b.jpg', 'bbbbbbbb-0000-0000-0000-000000000002')$$,
  '42501', null, 'attendee_cannot_upload_to_other_folder');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is((select count(*)::int from storage.objects where bucket_id = 'receipts'), 2, 'host_can_read_receipt_files_of_own_event');
select * from finish();
rollback;
