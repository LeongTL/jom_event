import { createClient } from 'npm:@supabase/supabase-js@2';
import { handleDeleteAccount } from './handler.ts';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

Deno.serve((req) =>
  handleDeleteAccount(req, {
    getUserId: async (jwt) => (await supabase.auth.getUser(jwt)).data.user?.id ?? null,
    erase: async (userId) => {
      const { error } = await supabase.schema('identity').rpc('erase_user', { p_user_id: userId });
      if (error) throw new Error(error.message);
    },
    deleteAuthUser: async (userId) => {
      const { error } = await supabase.auth.admin.deleteUser(userId);
      if (error) throw error;
    },
  })
);
