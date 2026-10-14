import { hmacHex } from '../_shared/signature.ts';
import { mockOutcome, OUTCOMES } from '../_shared/mock_provider.ts';
import type { Outcome } from '../_shared/payment_provider.ts';

export interface MockPayDeps {
  flavor: string;
  secret: string;
  getUserId(jwt: string): Promise<string | null>;
  loadAttempt(attemptId: string): Promise<{ reference: string; attendeeId: string; status: string } | null>;
  // posts the signed webhook; resolves with its HTTP status
  deliver(body: string, signature: string, deliveryId: string): Promise<number>;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

// Stands in for the gateway's hosted page in dev and staging: the app's Gateway screen calls this, and it
// sends the signed webhook that really decides the payment. There is no mock gateway in prod.
export async function handleMockPay(req: Request, deps: MockPayDeps): Promise<Response> {
  if (deps.flavor === 'prod') return json({ error: 'not_found' }, 404);
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const jwt = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  const userId = jwt ? await deps.getUserId(jwt) : null;
  if (!userId) return json({ error: 'unauthorized' }, 401);

  let body: { attemptId?: unknown; method?: unknown; forceOutcome?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  const { attemptId, method, forceOutcome } = body;
  if (typeof attemptId !== 'string' || typeof method !== 'string' || !method) return json({ error: 'bad_request' }, 400);
  if (forceOutcome !== undefined && !OUTCOMES.includes(forceOutcome as Outcome)) return json({ error: 'bad_request' }, 400);

  const attempt = await deps.loadAttempt(attemptId);
  if (!attempt) return json({ error: 'attempt_not_found' }, 404);
  if (attempt.attendeeId !== userId) return json({ error: 'forbidden' }, 403);

  const outcome = (forceOutcome as Outcome | undefined) ?? mockOutcome(attempt.reference);
  const payload = JSON.stringify({ attemptId, outcome, method });
  const status = await deps.deliver(payload, await hmacHex(deps.secret, payload), crypto.randomUUID());
  return status >= 200 && status < 300 ? json({ outcome }) : json({ error: 'webhook_failed' }, 502);
}
