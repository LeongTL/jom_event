-- Module schemas (one per module) plus `shared` for helpers.
create schema if not exists shared;
create schema if not exists identity;
create schema if not exists events;
create schema if not exists bookings;
create schema if not exists payments;
create schema if not exists reviews;
create schema if not exists chat;

-- True when text carries contact details: phone numbers (also spaced or spelled out),
-- WhatsApp / Telegram / Instagram mentions and @handles.
-- shortcut: any 8+ digit run counts, so "16 10 2026 10" is rejected too; add a date exemption if hosts complain.
create function shared.contains_contact_info(body text) returns boolean
language plpgsql immutable
as $$
declare
  t text := lower(coalesce(body, ''));
  n text;
  words text[] := array['zero','one','two','three','four','five','six','seven','eight','nine'];
begin
  -- link and handle tell-tales, checked as written
  if t ~ '\m(wa\.me|t\.me)' or t ~ '\minsta(gram)?\M' or t ~ '\mig\s*:' then
    return true;
  end if;

  -- "zero one two" -> "0 1 2" (whole words only, so "someone" is left alone)
  for i in 0..9 loop
    t := regexp_replace(t, '\m' || words[i + 1] || '\M', i::text, 'g');
  end loop;

  -- drop spaces, dots and dashes so "0 1 2" and "012-345" collapse
  n := regexp_replace(t, '[\s.\-]', '', 'g');
  return n ~ '[0-9]{8}' or n ~ 'whatsapp|telegram' or n ~ '@[a-z0-9_]{2,}';
end
$$;

-- Adds n working days (Mon-Fri, no holiday calendar), counted in Kuala Lumpur time.
-- shortcut: no public holidays, add a holiday table when payouts need it.
create function shared.add_working_days(d timestamptz, n int) returns timestamptz
language plpgsql immutable
as $$
declare
  local_ts timestamp := d at time zone 'Asia/Kuala_Lumpur';
  remaining int := n;
begin
  while remaining > 0 loop
    local_ts := local_ts + interval '1 day';
    if extract(isodow from local_ts) < 6 then
      remaining := remaining - 1;
    end if;
  end loop;
  return local_ts at time zone 'Asia/Kuala_Lumpur';
end
$$;

-- RLS on every table: a table created in a module schema starts with RLS on (no policy = no access),
-- so a later task cannot forget it. Tasks add policies as they need them.
create function shared.enable_rls_on_create() returns event_trigger
language plpgsql security definer set search_path = ''
as $$
declare
  r record;
begin
  for r in
    select object_identity from pg_event_trigger_ddl_commands()
    where object_type = 'table'
      and schema_name in ('identity','events','bookings','payments','reviews','chat')
  loop
    execute format('alter table %s enable row level security', r.object_identity);
  end loop;
end
$$;

create event trigger shared_enable_rls on ddl_command_end
  when tag in ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
  execute function shared.enable_rls_on_create();
