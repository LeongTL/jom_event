import { assert, assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import { handleSharePage, type SharePageDeps } from './handler.ts';

const base = 'https://share.example.invalid';
const event = {
  title: 'Sunset yoga',
  starts_at: '2030-01-12T10:00:00Z',
  ends_at: '2030-01-12T12:00:00Z',
  area: 'Bangsar',
  venue: 'Deck 5',
  price_sen: 3000,
  poster_url: 'https://img.invalid/p.jpg',
  host_name: 'Mei Studio',
  status: 'published',
  is_private: false,
};
const person = { name: 'Mei Studio', username: 'meihost', is_host: true, avatar_url: 'https://img.invalid/a.jpg', area: 'Bangsar' };

function deps(over: Partial<SharePageDeps> = {}): SharePageDeps {
  return {
    baseUrl: base,
    androidPackage: 'com.jom.jom',
    androidSha256: 'AA:BB',
    iosTeamId: 'TEAM123',
    iosBundleId: 'com.jom.jom',
    playUrl: 'https://play.invalid/jom',
    appStoreUrl: 'https://apps.invalid/jom',
    eventPreview: (code) => Promise.resolve(code === 'GOODCODE01' ? event : code === 'PRIVCODE02' ? { ...event, is_private: true } : null),
    personPreview: (u) => Promise.resolve(u === 'meihost' ? person : null),
    ...over,
  };
}
const get = (path: string, d = deps(), method = 'GET') => handleSharePage(new Request(`https://x.invalid${path}`, { method }), d);

Deno.test('an event page carries the preview tags and both buttons', async () => {
  const res = await get('/e/GOODCODE01');
  assertEquals(res.status, 200);
  assertStringIncludes(res.headers.get('content-type')!, 'text/html');
  const html = await res.text();
  assertStringIncludes(html, '<meta property="og:title" content="Sunset yoga">');
  assertStringIncludes(html, '<meta property="og:image" content="https://img.invalid/p.jpg">');
  assertStringIncludes(html, `<meta property="og:url" content="${base}/e/GOODCODE01">`);
  assertStringIncludes(html, '<meta name="twitter:card" content="summary_large_image">');
  assertStringIncludes(html, 'Bangsar');
  assertStringIncludes(html, 'RM 30');
  assertStringIncludes(html, 'href="jom://e/GOODCODE01"');
  assertStringIncludes(html, 'Get the app');
  assert(!html.includes('noindex'), 'a public event may be indexed');
});

Deno.test('the page works under the Supabase function path too', async () => {
  assertEquals((await get('/functions/v1/share-page/e/GOODCODE01')).status, 200);
});

Deno.test('a free event says Free and an event with no poster uses the default image', async () => {
  const d = deps({ eventPreview: () => Promise.resolve({ ...event, price_sen: 0, poster_url: null }) });
  const html = await (await get('/e/GOODCODE01', d)).text();
  assertStringIncludes(html, 'Free');
  assertStringIncludes(html, `<meta property="og:image" content="${base}/default-share.png">`);
});

Deno.test('a private event is shown to anyone with the link, marked noindex', async () => {
  const res = await get('/e/PRIVCODE02');
  assertEquals(res.status, 200);
  assertStringIncludes(await res.text(), '<meta name="robots" content="noindex">');
});

Deno.test('a wrong, cancelled or odd code is a friendly 404, never an error', async () => {
  for (const path of ['/e/NOPE', '/e/' + 'x'.repeat(200), '/e/a%2Fb', '/e/', '/e/%E0%A4%A']) {
    const res = await get(path);
    assertEquals(res.status, 404, path);
    assertStringIncludes(await res.text(), 'This event is not available');
  }
});

Deno.test('a lookup that throws is a 404 page, not a crash', async () => {
  const res = await get('/e/GOODCODE01', deps({ eventPreview: () => Promise.reject(new Error('db down')) }));
  assertEquals(res.status, 404);
});

Deno.test('every value is escaped', async () => {
  const d = deps({ eventPreview: () => Promise.resolve({ ...event, title: '<script>alert("x")</script> & "q"', area: "O'Neil" }) });
  const html = await (await get('/e/GOODCODE01', d)).text();
  assert(!html.includes('<script>alert'));
  assertStringIncludes(html, '&lt;script&gt;');
  assertStringIncludes(html, '&amp;');
  assertStringIncludes(html, '&quot;q&quot;');
});

Deno.test('every page is cached only briefly', async () => {
  for (const path of ['/e/GOODCODE01', '/e/NOPE', '/u/meihost']) {
    const cc = (await get(path)).headers.get('cache-control') ?? '';
    assert(/max-age=(\d+)/.test(cc) && Number(/max-age=(\d+)/.exec(cc)![1]) <= 300, `${path}: ${cc}`);
  }
});

Deno.test('a person page carries the preview tags', async () => {
  const res = await get('/u/meihost');
  assertEquals(res.status, 200);
  const html = await res.text();
  assertStringIncludes(html, '<meta property="og:title" content="Mei Studio">');
  assertStringIncludes(html, '@meihost');
  assertStringIncludes(html, `<meta property="og:url" content="${base}/u/meihost">`);
  assertStringIncludes(html, 'href="jom://u/meihost"');
});

Deno.test('an unknown person is a 404', async () => {
  const res = await get('/u/nobody');
  assertEquals(res.status, 404);
  assertStringIncludes(await res.text(), 'This profile is not available');
});

Deno.test('assetlinks.json names the package and certificate', async () => {
  const res = await get('/.well-known/assetlinks.json');
  assertEquals(res.status, 200);
  assertStringIncludes(res.headers.get('content-type')!, 'application/json');
  const j = await res.json();
  assertEquals(j[0].relation, ['delegate_permission/common.handle_all_urls']);
  assertEquals(j[0].target.package_name, 'com.jom.jom');
  assertEquals(j[0].target.sha256_cert_fingerprints, ['AA:BB']);
});

Deno.test('apple-app-site-association has no extension and names the app and the paths', async () => {
  const res = await get('/.well-known/apple-app-site-association');
  assertEquals(res.status, 200);
  assertStringIncludes(res.headers.get('content-type')!, 'application/json');
  const j = await res.json();
  assertEquals(j.applinks.details[0].appIDs, ['TEAM123.com.jom.jom']);
  assertEquals(j.applinks.details[0].paths, ['/e/*', '/u/*']);
});

Deno.test('an unknown path is 404 and HEAD works', async () => {
  assertEquals((await get('/nothing')).status, 404);
  const head = await get('/e/GOODCODE01', deps(), 'HEAD');
  assertEquals(head.status, 200);
  assertEquals(await head.text(), '');
});

Deno.test('with no base url configured the page still renders without an og:url', async () => {
  const html = await (await get('/e/GOODCODE01', deps({ baseUrl: '' }))).text();
  assert(!html.includes('og:url'));
});
