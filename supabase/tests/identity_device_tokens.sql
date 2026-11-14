begin;
select plan(6);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');

select throws_ok($$select identity.register_device_token('t1', 'ios')$$, '28000', 'login_required', 'register_needs_login');
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select identity.register_device_token('tok-a', 'ios');
select identity.register_device_token('tok-a', 'ios');
select throws_ok($$select identity.register_device_token('tok-b', 'web')$$, 'P0001', 'bad_platform', 'bad_platform_refused');
select throws_ok($$select count(*) from identity.device_tokens$$, '42501', null, 'clients_cannot_read_tokens_directly');
reset role;
select is((select count(*)::int from identity.device_tokens where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 1, 'register_twice_keeps_one_row');
-- same device, new user: the token moves
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select identity.register_device_token('tok-a', 'ios');
reset role;
select is((select user_id::text from identity.device_tokens where token = 'tok-a'), 'bbbbbbbb-0000-0000-0000-000000000002', 'token_moves_to_the_latest_user_of_the_device');
select lives_ok($$select shared.send_push('aaaaaaaa-0000-0000-0000-000000000001', 't', 'b', 'receipt', null)$$, 'send_push_never_raises_without_vault_secrets');
select * from finish();
rollback;
