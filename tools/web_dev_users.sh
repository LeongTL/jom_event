#!/usr/bin/env bash
# Local test people for the web back office (needs `supabase start`). Safe to run again. Local stack only.
# admin@jom.test / plain@jom.test / host@jom.test (approved) / mei@jom.test, ravi@jom.test (pending), all with password Passw0rd!local
set -euo pipefail
cd "$(dirname "$0")/.."
eval "$(supabase status -o env 2>/dev/null | grep -E '^(API_URL|SERVICE_ROLE_KEY)=')"
db=$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -1)

make_user() { # email name
  curl -s -o /dev/null "$API_URL/auth/v1/admin/users" -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"Passw0rd!local\",\"email_confirm\":true,\"user_metadata\":{\"full_name\":\"$2\"}}" || true
}
make_user admin@jom.test "Ada Admin"
make_user plain@jom.test "Pat Plain"
make_user host@jom.test "Hana Host"
make_user mei@jom.test "Mei Tan"
make_user ravi@jom.test "Ravi Kumar"

docker exec -i "$db" psql -U postgres -v ON_ERROR_STOP=1 -q <<'SQL'
insert into identity.admins (user_id) select id from auth.users where email = 'admin@jom.test' on conflict do nothing;
insert into identity.hosts (user_id, host_name, area, bio, ssm_number, status)
  select id, 'Hana Runs', 'PJ', 'Trail runs', '202001000009', 'approved' from auth.users where email = 'host@jom.test' on conflict do nothing;
insert into identity.hosts (user_id, host_name, area, bio, ssm_number, status)
  select id, 'Mei Studio', 'Bangsar', 'Sunrise yoga and coffee', '202001000001', 'pending' from auth.users where email = 'mei@jom.test' on conflict do nothing;
insert into identity.hosts (user_id, host_name, area, bio, ssm_number, status)
  select id, 'Ravi Climbs', 'KL', 'Indoor climbing socials', null, 'pending' from auth.users where email = 'ravi@jom.test' on conflict do nothing;
insert into identity.host_payout_accounts (user_id, account_holder, bank, account_number)
  select id, 'Mei Tan', 'Maybank', '1122334455' from auth.users where email = 'mei@jom.test' on conflict do nothing;
insert into identity.host_payout_accounts (user_id, account_holder, bank, account_number)
  select id, 'Ravi Kumar', 'CIMB', '9988776655' from auth.users where email = 'ravi@jom.test' on conflict do nothing;
update identity.profiles set is_host = true where user_id in (select id from auth.users where email = 'host@jom.test');
SQL
echo "ready: admin@jom.test (set up an authenticator on first sign-in), plain@jom.test, host@jom.test; two pending applications"
