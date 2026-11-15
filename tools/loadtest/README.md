# Load tests (k6)

Five scripts, each with thresholds that fail the run:

| Script | What it does | Passes when |
|---|---|---|
| `last_seat.js` | 1000 users (`VUS=n`) book an event with 5 seats at the same moment | exactly 5 booked, the rest `sold_out`, nothing else |
| `feed.js` | 500 users, then 1000 (`VUS=n`), open Home: `events.feed` (weekend), `events.list_all`, and a search | every call answers with a list, p95 < 400 ms (`FEED_P95_MS` changes the limit) |
| `chat.js` | 50 users send 20 messages each to one host | every message is sent |
| `search_people.js` | 500 users, then 1000, search People by a name or username start | every call answers with a list, p95 < 400 ms (`SEARCH_P95_MS`) |
| `submit_receipt.js` | 500 users (`VUS=n`) each book a seat on a paid event and submit a receipt | every booking and receipt accepted, receipt call p95 < 400 ms (`RECEIPT_P95_MS`) |

For a quick dry run on a laptop use small numbers, for example `BASE=10 VUS=20 USERS=5 tools/loadtest/run.sh feed`
(`BASE` is the first step of the ramp in `feed` and `search_people`).

## Run

Install k6 (`brew install k6`), then:

```
tools/loadtest/run.sh last_seat     # local backend: needs `supabase start`, keys come from `supabase status`
TARGET=staging SERVICE_ROLE_KEY=... tools/loadtest/run.sh feed    # URL and anon key from app/env/staging.json
```

The scripts create users, a host and an event with the admin API, so a run needs the service key. A host now needs approval, and admin functions need a two-factor session:
locally the scripts approve through `public.e2e_review_host` (load `tools/e2e_reset.sql` into the local database first, as
`tools/e2e.sh` does); on a hosted project set `ADMIN_TOKEN` to the access token of an admin who has just signed in to the
back office with the authenticator code (it lasts about an hour). They never print keys.
Test users are named `e2e-load-*@example.com`; `tools/e2e_reset.sql` sweeps them from a local database. On staging they stay
(delete them in the dashboard), and `last_seat` leaves one published event titled "Load last seat ..." behind.

## Shortcut

The scripts share a pool of 20 to 25 accounts between their virtual users (`USERS=n` changes it), because Supabase
allows only 30 password sign-ins per 5 minutes per IP. Nothing in `create_booking` or `send_message` limits one account to
one request, so the race is just as real. To use one account per virtual user, raise that limit on the test project.
