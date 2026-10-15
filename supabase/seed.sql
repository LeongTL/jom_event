-- Development and staging seed: 20 hosts and 87 published events across Kuala Lumpur and Selangor.
-- Loaded by `supabase db reset`; never part of a migration, so prod never gets it.
--
-- Times are relative to the moment the seed loads (re-run `supabase db reset` to refresh them):
--   Now      11 events: live, or starting within about 2 hours
--   Night     8 events: spread between 2 hours from now and 04:00 (moved to tomorrow evening when that window is closed)
--   Weekend  22 events: Saturday and Sunday of this weekend (or the next, once what is left of this one is too short)
--   Later    46 events: one to three weeks out
-- The 24 events from the prototype come first; the other 63 come from a pool of activity templates.
do $seed$
declare
  kl constant text := 'Asia/Kuala_Lumpur';
  t0 timestamptz := now();
  today date := (now() at time zone kl)::date;
  dow int := extract(isodow from today)::int;
  sat date := today + case when dow >= 6 then -(dow - 6) else 6 - dow end;   -- Saturday of this weekend, or the coming one
  night_start timestamptz := now() + interval '130 minutes';
  night_end timestamptz := (date_trunc('day', (now() at time zone kl) - interval '4 hours') + interval '1 day 4 hours') at time zone kl;
  night_open boolean;
  areas text[] := array['Bangsar', 'KLCC', 'PJ', 'Sri Hartamas', 'Mid Valley', 'Bukit Bintang'];
  hosts text[] := array[
    'KLCC Pokémon Club', 'The Loft Café', 'Midvalley Market Co', 'Salsa KL', 'Clay & Co', 'Mei Studio',
    'KL Run Crew', 'Game Haus', 'Quiet Riot', 'Kiara Hikers', 'Bangsar Makers', 'Batik House', 'Ink & Eggs',
    'KL Cyclists', 'Rangoli Lab', 'KL Lens Club', 'Spin Collective', 'Garuda Gym', 'Jom Quiz Club', 'Brickfields Bakers'];
  h int;
  uid uuid;
  r record;
  n_night int := 0;
  n_gen int;
  ev record;
  starts timestamptz;
  area_row record;
  cap int;
  policy text;
begin
  night_open := night_end - night_start >= interval '60 minutes';

  -- ===== 20 hosts: a sign-in account, a host profile and a payout account each =====
  for h in 1..20 loop
    uid := ('d5eed000-0000-4000-8000-' || lpad(h::text, 12, '0'))::uuid;
    insert into auth.users (id, email, aud, role, raw_user_meta_data)
    values (uid, 'host' || lpad(h::text, 2, '0') || '@seed.jom.test', 'authenticated', 'authenticated',
            jsonb_build_object('full_name', hosts[h]))
    on conflict (id) do nothing;
    update identity.profiles set is_host = true where user_id = uid;
    insert into identity.hosts (user_id, host_name, area, bio, verified_at)
    values (uid, hosts[h], areas[1 + (h * 5) % 6],
            'Hosting small, friendly sessions around the city. Everyone is welcome.',
            case when h % 3 <> 0 then now() end)       -- two in three are verified
    on conflict (user_id) do nothing;
    insert into identity.host_payout_accounts (user_id, account_holder, bank, account_number)
    values (uid, hosts[h], 'Maybank', '0000000000')
    on conflict (user_id) do nothing;
  end loop;

  -- ===== the event list: prototype events first, then generated ones =====
  create temp table seed_events (
    n int generated always as identity, tab text, title text, description text, glyph text, c1 text, c2 text, price int, cats text[],
    host text, area text, cap int, start_off int, tod int, day_off int, dur int, source text
  ) on commit drop;

  -- tab, title, description, glyph, colours, price (sen), categories, host, area, spots, minutes from now, minute of day, days out, minutes long
  insert into seed_events (tab, title, description, glyph, c1, c2, price, cats, host, area, cap, start_off, tod, day_off, dur, source) values
   ('now',  'Pokémon Trade Night', 'Bring your binder and swap cards with fellow trainers. All levels welcome.', '🎴', '#ff5f6d', '#ffc371', 0, '{meet}', 'KLCC Pokémon Club', 'KLCC', 24, -60, null, null, 150, 'https://www.instagram.com/klccpokemonclub'),
   ('now',  'Open Mic Night', 'Sing, read or just listen. Sign up at the door, five minutes each.', '🎤', '#7f00ff', '#e100ff', 1000, '{meet}', 'The Loft Café', 'Bangsar', 30, 38, null, null, 120, null),
   ('now',  'Midvalley Night Market', 'Street food, handmade goods and live acoustic sets under the lights.', '🛍', '#f7971e', '#d9a400', 0, '{meet}', 'Midvalley Market Co', 'Mid Valley', 40, -90, null, null, 210, null),
   ('now',  'Salsa Social', 'A relaxed social with a short beginner lesson first. No partner needed.', '💃', '#f857a6', '#ff5858', 1500, '{move,meet}', 'Salsa KL', 'Bangsar', 30, 78, null, null, 120, null),
   ('now',  'Late Pottery Drop-in', 'Open wheels for the evening. Clay and glaze are included.', '🏺', '#c97b63', '#e8a77a', 4500, '{make}', 'Clay & Co', 'Sri Hartamas', 8, 93, null, null, 120, null),
   ('now',  'Sunset Yoga Deck', 'Gentle flow on the rooftop deck as the sun goes down. Bring a mat.', '🧘', '#11998e', '#38ef7d', 2500, '{move}', 'Mei Studio', 'Bangsar', 16, 22, null, null, 75, null),
   ('night','Supper Run Club', 'An easy social run through the neighbourhood, then supper together.', '🏃', '#0f9b8e', '#1de9b6', 0, '{move,meet}', 'KL Run Crew', 'Bangsar', 40, null, null, null, 90, 'https://www.instagram.com/klrunCrew'),
   ('night','Midnight Board Games', 'Heavy strategy games and light party games. We teach everything.', '🎲', '#5f2c82', '#49a09d', 1200, '{meet}', 'Game Haus', 'PJ', 12, null, null, null, 150, null),
   ('night','Silent Disco', 'Three channels, one dance floor and no noise complaints.', '🎧', '#8e2de2', '#4a00e0', 3500, '{move,meet}', 'Quiet Riot', 'Bukit Bintang', 40, null, null, null, 120, null),
   ('weekend','Sunrise Hike Bukit Kiara', 'A steady two hour hike to catch the sunrise. Bring water and good shoes.', '⛰', '#2c7744', '#98d98e', 0, '{move,meet}', 'Kiara Hikers', 'Sri Hartamas', 30, null, 390, 0, 150, 'https://www.instagram.com/kiarahikers'),
   ('weekend','Pokémon Community Meetup', 'Our monthly meetup: trades, battles and a card swap table.', '🎴', '#ff5f6d', '#ffc371', 0, '{meet}', 'KLCC Pokémon Club', 'KLCC', 30, null, 660, 0, 180, 'https://www.instagram.com/klccpokemonclub'),
   ('weekend','Bangsar Flea Market', 'Makers, vintage finds and plants from small local sellers.', '🛍', '#ff8a00', '#e52e71', 0, '{meet}', 'Bangsar Makers', 'Bangsar', 40, null, 600, 0, 300, null),
   ('weekend','Batik Painting Workshop', 'Learn the wax and dye method and take home your own batik cloth.', '🎨', '#ee0979', '#ff6a00', 6000, '{make}', 'Batik House', 'Bangsar', 12, null, 840, 0, 150, null),
   ('weekend','Ceramics Open Studio', 'Hand building and glazing with a teacher on hand to help.', '🏺', '#b08968', '#e6ccb2', 4000, '{make}', 'Clay & Co', 'Sri Hartamas', 10, null, 930, 0, 150, null),
   ('weekend','Beginner Mat Pilates', 'A slow, friendly class that builds core strength. Mats provided.', '🧘', '#11998e', '#38ef7d', 3000, '{move}', 'Mei Studio', 'Bangsar', 14, null, 540, 1, 60, null),
   ('weekend','Sketch & Brunch', 'Sketch the café while you eat. Pencils and paper are on the table.', '✏️', '#f093fb', '#f5576c', 3800, '{make,meet}', 'Ink & Eggs', 'Bangsar', 16, null, 630, 1, 120, null),
   ('weekend','Pottery Wheel Basics', 'Your first time on the wheel, with plenty of hands on help.', '🏺', '#c97b63', '#e8a77a', 4500, '{make}', 'Clay & Co', 'Sri Hartamas', 8, null, 840, 1, 120, null),
   ('weekend','Sunday Cycling Club', 'An easy paced ride along the river. Helmets required.', '🚴', '#4facfe', '#00c6a7', 0, '{move,meet}', 'KL Cyclists', 'Bukit Bintang', 40, null, 420, 1, 150, 'https://www.instagram.com/klcyclists'),
   ('later', 'Board Game Night', 'A table for every taste, from quick card games to long campaigns.', '🎲', '#5f2c82', '#49a09d', 1500, '{meet}', 'Game Haus', 'PJ', 20, null, 1200, 8, 180, null),
   ('later', 'Sunset Stretch', 'A restful stretch session to close the week.', '🧘', '#11998e', '#38ef7d', 2500, '{move}', 'Mei Studio', 'Bangsar', 16, null, 1080, 9, 60, null),
   ('later', 'Kolam Art Workshop', 'Draw traditional kolam patterns with coloured rice flour.', '🎨', '#ee0979', '#ff6a00', 2000, '{make}', 'Rangoli Lab', 'Mid Valley', 20, null, 660, 10, 120, null),
   ('later', 'Photo Walk: Old KL', 'Wander the old streets with a camera or a phone. All levels.', '📸', '#2c3e50', '#4ca1af', 0, '{move,meet}', 'KL Lens Club', 'Bukit Bintang', 25, null, 450, 16, 150, 'https://www.instagram.com/kllensclub'),
   ('later', 'Vinyl Swap Meet', 'Bring records to swap, sell or just show off.', '💿', '#42275a', '#734b6d', 0, '{meet}', 'Spin Collective', 'Bangsar', 40, null, 720, 17, 180, null),
   ('later', 'Intro to Muay Thai', 'Pads, footwork and fun. No experience needed.', '🥊', '#cb2d3e', '#ef473a', 3500, '{move}', 'Garuda Gym', 'Bukit Bintang', 14, null, 600, 23, 90, null);

  -- 63 more from a pool of 20 templates: title, blurb, glyph, colours, price, categories, spots, minutes long, minute of day
  create temp table seed_pool (i int, title text, description text, glyph text, c1 text, c2 text, price int, cats text[], cap int, dur int, tod int) on commit drop;
  insert into seed_pool values
   (1,  'Sourdough Starter Swap', 'Trade starter and baking tips over fresh bread.', '🍞', '#d4a373', '#fefae0', 0, '{make,meet}', 20, 90, 600),
   (2,  'Watercolour Evening', 'Paint a small landscape step by step. Materials included.', '🖌', '#4facfe', '#00f2fe', 3500, '{make}', 12, 120, 1140),
   (3,  'Rooftop Run', 'A casual loop with a view, then cold drinks.', '🏃', '#0f9b8e', '#1de9b6', 0, '{move,meet}', 30, 75, 1110),
   (4,  'Sunrise Tai Chi', 'Slow, calming movement to start the day.', '☯️', '#2c7744', '#98d98e', 0, '{move}', 25, 60, 420),
   (5,  'Language Exchange Café', 'Practise a language with a native speaker, one coffee at a time.', '💬', '#f7971e', '#ffd200', 0, '{meet}', 30, 120, 1080),
   (6,  'Trivia Night', 'Teams of four, six rounds and bragging rights.', '🧠', '#5f2c82', '#49a09d', 1000, '{meet}', 40, 120, 1200),
   (7,  'Terrarium Workshop', 'Build a tiny garden in a jar and take it home.', '🌿', '#11998e', '#38ef7d', 5500, '{make}', 10, 105, 840),
   (8,  'Beginner Salsa Lesson', 'Basic steps and a few turns, no partner needed.', '💃', '#f857a6', '#ff5858', 2000, '{move}', 24, 90, 1230),
   (9,  'Board Game Brunch', 'Light games over a long, lazy brunch.', '🎲', '#5f2c82', '#49a09d', 1800, '{meet}', 16, 150, 630),
   (10, 'Film Photography Walk', 'Shoot a roll of film on an easy city walk.', '📸', '#2c3e50', '#4ca1af', 0, '{move,make}', 20, 150, 450),
   (11, 'Candle Pouring Class', 'Mix scents and pour your own soy candle.', '🕯', '#ee0979', '#ff6a00', 6000, '{make}', 8, 120, 900),
   (12, 'Badminton Social', 'Friendly doubles with rotating partners.', '🏸', '#4facfe', '#00c6a7', 1500, '{move,meet}', 24, 120, 1200),
   (13, 'Indie Gig Night', 'Three local bands in a small, loud room.', '🎸', '#7f00ff', '#e100ff', 2500, '{meet}', 40, 180, 1230),
   (14, 'Knitting Circle', 'Bring your project or start a scarf with us.', '🧶', '#f093fb', '#f5576c', 0, '{make,meet}', 14, 120, 840),
   (15, 'Boxing Basics', 'Stance, jab and cross with a friendly coach.', '🥊', '#cb2d3e', '#ef473a', 3000, '{move}', 14, 75, 1140),
   (16, 'Poetry Open Mic', 'Read your own words or someone else''s.', '📖', '#42275a', '#734b6d', 0, '{meet}', 30, 105, 1200),
   (17, 'Cold Brew Tasting', 'Taste six cold brews and learn how each is made.', '☕', '#b08968', '#e6ccb2', 3200, '{meet}', 14, 75, 960),
   (18, 'Calligraphy Basics', 'Brush, ink and a steady hand. Tools provided.', '✒️', '#c97b63', '#e8a77a', 4200, '{make}', 12, 120, 870),
   (19, 'Dance Cardio', 'Sweat to upbeat music, no steps to memorise.', '🕺', '#f857a6', '#f7971e', 2200, '{move}', 30, 60, 1110),
   (20, 'Plant Swap Sunday', 'Bring a cutting, take a cutting.', '🪴', '#2c7744', '#98d98e', 0, '{meet,make}', 30, 120, 600);

  -- 5 more Now, 5 more Night, 13 more Weekend, 40 more Later
  n_gen := 0;
  for r in select * from (values ('now', 5), ('night', 5), ('weekend', 13), ('later', 40)) t(tab, cnt) loop
    for h in 1..r.cnt loop
      n_gen := n_gen + 1;
      insert into seed_events (tab, title, description, glyph, c1, c2, price, cats, host, area, cap, start_off, tod, day_off, dur, source)
      select r.tab, p.title || ' · ' || areas[1 + (n_gen * 2) % 6], p.description, p.glyph, p.c1, p.c2, p.price, p.cats,
             hosts[1 + (n_gen * 7) % 20], areas[1 + (n_gen * 2) % 6], p.cap,
             case when r.tab = 'now' then (array[-45, 12, 25, 55, 105])[h] end,
             case when r.tab = 'weekend' then p.tod when r.tab = 'later' then p.tod end,
             case when r.tab = 'weekend' then (h - 1) % 2 when r.tab = 'later' then 8 + (h - 1) % 14 end,
             p.dur,
             case when p.price = 0 and n_gen % 3 = 0 then 'https://www.instagram.com/jomsessions' end
        from seed_pool p where p.i = 1 + (n_gen - 1) % 20;
    end loop;
  end loop;

  -- ===== place them in time and insert =====
  for ev in select e.*, row_number() over (partition by e.tab order by e.n) as ord, count(*) over (partition by e.tab) as total
              from seed_events e order by e.n loop
    if ev.tab = 'now' then
      starts := t0 + ev.start_off * interval '1 minute';
    elsif ev.tab = 'night' then
      if night_open then
        starts := night_start + ((night_end - night_start - interval '45 minutes') * (ev.ord::float8 / (ev.total + 1)::float8));
        starts := date_trunc('hour', starts) + (floor(extract(minute from starts) / 5)::int * 5) * interval '1 minute';
      else
        starts := ((today + 1) + (1230 + 15 * ev.ord) * interval '1 minute') at time zone kl;   -- tomorrow evening
      end if;
    elsif ev.tab = 'weekend' then
      starts := ((sat + ev.day_off) + ev.tod * interval '1 minute') at time zone kl;
      if starts < t0 + interval '150 minutes' then
        starts := starts + interval '7 days';
      end if;
    else
      starts := ((today + ev.day_off) + ev.tod * interval '1 minute') at time zone kl;
    end if;

    select a.lat, a.lng into area_row from events.areas a where a.name = ev.area;
    policy := case when ev.price = 0 then '24h'
                   when ev.title = 'Intro to Muay Thai' then 'none'
                   when ev.title = 'Kolam Art Workshop' then '7d'
                   when ev.n % 4 = 0 then '24h'
                   else '48h' end;

    insert into events.events (host_id, title, description, glyph, color_a, color_b, categories, area, venue, lat, lng,
                               starts_at, ends_at, capacity, price_sen, cancel_policy, accept_bookings, source_url, status)
    values (('d5eed000-0000-4000-8000-' || lpad(array_position(hosts, ev.host)::text, 12, '0'))::uuid,
            ev.title, ev.description, ev.glyph, ev.c1, ev.c2, ev.cats, ev.area, ev.host || ', ' || ev.area,
            area_row.lat + (((ev.n * 37) % 100) - 50) / 5000.0, area_row.lng + (((ev.n * 53) % 100) - 50) / 5000.0,
            starts, starts + ev.dur * interval '1 minute', ev.cap, ev.price, policy, true, ev.source, 'published');
  end loop;

  drop table seed_events;
  drop table seed_pool;
end
$seed$;
