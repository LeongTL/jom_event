begin;
select plan(33);

-- Run the next statements as a signed-in user (call from the superuser: `reset role` first).
create function pg_temp.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a@example.com', '{"full_name":"Mei Tan"}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'b@example.com', '{"full_name":"Bob Lim"}'),
  ('cccccccc-0000-0000-0000-000000000003', 'c@example.com', '{"full_name":"Carol Ng"}'),
  ('dddddddd-0000-0000-0000-000000000004', 'd@example.com', '{"full_name":"Dave Host"}'),
  ('eeeeeeee-0000-0000-0000-000000000005', 'e@example.com', '{"full_name":"Mei Two"}');
insert into identity.hosts (user_id, host_name, area, avatar_url)
  values ('dddddddd-0000-0000-0000-000000000004', 'Studio Dave', 'Bangsar', 'http://x/d.png');

-- sign-up and backfill
select ok((select username ~ '^meitan[0-9]{4}$' from identity.profiles where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'signup_assigns_username');
select is((select count(*)::int from identity.profiles where username is null and name is distinct from 'Deleted user'), 0,
  'backfill_leaves_no_null');

select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');

-- format
select throws_ok($$select identity.set_username('ab')$$, null, 'username_invalid', 'username_too_short_is_invalid');
select throws_ok($$select identity.set_username('abcdefghijklmnopqrstu')$$, null, 'username_invalid', 'username_too_long_is_invalid');
select throws_ok($$select identity.set_username('a b')$$, null, 'username_invalid', 'username_space_is_invalid');
select throws_ok($$select identity.set_username('a-b')$$, null, 'username_invalid', 'username_dash_is_invalid');
select throws_ok($$select identity.set_username('.abc')$$, null, 'username_invalid', 'username_leading_dot_invalid');
select throws_ok($$select identity.set_username('abc.')$$, null, 'username_invalid', 'username_trailing_dot_invalid');
select throws_ok($$select identity.set_username('a..bc')$$, null, 'username_invalid', 'username_double_dot_invalid');
select throws_ok($$select identity.set_username('0123456789')$$, null, 'username_invalid', 'phone_like_username_refused');
select throws_ok($$select identity.set_username('admin')$$, null, 'username_reserved', 'reserved_word_refused');
select throws_ok($$select identity.set_username('Admin')$$, null, 'username_reserved', 'reserved_word_refused_any_case');

-- normalising, own name, uniqueness
select is(identity.set_username('  Mei_Tan '), 'mei_tan', 'set_username_returns_trimmed_lowercase');
select is(identity.set_username('mei_tan'), 'mei_tan', 'own_name_again_is_not_taken');
select is((select username from identity.profiles where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'mei_tan',
  'set_username_saves');

reset role; select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select throws_ok($$select identity.set_username('MEI_TAN')$$, null, 'username_taken', 'uniqueness_is_case_insensitive');
select is(identity.username_available('mei_tan'), false, 'username_available_false_when_taken');
select is(identity.username_available('bob_free'), true, 'username_available_true_when_free');
select is(identity.username_available('ab'), false, 'username_available_false_when_invalid');

reset role; select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select is(identity.username_available('mei_tan'), true, 'username_available_true_for_own_name');
select is(identity.set_username('mei2'), 'mei2', 'changing_username_works');
reset role; select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select is(identity.set_username('mei_tan'), 'mei_tan', 'changing_frees_old_name');
select is(identity.set_username('bob.lim'), 'bob.lim', 'bob_takes_bob_lim');

-- search
reset role; select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select is((select count(*)::int from identity.search_people('b')), 0, 'search_needs_two_chars');
select is((select array_agg(username order by username) from identity.search_people('bo')), array['bob.lim'],
  'search_matches_start_of_username');
select is((select array_agg(username order by username) from identity.search_people('lim')), array['bob.lim'],
  'search_matches_start_of_a_word_in_the_name');
select is((select count(*)::int from identity.search_people('ca')), 0, 'search_excludes_caller');
select is((select count(*)::int from identity.search_people('%%')), 0, 'search_treats_percent_literally');
select ok((select count(*) from identity.search_people('me', 1)) = 1 and (select count(*) from identity.search_people('me')) = 2,
  'search_caps_results');
select ok((select count(*) from identity.search_people('studio') where avatar_url = 'http://x/d.png' and is_host and username like 'davehost%') = 1,
  'search_finds_host_by_host_name_with_avatar');
select is((select array_agg(k order by k) from (select jsonb_object_keys(to_jsonb(r)) k
            from identity.search_people('bo') r limit 5) s), array['avatar_url','is_host','name','user_id','username'],
  'search_returns_only_safe_columns');

reset role;
update identity.profiles set username = null where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select is((select count(*)::int from identity.search_people('bo')), 0, 'search_skips_users_without_username');

-- signed out
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select * from identity.search_people('bo')$$, '42501', null, 'search_needs_login');
reset role;

select * from finish();
rollback;
