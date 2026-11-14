begin;
select plan(8);

select results_eq(
  $$select jobname, schedule, command from cron.job order by jobname$$,
  $$values ('auto-complete', '*/15 * * * *', 'select events.auto_complete()'),
           ('expire-holds',  '* * * * *',    'select bookings.expire_holds()'),
           ('receipt-purge', '17 3 * * *',  'select shared.call_receipt_purge()'),
           ('receipt-reminders', '* * * * *', 'select payments.run_receipt_reminders()'),
           ('retry-refunds', '*/10 * * * *', 'select payments.retry_failed_refunds()')$$,
  'cron_jobs_are_scheduled_with_expected_intervals');
select is((select count(*)::int from cron.job where active), 5, 'all five jobs are active');
select is((select count(*)::int from cron.job where database = current_database()), 5, 'the jobs run in this database');

-- each scheduled command is a real function that runs cleanly
select lives_ok($$select bookings.expire_holds()$$, 'expire-holds runs');
select lives_ok($$select events.auto_complete()$$, 'auto-complete runs');
select lives_ok($$select payments.retry_failed_refunds()$$, 'retry-refunds runs');
select lives_ok($$select payments.run_receipt_reminders()$$, 'receipt-reminders runs');
select lives_ok($$select shared.call_receipt_purge()$$, 'receipt-purge runs');

select * from finish();
rollback;
