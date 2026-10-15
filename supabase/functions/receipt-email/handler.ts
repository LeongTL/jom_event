export interface ReceiptPayload {
  bookingId: string;
  email: string | null;
  name: string;
  eventTitle: string;
  startsAt: string;
  venue: string | null;
  people: number;
  amountSen: number;
  ticketCode: string;
}

export interface ReceiptDeps {
  serviceKey: string;
  send(mail: { to: string; subject: string; text: string }): Promise<void>;
  log(line: string): void;
}

// Same rule as the app: Free, RM 45, RM 45.50.
export function formatMoney(sen: number): string {
  if (sen === 0) return 'Free';
  const ringgit = Math.floor(sen / 100);
  const cents = sen % 100;
  return cents === 0 ? `RM ${ringgit}` : `RM ${ringgit}.${String(cents).padStart(2, '0')}`;
}

const when = (iso: string) =>
  new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Kuala_Lumpur', weekday: 'short', day: 'numeric', month: 'short',
    hour: 'numeric', minute: '2-digit', hour12: true,
  }).format(new Date(iso));

export function buildReceipt(p: ReceiptPayload): { subject: string; text: string } {
  const people = `${p.people} ${p.people === 1 ? 'person' : 'people'}`;
  return {
    subject: `Your Jom ticket ${p.ticketCode}: ${p.eventTitle}`,
    text: [
      `Hi ${p.name},`,
      '',
      `You're in. Show your ticket QR in the Jom app at the door.`,
      '',
      `Event:   ${p.eventTitle}`,
      `When:    ${when(p.startsAt)} (Kuala Lumpur time)`,
      ...(p.venue ? [`Where:   ${p.venue}`] : []),
      `Who:     ${people}`,
      `Total:   ${formatMoney(p.amountSen)}`,
      `Ticket:  ${p.ticketCode}`,
      '',
      'See you there,',
      'Jom',
    ].join('\n'),
  };
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

const isReceipt = (b: Record<string, unknown>): b is Record<string, unknown> & ReceiptPayload =>
  typeof b.bookingId === 'string' && typeof b.name === 'string' && typeof b.eventTitle === 'string' &&
  typeof b.startsAt === 'string' && typeof b.ticketCode === 'string' &&
  typeof b.people === 'number' && typeof b.amountSen === 'number' &&
  (b.email === null || typeof b.email === 'string') && (b.venue === null || typeof b.venue === 'string');

// Called by the database (pg_net) right after a booking is confirmed. Only the service key may call it.
export async function handleReceipt(req: Request, deps: ReceiptDeps): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (req.headers.get('authorization') !== `Bearer ${deps.serviceKey}`) return json({ error: 'unauthorized' }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  if (!isReceipt(body)) return json({ error: 'bad_request' }, 400);

  const { subject, text } = buildReceipt(body);
  if (!body.email) {
    deps.log(`receipt for ${body.ticketCode} not emailed: the guest signed in with a phone number`);
    return json({ skipped: 'no_email' });
  }
  try {
    await deps.send({ to: body.email, subject, text });
  } catch {
    return json({ error: 'send_failed' }, 502);
  }
  return json({ sent: true });
}
