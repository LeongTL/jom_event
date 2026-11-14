import { createClient } from 'npm:@supabase/supabase-js@2';
import { handlePush } from './handler.ts';

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});
const flavor = Deno.env.get('FLAVOR') ?? 'prod';

const b64url = (b: ArrayBuffer | string) =>
  btoa(typeof b === 'string' ? b : String.fromCharCode(...new Uint8Array(b))).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');

// FCM HTTP v1 wants an OAuth token made from the Firebase service account (secret FCM_SERVICE_ACCOUNT).
async function accessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const head = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = b64url(JSON.stringify({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[A-Z ]+-----|\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${head}.${claim}`));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${head}.${claim}.${b64url(sig)}` }),
  });
  return (await res.json()).access_token;
}

Deno.serve((req) =>
  handlePush(req, {
    tokens: async (userId) => {
      const { data, error } = await supabase.schema('identity').rpc('device_tokens_of', { p_user_id: userId });
      if (error) throw new Error(error.message);
      return data as string[];
    },
    remove: async (token) => {
      await supabase.schema('identity').rpc('remove_device_token', { p_token: token });
    },
    fcm: async (token, title, body, data) => {
      const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
      if (!raw) {
        // shortcut: without a Firebase project, dev and staging only log the push. prod fails loudly.
        if (flavor === 'prod') throw new Error('FCM_SERVICE_ACCOUNT is not set');
        console.log(`PUSH to ${token.slice(0, 8)}: ${title} / ${body}`);
        return 'ok';
      }
      const sa = JSON.parse(raw);
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
        method: 'POST',
        headers: { authorization: `Bearer ${await accessToken(sa)}`, 'content-type': 'application/json' },
        body: JSON.stringify({ message: { token, notification: { title, body }, data } }),
      });
      if (res.status === 404) return 'gone';
      if (!res.ok) throw new Error(`fcm ${res.status}`);
      return 'ok';
    },
  })
);
