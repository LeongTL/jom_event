begin;
select plan(3);

-- every module schema exists
select is(
  (select count(*)::int from pg_namespace
    where nspname in ('shared','identity','events','bookings','payments','reviews','chat')),
  7, 'all seven schemas exist');

-- a table created later, with no RLS statement at all, still ends up with RLS on
create table chat.rls_probe (id int);
select ok(
  (select relrowsecurity from pg_class where oid = 'chat.rls_probe'::regclass),
  'a new table in a module schema gets RLS automatically');

-- no table in any module schema is without RLS
select is(
  (select coalesce(string_agg(n.nspname || '.' || c.relname, ', '), '')
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r','p')
      and n.nspname in ('identity','events','bookings','payments','reviews','chat')
      and not c.relrowsecurity),
  '', 'no module table is missing RLS');

select * from finish();
rollback;
