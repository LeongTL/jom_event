// 50 users send 20 messages each to one host: no message may fail.
import { check } from 'k6';
import { rpc, newHost, pool } from './lib.js';

export const options = {
  setupTimeout: '5m',
  scenarios: { chat: { executor: 'per-vu-iterations', vus: 50, iterations: 20, maxDuration: '5m' } },
  thresholds: {
    http_req_failed: ['rate==0'],
    checks: ['rate==1'],
  },
};

export function setup() {
  const host = newHost('Load Chat Host');
  const guests = pool(Number(__ENV.USERS || 25));
  for (const g of guests) {
    const t = rpc('chat', 'open_thread', g.token, { p_host_id: host.id });
    if (t.status !== 200) throw new Error(`open_thread: ${t.status} ${t.body}`);
    g.thread = t.json();
  }
  return { guests };
}

export default function (data) {
  const g = data.guests[__VU % data.guests.length];
  const r = rpc('chat', 'send_message', g.token, { p_thread_id: g.thread, p_body: `Load message ${__VU} of ${__ITER}` });
  check(r, { 'message sent': (x) => x.status === 200 });
}
