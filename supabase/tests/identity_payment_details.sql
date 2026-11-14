begin;
select plan(8);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin perform identity.apply_host('Mei Studio', 'Bangsar', 'Pottery', 'Mei Ling', 'Maybank', '1122334455'); end $$;

-- qr only
select lives_ok($$select identity.save_payment_details(null, null, null, 'aaaaaaaa-0000-0000-0000-000000000001/qr.jpg')$$, 'qr_only_is_accepted');
select throws_ok($$select identity.save_payment_details('Mei', 'Maybank', null, null)$$, 'P0001', 'payment_details_required', 'partial_bank_without_qr_is_refused');
select throws_ok($$select identity.save_payment_details(null, null, null, null)$$, 'P0001', 'payment_details_required', 'nothing_is_refused');
select lives_ok($$select identity.save_payment_details('Mei Ling', 'CIMB', '999', null)$$, 'bank_only_is_accepted');
select results_eq($$select bank, account_number, duitnow_qr_path from identity.host_payout_accounts where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values ('CIMB', '999', null::text)$$, 'save_overwrites_existing_account');

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select throws_ok($$select identity.save_payment_details('B', 'X', '1', null)$$, 'P0001', 'not_a_host', 'non_host_cannot_save');
select is((select count(*)::int from identity.host_payout_accounts), 0, 'guest_cannot_read_account_row_directly');
reset role;

-- QR file policy: a booked guest reads, a stranger does not
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, accept_bookings, area, venue, lat, lng)
values ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'E', 'published', 3000, 5,
  '2030-01-10 20:00+08', '2030-01-10 22:00+08', '48h', true, 'Bangsar', 'V', 3.1, 101.6);
insert into bookings.bookings (event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
values ('e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'held', now() + interval '1 hour', 'KLS-00001', 'B', '1', 3000);
insert into storage.objects (bucket_id, name, owner) values ('payment-qr', 'aaaaaaaa-0000-0000-0000-000000000001/qr.jpg', 'aaaaaaaa-0000-0000-0000-000000000001');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select set_config('t.bob', (select count(*)::text from storage.objects where bucket_id = 'payment-qr'), true);
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
select set_config('t.carol', (select count(*)::text from storage.objects where bucket_id = 'payment-qr'), true);
reset role;
select is(current_setting('t.bob') || '/' || current_setting('t.carol'), '1/0', 'qr_policy_lets_booked_guest_read_and_stranger_not');

select * from finish();
rollback;
