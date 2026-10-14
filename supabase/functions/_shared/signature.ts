// HMAC-SHA256 over the raw request body, as lowercase hex. The gateway sends it in x-gateway-signature.
const enc = new TextEncoder();

const key = (secret: string, usage: KeyUsage) =>
  crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, [usage]);

const toHex = (buf: ArrayBuffer) => [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');

export async function hmacHex(secret: string, body: string): Promise<string> {
  return toHex(await crypto.subtle.sign('HMAC', await key(secret, 'sign'), enc.encode(body)));
}

// crypto.subtle.verify compares in constant time.
export async function verifySignature(secret: string, body: string, signatureHex: string): Promise<boolean> {
  if (!/^([0-9a-f]{2})+$/i.test(signatureHex)) return false;
  const sig = Uint8Array.from(signatureHex.match(/../g)!.map((h) => parseInt(h, 16)));
  return await crypto.subtle.verify('HMAC', await key(secret, 'verify'), sig, enc.encode(body));
}
