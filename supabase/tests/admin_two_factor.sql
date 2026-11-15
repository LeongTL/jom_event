begin;
select plan(19);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001', 'admin@example.com'),
  ('b0000000-0000-0000-0000-000000000001', 'host@example.com'),
  ('c0000000-0000-0000-0000-000000000001', 'guest@example.com');
insert into identity.admins (user_id) values ('a0000000-0000-0000-0000-000000000001');

create function pg_temp.as_(uid text, level text) returns void language sql as $$
  select set_config('request.jwt.claims', '{"sub":"' || uid || '","role":"authenticated","aal":"' || level || '"}', true) $$;

select pg_temp.as_('b0000000-0000-0000-0000-000000000001', 'aal1');
set local role authenticated;
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'bio', 'Mei', 'Maybank', '1', 'SSM1'); end $$;
reset role;
insert into storage.objects (bucket_id, name) values ('payment-qr', 'b0000000-0000-0000-0000-000000000001/qr.png');

-- an admin with a password only (aal1)
select pg_temp.as_('a0000000-0000-0000-0000-000000000001', 'aal1');
set local role authenticated;
select is(identity.is_admin(), true, 'is_admin_stays_true_at_aal1_so_the_screen_can_ask_for_the_code');
select throws_ok($$select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'approve', null)$$, 'P0001', 'mfa_required', 'review_needs_two_factor');
select throws_ok($$select * from identity.pending_hosts()$$, 'P0001', 'mfa_required', 'pending_hosts_needs_two_factor');
select throws_ok($$select * from identity.host_application('b0000000-0000-0000-0000-000000000001')$$, 'P0001', 'mfa_required', 'host_application_needs_two_factor');
select throws_ok($$select * from identity.open_reports()$$, 'P0001', 'mfa_required', 'open_reports_needs_two_factor');
select is((select count(*)::int from storage.objects where bucket_id = 'payment-qr'), 0, 'an_admin_at_aal1_cannot_read_the_qr');

-- an admin with the second factor (aal2)
select pg_temp.as_('a0000000-0000-0000-0000-000000000001', 'aal2');
select is((select count(*)::int from identity.pending_hosts()), 1, 'pending_hosts_works_at_aal2');
select lives_ok($$select * from identity.host_application('b0000000-0000-0000-0000-000000000001')$$, 'host_application_works_at_aal2');
select lives_ok($$select * from identity.open_reports()$$, 'open_reports_works_at_aal2');
select is((select count(*)::int from storage.objects where bucket_id = 'payment-qr'), 1, 'an_admin_at_aal2_can_read_the_qr');
select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'approve', null);
reset role;
select results_eq($$select admin_id, action, target_user_id, (created_at > now() - interval '1 minute') from identity.admin_actions$$,
  $$values ('a0000000-0000-0000-0000-000000000001'::uuid, 'approve', 'b0000000-0000-0000-0000-000000000001'::uuid, true)$$,
  'the_decision_is_logged_with_who_and_when');

-- not an admin, even with aal2
select pg_temp.as_('c0000000-0000-0000-0000-000000000001', 'aal2');
set local role authenticated;
select throws_ok($$select * from identity.pending_hosts()$$, 'P0001', 'not_admin', 'a_plain_user_at_aal2_is_not_an_admin');
select is((select count(*)::int from storage.objects where bucket_id = 'payment-qr'), 0, 'a_plain_user_cannot_read_someone_elses_qr');
select throws_ok($$update identity.admin_actions set reason = 'x'$$, '42501', null, 'the_log_cannot_be_updated');
select throws_ok($$delete from identity.admin_actions$$, '42501', null, 'the_log_cannot_be_deleted');
select throws_ok($$select * from identity.admin_actions$$, '42501', null, 'the_log_is_not_readable_directly');

-- no token level at all (signed in by an old client) counts as aal1
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select throws_ok($$select * from identity.pending_hosts()$$, 'P0001', 'mfa_required', 'a_token_without_a_level_is_refused');
select is(identity.is_admin(), true, 'and_is_admin_still_answers');
reset role;
select is((select count(*)::int from identity.admin_actions), 1, 'still_exactly_one_log_row');
select * from finish();
rollback;
