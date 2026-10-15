import { assertEquals } from 'jsr:@std/assert@1';
import { type DeleteDeps, handleDeleteAccount } from './handler.ts';

function deps(over: Partial<DeleteDeps> = {}) {
  const calls: string[] = [];
  const d: DeleteDeps = {
    getUserId: (jwt) => Promise.resolve(jwt === 'good' ? 'user-1' : null),
    erase: (id) => (calls.push(`erase:${id}`), Promise.resolve()),
    deleteAuthUser: (id) => (calls.push(`auth:${id}`), Promise.resolve()),
    ...over,
  };
  return { d, calls };
}

const call = (token: string | null = 'good', method = 'POST') =>
  new Request('http://localhost/delete-account', {
    method,
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });

Deno.test('delete_account_requires_auth', async () => {
  const { d, calls } = deps();
  assertEquals((await handleDeleteAccount(call(null), d)).status, 401);
  assertEquals((await handleDeleteAccount(call('bad'), d)).status, 401);
  assertEquals(calls, []);
});

Deno.test('delete_account_only_accepts_post', async () => {
  const { d, calls } = deps();
  assertEquals((await handleDeleteAccount(call('good', 'GET'), d)).status, 405);
  assertEquals(calls, []);
});

Deno.test('delete_account_anonymises_profile_and_removes_personal_rows: erases the data first, then the sign-in account', async () => {
  const { d, calls } = deps();
  const res = await handleDeleteAccount(call(), d);
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { deleted: true });
  assertEquals(calls, ['erase:user-1', 'auth:user-1']);
});

Deno.test('delete_account_refuses_host_with_active_events: nothing is deleted, not even the sign-in', async () => {
  const { d, calls } = deps({ erase: () => Promise.reject(new Error('host_has_active_events')) });
  const res = await handleDeleteAccount(call(), d);
  assertEquals(res.status, 409);
  assertEquals(await res.json(), { error: 'host_has_active_events' });
  assertEquals(calls, []);
});

Deno.test('delete_account_refuses_a_host_who_is_still_owed_a_payout', async () => {
  const { d, calls } = deps({ erase: () => Promise.reject(new Error('host_has_pending_payouts')) });
  const res = await handleDeleteAccount(call(), d);
  assertEquals(res.status, 409);
  assertEquals(await res.json(), { error: 'host_has_pending_payouts' });
  assertEquals(calls, []);
});

Deno.test('an unexpected erase failure answers 500 and keeps the sign-in so the user can retry', async () => {
  const { d, calls } = deps({ erase: () => Promise.reject(new Error('connection reset')) });
  assertEquals((await handleDeleteAccount(call(), d)).status, 500);
  assertEquals(calls, []);
});

Deno.test('if removing the sign-in fails the data is already erased and a retry finishes the job', async () => {
  const { d } = deps({ deleteAuthUser: () => Promise.reject(new Error('auth down')) });
  const res = await handleDeleteAccount(call(), d);
  assertEquals(res.status, 502);
  assertEquals(await res.json(), { error: 'auth_delete_failed' });
});
