begin;
select plan(8);

insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin
  perform identity.apply_host('Mei Studio', 'Bangsar', 'Pottery nights', 'Mei Ling', 'Maybank', '1122334455');
end $$;
reset role;

select is((select is_host from identity.profiles where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), true,
  'apply_host_sets_is_host');
select results_eq(
  $$select host_name, area, bio, ssm_number from identity.hosts where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values ('Mei Studio', 'Bangsar', 'Pottery nights', null::text)$$,
  'apply_host saves the host profile, ssm optional');
select results_eq(
  $$select account_holder, bank, account_number from identity.host_payout_accounts where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values ('Mei Ling', 'Maybank', '1122334455')$$,
  'apply_host saves the payout account');
select is((select verified_at from identity.hosts where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), null,
  'apply_host_keeps_verified_at_null');

-- applying again updates details but never touches verification
update identity.hosts set verified_at = now() where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
set local role authenticated;
do $$ begin
  perform identity.apply_host('Mei Pottery', 'PJ', 'New bio', 'Mei Ling', 'CIMB', '9988776655', 'SSM123');
end $$;
reset role;
select results_eq(
  $$select host_name, area, ssm_number from identity.hosts where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values ('Mei Pottery', 'PJ', 'SSM123')$$,
  'applying again updates the details');
select isnt((select verified_at from identity.hosts where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), null,
  'applying again keeps verified_at');

set local role authenticated;
select throws_ok($$select identity.apply_host('  ', 'PJ', 'bio', 'Mei', 'CIMB', '1')$$,
  'P0001', 'details_required', 'apply_host_requires_a_host_name');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select identity.apply_host('A', 'PJ', 'bio', 'Mei', 'CIMB', '1')$$,
  '42501', null, 'apply_host_requires_login');
reset role;

select * from finish();
rollback;
