-- Scheduled jobs (pg_cron). Each one calls a function that already exists and is safe to run repeatedly.
create extension if not exists pg_cron with schema pg_catalog;

-- Frees the seats of holds that ran out.
select cron.schedule('expire-holds', '* * * * *', 'select bookings.expire_holds()');
-- Completes events 24 hours after they ended, when the host did not.
select cron.schedule('auto-complete', '*/15 * * * *', 'select events.auto_complete()');
-- Tries failed refunds again, up to 5 attempts each.
select cron.schedule('retry-refunds', '*/10 * * * *', 'select payments.retry_failed_refunds()');
