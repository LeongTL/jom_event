begin;
select plan(8);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com'),
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com');
update identity.notification_prefs set chat = false, review_requests = false
 where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';

do $$ begin
  perform identity.notify('aaaaaaaa-0000-0000-0000-000000000001', 'chat_message', 'thread', gen_random_uuid(), 'New message', 'hi');
  perform identity.notify('aaaaaaaa-0000-0000-0000-000000000001', 'review_request', 'booking', gen_random_uuid(), 'How was it?', 'Leave a review');
  perform identity.notify('aaaaaaaa-0000-0000-0000-000000000001', 'payment', 'booking', gen_random_uuid(), 'Payment received', 'RM 30');
  perform identity.notify('bbbbbbbb-0000-0000-0000-000000000002', 'chat_message', 'thread', gen_random_uuid(), 'New message', 'hi');
end $$;

select is((select count(*)::int from identity.notifications
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'chat_message'), 0,
  'notify_skips_chat_type_when_pref_off');
select is((select count(*)::int from identity.notifications
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'review_request'), 0,
  'notify_skips_review_request_when_pref_off');
select is((select count(*)::int from identity.notifications
            where user_id = 'aaaaaaaa-0000-0000-0000-000000000001' and type = 'payment'), 1,
  'notify_still_writes_payment_type_when_chat_pref_off');
select is((select count(*)::int from identity.notifications
            where user_id = 'bbbbbbbb-0000-0000-0000-000000000002' and type = 'chat_message'), 1,
  'notify_writes_chat_type_when_pref_on');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$select identity.notify('bbbbbbbb-0000-0000-0000-000000000002', 'payment', null, null, 'x', 'y')$$,
  '42501', null, 'notify_is_not_callable_by_clients');
reset role;

-- mark_read and unread_count only touch the caller's own rows
insert into identity.notifications (id, user_id, type, title) values
  ('11111111-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000003', 'booking', 'one'),
  ('11111111-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000003', 'booking', 'two'),
  ('11111111-0000-0000-0000-000000000003', 'dddddddd-0000-0000-0000-000000000004', 'booking', 'three');

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select is(identity.unread_count(), 2, 'unread_count counts my unread');
do $$ begin
  perform identity.mark_read(array['11111111-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000003']::uuid[]);
end $$;
select is(identity.unread_count(), 1, 'mark_read marks mine and the badge drops');
reset role;
select is((select read_at is null from identity.notifications
            where id = '11111111-0000-0000-0000-000000000003'), true,
  'mark_read_ignores_other_users_notifications');

select * from finish();
rollback;
