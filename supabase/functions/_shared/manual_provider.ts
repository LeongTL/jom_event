import type { PaymentProvider } from './payment_provider.ts';

// Manual transfer: the guest pays the host directly, so there is no session, no webhook and no money to move.
export class ManualTransferProvider implements PaymentProvider {
  createSession(_a: { attemptId: string; reference: string; amountSen: number }) {
    return Promise.resolve({ sessionUrl: '', expiresAt: new Date(Date.now() + 60 * 60_000).toISOString() });
  }

  parseWebhook(_req: Request): Promise<never> {
    return Promise.reject(new Error('not_supported'));
  }

  // The host refunds by hand outside the app; this only gives the record a reference.
  refund(a: { reference: string; amountSen: number }) {
    return Promise.resolve({ providerRef: `manual:${a.reference}` });
  }
}
