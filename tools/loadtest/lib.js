// Shared by the k6 scripts: users, a host with a published event, and the RPC call the app makes.
import http from 'k6/http';

const URL = __ENV.SUPABASE_URL;
const ANON = __ENV.SUPABASE_ANON_KEY;
const SERVICE = __ENV.SERVICE_ROLE_KEY;
const JSON_HEADERS = { 'Content-Type': 'application/json' };

// Digit-free: long digit runs in event text are refused as phone numbers.
export const uniqueWord = () => String(Date.now()).replace(/\d/g, (d) => 'abcdefghij'[d]);

export function rpc(schema, fn, token, body) {
  return http.post(`${URL}/rest/v1/rpc/${fn}`, JSON.stringify(body), {
    headers: { ...JSON_HEADERS, apikey: ANON, Authorization: `Bearer ${token || ANON}`, 'Content-Profile': schema },
  });
}

// Email prefix e2e- so tools/e2e_reset.sql sweeps these users away on a local database.
export function newUser(tag) {
  const email = `e2e-load-${Date.now()}-${tag}@example.com`;
  const password = 'e2e-load-pass-123';
  const made = http.post(`${URL}/auth/v1/admin/users`, JSON.stringify({ email, password, email_confirm: true }), {
    headers: { ...JSON_HEADERS, apikey: SERVICE, Authorization: `Bearer ${SERVICE}` },
  });
  if (made.status !== 200) throw new Error(`create user: ${made.status} ${made.body}`);
  const login = http.post(`${URL}/auth/v1/token?grant_type=password`, JSON.stringify({ email, password }), {
    headers: { ...JSON_HEADERS, apikey: ANON },
  });
  if (login.status !== 200) throw new Error(`sign in: ${login.status} ${login.body}`);
  return { id: login.json('user.id'), token: login.json('access_token') };
}

// An admin approves the hosts the scripts create (host registration needs approval). With ADMIN_EMAIL and
// ADMIN_PASSWORD it signs in an admin you gave the role by hand (the hosted project); without them it makes one
// through public.e2e_make_admin, which exists only on a local database after tools/e2e_reset.sql.
let admin;
function adminUser() {
  if (admin) return admin;
  if (__ENV.ADMIN_EMAIL) {
    const login = http.post(`${URL}/auth/v1/token?grant_type=password`,
      JSON.stringify({ email: __ENV.ADMIN_EMAIL, password: __ENV.ADMIN_PASSWORD }), { headers: { ...JSON_HEADERS, apikey: ANON } });
    if (login.status !== 200) throw new Error(`admin sign in: ${login.status} ${login.body}`);
    admin = { id: login.json('user.id'), token: login.json('access_token') };
  } else {
    admin = newUser('admin');
    const made = rpc('public', 'e2e_make_admin', SERVICE, { p_user_id: admin.id });
    if (made.status >= 300) throw new Error(`e2e_make_admin: ${made.status} ${made.body} (run tools/e2e_reset.sql on a local database or set ADMIN_EMAIL and ADMIN_PASSWORD)`);
  }
  return admin;
}

export function newHost(name) {
  const host = newUser('host');
  const r = rpc('identity', 'apply_host', host.token, {
    host_name: name, area: 'Bangsar', bio: null, account_holder: name, bank: 'Maybank', account_number: '1234564821',
  });
  if (r.status >= 300) throw new Error(`apply_host: ${r.status} ${r.body}`);
  const ok = rpc('identity', 'admin_review_host', adminUser().token, { p_user_id: host.id, p_decision: 'approve', p_reason: null });
  if (ok.status >= 300) throw new Error(`admin_review_host: ${ok.status} ${ok.body}`);
  return host;
}

export function publishEvent(host, { title, capacity, priceSen }) {
  const start = new Date(Date.now() + 26 * 3600 * 1000);
  const saved = rpc('events', 'save_draft', host.token, {
    payload: {
      title, description: 'A load test event.', categories: ['make'], area: 'Bangsar', venue: 'Test Deck',
      starts_at: start.toISOString(), ends_at: new Date(start.getTime() + 2 * 3600 * 1000).toISOString(),
      capacity, price_sen: priceSen, cancel_policy: '24h', accept_bookings: true,
    },
  });
  if (saved.status >= 300) throw new Error(`save_draft: ${saved.status} ${saved.body}`);
  const id = saved.json();
  const pub = rpc('events', 'publish', host.token, { event_id: id });
  if (pub.status >= 300) throw new Error(`publish: ${pub.status} ${pub.body}`);
  return id;
}

// shortcut: scripts share a pool of accounts between their virtual users, because Supabase allows 30 password
// sign-ins per 5 minutes per IP; upgrade: raise that limit on the test project and set USERS to the VU count.
export function pool(n) {
  return Array.from({ length: n }, (_, i) => newUser(`u${i}`));
}
