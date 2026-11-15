// Signed-in users search People (identity.search_people) by a name or username start; 500 users, then 1000.
// The accounts the scripts create get a username at sign-up, so a prefix like "e2e" always has matches.
import { check, sleep } from 'k6';
import { rpc, pool } from './lib.js';

export const options = {
  setupTimeout: '5m',
  scenarios: {
    search: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '20s', target: Number(__ENV.BASE || 500) },
        { duration: '30s', target: Number(__ENV.BASE || 500) },
        { duration: '20s', target: Number(__ENV.VUS || 1000) },
        { duration: '30s', target: Number(__ENV.VUS || 1000) },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate==0'],
    http_req_duration: [`p(95)<${__ENV.SEARCH_P95_MS || 400}`],
    checks: ['rate==1'],
  },
};

const queries = ['e2e', 'load', 'mei', 'ahmad', 'studio'];

export function setup() {
  return { users: pool(Number(__ENV.USERS || 20)) };
}

export default function (data) {
  const user = data.users[__VU % data.users.length];
  const q = queries[__ITER % queries.length];
  const r = rpc('identity', 'search_people', user.token, { p_query: q });
  check(r, { 'search_people answers with a list': (x) => x.status === 200 && Array.isArray(x.json()) });
  sleep(0.5);
}
