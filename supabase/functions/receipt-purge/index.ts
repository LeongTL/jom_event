import { createClient } from 'npm:@supabase/supabase-js@2';
import { handlePurge } from './handler.ts';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

Deno.serve((req) =>
  handlePurge(req, {
    claim: async () => {
      const { data, error } = await supabase.schema('payments').rpc('claim_expired_receipt_files');
      if (error) throw new Error(error.message);
      return (data as { image_path: string }[]).map((r) => r.image_path);
    },
    remove: async (paths) => {
      const { error } = await supabase.storage.from('receipts').remove(paths);
      if (error) throw new Error(error.message);
    },
  })
);
