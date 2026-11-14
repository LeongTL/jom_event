import { isServiceRole, json } from '../_shared/service_role.ts';

export interface PushDeps {
  tokens(userId: string): Promise<string[]>;
  /** 'gone' = the token is no longer valid and should be forgotten. */
  fcm(token: string, title: string, body: string, data: Record<string, string>): Promise<'ok' | 'gone'>;
  remove(token: string): Promise<void>;
}

// Called by the database (pg_net) and by receipt-reminders. Only a service_role token may call it.
export async function handlePush(req: Request, deps: PushDeps): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!isServiceRole(req.headers.get('authorization'))) return json({ error: 'unauthorized' }, 401);
  let b: Record<string, unknown>;
  try {
    b = await req.json();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  if (typeof b.userId !== 'string' || typeof b.title !== 'string' || typeof b.body !== 'string') {
    return json({ error: 'bad_request' }, 400);
  }
  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries((b.data ?? {}) as Record<string, unknown>)) {
    if (v != null) data[k] = String(v);
  }
  let sent = 0;
  for (const token of await deps.tokens(b.userId)) {
    try {
      if ((await deps.fcm(token, b.title, b.body, data)) === 'gone') await deps.remove(token);
      else sent++;
    } catch {
      // one bad token must not stop the rest
    }
  }
  return json({ sent });
}
