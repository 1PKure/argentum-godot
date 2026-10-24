// Replace the hash at deployment, never the plaintext server credential.
const expectedHash = '__AO_STORE_KEY_SHA256__';
const reply = (data: unknown, status = 200) => Response.json(data, {status});
Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') return reply({error: 'Method not allowed'}, 405);
  const token = request.headers.get('authorization')?.replace(/^Bearer /, '') || '';
  if (token.length < 32 || token.length > 256) return reply({error: 'Unauthorized'}, 401);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(token)));
  const hex = Array.from(digest, b => b.toString(16).padStart(2, '0')).join('');
  if (hex !== expectedHash) return reply({error: 'Unauthorized'}, 401);
  try {
    const reader = request.body?.getReader();
    if (!reader) return reply({error: 'Missing body'}, 400);
    let size = 0;
    const chunks: Uint8Array[] = [];
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 8 * 1024 * 1024) { await reader.cancel(); return reply({error: 'Too large'}, 413); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    const {operation, args} = JSON.parse(new TextDecoder().decode(bytes));
    if (!['ao_store_load', 'ao_store_commit'].includes(operation)) return reply({error: 'Invalid operation'}, 400);
    const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}');
    const key = keys.default || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if (!key) throw Error('Missing key');
    const headers: Record<string, string> = {apikey: key, 'Content-Type': 'application/json'};
    if (key.startsWith('eyJ')) headers.Authorization = 'Bearer ' + key;
    const result = await fetch(Deno.env.get('SUPABASE_URL') + '/rest/v1/rpc/' + operation, {
      method: 'POST', headers, body: JSON.stringify(args || {}), signal: AbortSignal.timeout(6000), redirect: 'error'
    });
    if (!result.ok) return reply({error: 'Storage unavailable'}, 503);
    return reply(await result.json());
  } catch { return reply({error: 'Storage unavailable'}, 503); }
});
