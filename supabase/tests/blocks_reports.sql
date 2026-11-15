begin;
select plan(34);

create function pg_temp.as_user(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end $$;

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a@example.com', '{"full_name":"Ann Lee"}'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'b@example.com', '{"full_name":"Bobby Lim"}'),
  ('cccccccc-0000-0000-0000-000000000003', 'c@example.com', '{"full_name":"Carol Ng"}'),
  ('dddddddd-0000-0000-0000-000000000004', 'd@example.com', '{"full_name":"Dave Host"}'),
  ('eeeeeeee-0000-0000-0000-000000000005', 'e@example.com', '{"full_name":"Eve Admin"}');
update identity.profiles set username = 'ann' where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
update identity.profiles set username = 'bobby' where user_id = 'bbbbbbbb-0000-0000-0000-000000000002';
update identity.profiles set username = 'carol' where user_id = 'cccccccc-0000-0000-0000-000000000003';
update identity.profiles set username = 'davehost', is_host = true where user_id = 'dddddddd-0000-0000-0000-000000000004';
insert into identity.hosts (user_id, host_name, area, status) values
  ('dddddddd-0000-0000-0000-000000000004', 'Dave Runs', 'PJ', 'approved');
insert into identity.admins (user_id) values ('eeeeeeee-0000-0000-0000-000000000005');
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue) values
  ('e1000000-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000004', 'Sunrise run', 'published', 0, 10,
   '2030-01-11 06:00+08', '2030-01-11 07:00+08', 'PJ', 'V');

-- Ann follows Bobby and Bobby follows Ann; Ann and Bobby have a thread with Dave? no: Ann (guest) talks to Dave (host)
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select identity.follow('bbbbbbbb-0000-0000-0000-000000000002');
select set_config('t.th', chat.open_thread('dddddddd-0000-0000-0000-000000000004')::text, true);
select chat.send_message(current_setting('t.th')::uuid, 'hello host');
select set_config('t.msg', (select m.id::text from chat.messages m where m.thread_id = current_setting('t.th')::uuid limit 1), true);
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select identity.follow('aaaaaaaa-0000-0000-0000-000000000001');

-- block
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select identity.block_user('bbbbbbbb-0000-0000-0000-000000000002');
select identity.block_user('bbbbbbbb-0000-0000-0000-000000000002');
select throws_ok($$select identity.block_user('aaaaaaaa-0000-0000-0000-000000000001')$$, null, 'cannot_block_self', 'no_self_block');
select throws_ok($$select identity.block_user('99999999-0000-0000-0000-000000000009')$$, null, 'user_not_found', 'block_unknown_user');
select is((select count(*)::int from identity.blocks), 1, 'blocking_twice_is_one_row');
select results_eq($$select user_id, username from identity.my_blocks()$$,
  $$values ('bbbbbbbb-0000-0000-0000-000000000002'::uuid, 'bobby'::text)$$, 'my_blocks_lists_who_i_blocked');

-- search and follow, both ways
select is((select count(*)::int from identity.search_people('bobby')), 0, 'blocker_does_not_find_the_blocked');
select throws_ok($$select identity.follow('bbbbbbbb-0000-0000-0000-000000000002')$$, null, 'blocked', 'blocker_cannot_follow_blocked');
select pg_temp.as_user('bbbbbbbb-0000-0000-0000-000000000002');
select is((select count(*)::int from identity.search_people('ann')), 0, 'blocked_does_not_find_the_blocker');
select throws_ok($$select identity.follow('aaaaaaaa-0000-0000-0000-000000000001')$$, null, 'blocked', 'blocked_cannot_follow_blocker');
select is((select count(*)::int from identity.blocks), 0, 'blocks_are_invisible_to_the_blocked');
select is((select count(*)::int from identity.my_blocks()), 0, 'my_blocks_does_not_show_who_blocked_me');
reset role;
select is((select count(*)::int from identity.follows where (follower_id, followee_id) in
  (('aaaaaaaa-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000002'),
   ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001'))), 0, 'block_removes_follows_both_ways');

-- chat: Ann blocks the host Dave
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select is((select count(*)::int from chat.my_threads()), 1, 'thread_visible_before_blocking_the_host');
select identity.block_user('dddddddd-0000-0000-0000-000000000004');
select is((select count(*)::int from chat.my_threads()), 0, 'thread_hidden_from_the_blocker');
select throws_ok($$select chat.send_message(current_setting('t.th')::uuid, 'still there?')$$, null, 'blocked', 'blocker_cannot_send');
select throws_ok($$select chat.open_thread('dddddddd-0000-0000-0000-000000000004')$$, null, 'blocked', 'blocker_cannot_open_thread');
select pg_temp.as_user('dddddddd-0000-0000-0000-000000000004');
select is((select count(*)::int from chat.my_threads()), 0, 'thread_hidden_from_the_blocked_too');
select throws_ok($$select chat.send_message(current_setting('t.th')::uuid, 'hi again')$$, null, 'blocked', 'blocked_cannot_send');

-- unblock
select pg_temp.as_user('aaaaaaaa-0000-0000-0000-000000000001');
select identity.unblock_user('dddddddd-0000-0000-0000-000000000004');
select identity.unblock_user('bbbbbbbb-0000-0000-0000-000000000002');
select is((select count(*)::int from identity.my_blocks()), 0, 'unblock_empties_the_list');
select is((select count(*)::int from identity.search_people('bobby')), 1, 'unblock_restores_search');
select lives_ok($$select identity.follow('bbbbbbbb-0000-0000-0000-000000000002')$$, 'unblock_allows_following_again');
select is((select count(*)::int from chat.my_threads()), 1, 'unblock_restores_the_thread');
select lives_ok($$select chat.send_message(current_setting('t.th')::uuid, 'back again')$$, 'unblock_allows_messaging');
select lives_ok($$select identity.unblock_user('bbbbbbbb-0000-0000-0000-000000000002')$$, 'unblock_when_not_blocked_is_fine');

-- reports
select lives_ok($$select identity.report('user', 'cccccccc-0000-0000-0000-000000000003', 'spam', 'sells things')$$, 'report_a_person');
select lives_ok($$select identity.report('event', 'e1000000-0000-0000-0000-000000000001', 'fake_event', null)$$, 'report_an_event');
select lives_ok($$select identity.report('message', current_setting('t.msg')::uuid, 'harassment', null)$$, 'report_a_message_in_my_thread');
select throws_ok($$select identity.report('chat', 'cccccccc-0000-0000-0000-000000000003', 'spam', null)$$, null, 'bad_target', 'bad_target_type');
select throws_ok($$select identity.report('user', 'cccccccc-0000-0000-0000-000000000003', 'rude', null)$$, null, 'bad_reason', 'bad_reason');
select throws_ok($$select identity.report('event', '99999999-0000-0000-0000-000000000009', 'spam', null)$$, null, 'event_not_found', 'report_missing_event');
select pg_temp.as_user('cccccccc-0000-0000-0000-000000000003');
select throws_ok($$select identity.report('message', current_setting('t.msg')::uuid, 'spam', null)$$, null, 'not_participant', 'message_report_needs_a_participant');
select throws_ok($$select count(*) from identity.reports$$, '42501', null, 'reports_are_not_readable_by_users');
select throws_ok($$select * from identity.open_reports()$$, null, 'not_admin', 'open_reports_needs_an_admin');
select pg_temp.as_user('eeeeeeee-0000-0000-0000-000000000005');
select is((select count(*)::int from identity.open_reports()), 3, 'an_admin_sees_the_reports');
reset role;
select is((select status from identity.reports order by created_at limit 1), 'open', 'reports_start_open');

select * from finish();
rollback;
