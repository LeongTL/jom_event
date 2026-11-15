-- What a shared link shows before anyone opens the app: just enough for a preview card, nothing private.
-- Both are readable without signing in (the web page that WhatsApp and Telegram fetch has no account).

-- A published or ended event by its share code, public or private (the code is the secret). A draft or a cancelled
-- event, an unknown code and an empty one return nothing. No phone, payment details, guest data or coordinates.
create function events.share_preview(p_code text)
returns table (title text, starts_at timestamptz, ends_at timestamptz, area text, venue text, price_sen int,
               poster_url text, host_name text, status text, is_private boolean)
language sql stable security definer set search_path = ''
as $$
  select e.title, e.starts_at, e.ends_at, e.area, e.venue, coalesce(e.price_sen, 0), e.poster_url,
         h.host_name, e.status, e.visibility = 'private'
    from events.events e
    left join identity.hosts h on h.user_id = e.host_id
   where p_code is not null and p_code <> '' and e.share_code = p_code and e.status in ('published', 'ended')
$$;

-- A person by username: an approved host for anyone, a guest only for a signed-in caller (the same rule as their page
-- in the app). Name, username, host flag, avatar, and the area for hosts. Nothing else.
create function identity.person_preview(p_username text)
returns table (name text, username text, is_host boolean, avatar_url text, area text)
language sql stable security definer set search_path = ''
as $$
  select coalesce(h.host_name, nullif(btrim(p.name), ''), 'Guest'), p.username, p.is_host,
         case when p.is_host then h.avatar_url end, case when p.is_host then h.area end
    from identity.profiles p
    left join identity.hosts h on h.user_id = p.user_id and p.is_host
   where p.username is not null and lower(p.username) = lower(coalesce(p_username, ''))
     and (p.is_host or auth.uid() is not null)
$$;

-- For the app's /u/<username> link: the id behind a username, under the same visibility rule.
create function identity.user_id_by_username(p_username text) returns uuid
language sql stable security definer set search_path = ''
as $$
  select p.user_id from identity.profiles p
   where p.username is not null and lower(p.username) = lower(coalesce(p_username, ''))
     and (p.is_host or auth.uid() is not null)
$$;

revoke all on function events.share_preview(text) from public;
revoke all on function identity.person_preview(text) from public;
revoke all on function identity.user_id_by_username(text) from public;
grant execute on function events.share_preview(text) to anon, authenticated;
grant execute on function identity.person_preview(text) to anon, authenticated;
grant execute on function identity.user_id_by_username(text) to anon, authenticated;
