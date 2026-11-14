import { assertEquals } from 'jsr:@std/assert@1';
import { handlePush, type PushDeps } from './handler.ts';

const b64 = (o: unknown) => btoa(JSON.stringify(o)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const jwt = (role: string) => `${b64({ alg: 'HS256' })}.${b64({ role })}.sig`;
const req = (auth: string | null, body: unknown = { userId: 'u1', title: 'T', body: 'B', data: { refType: 'receipt', refId: 'r1' } }) =>
  new Request('http://x/send-push', {
    method: 'POST',
    headers: auth ? { authorization: auth, 'content-type': 'application/json' } : {},
    body: JSON.stringify(body),
  });

function deps(tokens: string[], result: (t: string) => 'ok' | 'gone' | 'fail' = () => 'ok') {
  const sent: string[] = [];
  const removed: string[] = [];
  const d: PushDeps = {
    tokens: () => Promise.resolve(tokens),
    fcm: (t) => {
      sent.push(t);
      const r = result(t);
      return r === 'fail' ? Promise.reject(new Error('boom')) : Promise.resolve(r);
    },
    remove: (t) => (removed.push(t), Promise.resolve()),
  };
  return { d, sent, removed };
}

Deno.test('sends_to_every_token_of_the_user', async () => {
  const { d, sent } = deps(['a', 'b']);
  const res = await handlePush(req(`Bearer ${jwt('service_role')}`), d);
  assertEquals(res.status, 200);
  assertEquals(sent, ['a', 'b']);
});

Deno.test('deletes_tokens_fcm_reports_gone', async () => {
  const { d, removed } = deps(['a', 'b'], (t) => (t === 'b' ? 'gone' : 'ok'));
  await handlePush(req(`Bearer ${jwt('service_role')}`), d);
  assertEquals(removed, ['b']);
});

Deno.test('rejects_requests_without_the_service_key', async () => {
  const { d, sent } = deps(['a']);
  assertEquals((await handlePush(req(null), d)).status, 401);
  assertEquals((await handlePush(req(`Bearer ${jwt('authenticated')}`), d)).status, 401);
  assertEquals(sent, []);
});

Deno.test('fcm_failure_for_one_token_does_not_stop_the_others', async () => {
  const { d, sent } = deps(['a', 'b', 'c'], (t) => (t === 'a' ? 'fail' : 'ok'));
  const res = await handlePush(req(`Bearer ${jwt('service_role')}`), d);
  assertEquals(res.status, 200);
  assertEquals(sent, ['a', 'b', 'c']);
});

Deno.test('bad_body_is_a_400', async () => {
  const { d } = deps(['a']);
  assertEquals((await handlePush(req(`Bearer ${jwt('service_role')}`, { nope: 1 }), d)).status, 400);
});
