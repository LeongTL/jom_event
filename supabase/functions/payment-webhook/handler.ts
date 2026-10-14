import { verifySignature } from '../_shared/signature.ts';
import type { Outcome, PaymentProvider } from '../_shared/payment_provider.ts';

export interface WebhookDeps {
  secret: string;
  provider: PaymentProvider;
  // true the first time a delivery id is seen; false for a repeat of the same delivery
  claimDelivery(deliveryId: string): Promise<boolean>;
  releaseDelivery(deliveryId: string): Promise<void>;
  apply(r: { attemptId: string; outcome: Outcome; method: string }): Promise<string>;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

// The gateway's webhook decides a payment result, never the app screen.
export async function handleWebhook(req: Request, deps: WebhookDeps): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const raw = await req.clone().text();
  const signature = req.headers.get('x-gateway-signature') ?? '';
  if (!(await verifySignature(deps.secret, raw, signature))) return json({ error: 'invalid_signature' }, 401);

  const deliveryId = req.headers.get('x-delivery-id');
  if (!deliveryId) return json({ error: 'missing_delivery_id' }, 400);

  let result;
  try {
    result = await deps.provider.parseWebhook(req);
  } catch {
    return json({ error: 'bad_payload' }, 400);
  }

  if (!(await deps.claimDelivery(deliveryId))) return json({ duplicate: true });
  try {
    return json({ status: await deps.apply(result) });
  } catch {
    // give the delivery back so the gateway's retry is applied instead of being dropped as a duplicate
    await deps.releaseDelivery(deliveryId);
    return json({ error: 'apply_failed' }, 500);
  }
}
