begin;
select plan(14);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
insert into identity.hosts (user_id, host_name, area, bio)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'Mei Studio', 'Bangsar', 'Pottery nights');
insert into identity.host_payout_accounts
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'Mei Ling', 'Maybank', '1122334455');
insert into identity.saved_events (user_id, event_id)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000001');
insert into identity.notifications (user_id, type, title)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'booking', 'You are in');

-- bob sees nothing of alice's
select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from identity.saved_events), 0, 'user_cannot_read_other_users_saved');
select is((select count(*)::int from identity.notifications), 0, 'user_cannot_read_other_users_notifications');
select is((select count(*)::int from identity.host_payout_accounts), 0, 'payout_account_hidden_from_other_users');
reset role;

-- alice sees her own
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*)::int from identity.saved_events), 1, 'owner_reads_own_saved');
select is((select count(*)::int from identity.notifications), 1, 'owner_reads_own_notifications');
select is((select count(*)::int from identity.host_payout_accounts), 1, 'payout_account_readable_only_by_owner');
reset role;

select is(
  (select array_agg(column_name::text order by ordinal_position)
     from information_schema.columns
    where table_schema = 'identity' and table_name = 'host_public'),
  array['user_id','host_name','area','bio','avatar_url','since'],
  'host_public_view_hides_bank_fields');

-- signed-out visitors
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is((select count(*)::int from identity.host_public), 1, 'anon_reads_host_public');
select throws_ok($$select * from identity.host_payout_accounts$$, '42501', null, 'anon_cannot_read_payout_accounts');
select throws_ok($$select * from identity.hosts$$, '42501', null, 'anon_cannot_read_hosts_table_directly');
reset role;

-- signed-in users cannot write these tables directly
select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select throws_ok($$update identity.hosts set verified_at = now()$$, '42501', null,
  'user_cannot_set_verified_at_directly');
select throws_ok($$update identity.profiles set is_host = true$$, '42501', null,
  'user_cannot_set_is_host_directly');
select throws_ok($$insert into identity.notifications (user_id, type, title)
  values ('bbbbbbbb-0000-0000-0000-000000000002', 'booking', 'spam')$$, '42501', null,
  'user_cannot_write_notifications_directly');
select throws_ok($$insert into identity.saved_events (user_id, event_id)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'eeeeeeee-0000-0000-0000-000000000002')$$, '42501', null,
  'user_cannot_write_saved_events_directly');
reset role;

select * from finish();
rollback;
