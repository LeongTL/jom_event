import { isServiceRole, json } from '../_shared/service_role.ts';

export interface PurgeDeps {
  /** Paths of receipt files whose event ended more than 30 days ago (each is handed out once). */
  claim(): Promise<string[]>;
  remove(paths: string[]): Promise<void>;
}

// Called daily by the database. The receipt rows stay; only the image files go.
export async function handlePurge(req: Request, deps: PurgeDeps): Promise<Response> {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!isServiceRole(req.headers.get('authorization'))) return json({ error: 'unauthorized' }, 401);
  const paths = await deps.claim();
  if (paths.length > 0) await deps.remove(paths);
  return json({ purged: paths.length });
}
