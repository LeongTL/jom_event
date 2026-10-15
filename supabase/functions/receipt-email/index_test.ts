import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { buildReceipt, formatMoney, handleReceipt, type ReceiptDeps, type ReceiptPayload } from './handler.ts';

const payload: ReceiptPayload = {
  bookingId: 'b1',
  email: 'bob@example.com',
  name: 'Bob Tan',
  eventTitle: 'Pottery night',
  startsAt: '2030-01-10T12:00:00+00:00', // 8:00 pm in Kuala Lumpur
  venue: 'Clay & Co',
  people: 2,
  amountSen: 6000,
  ticketCode: 'KLS-48111',
};

// The gateway has already checked a token's signature (verify_jwt); the function checks which role it carries.
const b64 = (o: unknown) => btoa(JSON.stringify(o)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const jwt = (role: string) => `${b64({ alg: 'HS256', typ: 'JWT' })}.${b64({ iss: 'supabase', role })}.signature`;
const SERVICE = `Bearer ${jwt('service_role')}`;

function deps(over: Partial<ReceiptDeps> = {}) {
  const sent: { to: string; subject: string; text: string }[] = [];
  const logged: string[] = [];
  const d: ReceiptDeps = {
    send: (m) => (sent.push(m), Promise.resolve()),
    log: (l) => void logged.push(l),
    ...over,
  };
  return { d, sent, logged };
}

const call = (body: unknown, auth: string | null = SERVICE, method = 'POST') =>
  new Request('http://localhost/receipt-email', {
    method,
    headers: auth ? { authorization: auth, 'content-type': 'application/json' } : {},
    body: method === 'POST' ? JSON.stringify(body) : undefined,
  });

Deno.test('formatMoney: Free, whole ringgit and sen', () => {
  assertEquals(formatMoney(0), 'Free');
  assertEquals(formatMoney(4500), 'RM 45');
  assertEquals(formatMoney(4550), 'RM 45.50');
  assertEquals(formatMoney(31860), 'RM 318.60');
});

Deno.test('receipt for a paid booking shows ticket, event, time in Kuala Lumpur, people and total', () => {
  const { subject, text } = buildReceipt(payload);
  assertStringIncludes(subject, 'KLS-48111');
  assertStringIncludes(subject, 'Pottery night');
  for (const part of ['Bob Tan', 'Clay & Co', '2 people', 'RM 60', '8:00', 'Jan']) assertStringIncludes(text, part);
});

Deno.test('receipt for one free spot says Free and 1 person', () => {
  const { text } = buildReceipt({ ...payload, people: 1, amountSen: 0 });
  assertStringIncludes(text, '1 person');
  assertStringIncludes(text, 'Free');
  assert(!text.includes('RM'));
});

Deno.test('receipt endpoint only answers to a service_role token', async () => {
  const { d, sent } = deps();
  assertEquals((await handleReceipt(call(payload, null), d)).status, 401);
  assertEquals((await handleReceipt(call(payload, `Bearer ${jwt('anon')}`), d)).status, 401);
  assertEquals((await handleReceipt(call(payload, `Bearer ${jwt('authenticated')}`), d)).status, 401);
  assertEquals((await handleReceipt(call(payload, 'Bearer not-a-token'), d)).status, 401);
  assertEquals((await handleReceipt(call(payload, `Bearer ${jwt('service_role').split('.')[1]}`), d)).status, 401);
  assertEquals((await handleReceipt(call(payload, jwt('service_role')), d)).status, 401); // no "Bearer"
  assertEquals(sent.length, 0);
});

Deno.test('receipt endpoint accepts any valid service_role token, so a reset of the project keys cannot break it', async () => {
  const { d, sent } = deps();
  assertEquals((await handleReceipt(call(payload, `Bearer ${jwt('service_role')}`), d)).status, 200);
  assertEquals(sent.length, 1);
});

Deno.test('receipt endpoint only accepts POST', async () => {
  const { d } = deps();
  assertEquals((await handleReceipt(new Request('http://localhost/receipt-email', { method: 'GET' }), d)).status, 405);
});

Deno.test('receipt endpoint rejects a body that is not a receipt', async () => {
  const { d, sent } = deps();
  assertEquals((await handleReceipt(call({ hello: 'world' }), d)).status, 400);
  assertEquals((await handleReceipt(call({ ...payload, people: 'two' }), d)).status, 400);
  assertEquals(sent.length, 0);
});

Deno.test('receipt is emailed once to the guest', async () => {
  const { d, sent } = deps();
  const res = await handleReceipt(call(payload), d);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { sent: true });
  assertEquals(sent.length, 1);
  assertEquals(sent[0].to, 'bob@example.com');
  assertStringIncludes(sent[0].subject, 'KLS-48111');
});

Deno.test('a guest who signed in with a phone has no email: nothing is sent, and it is logged', async () => {
  const { d, sent, logged } = deps();
  const res = await handleReceipt(call({ ...payload, email: null }), d);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { skipped: 'no_email' });
  assertEquals(sent.length, 0);
  assertEquals(logged.length, 1);
  assertStringIncludes(logged[0], 'KLS-48111');
});

Deno.test('a sending failure answers 502 so it shows up in the logs', async () => {
  const { d } = deps({ send: () => Promise.reject(new Error('smtp down')) });
  assertEquals((await handleReceipt(call(payload), d)).status, 502);
});
