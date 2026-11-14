begin;
select plan(2);
insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
select vault.create_secret('http://example.invalid/functions/v1', 'functions_url');
select vault.create_secret('k', 'service_role_key');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'x', 'Mei', 'Maybank', '1'); end $$;
select identity.register_device_token('tok-host', 'ios');
reset role;
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, cancel_policy, accept_bookings, area, venue, lat, lng)
values ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'E', 'published', 3000, 5,
  now() + interval '3 days', now() + interval '3 days 2 hours', '48h', true, 'Bangsar', 'V', 3.1, 101.6);
insert into bookings.bookings (id, event_id, attendee_id, people, status, hold_expires_at, ticket_code, contact_name, contact_phone, amount_sen)
values ('b0000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, 'held', now() + interval '1 hour', 'KLS-00001', 'Bob', '1', 3000);
select count(*) as before_count from net.http_request_queue \gset
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select payments.submit_receipt('b0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001/a.jpg');
reset role;
select is((select count(*)::int from net.http_request_queue) - :before_count, 1, 'submit_pushes_host_once_when_tokens_exist');
select is((select count(*)::int from net.http_request_queue where url like '%/send-push') > 0, true, 'push_goes_to_send_push');
select * from finish();
rollback;
