import { createClient } from 'npm:@supabase/supabase-js@2';
import { handleSharePage } from './handler.ts';

// Public: it answers link previews and people without an account, so it reads only through the two preview
// functions, with the anon key. Settings come from the function's environment (see docs/release/sharing.md).
const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
  auth: { persistSession: false },
});

const env = (k: string) => Deno.env.get(k) ?? '';

Deno.serve((req) =>
  handleSharePage(req, {
    baseUrl: env('SHARE_BASE_URL'),
    androidPackage: 'com.jom.jom',
    androidSha256: env('ANDROID_CERT_SHA256'),
    iosTeamId: env('IOS_TEAM_ID'),
    iosBundleId: 'com.jom.jom',
    playUrl: env('PLAY_STORE_URL'),
    appStoreUrl: env('APP_STORE_URL'),
    eventPreview: async (code) => {
      const { data, error } = await supabase.schema('events').rpc('share_preview', { p_code: code });
      if (error) throw new Error(error.message);
      return (data as unknown[])[0] as never ?? null;
    },
    personPreview: async (username) => {
      const { data, error } = await supabase.schema('identity').rpc('person_preview', { p_username: username });
      if (error) throw new Error(error.message);
      return (data as unknown[])[0] as never ?? null;
    },
  })
);
