// Each virtual user books a seat on a paid event and uploads a transfer receipt (payments.submit_receipt).
// The image itself is not uploaded: the function only checks the path starts with the booking id. VUS=n changes the
// number of users (default 500); the event has room for all of them.
import { check } from 'k6';
import { Trend } from 'k6/metrics';
import { rpc, newHost, publishEvent, pool, uniqueWord } from './lib.js';

const VUS = Number(__ENV.VUS || 500);
const submitMs = new Trend('submit_receipt_ms', true);

export const options = {
  setupTimeout: '5m',
  scenarios: { upload: { executor: 'per-vu-iterations', vus: VUS, iterations: 1, maxDuration: '5m' } },
  thresholds: {
    checks: ['rate==1'],
    submit_receipt_ms: [`p(95)<${__ENV.RECEIPT_P95_MS || 400}`],
  },
};

export function setup() {
  const host = newHost('Load Receipt Host');
  const eventId = publishEvent(host, { title: `Load receipts ${uniqueWord()}`, capacity: VUS + 10, priceSen: 3000 });
  return { eventId, users: pool(Number(__ENV.USERS || 20)) };
}

export default function (data) {
  const user = data.users[__VU % data.users.length];
  const booked = rpc('bookings', 'create_booking', user.token, {
    p_event_id: data.eventId, p_people: 1, p_name: 'Load Guest', p_phone: '60111111111',
  });
  if (!check(booked, { 'booking made': (x) => x.status === 200 })) return;
  const id = booked.json('id');
  const sent = rpc('payments', 'submit_receipt', user.token, { p_booking_id: id, p_image_path: `${id}/receipt.jpg` });
  submitMs.add(sent.timings.duration);
  check(sent, { 'receipt accepted': (x) => x.status === 200 });
}
