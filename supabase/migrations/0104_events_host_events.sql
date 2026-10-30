-- The host's own events with seats sold, for the host Events tab and the edit form. The host reads their drafts
-- and events through RLS already, but seats sold lives in bookings, so this goes through a function.
-- p_status is draft | published | ended (null = any); p_event_id picks one event.
create function events.host_events(p_status text default null, p_event_id uuid default null)
returns table (
  id uuid, title text, description text, glyph text, color_a text, color_b text, poster_url text,
  categories text[], area text, venue text, starts_at timestamptz, ends_at timestamptz, capacity int,
  price_sen int, cancel_policy text, accept_bookings boolean, status text, seats_sold int)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  return query
  select e.id, e.title, e.description, e.glyph, e.color_a, e.color_b, e.poster_url, e.categories, e.area, e.venue,
         e.starts_at, e.ends_at, e.capacity, e.price_sen, e.cancel_policy, e.accept_bookings, e.status,
         bookings.seats_taken(e.id)
    from events.events e
   where e.host_id = auth.uid()
     and (p_status is null or e.status = p_status)
     and (p_event_id is null or e.id = p_event_id)
   order by case when e.status = 'published' then e.starts_at end asc,
            case when e.status <> 'published' then coalesce(e.starts_at, e.created_at) end desc;
end
$$;

revoke all on function events.host_events(text, uuid) from public, anon, authenticated;
grant execute on function events.host_events(text, uuid) to authenticated;
