-- The public host page in one call: who they are, the tick, how many guests they have hosted, and the ids of
-- their coming events (the app turns the ids into cards with events.cards). No row for a non-host.
-- Reads identity through its public view and function, and bookings through going_count.

create function events.host_page(p_host_id uuid, p_now timestamptz default now())
returns table (host_name text, area text, bio text, since timestamptz, verified boolean, guests int, upcoming uuid[])
language sql stable security definer set search_path = ''
as $$
  select hp.host_name, hp.area, hp.bio, hp.since, c.verified,
         (select coalesce(sum(bookings.going_count(e.id)), 0)::int
            from events.events e where e.host_id = p_host_id and e.status in ('published', 'ended')),
         coalesce((select array_agg(e.id order by e.starts_at, e.id)
                     from events.events e
                    where e.host_id = p_host_id and e.status = 'published' and e.starts_at > p_now), '{}')
    from identity.host_public hp
    join identity.host_cards(array[p_host_id]) c on c.user_id = hp.user_id
   where hp.user_id = p_host_id
$$;

revoke all on function events.host_page(uuid, timestamptz) from public;
grant execute on function events.host_page(uuid, timestamptz) to anon, authenticated;
