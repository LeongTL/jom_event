begin;
select plan(7);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com');
-- carol's row is gone (as if sign-up had missed it): saving must still work
delete from identity.notification_prefs where user_id = 'cccccccc-0000-0000-0000-000000000003';

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select lives_ok($$select identity.set_notification_prefs(false, true)$$, 'a signed-in user can save their switches');
select is((select chat from identity.notification_prefs where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), false,
  'the chat switch is saved');
select is((select review_requests from identity.notification_prefs where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), true,
  'the review switch is saved');
select throws_ok($$select identity.set_notification_prefs(null, true)$$, 'P0001', 'prefs_required', 'a switch cannot be left empty');
reset role;

select is((select chat from identity.notification_prefs where user_id = 'bbbbbbbb-0000-0000-0000-000000000002'), true,
  'saving my switches leaves other people untouched');

select set_config('request.jwt.claims', '{"sub":"cccccccc-0000-0000-0000-000000000003","role":"authenticated"}', true);
set local role authenticated;
select identity.set_notification_prefs(false, false);
reset role;
select is((select chat from identity.notification_prefs where user_id = 'cccccccc-0000-0000-0000-000000000003'), false,
  'saving creates the row when it is missing');

set local role anon;
select throws_ok($$select identity.set_notification_prefs(true, true)$$, '42501', null, 'a signed-out visitor cannot save switches');
reset role;

select * from finish();
rollback;
