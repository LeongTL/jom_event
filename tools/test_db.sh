#!/usr/bin/env bash
# Runs every database check. Needs `supabase start`.
# Two phases, because the development seed and the main test suite need different databases:
#   1. an empty database: the whole pgTAP suite and the parallel last-seat race
#   2. the seeded database: the seed checks in supabase/seed_tests
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== phase 1: empty database"
supabase db reset --no-seed
supabase test db
tools/concurrency/last_seat.sh

echo "== phase 2: seeded database"
supabase db reset
supabase test db supabase/seed_tests

echo "all database checks passed"
