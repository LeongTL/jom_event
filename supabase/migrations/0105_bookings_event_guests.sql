-- The host's guest list and manual check-in list: paid guests of one of their events (names are the booking's contact name).
create function bookings.event_guests(p_event_id uuid)
returns table (booking_id uuid, guest_name text, people int, ticket_code text, checked_in boolean)
language plpgsql stable security definer set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'login_required' using errcode = '28000';
  end if;
  if (select h.host_id from events.event_brief(p_event_id) h) is distinct from auth.uid() then
    raise exception 'not_owner';
  end if;
  return query
  select b.id, b.contact_name, b.people, b.ticket_code, b.status = 'attended'
    from bookings.bookings b
   where b.event_id = p_event_id and b.status in ('confirmed', 'attended', 'no_show')
   order by b.created_at, b.id;
end
$$;

revoke all on function bookings.event_guests(uuid) from public, anon, authenticated;
grant execute on function bookings.event_guests(uuid) to authenticated;
