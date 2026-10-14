import type { Outcome, PaymentProvider } from './payment_provider.ts';

// Test rules: a reference ending -FAIL fails, -SLOW stays pending, anything else succeeds.
export function mockOutcome(reference: string): Outcome {
  if (reference.endsWith('-FAIL')) return 'failed';
  if (reference.endsWith('-SLOW')) return 'pending';
  return 'success';
}

export const OUTCOMES: readonly Outcome[] = ['success', 'failed', 'pending'];

export class MockProvider implements PaymentProvider {
  createSession(a: { attemptId: string; reference: string; amountSen: number }) {
    return Promise.resolve({
      sessionUrl: `mock://gateway/${a.attemptId}`,
      expiresAt: new Date(Date.now() + 10 * 60_000).toISOString(),
    });
  }

  async parseWebhook(req: Request) {
    const b = await req.json();
    if (typeof b?.attemptId !== 'string' || typeof b?.method !== 'string' || !OUTCOMES.includes(b?.outcome)) {
      throw new Error('not a gateway result');
    }
    return { attemptId: b.attemptId as string, outcome: b.outcome as Outcome, method: b.method as string };
  }

  refund(a: { reference: string; amountSen: number }) {
    return Promise.resolve({ providerRef: `mock-refund-${a.reference}` });
  }
}
