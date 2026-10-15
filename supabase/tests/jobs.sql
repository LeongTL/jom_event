begin;
select plan(6);

select results_eq(
  $$select jobname, schedule, command from cron.job order by jobname$$,
  $$values ('auto-complete', '*/15 * * * *', 'select events.auto_complete()'),
           ('expire-holds',  '* * * * *',    'select bookings.expire_holds()'),
           ('retry-refunds', '*/10 * * * *', 'select payments.retry_failed_refunds()')$$,
  'cron_jobs_are_scheduled_with_expected_intervals');
select is((select count(*)::int from cron.job where active), 3, 'all three jobs are active');
select is((select count(*)::int from cron.job where database = current_database()), 3, 'the jobs run in this database');

-- each scheduled command is a real function that runs cleanly
select lives_ok($$select bookings.expire_holds()$$, 'expire-holds runs');
select lives_ok($$select events.auto_complete()$$, 'auto-complete runs');
select lives_ok($$select payments.retry_failed_refunds()$$, 'retry-refunds runs');

select * from finish();
rollback;
