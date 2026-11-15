begin;
select plan(5);

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select is((select value from app.get_flags() where key = 'host_entry_enabled'), 'true'::jsonb, 'anon reads the host entrance flag, on by default');
reset role;

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;
select is((select value from app.get_flags() where key = 'host_entry_enabled'), 'true'::jsonb, 'a signed-in user reads it too');
select throws_ok($$update app.flags set value = 'false'$$, '42501', null, 'the app cannot change a flag');
select throws_ok($$insert into app.flags (key, value) values ('x', 'true')$$, '42501', null, 'or add one');
reset role;

update app.flags set value = 'false' where key = 'host_entry_enabled';
set local role anon;
select is((select value from app.get_flags() where key = 'host_entry_enabled'), 'false'::jsonb, 'a hand update shows in get_flags');
reset role;

select * from finish();
rollback;
