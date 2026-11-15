// The web page behind a shared link. WhatsApp and Telegram fetch it for the preview card; a person without the app
// lands on it and taps Open in the app or Get the app. Pure: the database lookups and the settings come in as deps.

export interface EventPreview {
  title: string;
  starts_at: string | null;
  ends_at: string | null;
  area: string | null;
  venue: string | null;
  price_sen: number;
  poster_url: string | null;
  host_name: string | null;
  status: string;
  is_private: boolean;
}

export interface PersonPreview {
  name: string;
  username: string;
  is_host: boolean;
  avatar_url: string | null;
  area: string | null;
}

export interface SharePageDeps {
  /** The public address of this site, from the SHARE_BASE_URL setting. Empty means not set up yet. */
  baseUrl: string;
  androidPackage: string;
  androidSha256: string;
  iosTeamId: string;
  iosBundleId: string;
  playUrl: string;
  appStoreUrl: string;
  eventPreview(code: string): Promise<EventPreview | null>;
  personPreview(username: string): Promise<PersonPreview | null>;
}

const esc = (s: string) =>
  s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');

const CODE = /^[A-Za-z0-9_-]{1,64}$/;
const USERNAME = /^[a-z0-9_][a-z0-9_.]{1,18}[a-z0-9_]$/;
const CACHE = 'public, max-age=60';

const when = (iso: string | null) =>
  iso
    ? new Intl.DateTimeFormat('en-MY', {
      weekday: 'short', day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kuala_Lumpur',
    }).format(new Date(iso))
    : '';

const price = (sen: number) => (sen <= 0 ? 'Free' : `RM ${sen % 100 === 0 ? sen / 100 : (sen / 100).toFixed(2)}`);

function page(status: number, o: {
  title: string;
  description: string;
  image?: string;
  url?: string;
  noindex?: boolean;
  openLink?: string;
  d: SharePageDeps;
  head: boolean;
}): Response {
  const meta = [
    `<meta property="og:title" content="${esc(o.title)}">`,
    `<meta property="og:description" content="${esc(o.description)}">`,
    o.image ? `<meta property="og:image" content="${esc(o.image)}">` : '',
    o.url ? `<meta property="og:url" content="${esc(o.url)}">` : '',
    '<meta property="og:type" content="website">',
    `<meta name="twitter:card" content="${o.image ? 'summary_large_image' : 'summary'}">`,
    `<meta name="twitter:title" content="${esc(o.title)}">`,
    `<meta name="twitter:description" content="${esc(o.description)}">`,
    o.image ? `<meta name="twitter:image" content="${esc(o.image)}">` : '',
    o.noindex ? '<meta name="robots" content="noindex">' : '',
  ].filter(Boolean).join('\n');
  const buttons = o.openLink
    ? `<p><a class="b" href="${esc(o.openLink)}">Open in the app</a></p>
<p>Get the app: <a href="${esc(o.d.appStoreUrl)}">App Store</a> · <a href="${esc(o.d.playUrl)}">Google Play</a></p>`
    : `<p>Get the app: <a href="${esc(o.d.appStoreUrl)}">App Store</a> · <a href="${esc(o.d.playUrl)}">Google Play</a></p>`;
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(o.title)}</title>
${meta}
<style>body{font-family:system-ui,sans-serif;max-width:32rem;margin:2rem auto;padding:0 1rem;color:#1f2430}.b{display:inline-block;background:#1f4d44;color:#fff;padding:.8rem 1.2rem;border-radius:.8rem;text-decoration:none}img{max-width:100%;border-radius:1rem}</style>
</head><body>
${o.image ? `<img src="${esc(o.image)}" alt="">` : ''}
<h1>${esc(o.title)}</h1>
<p>${esc(o.description)}</p>
${buttons}
</body></html>`;
  const headers: Record<string, string> = { 'content-type': 'text/html; charset=utf-8', 'cache-control': CACHE };
  if (o.noindex) headers['x-robots-tag'] = 'noindex';
  return new Response(o.head ? null : html, { status, headers });
}

const jsonFile = (body: unknown, head: boolean) =>
  new Response(head ? null : JSON.stringify(body), {
    headers: { 'content-type': 'application/json', 'cache-control': 'public, max-age=3600' },
  });

export async function handleSharePage(req: Request, d: SharePageDeps): Promise<Response> {
  if (req.method !== 'GET' && req.method !== 'HEAD') return new Response('Method not allowed', { status: 405 });
  const head = req.method === 'HEAD';
  const path = new URL(req.url).pathname;
  const base = d.baseUrl.replace(/\/+$/, '');

  if (path.endsWith('/.well-known/assetlinks.json')) {
    return jsonFile([{
      relation: ['delegate_permission/common.handle_all_urls'],
      target: { namespace: 'android_app', package_name: d.androidPackage, sha256_cert_fingerprints: [d.androidSha256] },
    }], head);
  }
  if (path.endsWith('/.well-known/apple-app-site-association')) {
    return jsonFile({
      applinks: { details: [{ appIDs: [`${d.iosTeamId}.${d.iosBundleId}`], paths: ['/e/*', '/u/*'] }] },
    }, head);
  }

  const event = /(?:^|\/)e(?:\/([^/]*))?\/?$/.exec(path);
  if (event) {
    const notFound = () =>
      page(404, {
        title: 'This event is not available',
        description: 'The link may be wrong, or the host has cancelled the event.',
        d,
        head,
      });
    let code: string;
    try {
      code = decodeURIComponent(event[1] ?? '');
    } catch {
      return notFound();
    }
    if (!CODE.test(code)) return notFound();
    let e: EventPreview | null;
    try {
      e = await d.eventPreview(code);
    } catch {
      return notFound();
    }
    if (!e) return notFound();
    const description = [when(e.starts_at), [e.area, e.venue].filter(Boolean).join(' · '), price(e.price_sen)]
      .filter(Boolean).join(' · ');
    return page(200, {
      title: e.title,
      description,
      image: e.poster_url ?? (base ? `${base}/default-share.png` : undefined),
      url: base ? `${base}/e/${code}` : undefined,
      noindex: e.is_private,
      openLink: `jom://e/${code}`,
      d,
      head,
    });
  }

  const person = /(?:^|\/)u(?:\/([^/]*))?\/?$/.exec(path);
  if (person) {
    const notFound = () =>
      page(404, { title: 'This profile is not available', description: 'The link may be wrong.', d, head });
    let name: string;
    try {
      name = decodeURIComponent(person[1] ?? '').toLowerCase();
    } catch {
      return notFound();
    }
    if (!USERNAME.test(name) || name.includes('..')) return notFound();
    let p: PersonPreview | null;
    try {
      p = await d.personPreview(name);
    } catch {
      return notFound();
    }
    if (!p) return notFound();
    return page(200, {
      title: p.name,
      description: [`@${p.username}`, p.is_host ? 'Event owner' : '', p.area ?? ''].filter(Boolean).join(' · '),
      image: p.avatar_url ?? (base ? `${base}/default-share.png` : undefined),
      url: base ? `${base}/u/${p.username}` : undefined,
      openLink: `jom://u/${p.username}`,
      d,
      head,
    });
  }

  return new Response('Not found', { status: 404, headers: { 'cache-control': CACHE } });
}
