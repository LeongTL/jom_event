#!/usr/bin/env bash
# End-to-end journeys against the local Supabase, on a booted simulator or emulator.
# Needs: `supabase start`, `supabase functions serve --no-verify-jwt --env-file <FLAVOR=dev + GATEWAY_WEBHOOK_SECRET>`.
# Usage: tools/e2e.sh <device id> [journey file ...]   (default: every *_journey_test.dart)
set -euo pipefail
cd "$(dirname "$0")/.."
device=${1:?usage: tools/e2e.sh <device id> [journey file ...]}
shift || true

mkdir -p app/env
supabase status -o json | python3 -c '
import json, sys
s = json.load(sys.stdin)
json.dump({"FLAVOR": "dev", "SUPABASE_URL": s["API_URL"], "SUPABASE_ANON_KEY": s["ANON_KEY"],
           "SERVICE_ROLE_KEY": s["SERVICE_ROLE_KEY"]}, open("app/env/e2e.json", "w"))'

db=$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -1)
if [ "$#" -gt 0 ]; then files=("$@"); else files=(app/integration_test/*_journey_test.dart); fi
for f in "${files[@]}"; do
  echo "== $(basename "$f")"
  docker exec -i "$db" psql -U postgres -v ON_ERROR_STOP=1 -q < tools/e2e_reset.sql
  # drive, not test: `flutter test` cannot start its debug service on the simulator; `--no-dds` with drive works
  (cd app && flutter drive --driver=test_driver/integration_test.dart --target="${f#app/}" -d "$device" --no-dds --dart-define-from-file=env/e2e.json)
done
