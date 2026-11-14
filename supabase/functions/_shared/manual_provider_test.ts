import { assertEquals, assertRejects } from 'jsr:@std/assert@1';
import { ManualTransferProvider } from './manual_provider.ts';

const p = new ManualTransferProvider();

Deno.test('create_session_returns_no_url', async () => {
  const s = await p.createSession({ attemptId: 'a', reference: 'KLS-00001', amountSen: 3000 });
  assertEquals(s.sessionUrl, '');
});

Deno.test('webhook_is_not_supported', async () => {
  await assertRejects(() => p.parseWebhook(new Request('http://x', { method: 'POST' })), Error, 'not_supported');
});

Deno.test('refund_returns_a_manual_reference', async () => {
  assertEquals(await p.refund({ reference: 'KLS-00001', amountSen: 3000 }), { providerRef: 'manual:KLS-00001' });
});
