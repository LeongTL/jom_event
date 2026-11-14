begin;
select plan(25);

create function pg_temp.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a@example.com', '{"full_name":"Ann Lee"}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'b@example.com', '{"full_name":"Bob Lim"}'),
  ('cccccccc-0000-0000-0000-000000000003', 'c@example.com', '{"full_name":"Carol Ng"}'),
  ('dddddddd-0000-0000-0000-000000000004', 'd@example.com', '{"full_name":"Dave Host"}');
insert into identity.hosts (user_id, host_name, area, avatar_url)
  values ('dddddddd-0000-0000-0000-000000000004', 'Studio Dave', 'Bangsar', 'http://x/d.png');

select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select identity.follow('bbbbbbbb-0000-0000-0000-000000000002');
select identity.follow('bbbbbbbb-0000-0000-0000-000000000002');
select identity.follow('dddddddd-0000-0000-0000-000000000004');
select throws_ok($$select identity.follow('aaaaaaaa-0000-0000-0000-000000000001')$$, null, 'cannot_follow_self', 'no_self_follow');
select throws_ok($$select identity.follow('99999999-0000-0000-0000-000000000009')$$, null, 'user_not_found', 'follow_unknown_user_errors');

-- own rows are readable, nobody else's
select is((select count(*)::int from identity.follows), 2, 'follows_table_shows_only_my_own_rows');
reset role;

select is((select count(*)::int from identity.follows where follower_id = 'aaaaaaaa-0000-0000-0000-000000000001'
            and followee_id = 'bbbbbbbb-0000-0000-0000-000000000002'), 1, 'follow_is_idempotent_one_row');
select is((select count(*)::int from identity.notifications where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and type = 'follow'), 1,
  'follow_twice_writes_one_notification');
select results_eq($$select ref_type, ref_id, title from identity.notifications
                     where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and type = 'follow'$$,
  $$values ('user'::text, 'aaaaaaaa-0000-0000-0000-000000000001'::uuid, 'Ann Lee started following you'::text)$$,
  'follow_notification_names_the_follower');
select is((select count(*)::int from identity.notifications where user_id = 'dddddddd-0000-0000-0000-000000000004'
            and title = 'Ann Lee started following you'), 1, 'follow_notifies_a_host_too');

-- counts
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select results_eq($$select followers, following, i_follow from identity.follow_counts('bbbbbbbb-0000-0000-0000-000000000002')$$,
  $$values (1, 0, true)$$, 'counts_for_followee_and_i_follow');
select results_eq($$select followers, following, i_follow from identity.follow_counts('aaaaaaaa-0000-0000-0000-000000000001')$$,
  $$values (0, 2, false)$$, 'counts_for_follower');
reset role; select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select identity.follow('bbbbbbbb-0000-0000-0000-000000000002');
select is((select followers from identity.follow_counts('bbbbbbbb-0000-0000-0000-000000000002')), 2, 'followers_count_grows');

-- lists
select is((select count(*)::int from identity.list_followers('bbbbbbbb-0000-0000-0000-000000000002')), 2, 'list_followers_lists_both_followers');
select results_eq($$select name, avatar_url, is_host from identity.list_following('aaaaaaaa-0000-0000-0000-000000000001', 1, 0)$$,
  $$values ('Studio Dave'::text, 'http://x/d.png'::text, true)$$, 'list_following_newest_first_with_host_avatar');
select is((select count(*)::int from identity.list_following('aaaaaaaa-0000-0000-0000-000000000001', 1, 1)), 1, 'list_offset_pages');
select is((select array_agg(k order by k) from (select jsonb_object_keys(to_jsonb(r)) k
            from identity.list_followers('bbbbbbbb-0000-0000-0000-000000000002', 1, 0) r) s),
  array['avatar_url','is_host','name','user_id','username'], 'lists_return_only_safe_columns');

-- unfollow
reset role; select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select identity.unfollow('bbbbbbbb-0000-0000-0000-000000000002');
select is((select followers from identity.follow_counts('bbbbbbbb-0000-0000-0000-000000000002')), 1, 'unfollow_removes');
select lives_ok($$select identity.unfollow('bbbbbbbb-0000-0000-0000-000000000002')$$, 'unfollow_when_not_following_is_silent');
select is((select followers from identity.follow_counts('bbbbbbbb-0000-0000-0000-000000000002')), 1, 'unfollow_twice_leaves_counts');
select is((select count(*)::int from identity.person('bbbbbbbb-0000-0000-0000-000000000002')), 1, 'person_returns_guest_to_signed_in');
select is((select is_host from identity.person('dddddddd-0000-0000-0000-000000000004')), true, 'person_flags_hosts');

-- signed out
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select identity.follow('bbbbbbbb-0000-0000-0000-000000000002')$$, '42501', null, 'follow_needs_login');
select throws_ok($$select * from identity.list_followers('bbbbbbbb-0000-0000-0000-000000000002')$$, '42501', null, 'lists_need_login');
select results_eq($$select followers, i_follow from identity.follow_counts('bbbbbbbb-0000-0000-0000-000000000002')$$,
  $$values (1, false)$$, 'counts_work_signed_out');
select is((select count(*)::int from identity.person('dddddddd-0000-0000-0000-000000000004')), 1, 'person_shows_hosts_signed_out');
select is((select count(*)::int from identity.person('bbbbbbbb-0000-0000-0000-000000000002')), 0, 'person_hides_guests_signed_out');
reset role;

-- removing people
select identity.erase_user('bbbbbbbb-0000-0000-0000-000000000002');
select results_eq($$select username, (select count(*) from identity.follows where followee_id = p.user_id or follower_id = p.user_id)
                    from identity.profiles p where p.user_id = 'bbbbbbbb-0000-0000-0000-000000000002'$$,
  $$values (null::text, 0::bigint)$$, 'erase_user_clears_username_and_follows');

select * from finish();
rollback;
