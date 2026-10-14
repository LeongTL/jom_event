begin;
select plan(7);

insert into auth.users (id, email, phone, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'mei@example.com', '60123456789', '{"full_name":"Mei Ling"}');

select is((select count(*)::int from identity.profiles
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 1,
  'signup_creates_profile');
select is((select name from identity.profiles
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'Mei Ling',
  'profile takes the name from sign-in metadata');
select is((select phone from identity.profiles
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), '60123456789',
  'profile keeps the phone');
select is((select is_host from identity.profiles
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), false,
  'a new profile is not a host');
select ok((select chat and review_requests from identity.notification_prefs
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'signup_creates_prefs_with_both_switches_on');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin perform identity.update_profile('Mei L', '60111222333'); end $$;
reset role;
select results_eq(
  $$select name, phone from identity.profiles where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'$$,
  $$values ('Mei L', '60111222333')$$,
  'update_profile_changes_own_name_and_phone');

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select identity.update_profile('x', 'y')$$, '42501', null,
  'update_profile_requires_login');
reset role;

select * from finish();
rollback;
