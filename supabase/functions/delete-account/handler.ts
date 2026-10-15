export interface DeleteDeps {
  getUserId(jwt: string): Promise<string | null>;
  // erases the user's data in the database; rejects with an Error whose message is the reason code when refused
  erase(userId: string): Promise<void>;
  deleteAuthUser(userId: string): Promise<void>;
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

// Reasons the database gives for refusing; the app shows a clear message for each.
const REFUSALS = ['host_has_active_events', 'host_has_pending_payouts'];

// A signed-in user deletes their own account: personal data first (one database transaction), then the
// sign-in. If the second step fails the first is already done, and calling again finishes the job.
export async function handleDeleteAccount(req: Request, deps: DeleteDeps): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

  const jwt = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
  const userId = jwt ? await deps.getUserId(jwt) : null;
  if (!userId) return json({ error: 'unauthorized' }, 401);

  try {
    await deps.erase(userId);
  } catch (e) {
    const reason = REFUSALS.find((r) => String((e as Error).message).includes(r));
    return reason ? json({ error: reason }, 409) : json({ error: 'erase_failed' }, 500);
  }
  try {
    await deps.deleteAuthUser(userId);
  } catch {
    return json({ error: 'auth_delete_failed' }, 502);
  }
  return json({ deleted: true });
}
