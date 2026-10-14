begin;
select plan(7);

insert into auth.users (id, email) values ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com');

insert into events.events (id, host_id, title, status) values
  ('eeeeeeee-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Pottery night', 'published'),
  ('eeeeeeee-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Unfinished draft', 'draft');

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select is(identity.toggle_save('eeeeeeee-0000-0000-0000-000000000001'), true,
  'toggle_save returns true when it saves');
select is((select count(*)::int from identity.saved_events), 1, 'the saved row exists');
select is(identity.toggle_save('eeeeeeee-0000-0000-0000-000000000001'), false,
  'toggle_save returns false when it unsaves');
select is((select count(*)::int from identity.saved_events), 0,
  'toggle_save_twice_returns_true_then_false_and_leaves_no_row');

-- an event that is not published cannot be saved
select throws_ok($$select identity.toggle_save('eeeeeeee-0000-0000-0000-000000000002')$$,
  'P0001', 'event_not_found', 'toggle_save_rejects_unpublished_event');

-- but an event that has since ended can still be unsaved
select identity.toggle_save('eeeeeeee-0000-0000-0000-000000000001');
reset role;
update events.events set status = 'ended' where id = 'eeeeeeee-0000-0000-0000-000000000001';
set local role authenticated;
select is(identity.toggle_save('eeeeeeee-0000-0000-0000-000000000001'), false,
  'unsaving still works after the event has ended');
reset role;

select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select identity.toggle_save('eeeeeeee-0000-0000-0000-000000000001')$$,
  '42501', null, 'toggle_save_requires_login');
reset role;

select * from finish();
rollback;
