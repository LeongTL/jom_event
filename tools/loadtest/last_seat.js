// 200 virtual users book the last 5 seats of one event at the same moment: exactly 5 must get a seat, the rest sold_out.
import { Counter } from 'k6/metrics';
import { rpc, newHost, publishEvent, pool, uniqueWord } from './lib.js';

const SEATS = 5;
const VUS = 200;
const booked = new Counter('booked');
const soldOut = new Counter('sold_out');
const other = new Counter('other_errors');

export const options = {
  setupTimeout: '5m',
  scenarios: { race: { executor: 'per-vu-iterations', vus: VUS, iterations: 1, maxDuration: '2m' } },
  thresholds: {
    booked: [`count==${SEATS}`],
    sold_out: [`count==${VUS - SEATS}`],
    other_errors: ['count==0'],
  },
};

export function setup() {
  const host = newHost('Load Host');
  const eventId = publishEvent(host, { title: `Load last seat ${uniqueWord()}`, capacity: SEATS, priceSen: 3000 });
  return { eventId, users: pool(Number(__ENV.USERS || 20)) };
}

export default function (data) {
  const user = data.users[__VU % data.users.length];
  const r = rpc('bookings', 'create_booking', user.token, {
    p_event_id: data.eventId, p_people: 1, p_name: 'Load Guest', p_phone: '60111111111',
  });
  if (r.status === 200) booked.add(1);
  else if (String(r.body).includes('sold_out')) soldOut.add(1);
  else {
    other.add(1);
    console.error(`unexpected: ${r.status} ${r.body}`);
  }
}
