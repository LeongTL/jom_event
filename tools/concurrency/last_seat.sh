#!/usr/bin/env bash
# Many people tap Join at once on an event with 3 seats: exactly 3 bookings must result, the rest sold_out.
# Needs the local Supabase running (supabase start). Uses psql when installed, else the db container.
set -euo pipefail

SEATS=3
PEOPLE=12
EVENT=c0c0c0c0-0000-0000-0000-000000000001
DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54422/postgres}"
DB_CONTAINER="${DB_CONTAINER:-supabase_db_jom_event}"

if command -v psql >/dev/null 2>&1; then
  sql() { psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1 -c "$1"; }
else
  sql() { docker exec "$DB_CONTAINER" psql -U postgres -X -q -At -v ON_ERROR_STOP=1 -c "$1"; }
fi

out=$(mktemp -d)
clean_db() {
  sql "delete from bookings.bookings where event_id = '$EVENT'; delete from events.events where id = '$EVENT';" >/dev/null 2>&1 || true
}
trap 'clean_db; rm -rf "$out"' EXIT
clean_db

# Far from Kuala Lumpur (lat/lng 0) so it never shows up in a feed.
sql "insert into events.events (id, host_id, title, status, price_sen, capacity, starts_at, ends_at, lat, lng)
     values ('$EVENT', gen_random_uuid(), 'last seat race', 'published', 3000, $SEATS,
             now() + interval '30 days', now() + interval '30 days 2 hours', 0, 0);"

for i in $(seq 1 "$PEOPLE"); do
  uid=$(printf 'a0a0a0a0-0000-0000-0000-%012d' "$i")
  sql "begin;
       select set_config('request.jwt.claims', '{\"sub\":\"$uid\",\"role\":\"authenticated\"}', true);
       set local role authenticated;
       select (bookings.create_booking('$EVENT', 1, 'User $i', '601')).id;
       commit;" >"$out/$i.out" 2>"$out/$i.err" &
done
wait

booked=$(sql "select coalesce(sum(people), 0) from bookings.bookings where event_id = '$EVENT'")
sold_out=$(cat "$out"/*.err | grep -c 'sold_out' || true)
echo "seats: $SEATS   people trying: $PEOPLE   seats booked: $booked   told sold_out: $sold_out"

if [ "$booked" -ne "$SEATS" ] || [ "$sold_out" -ne $((PEOPLE - SEATS)) ]; then
  echo "FAIL: expected exactly $SEATS bookings and $((PEOPLE - SEATS)) sold_out" >&2
  exit 1
fi
echo "PASS"
