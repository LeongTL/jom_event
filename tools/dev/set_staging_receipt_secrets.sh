#!/usr/bin/env bash
# Turns receipts on for the hosted staging project (jom-stg): stores the functions URL and the service-role key
# in the database's Vault, so the database can call the receipt-email function.
#
# YOU run this, on your own machine, signed in to the Supabase CLI. It reads the key through your login and
# never prints it, so there is nothing to copy or paste. Safe to run again: it replaces the two secrets.
# If you reset the project's JWT secret later, run it again to store the new key.
set -euo pipefail
cd "$(dirname "$0")/../.."

REF=$(cat supabase/.temp/project-ref 2>/dev/null || true)
[ -n "$REF" ] || { echo "this folder is not linked to a Supabase project (run: supabase link --project-ref <ref>)" >&2; exit 1; }
echo "project: $REF"

SQL_FILE=$(mktemp)
trap 'rm -f "$SQL_FILE"' EXIT
chmod 600 "$SQL_FILE"

# Build the SQL in a private temp file (deleted on exit) so the key never appears on the command line.
REF="$REF" SQL_FILE="$SQL_FILE" python3 - <<'PY'
import json, os, subprocess, sys
ref = os.environ["REF"]
out = subprocess.run(["supabase", "projects", "api-keys", "--project-ref", ref, "-o", "json"],
                     capture_output=True, text=True, stdin=subprocess.DEVNULL).stdout
keys = json.loads(out[out.index("["):out.rindex("]") + 1])
key = next((k["api_key"] for k in keys if k.get("name") == "service_role"), None)
if not key:
    sys.exit("could not find the legacy service_role key for this project")
url = f"https://{ref}.supabase.co/functions/v1"
with open(os.environ["SQL_FILE"], "w") as f:
    f.write("delete from vault.secrets where name in ('functions_url', 'service_role_key');\n")
    f.write(f"select vault.create_secret('{url}', 'functions_url', 'where the database calls Edge Functions');\n")
    f.write(f"select vault.create_secret('{key}', 'service_role_key', 'service key for database-to-function calls');\n")
PY

supabase db query --linked -f "$SQL_FILE" < /dev/null > /dev/null
echo "done: receipts are on for $REF (the database will now call the receipt-email function)."
echo "check: the database now holds these secrets:" \
  "$(supabase db query --linked -o json "select string_agg(name, ', ' order by name) as secrets from vault.secrets where name in ('functions_url','service_role_key')" < /dev/null 2>/dev/null \
     | python3 -c "
import sys, json
t = sys.stdin.read()
print(json.loads(t[t.index('{'):t.rindex('}')+1])['rows'][0]['secrets'])")"
