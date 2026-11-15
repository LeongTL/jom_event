begin;
select plan(22);

insert into auth.users (id, email) values
  ('a0000000-0000-0000-0000-000000000001', 'admin1@example.com'),
  ('a0000000-0000-0000-0000-000000000002', 'admin2@example.com'),
  ('b0000000-0000-0000-0000-000000000001', 'host@example.com'),
  ('c0000000-0000-0000-0000-000000000001', 'guest@example.com');
insert into identity.admins (user_id) values ('a0000000-0000-0000-0000-000000000001'), ('a0000000-0000-0000-0000-000000000002');

-- the host applies
select set_config('request.jwt.claims', '{"sub":"b0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'bio', 'Mei', 'Maybank', '1', 'SSM1'); end $$;
select is(identity.is_admin(), false, 'a host is not an admin');

-- a non-admin cannot review, list or read applications
select throws_ok($$select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'approve', null)$$, 'P0001', 'not_admin', 'non-admin cannot review');
select throws_ok($$select * from identity.pending_hosts()$$, 'P0001', 'not_admin', 'non-admin cannot list pending');
select throws_ok($$select * from identity.host_application('b0000000-0000-0000-0000-000000000001')$$, 'P0001', 'not_admin', 'non-admin cannot read an application');
select throws_ok($$insert into identity.admins (user_id) values ('c0000000-0000-0000-0000-000000000001')$$, '42501', null, 'nobody inserts an admin from the app');
select throws_ok($$insert into identity.admin_actions (admin_id, action, target_user_id) values ('c0000000-0000-0000-0000-000000000001', 'approve', 'c0000000-0000-0000-0000-000000000001')$$, '42501', null, 'nobody writes the log');

-- an admin
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
select is(identity.is_admin(), true, 'an admin is an admin');
select is((select count(*)::int from identity.pending_hosts()), 1, 'one application is waiting');
select results_eq($$select host_name, ssm_number, account_holder, status from identity.host_application('b0000000-0000-0000-0000-000000000001')$$,
  $$values ('Mei', 'SSM1', 'Mei', 'pending')$$, 'the admin reads the application');
select throws_ok($$select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'reject', '  ')$$, 'P0001', 'reason_required', 'a rejection needs a reason');
select throws_ok($$select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'wat', null)$$, 'P0001', 'bad_decision', 'an unknown decision is refused');
select throws_ok($$select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'suspend', 'x')$$, 'P0001', 'bad_state', 'cannot suspend a pending host');

-- reject, then the host applies again, then approve
select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'reject', 'Add a real photo');
reset role;
select results_eq($$select status, reject_reason, reviewed_by from identity.hosts where user_id = 'b0000000-0000-0000-0000-000000000001'$$,
  $$values ('rejected', 'Add a real photo', 'a0000000-0000-0000-0000-000000000001'::uuid)$$, 'reject records status, reason and who');
select is((select count(*)::int from identity.notifications where user_id = 'b0000000-0000-0000-0000-000000000001' and type = 'host_rejected'), 1, 'the host is told about the rejection');

select set_config('request.jwt.claims', '{"sub":"b0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'bio', 'Mei', 'Maybank', '1'); end $$;
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}', true);
select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'approve', null);
reset role;
select results_eq($$select h.status, p.is_host, h.reviewed_by from identity.hosts h join identity.profiles p using (user_id) where h.user_id = 'b0000000-0000-0000-0000-000000000001'$$,
  $$values ('approved', true, 'a0000000-0000-0000-0000-000000000002'::uuid)$$, 'a second admin approves: status, is_host and who');
select is((select count(*)::int from identity.notifications where user_id = 'b0000000-0000-0000-0000-000000000001' and type = 'host_approved'), 1, 'the host is told about the approval');
select is((select count(*)::int from identity.notifications where user_id = 'b0000000-0000-0000-0000-000000000001' and (body like '%a0000000%' or body like '%admin%')), 0, 'the notice does not name the admin');

-- suspend blocks creating events, unsuspend restores
select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'suspend', 'Complaint');
reset role;
select is(identity.is_host('b0000000-0000-0000-0000-000000000001'), false, 'suspend removes is_host');
select identity.admin_review_host('b0000000-0000-0000-0000-000000000001', 'unsuspend', null) from (select set_config('request.jwt.claims', '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}', true)) x;
select is(identity.is_host('b0000000-0000-0000-0000-000000000001'), true, 'unsuspend restores is_host');

-- the log: who, what, when; nobody edits it
select results_eq($$select action, admin_id from identity.admin_actions where target_user_id = 'b0000000-0000-0000-0000-000000000001' order by action$$,
  $$values ('approve', 'a0000000-0000-0000-0000-000000000002'::uuid), ('reject', 'a0000000-0000-0000-0000-000000000001'::uuid),
           ('suspend', 'a0000000-0000-0000-0000-000000000001'::uuid), ('unsuspend', 'a0000000-0000-0000-0000-000000000001'::uuid)$$,
  'every decision is logged with its admin');
select is((select count(*)::int from identity.admin_actions where created_at is null), 0, 'and when');
set local role authenticated;
select throws_ok($$update identity.admin_actions set action = 'x'$$, '42501', null, 'the log cannot be updated');

select * from finish();
rollback;
