import { createClient } from 'npm:@supabase/supabase-js@2';
import { handleMockPay } from './handler.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(url, serviceKey, { auth: { persistSession: false } });

Deno.serve((req) =>
  handleMockPay(req, {
    flavor: Deno.env.get('FLAVOR') ?? 'prod', // fail closed: no FLAVOR means no mock gateway
    secret: Deno.env.get('GATEWAY_WEBHOOK_SECRET')!,
    getUserId: async (jwt) => (await supabase.auth.getUser(jwt)).data.user?.id ?? null,
    loadAttempt: async (id) => {
      const { data, error } = await supabase.schema('payments').rpc('attempt_info', { p_attempt_id: id });
      if (error) throw error;
      const row = (data as { reference: string; attendee_id: string; status: string }[])[0];
      return row ? { reference: row.reference, attendeeId: row.attendee_id, status: row.status } : null;
    },
    deliver: async (body, signature, deliveryId) =>
      (await fetch(`${url}/functions/v1/payment-webhook`, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-gateway-signature': signature,
          'x-delivery-id': deliveryId,
          authorization: `Bearer ${serviceKey}`,
        },
        body,
      })).status,
  })
);
