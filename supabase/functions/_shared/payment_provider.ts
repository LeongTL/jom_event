// Every payment gateway sits behind this interface. The MVP ships MockProvider only; a real gateway
// is a new implementation (and a new design), nothing else changes.
export type Outcome = 'success' | 'failed' | 'pending';

export interface PaymentProvider {
  createSession(a: { attemptId: string; reference: string; amountSen: number }): Promise<{ sessionUrl: string; expiresAt: string }>;
  parseWebhook(req: Request): Promise<{ attemptId: string; outcome: Outcome; method: string }>;
  refund(a: { reference: string; amountSen: number }): Promise<{ providerRef: string }>;
}
