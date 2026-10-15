#!/usr/bin/env bash
# Checks a hosted Jom backend from the outside, the way the app and strangers reach it.
# Reads SUPABASE_URL and SUPABASE_ANON_KEY from the environment, or from app/env/staging.json.
#   EXPECT_SEEDED=1 also checks the 87 seed events are there.
# Prints PASS or FAIL for every check and exits non-zero if any failed. Never prints keys or tokens.
set -uo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-app/env/staging.json}"
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  [ -f "$ENV_FILE" ] || { echo "no SUPABASE_URL/SUPABASE_ANON_KEY and no $ENV_FILE" >&2; exit 2; }
  SUPABASE_URL=$(python3 -c "import json,sys; print(json.load(open('$ENV_FILE'))['SUPABASE_URL'])")
  SUPABASE_ANON_KEY=$(python3 -c "import json,sys; print(json.load(open('$ENV_FILE'))['SUPABASE_ANON_KEY'])")
fi
PHONE="${TEST_PHONE:-+60123456789}"
CODE="${TEST_CODE:-123456}"

fails=0
check() { # name, expected, actual
  if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1   (wanted: $2, got: $3)"; fails=$((fails + 1)); fi
}
http() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$@"; }
json() { curl -s --max-time 20 "$@"; }
rpc() { # schema function bearer json-body
  json -X POST "$SUPABASE_URL/rest/v1/rpc/$2" -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer ${3:-$SUPABASE_ANON_KEY}" \
       -H "Content-Profile: $1" -H 'Content-Type: application/json' -d "$4"
}
pyget() { python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    print($1)
except Exception:
    print('?')"; }

echo "== functions answer, and refuse callers they should refuse"
check "payment-webhook rejects a forged signature"   401 "$(http -X POST "$SUPABASE_URL/functions/v1/payment-webhook" -H 'x-gateway-signature: 00ff' -H 'x-delivery-id: smoke' -H 'Content-Type: application/json' -d '{}')"
check "mock-gateway-pay needs a signed-in user"      401 "$(http -X POST "$SUPABASE_URL/functions/v1/mock-gateway-pay" -H 'Content-Type: application/json' -d '{}')"
check "delete-account needs a signed-in user"        401 "$(http -X POST "$SUPABASE_URL/functions/v1/delete-account" -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY")"
check "receipt-email only answers to the service key" 401 "$(http -X POST "$SUPABASE_URL/functions/v1/receipt-email" -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' -d '{}')"

echo "== a signed-out visitor can browse"
FEED=$(rpc events feed "" '{"p_tab":"now","p_lat":3.14,"p_lng":101.68,"p_km":50}')
check "events.feed answers with a list of 9 or fewer" ok "$(echo "$FEED" | pyget "'ok' if isinstance(d, list) and len(d) <= 9 else 'bad'")"
if [ "${EXPECT_SEEDED:-0}" = "1" ]; then
  check "the seed is loaded (87 events in View all)" 87 "$(rpc events tab_counts "" '{"p_lat":3.14,"p_lng":101.68,"p_km":50}' | pyget "[r['n'] for r in d if r['tab']=='all'][0]")"
fi
check "a visitor cannot save an event"               42501 "$(rpc identity toggle_save "" '{"event_id":"00000000-0000-0000-0000-000000000000"}' | pyget "d.get('code')")"
check "a visitor cannot read bookings directly"      42501 "$(json "$SUPABASE_URL/rest/v1/bookings" -H "apikey: $SUPABASE_ANON_KEY" -H 'Accept-Profile: bookings' | pyget "d.get('code')")"

echo "== sign in with the test phone number"
json -o /dev/null -X POST "$SUPABASE_URL/auth/v1/otp" -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' -d "{\"phone\":\"$PHONE\"}"
TOKEN=$(json -X POST "$SUPABASE_URL/auth/v1/verify" -H "apikey: $SUPABASE_ANON_KEY" -H 'Content-Type: application/json' \
          -d "{\"phone\":\"$PHONE\",\"token\":\"$CODE\",\"type\":\"sms\"}" | pyget "d.get('access_token','')")
check "the test phone number signs in with the test code" yes "$([ -n "$TOKEN" ] && [ "$TOKEN" != "?" ] && echo yes || echo no)"

if [ -n "$TOKEN" ] && [ "$TOKEN" != "?" ]; then
  echo "== what a signed-in user can and cannot do"
  check "identity.unread_count answers 0 for a new user"   0     "$(rpc identity unread_count "$TOKEN" '{}')"
  check "the profile was created by the sign-up trigger"   1     "$(json "$SUPABASE_URL/rest/v1/profiles?select=user_id" -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $TOKEN" -H 'Accept-Profile: identity' | pyget "len(d)")"
  check "identity.notify is not callable by a user"        42501 "$(rpc identity notify "$TOKEN" '{"user_id":"00000000-0000-0000-0000-000000000000","type":"payment","ref_type":null,"ref_id":null,"title":"x","body":null}' | pyget "d.get('code')")"
  check "a user cannot write events directly"              42501 "$(json -X POST "$SUPABASE_URL/rest/v1/events" -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $TOKEN" -H 'Content-Profile: events' -H 'Content-Type: application/json' -d '{"host_id":"00000000-0000-0000-0000-000000000000","title":"x"}' | pyget "d.get('code')")"
fi

echo
if [ "$fails" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "$fails CHECK(S) FAILED"; exit 1; fi
