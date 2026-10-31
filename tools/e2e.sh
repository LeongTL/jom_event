#!/usr/bin/env bash
# End-to-end journeys against the local Supabase, on a booted simulator or emulator.
# Needs: `supabase start`, `supabase functions serve --no-verify-jwt --env-file <FLAVOR=dev + GATEWAY_WEBHOOK_SECRET>`.
# Usage: tools/e2e.sh <device id> [journey file ...]   (default: every *_journey_test.dart)
# E2E_TIMEOUT=<seconds> stops a journey that hangs (CI sets it; needs GNU timeout).
# E2E_API_HOST=10.0.2.2 makes the app reach Supabase from an Android emulator (it cannot see the host's 127.0.0.1).
set -euo pipefail
cd "$(dirname "$0")/.."
device=${1:?usage: tools/e2e.sh <device id> [journey file ...]}
shift || true

mkdir -p app/env
supabase status -o json | python3 -c '
import json, sys
s = json.load(sys.stdin)
import os
url = s["API_URL"].replace("127.0.0.1", os.environ.get("E2E_API_HOST", "127.0.0.1"))
json.dump({"FLAVOR": "dev", "SUPABASE_URL": url, "SUPABASE_ANON_KEY": s["ANON_KEY"],
           "SERVICE_ROLE_KEY": s["SERVICE_ROLE_KEY"]}, open("app/env/e2e.json", "w"))'

db=$(docker ps --format '{{.Names}}' | grep '^supabase_db_' | head -1)
if [ "$#" -gt 0 ]; then files=("$@"); else files=(app/integration_test/*_journey_test.dart); fi
for f in "${files[@]}"; do
  # iOS simulators: the location prompt would cover the app. The app stays installed between runs (--keep-app-running),
  # so this grant sticks; on a brand-new simulator accept the prompt once by hand.
  xcrun simctl privacy "$device" grant location com.jom.jom >/dev/null 2>&1 || true
  echo "== $(basename "$f")"
  docker exec -i "$db" psql -U postgres -v ON_ERROR_STOP=1 -q < tools/e2e_reset.sql
  # drive, not test: `flutter test` cannot start its debug service on the simulator; `--no-dds` with drive works
  out=$(mktemp)
  (cd app && ${E2E_TIMEOUT:+timeout "$E2E_TIMEOUT"} flutter drive --driver=test_driver/integration_test.dart --target="${f#app/}" -d "$device" --no-dds --keep-app-running --dart-define-from-file=env/e2e.json) 2>&1 | tee "$out"
  # a compile error is only printed: drive then runs the app that was installed before, so fail on it here
  if grep -q 'Error output from Xcode build\|Gradle task .* failed' "$out"; then echo "build failed: $f" >&2; exit 1; fi
  grep -q 'All tests passed' "$out" || { echo "journey failed: $f" >&2; exit 1; }
done
