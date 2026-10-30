begin;
select plan(6);

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com');
update identity.profiles set is_host = true;

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select set_config('t.pub', events.save_draft(jsonb_build_object('title', 'Pottery', 'area', 'Bangsar', 'venue', 'Studio',
  'starts_at', now() + interval '2 days', 'ends_at', now() + interval '2 days 2 hours', 'capacity', 12, 'price_sen', 3000))::text, true);
select events.publish(current_setting('t.pub')::uuid);
select set_config('t.draft', events.save_draft(jsonb_build_object('title', 'Later idea'))::text, true);

reset role;
insert into bookings.bookings (event_id, attendee_id, people, status, ticket_code, contact_name, contact_phone, amount_sen)
values (current_setting('t.pub')::uuid, 'bbbbbbbb-0000-0000-0000-000000000002', 2, 'confirmed', 'T-1', 'Guest', '601', 6000);

select set_config('request.jwt.claims', '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select results_eq($$select title, seats_sold from events.host_events('published')$$, $$values ('Pottery', 2)$$,
  'published_tab_lists_my_event_with_seats_sold');
select results_eq($$select title, seats_sold from events.host_events('draft')$$, $$values ('Later idea', 0)$$,
  'draft_tab_lists_drafts');
select is_empty($$select 1 from events.host_events('ended')$$, 'ended_tab_is_empty_until_something_ended');
select results_eq($$select capacity from events.host_events(null, current_setting('t.pub')::uuid)$$, $$values (12)$$,
  'one_event_by_id_returns_its_full_row');

select set_config('request.jwt.claims', '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);
select is_empty($$select 1 from events.host_events('published')$$, 'someone_elses_events_are_not_listed');
select is_empty($$select 1 from events.host_events(null, current_setting('t.pub')::uuid)$$, 'someone_elses_event_by_id_is_not_returned');

select * from finish();
rollback;
