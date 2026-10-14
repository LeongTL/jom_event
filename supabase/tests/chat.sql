begin;
select plan(51);

insert into auth.users (id, email, raw_user_meta_data) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com', '{"full_name":"Alice Owner"}'),  -- host "Mei Studio"
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com',   '{"full_name":"Bob Tan"}'),      -- guest
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com', '{"full_name":"Carol Lim"}'),    -- guest
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com',  '{"full_name":"Dave Host"}');    -- another host
update identity.profiles set is_host = true where user_id in ('aaaaaaaa-0000-0000-0000-000000000001', 'dddddddd-0000-0000-0000-000000000004');
insert into identity.hosts (user_id, host_name, area, avatar_url) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Mei Studio', 'Bangsar', 'https://img/mei.png'),
  ('dddddddd-0000-0000-0000-000000000004', 'Dave Runs', 'PJ', null);
insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, area, venue) values
  ('e1000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Pottery night', 'published', 3000, 10, '2030-01-10 20:00+08', '2030-01-10 22:00+08', 'Bangsar', 'V'),
  ('e2000000-0000-0000-0000-000000000002', 'dddddddd-0000-0000-0000-000000000004', 'Sunrise run', 'published', 0, 10, '2030-01-11 06:00+08', '2030-01-11 07:00+08', 'PJ', 'V');

-- threads
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.th1', chat.open_thread('aaaaaaaa-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001')::text, true);
select set_config('t.th1b', chat.open_thread('aaaaaaaa-0000-0000-0000-000000000001')::text, true);
select is(current_setting('t.th1b')::uuid, current_setting('t.th1')::uuid, 'open_thread_twice_returns_same_thread');
select throws_ok($$select chat.open_thread(gen_random_uuid())$$, 'P0001', 'not_a_host', 'you can only open a thread with a host (unknown user)');
select throws_ok($$select chat.open_thread('cccccccc-0000-0000-0000-000000000003')$$, 'P0001', 'not_a_host', 'a plain guest is not a host');
select throws_ok($$select chat.open_thread('dddddddd-0000-0000-0000-000000000004', 'e1000000-0000-0000-0000-000000000001')$$, 'P0001', 'event_host_mismatch',
  'the event must belong to that host');
select throws_ok($$select chat.open_thread('dddddddd-0000-0000-0000-000000000004', gen_random_uuid())$$, 'P0001', 'event_not_found', 'and exist');
reset role;
select is((select event_id from chat.threads where id = current_setting('t.th1')::uuid), 'e1000000-0000-0000-0000-000000000001'::uuid,
  'guest_can_message_host_without_booking: the thread remembers the event it started from');
select is((select count(*)::int from chat.threads), 1, 'asking twice made one thread');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select chat.open_thread('aaaaaaaa-0000-0000-0000-000000000001')$$, 'P0001', 'cannot_message_self', 'host_cannot_open_thread_with_self');
reset role;
set local role authenticated;
select set_config('request.jwt.claims', '', true);
select throws_ok($$select chat.open_thread('aaaaaaaa-0000-0000-0000-000000000001')$$, '28000', 'login_required', 'open_thread_requires_login');
reset role;
set local role anon;
select throws_ok($$select chat.open_thread('aaaaaaaa-0000-0000-0000-000000000001')$$, '42501', null, 'signed-out visitors cannot call open_thread');
select throws_ok($$select * from chat.messages$$, '42501', null, 'nor read messages');
reset role;

-- the same guest and host can also start a thread the other way round
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.th3', chat.open_thread('dddddddd-0000-0000-0000-000000000004')::text, true);
reset role;
select isnt(current_setting('t.th3'), current_setting('t.th1'), 'a host chatting as a guest of another host gets a separate thread');

-- sending
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.m1', (chat.send_message(current_setting('t.th1')::uuid, '  Is it beginner friendly?  ')).id::text, true);
reset role;
select results_eq($$select thread_id, sender_id, body from chat.messages where id = current_setting('t.m1')::uuid$$,
  $$values (current_setting('t.th1')::uuid, 'bbbbbbbb-0000-0000-0000-000000000002'::uuid, 'Is it beginner friendly?')$$, 'a message is stored trimmed');
select is((select last_message_at from chat.threads where id = current_setting('t.th1')::uuid), (select created_at from chat.messages where id = current_setting('t.m1')::uuid),
  'the thread''s last_message_at follows the message');

-- the contact filter
set local role authenticated;
select throws_ok(format($f$select chat.send_message(%L, %L)$f$, current_setting('t.th1'), c), 'P0001', 'contact_info_not_allowed', 'send_rejects: ' || c)
  from unnest(array['0123456789', '012-345 6789', '0 1 2 3 4 5 6 7 8 9', '+60 12 345 6789', 'wa.me/60123456789', 'whatsapp me',
                    '@mei.studio', 'ig: meistudio', 'zero one two three four five six seven eight']) c;
select lives_ok(format($f$select chat.send_message(%L, %L)$f$, current_setting('t.th1'), c), 'send_accepts: ' || c)
  from unnest(array['see you at 9:00', 'RM30 for 2 people', 'Jalan Telawi 3']) c;
select throws_ok(format($f$select chat.send_message(%L, %L)$f$, current_setting('t.th1'), repeat('a', 1001)), 'P0001', 'message_too_long', 'send_over_1000_chars_raises');
select lives_ok(format($f$select chat.send_message(%L, %L)$f$, current_setting('t.th1'), repeat('a', 1000)), 'exactly 1000 characters is fine');
select throws_ok(format($f$select chat.send_message(%L, %L)$f$, current_setting('t.th1'), '   '), 'P0001', 'message_empty', 'a blank message raises');
reset role;

-- who can see and send
select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format($f$select chat.send_message(%L, 'hello')$f$, current_setting('t.th1')), 'P0001', 'not_participant', 'only_the_two_participants_can_send');
select throws_ok(format($f$select chat.mark_thread_read(%L)$f$, current_setting('t.th1')), 'P0001', 'not_participant', 'or mark read');
select is((select count(*)::int from chat.messages), 0, 'and read: a third person sees no messages');
select is((select count(*)::int from chat.threads), 0, 'and no threads');
select is((select count(*)::int from chat.my_threads()), 0, 'my_threads is empty for them');
reset role;
select set_config('request.jwt.claims', '{"sub":"dddddddd-0000-0000-0000-000000000004","role":"authenticated"}', true);
set local role authenticated;
select throws_ok(format($f$select chat.send_message(%L, 'hello')$f$, current_setting('t.th1')), 'P0001', 'not_participant', 'another host cannot send into the thread');
select is((select count(*)::int from chat.messages), 0, 'or read it');
reset role;
set local role authenticated;
select throws_ok($$insert into chat.messages (thread_id, sender_id, body) values (gen_random_uuid(), gen_random_uuid(), 'x')$$, '42501', null, 'clients cannot write messages directly');
select throws_ok($$update chat.threads set host_id = gen_random_uuid()$$, '42501', null, 'or edit threads');
reset role;

-- notifications and unread
select is((select count(*)::int from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'chat_message'), 5,
  'send_notifies_other_side: the host got a notice for each message that went through');
select results_eq($$select title, ref_type, ref_id from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'chat_message' order by created_at limit 1$$,
  $$values ('Bob Tan', 'thread', current_setting('t.th1')::uuid)$$, 'the notice names the sender and points at the thread');
select is((select count(*)::int from identity.notifications where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and type = 'chat_message'), 0,
  'the sender is not notified of their own message');

update identity.notification_prefs set chat = false where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select chat.send_message(current_setting('t.th1')::uuid, 'one more question');
reset role;
select is((select count(*)::int from identity.notifications where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'chat_message'), 5,
  'no notice when the host turned chat notices off (the message still arrives)');
update identity.notification_prefs set chat = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';

-- inbox
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select results_eq($$select other_name, last_body, unread, event_title from chat.my_threads() where thread_id = current_setting('t.th1')::uuid$$,
  $$values ('Bob Tan'::text, 'one more question'::text, true, 'Pottery night'::text)$$, 'host inbox: guest name, last message, unread, event');
select is(chat.unread_total(), 1, 'one thread has unread messages');
select is((select count(*)::int from chat.my_threads()), 1, 'a thread with no messages is not listed');
select chat.mark_thread_read(current_setting('t.th1')::uuid);
select is((select unread from chat.my_threads() where thread_id = current_setting('t.th1')::uuid), false, 'unread_flags_clear_after_mark_read');
select is(chat.unread_total(), 0, 'the badge count drops to 0');
reset role;

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select results_eq($$select other_name, other_avatar, unread from chat.my_threads()$$,
  $$values ('Mei Studio'::text, 'https://img/mei.png'::text, false)$$, 'guest inbox: the host''s name and avatar; their own messages are never unread');
reset role;

-- a new message from the host makes it unread for the guest again
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select chat.send_message(current_setting('t.th1')::uuid, 'Yes, beginners welcome');
reset role;
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is(chat.unread_total(), 1, 'a reply makes the thread unread for the guest');
select is((select count(*)::int from chat.messages where thread_id = current_setting('t.th1')::uuid), 7, 'the guest reads the whole conversation (7 messages)');
reset role;

-- realtime
select is((select count(*)::int from pg_publication_tables where pubname = 'supabase_realtime'
            and ((schemaname = 'chat' and tablename = 'messages') or (schemaname = 'identity' and tablename = 'notifications'))), 2,
  'realtime is enabled on chat.messages and identity.notifications');

select * from finish();
rollback;
