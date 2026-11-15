begin;
select plan(10);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select status from identity.my_host_status()), 'none', 'no application is none');
do $$ begin perform identity.apply_host('Mei', 'Bangsar', 'x', 'Mei', 'Maybank', '1'); end $$;
select is((select status from identity.my_host_status()), 'pending', 'apply creates a pending host');
reset role;
select is((select is_host from identity.profiles where user_id = 'aaaaaaaa-0000-0000-0000-000000000001'), false,
  'apply does not make a host');
select is(identity.is_host('aaaaaaaa-0000-0000-0000-000000000001'), false, 'is_host stays false until approval');

-- an approved host who applies again stays approved
update identity.hosts set status = 'approved' where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
update identity.profiles set is_host = true where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
set local role authenticated;
do $$ begin perform identity.apply_host('Mei 2', 'PJ', 'y', 'Mei', 'CIMB', '2'); end $$;
select is((select status from identity.my_host_status()), 'approved', 'applying again keeps an approved host approved');
reset role;
select is(identity.is_host('aaaaaaaa-0000-0000-0000-000000000001'), true, 'and still a host');

-- a rejected user sees the reason and can apply again
update identity.hosts set status = 'rejected', reject_reason = 'Add a real photo' where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
update identity.profiles set is_host = false where user_id = 'aaaaaaaa-0000-0000-0000-000000000001';
set local role authenticated;
select results_eq($$select status, reason from identity.my_host_status()$$, $$values ('rejected', 'Add a real photo')$$,
  'a rejected user sees the reason');
do $$ begin perform identity.apply_host('Mei 3', 'PJ', 'z', 'Mei', 'CIMB', '3'); end $$;
select results_eq($$select status, reason from identity.my_host_status()$$, $$values ('pending', null)$$,
  'applying again after a rejection is pending, reason cleared');
reset role;

-- signed out
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is((select status from identity.my_host_status()), 'none', 'signed out is none, not an error');
reset role;

-- a host row from before the migration is approved (the backfill)
select is((select count(*)::int from identity.hosts h join identity.profiles p using (user_id)
            where p.is_host and h.status <> 'approved'), 0, 'every host with is_host is approved');

select * from finish();
rollback;
