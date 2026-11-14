// True when the Authorization header carries a token whose role is service_role.
// shortcut: reads the role claim without checking the signature because Supabase's gateway has already verified it
// (verify_jwt = true in config.toml). Keep that on for every function that uses this.
export function isServiceRole(authorization: string | null): boolean {
  const token = /^Bearer (\S+)$/.exec(authorization ?? '')?.[1];
  const payload = token?.split('.')[1];
  if (!payload) return false;
  try {
    const json = atob(payload.replaceAll('-', '+').replaceAll('_', '/').padEnd(Math.ceil(payload.length / 4) * 4, '='));
    return JSON.parse(json)?.role === 'service_role';
  } catch {
    return false;
  }
}

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
