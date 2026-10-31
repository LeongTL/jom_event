// 100 users open Home: the This weekend carousel (events.feed), the Near you list (events.list_all) and a search,
// from Bangsar with the radius widened to all of KL.
import { check, sleep } from 'k6';
import { rpc } from './lib.js';

export const options = {
  vus: 100,
  duration: '30s',
  thresholds: {
    http_req_failed: ['rate==0'],
    http_req_duration: [`p(95)<${__ENV.FEED_P95_MS || 400}`],
    checks: ['rate==1'],
  },
};

const here = { p_lat: 3.129, p_lng: 101.671, p_km: 50 };

export default function () {
  const calls = [
    ['feed', { ...here, p_tab: 'weekend' }],
    ['list_all', { ...here, p_category: 'all' }],
    ['list_all', { ...here, p_category: 'all', p_query: 'run' }],
  ];
  for (const [fn, body] of calls) {
    const r = rpc('events', fn, null, body);
    check(r, { [`${fn} answers with a list`]: (x) => x.status === 200 && Array.isArray(x.json()) });
  }
  sleep(0.5);
}
