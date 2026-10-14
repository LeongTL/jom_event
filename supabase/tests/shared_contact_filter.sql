begin;
select plan(23);

-- contact details are rejected, however they are disguised
select ok(shared.contains_contact_info(t), 'rejects: ' || t)
from unnest(array[
  '0123456789',
  '012-345 6789',
  '0 1 2 3 4 5 6 7 8 9',
  '+60 12 345 6789',
  'wa.me/60123456789',
  'whatsapp me',
  '@mei.studio',
  'ig: meistudio',
  'zero one two three four five six seven eight',
  'telegram: mei',
  'find me on t.me/mei',
  'dm me on insta'
]) as t;

-- ordinary event text passes
select ok(not shared.contains_contact_info(t), 'allows: ' || t)
from unnest(array[
  'see you at 9:00',
  'RM30 for 2 people',
  'Jalan Telawi 3',
  'bring a mat',
  'instant coffee provided',
  'someone brings one mat'
]) as t;

-- working days skip Saturday and Sunday
select is(
  shared.add_working_days('2026-10-16 10:00+08', 3),
  '2026-10-21 10:00+08'::timestamptz,
  'Fri + 3 working days = Wed');
select is(
  shared.add_working_days('2026-10-19 10:00+08', 3),
  '2026-10-22 10:00+08'::timestamptz,
  'Mon + 3 working days = Thu');
select is(
  shared.add_working_days('2026-10-17 10:00+08', 1),
  '2026-10-19 10:00+08'::timestamptz,
  'Sat + 1 working day = Mon');
select is(
  shared.add_working_days('2026-10-16 10:00+08', 0),
  '2026-10-16 10:00+08'::timestamptz,
  '0 working days changes nothing');
set local timezone = 'Pacific/Auckland'; -- there, Fri 23:30 KL is already Saturday
select is(
  shared.add_working_days('2026-10-16 23:30+08', 1),
  '2026-10-19 23:30+08'::timestamptz,
  'a Friday-night KL time is still Friday, whatever the session zone');

select * from finish();
rollback;
