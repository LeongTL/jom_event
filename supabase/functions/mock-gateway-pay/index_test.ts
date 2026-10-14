import { assertEquals } from 'jsr:@std/assert@1';
import { verifySignature } from '../_shared/signature.ts';
import { mockOutcome } from '../_shared/mock_provider.ts';
import { handleMockPay, type MockPayDeps } from './handler.ts';

function deps(over: Partial<MockPayDeps> = {}) {
  const delivered: { body: string; sig: string; delivery: string }[] = [];
  const d: MockPayDeps = {
    flavor: 'dev',
    secret: 'test-secret',
    getUserId: (jwt) => Promise.resolve(jwt === 'good' ? 'user-1' : null),
    loadAttempt: (id) =>
      Promise.resolve(id === 'a1' ? { reference: 'KLS-00001-AB12CD34', attendeeId: 'user-1', status: 'created' } : null),
    deliver: (body, sig, delivery) => (delivered.push({ body, sig, delivery }), Promise.resolve(200)),
    ...over,
  };
  return { d, delivered };
}

const call = (payload: unknown, token: string | null = 'good', method = 'POST') =>
  new Request('http://localhost/mock-gateway-pay', {
    method,
    headers: token ? { authorization: `Bearer ${token}`, 'content-type': 'application/json' } : {},
    body: method === 'POST' ? JSON.stringify(payload) : undefined,
  });

Deno.test('mockOutcome: a reference ending -FAIL fails, -SLOW stays pending, anything else succeeds', () => {
  assertEquals(mockOutcome('KLS-00001-FAIL'), 'failed');
  assertEquals(mockOutcome('KLS-00001-SLOW'), 'pending');
  assertEquals(mockOutcome('KLS-00001-AB12CD34'), 'success');
});

Deno.test('mock gateway is not found in prod', async () => {
  const { d, delivered } = deps({ flavor: 'prod' });
  const res = await handleMockPay(call({ attemptId: 'a1', method: 'fpx' }), d);
  assertEquals(res.status, 404);
  assertEquals(delivered.length, 0);
});

Deno.test('mock gateway needs a signed-in user', async () => {
  const { d } = deps();
  assertEquals((await handleMockPay(call({ attemptId: 'a1', method: 'fpx' }, null), d)).status, 401);
  assertEquals((await handleMockPay(call({ attemptId: 'a1', method: 'fpx' }, 'bad'), d)).status, 401);
});

Deno.test('mock gateway only lets the owner pay an attempt', async () => {
  const { d, delivered } = deps({ getUserId: () => Promise.resolve('someone-else') });
  const res = await handleMockPay(call({ attemptId: 'a1', method: 'fpx' }), d);
  assertEquals(res.status, 403);
  assertEquals(delivered.length, 0);
});

Deno.test('mock gateway reports an unknown attempt', async () => {
  const { d } = deps();
  assertEquals((await handleMockPay(call({ attemptId: 'nope', method: 'fpx' }), d)).status, 404);
});

Deno.test('mock gateway sends a signed success webhook for a normal reference', async () => {
  const { d, delivered } = deps();
  const res = await handleMockPay(call({ attemptId: 'a1', method: 'fpx' }), d);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { outcome: 'success' });
  assertEquals(delivered.length, 1);
  assertEquals(JSON.parse(delivered[0].body), { attemptId: 'a1', outcome: 'success', method: 'fpx' });
  assertEquals(await verifySignature('test-secret', delivered[0].body, delivered[0].sig), true);
});

Deno.test('mock gateway lets the dev screen force failed or pending', async () => {
  const failed = deps();
  await handleMockPay(call({ attemptId: 'a1', method: 'card', forceOutcome: 'failed' }), failed.d);
  assertEquals(JSON.parse(failed.delivered[0].body).outcome, 'failed');
  const slow = deps();
  await handleMockPay(call({ attemptId: 'a1', method: 'card', forceOutcome: 'pending' }), slow.d);
  assertEquals(JSON.parse(slow.delivered[0].body).outcome, 'pending');
});

Deno.test('mock gateway follows a -FAIL reference when nothing is forced', async () => {
  const { d, delivered } = deps({
    loadAttempt: () => Promise.resolve({ reference: 'KLS-00001-FAIL', attendeeId: 'user-1', status: 'created' }),
  });
  await handleMockPay(call({ attemptId: 'a1', method: 'fpx' }), d);
  assertEquals(JSON.parse(delivered[0].body).outcome, 'failed');
});

Deno.test('mock gateway rejects an unknown forced outcome and a missing method', async () => {
  const { d, delivered } = deps();
  assertEquals((await handleMockPay(call({ attemptId: 'a1', method: 'fpx', forceOutcome: 'maybe' }), d)).status, 400);
  assertEquals((await handleMockPay(call({ attemptId: 'a1' }), d)).status, 400);
  assertEquals(delivered.length, 0);
});

Deno.test('mock gateway answers 502 when the webhook did not accept the result', async () => {
  const { d } = deps({ deliver: () => Promise.resolve(500) });
  assertEquals((await handleMockPay(call({ attemptId: 'a1', method: 'fpx' }), d)).status, 502);
});
