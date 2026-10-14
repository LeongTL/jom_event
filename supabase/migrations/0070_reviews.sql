-- Reviews: one verified review per attended booking, public host rating. Clients read their own rows; every
-- write goes through submit_review. event_id, host_id, attendee_id and booking_id have no foreign keys:
-- they belong to other modules (submit_review checks them through functions).

create table reviews.reviews (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null unique,
  event_id    uuid not null,
  host_id     uuid not null,
  attendee_id uuid not null,
  stars       int not null check (stars between 1 and 5),
  tags        text[] not null default '{}'
              check (tags <@ array['friendly_host', 'good_value', 'beginner_friendly', 'clean_venue']),
  body        text check (char_length(body) <= 1000),
  created_at  timestamptz not null default now()
);

alter table reviews.reviews enable row level security;
create policy own_reviews on reviews.reviews for select to authenticated
  using (attendee_id = (select auth.uid()));

grant usage on schema reviews to anon, authenticated;
grant select on reviews.reviews to authenticated;

-- A host's average (one decimal) and count. Runs with the owner's rights on purpose so visitors see the
-- numbers without reading the table; it holds no attendee data.
create view reviews.host_rating as
  select r.host_id, round(avg(r.stars), 1)::numeric(2, 1) as average, count(*)::int as count
    from reviews.reviews r
   group by r.host_id;
grant select on reviews.host_rating to anon, authenticated;

-- What reviews needs from the other modules, through functions only. Internal.
create function bookings.is_attended(p_booking_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from bookings.bookings b where b.id = p_booking_id and b.status = 'attended') $$;

create function events.is_ended(p_event_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$ select exists (select 1 from events.events e where e.id = p_event_id and e.status = 'ended') $$;

create function identity.first_name(p_user_id uuid) returns text
language sql stable security definer set search_path = ''
as $$
  select coalesce(nullif(split_part(btrim(p.name), ' ', 1), ''), 'Guest')
    from identity.profiles p where p.user_id = p_user_id
$$;

-- Only an attended booking of a completed event can be reviewed (a no-show cannot).
create function reviews.reviewable(p_booking_id uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select bookings.is_attended(p_booking_id)
     and events.is_ended((select b.event_id from bookings.booking_brief(p_booking_id) b))
$$;

create function reviews.submit_review(p_booking_id uuid, p_stars int, p_tags text[], p_body text) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  br record;
  tags text[];
  body text := nullif(btrim(p_body), '');
  new_id uuid;
begin
  if uid is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  select * into br from bookings.booking_brief(p_booking_id);
  if not found or br.attendee_id <> uid then
    raise exception 'not_owner';
  end if;
  if not bookings.is_attended(p_booking_id) then
    raise exception 'not_attended';
  end if;
  if not events.is_ended(br.event_id) then
    raise exception 'event_not_completed';
  end if;
  if p_stars is null or p_stars not between 1 and 5 then
    raise exception 'stars_out_of_range';
  end if;
  tags := coalesce((select array_agg(distinct t order by t) from unnest(p_tags) t), '{}');
  if not tags <@ array['friendly_host', 'good_value', 'beginner_friendly', 'clean_venue'] then
    raise exception 'unknown_tag';
  end if;
  if char_length(body) > 1000 then
    raise exception 'body_too_long';
  end if;
  if shared.contains_contact_info(body) then
    raise exception 'contact_info_not_allowed';
  end if;

  begin
    insert into reviews.reviews (booking_id, event_id, host_id, attendee_id, stars, tags, body)
    values (p_booking_id, br.event_id, (select e.host_id from events.event_brief(br.event_id) e), uid, p_stars, tags, body)
    returning id into new_id;
  exception when unique_violation then
    raise exception 'already_reviewed';
  end;
  return new_id;
end
$$;

-- Public: what guests said about a host, newest first. First names only, never attendee ids.
create function reviews.host_reviews(p_host_id uuid, p_limit int default 20)
returns table (attendee_first_name text, stars int, body text, created_at timestamptz)
language sql stable security definer set search_path = ''
as $$
  select identity.first_name(r.attendee_id), r.stars, r.body, r.created_at
    from reviews.reviews r
   where r.host_id = p_host_id
   order by r.created_at desc, r.id
   limit least(greatest(coalesce(p_limit, 20), 1), 100)
$$;

-- The caller's own reviews (row-level security already limits this to them).
create function reviews.my_reviews() returns setof reviews.reviews
language sql stable set search_path = ''
as $$ select r.* from reviews.reviews r where r.attendee_id = auth.uid() order by r.created_at desc $$;

revoke all on function bookings.is_attended(uuid) from public, anon, authenticated;
revoke all on function events.is_ended(uuid) from public, anon, authenticated;
revoke all on function identity.first_name(uuid) from public, anon, authenticated;
revoke all on function reviews.reviewable(uuid) from public, anon, authenticated;
revoke all on function reviews.submit_review(uuid, int, text[], text) from public, anon, authenticated;
revoke all on function reviews.host_reviews(uuid, int) from public;
revoke all on function reviews.my_reviews() from public, anon, authenticated;

grant execute on function reviews.reviewable(uuid) to authenticated;
grant execute on function reviews.submit_review(uuid, int, text[], text) to authenticated;
grant execute on function reviews.host_reviews(uuid, int) to anon, authenticated;
grant execute on function reviews.my_reviews() to authenticated;
