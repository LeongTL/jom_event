import { assertEquals } from 'jsr:@std/assert@1';
import { hmacHex } from '../_shared/signature.ts';
import { MockProvider } from '../_shared/mock_provider.ts';
import { handleWebhook, type WebhookDeps } from './handler.ts';

const SECRET = 'test-secret';
const body = JSON.stringify({ attemptId: 'a1', outcome: 'success', method: 'fpx' });

async function request(opts: { sig?: string; delivery?: string | null; body?: string } = {}) {
  const text = opts.body ?? body;
  const headers = new Headers({ 'content-type': 'application/json' });
  headers.set('x-gateway-signature', opts.sig ?? (await hmacHex(SECRET, text)));
  if (opts.delivery !== null) headers.set('x-delivery-id', opts.delivery ?? 'd1');
  return new Request('http://localhost/payment-webhook', { method: 'POST', headers, body: text });
}

function deps(over: Partial<WebhookDeps> = {}) {
  const calls: unknown[] = [];
  const claimed = new Set<string>();
  const d: WebhookDeps = {
    secret: SECRET,
    provider: new MockProvider(),
    claimDelivery: (id) => Promise.resolve(!claimed.has(id) && !!claimed.add(id)),
    releaseDelivery: (id) => Promise.resolve(void claimed.delete(id)),
    apply: (r) => (calls.push(r), Promise.resolve('confirmed')),
    ...over,
  };
  return { d, calls, claimed };
}

Deno.test('webhook_rejects_bad_signature_with_401', async () => {
  const { d, calls } = deps();
  const res = await handleWebhook(await request({ sig: 'deadbeef' }), d);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('webhook_rejects_a_signature_made_with_another_secret', async () => {
  const { d, calls } = deps();
  const res = await handleWebhook(await request({ sig: await hmacHex('other-secret', body) }), d);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('webhook_rejects_a_body_that_was_changed_after_signing', async () => {
  const { d, calls } = deps();
  const tampered = body.replace('success', 'failed');
  const res = await handleWebhook(await request({ body: tampered, sig: await hmacHex(SECRET, body) }), d);
  assertEquals(res.status, 401);
  assertEquals(calls.length, 0);
});

Deno.test('webhook_applies_a_valid_delivery_once_with_what_the_gateway_said', async () => {
  const { d, calls } = deps();
  const res = await handleWebhook(await request(), d);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { status: 'confirmed' });
  assertEquals(calls, [{ attemptId: 'a1', outcome: 'success', method: 'fpx' }]);
});

Deno.test('webhook_calls_apply_gateway_result_once_for_duplicate_delivery', async () => {
  const { d, calls } = deps();
  const first = await handleWebhook(await request(), d);
  const second = await handleWebhook(await request(), d);
  assertEquals(first.status, 200);
  assertEquals(second.status, 200);
  assertEquals(await second.json(), { duplicate: true });
  assertEquals(calls.length, 1);
});

Deno.test('webhook_lets_the_gateway_retry_after_an_error', async () => {
  let fail = true;
  const attempts: unknown[] = [];
  const { d } = deps({
    apply: (r) => {
      attempts.push(r);
      return fail ? Promise.reject(new Error('db down')) : Promise.resolve('confirmed');
    },
  });
  const first = await handleWebhook(await request(), d);
  assertEquals(first.status, 500);
  fail = false;
  const retry = await handleWebhook(await request(), d);
  assertEquals(retry.status, 200);
  assertEquals(attempts.length, 2);
});

Deno.test('webhook_rejects_a_body_that_is_not_a_result', async () => {
  const { d, calls } = deps();
  const junk = JSON.stringify({ hello: 'world' });
  const res = await handleWebhook(await request({ body: junk }), d);
  assertEquals(res.status, 400);
  assertEquals(calls.length, 0);
});

Deno.test('webhook_needs_a_delivery_id', async () => {
  const { d } = deps();
  const res = await handleWebhook(await request({ delivery: null }), d);
  assertEquals(res.status, 400);
});

Deno.test('webhook_only_accepts_post', async () => {
  const { d } = deps();
  const res = await handleWebhook(new Request('http://localhost/payment-webhook', { method: 'GET' }), d);
  assertEquals(res.status, 405);
});
