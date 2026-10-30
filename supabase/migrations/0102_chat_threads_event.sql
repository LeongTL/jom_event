-- Calm chat list: a guest's row shows the event's category art, so each inbox row also says which event it is about
-- and that event's categories (read through events.cards, never a join into the events tables).
drop function chat.my_threads();

create function chat.my_threads()
returns table (thread_id uuid, other_name text, other_avatar text, last_body text, last_at timestamptz,
               unread boolean, event_title text, event_id uuid, event_categories text[])
language sql stable security definer set search_path = ''
as $$
  select t.id, p.name, p.avatar_url, lm.body, t.last_message_at,
         exists (select 1 from chat.messages m
                  where m.thread_id = t.id and m.sender_id <> auth.uid()
                    and m.created_at > coalesce((select r.read_at from chat.thread_reads r
                                                  where r.thread_id = t.id and r.user_id = auth.uid()), '-infinity')),
         (select e.title from events.event_brief(t.event_id) e),
         t.event_id,
         (select c.categories from events.cards(array[t.event_id]) c)
    from chat.threads t
   cross join lateral identity.chat_party(case when t.attendee_id = auth.uid() then t.host_id else t.attendee_id end) p
   cross join lateral (select m.body from chat.messages m where m.thread_id = t.id order by m.created_at desc limit 1) lm
   where auth.uid() in (t.attendee_id, t.host_id)
   order by t.last_message_at desc
$$;

revoke all on function chat.my_threads() from public, anon, authenticated;
grant execute on function chat.my_threads() to authenticated;
