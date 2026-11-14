import { assertEquals } from 'jsr:@std/assert@1';
import { handlePurge, type PurgeDeps } from './handler.ts';

const b64 = (o: unknown) => btoa(JSON.stringify(o)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const auth = (role: string) => `Bearer ${b64({ alg: 'HS256' })}.${b64({ role })}.sig`;
const req = (a: string | null) => new Request('http://x/receipt-purge', { method: 'POST', headers: a ? { authorization: a } : {} });

Deno.test('purge_removes_files_through_the_storage_api', async () => {
  const removed: string[][] = [];
  const d: PurgeDeps = { claim: () => Promise.resolve(['a/1.jpg', 'b/2.jpg']), remove: (p) => (removed.push(p), Promise.resolve()) };
  const res = await handlePurge(req(auth('service_role')), d);
  assertEquals(await res.json(), { purged: 2 });
  assertEquals(removed, [['a/1.jpg', 'b/2.jpg']]);
});

Deno.test('nothing_to_purge_calls_no_storage', async () => {
  let called = false;
  const d: PurgeDeps = { claim: () => Promise.resolve([]), remove: () => ((called = true), Promise.resolve()) };
  assertEquals((await handlePurge(req(auth('service_role')), d)).status, 200);
  assertEquals(called, false);
});

Deno.test('purge_needs_the_service_key', async () => {
  const d: PurgeDeps = { claim: () => Promise.resolve(['x']), remove: () => Promise.resolve() };
  assertEquals((await handlePurge(req(null), d)).status, 401);
  assertEquals((await handlePurge(req(auth('authenticated')), d)).status, 401);
});
