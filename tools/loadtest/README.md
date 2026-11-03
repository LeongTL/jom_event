# Load tests (k6)

Three scripts, each with thresholds that fail the run:

| Script | What it does | Passes when |
|---|---|---|
| `last_seat.js` | 200 users book an event with 5 seats at the same moment | exactly 5 booked, 195 `sold_out`, nothing else |
| `feed.js` | 100 users open Home for 30 s: `events.feed` (weekend), `events.list_all`, and a search | every call answers with a list, p95 < 400 ms (`FEED_P95_MS` changes the limit) |
| `chat.js` | 50 users send 20 messages each to one host | every message is sent |

## Run

Install k6 (`brew install k6`), then:

```
tools/loadtest/run.sh last_seat     # local backend: needs `supabase start`, keys come from `supabase status`
TARGET=staging SERVICE_ROLE_KEY=... tools/loadtest/run.sh feed    # URL and anon key from app/env/staging.json
```

The scripts create users, a host and an event with the admin API, so a run needs the service key. They never print keys.
Test users are named `e2e-load-*@example.com`; `tools/e2e_reset.sql` sweeps them from a local database. On staging they stay
(delete them in the dashboard), and `last_seat` leaves one published event titled "Load last seat ..." behind.

## Shortcut

The scripts share a pool of 20 to 25 accounts between their virtual users (`USERS=n` changes it), because Supabase
allows only 30 password sign-ins per 5 minutes per IP. Nothing in `create_booking` or `send_message` limits one account to
one request, so the race is just as real. To use one account per virtual user, raise that limit on the test project.
