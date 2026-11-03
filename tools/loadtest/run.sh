#!/usr/bin/env bash
# Runs one k6 script against the local Supabase (default) or a hosted one.
#   tools/loadtest/run.sh last_seat|feed|chat            local, keys read from `supabase status`
#   TARGET=staging SERVICE_ROLE_KEY=... tools/loadtest/run.sh feed    URL and anon key from app/env/staging.json
# Never prints keys.
set -euo pipefail
cd "$(dirname "$0")/../.."
script=${1:?usage: tools/loadtest/run.sh last_seat|feed|chat}
if [ "${TARGET:-local}" = staging ]; then
  : "${SERVICE_ROLE_KEY:?set SERVICE_ROLE_KEY for the staging project}"
  export SUPABASE_URL=$(python3 -c "import json; print(json.load(open('app/env/staging.json'))['SUPABASE_URL'])")
  export SUPABASE_ANON_KEY=$(python3 -c "import json; print(json.load(open('app/env/staging.json'))['SUPABASE_ANON_KEY'])")
else
  status=$(supabase status -o json 2>/dev/null)
  export SUPABASE_URL=$(STATUS="$status" python3 -c "import json,os; print(json.loads(os.environ['STATUS'])['API_URL'])")
  export SUPABASE_ANON_KEY=$(STATUS="$status" python3 -c "import json,os; print(json.loads(os.environ['STATUS'])['ANON_KEY'])")
  export SERVICE_ROLE_KEY=$(STATUS="$status" python3 -c "import json,os; print(json.loads(os.environ['STATUS'])['SERVICE_ROLE_KEY'])")
fi
exec k6 run --quiet "tools/loadtest/$script.js"
