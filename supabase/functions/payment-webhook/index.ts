import { createClient } from 'npm:@supabase/supabase-js@2';
import { MockProvider } from '../_shared/mock_provider.ts';
import { handleWebhook } from './handler.ts';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});
const payments = supabase.schema('payments');

async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
  const { data, error } = await payments.rpc(fn, args);
  if (error) throw error;
  return data as T;
}

Deno.serve((req) =>
  handleWebhook(req, {
    secret: Deno.env.get('GATEWAY_WEBHOOK_SECRET')!,
    provider: new MockProvider(),
    claimDelivery: (id) => rpc<boolean>('claim_webhook_delivery', { p_delivery_id: id }),
    releaseDelivery: async (id) => void (await rpc('release_webhook_delivery', { p_delivery_id: id })),
    apply: (r) =>
      rpc<string>('apply_gateway_result', { p_attempt_id: r.attemptId, p_outcome: r.outcome, p_method: r.method }),
  })
);
