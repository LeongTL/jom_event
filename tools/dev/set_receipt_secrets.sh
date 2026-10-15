#!/usr/bin/env bash
# Turns receipts on for the local database: stores the functions URL and the service key in Vault so the
# database can call the receipt-email function. Run after `supabase db reset` (a reset empties Vault).
# Needs `supabase start`, and `supabase functions serve` for the call to land anywhere.
set -euo pipefail
cd "$(dirname "$0")/../.."

DB_CONTAINER="${DB_CONTAINER:-supabase_db_jom_event}"
# The database container reaches the Edge Functions through the API gateway container.
FUNCTIONS_URL="${FUNCTIONS_URL:-http://supabase_kong_jom_event:8000/functions/v1}"
KEY=$(supabase status -o env | sed -n 's/^SERVICE_ROLE_KEY="\(.*\)"$/\1/p')
[ -n "$KEY" ] || { echo "could not read the service key from 'supabase status'" >&2; exit 1; }

docker exec -i "$DB_CONTAINER" psql -U postgres -X -q -v ON_ERROR_STOP=1 -v url="$FUNCTIONS_URL" -v key="$KEY" <<'SQL'
delete from vault.secrets where name in ('functions_url', 'service_role_key');
select vault.create_secret(:'url', 'functions_url', 'where the database calls Edge Functions');
select vault.create_secret(:'key', 'service_role_key', 'service key for database-to-function calls');
SQL
echo "receipts are on: the database will call $FUNCTIONS_URL/receipt-email"
