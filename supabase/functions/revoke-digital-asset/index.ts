// Edge Function : revoke-digital-asset (chantier fichiers numériques, entrée c — dé-vérification).
//
// Annule une revendication « domaine public » erronée sur un digital_asset :
//   1. fn_revoke_digital_asset_record (RPC gatée, JWT usager relayé) supprime la ligne
//      digital_asset, délie un éventuel received_asset (retour en file d'attache), et
//      renvoie file_orphaned=true si le fichier n'est plus référencé nulle part.
//   2. Si orphelin, l'EF (service_role) RETIRE le fichier du bucket final (best-effort :
//      la ligne est déjà supprimée, un retrait raté ne laisse qu'un fichier orphelin GC-able).
//      Si le fichier est PARTAGÉ avec le catalogue (book_digital_resources, cas entrée a),
//      file_orphaned=false → on ne touche PAS au fichier (ne pas casser le lecteur).
//
// verify_jwt par défaut (true) : JWT usager requis et relayé à la RPC gatée.

import { createClient } from 'npm:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed. Use POST.' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing Authorization header.' }, 401);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Body must be valid JSON.' }, 400); }
  const assetId = Number(body?.asset_id);
  if (!Number.isInteger(assetId) || assetId <= 0) {
    return json({ error: 'Body must contain a positive integer asset_id.' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceKey) return json({ error: 'Server misconfigured.' }, 500);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });

  // 1. Dé-vérification gatée (supprime la ligne + délie le reçu), sous le JWT usager.
  const { data: rec, error: recErr } = await userClient.rpc('fn_revoke_digital_asset_record', { p_asset_id: assetId });
  if (recErr) {
    const restricted = /coordenador|restrito|acesso|obrigatorio/i.test(recErr.message || '');
    return json({ error: recErr.message }, restricted ? 403 : 500);
  }

  // 2. Retrait du fichier physique SEULEMENT s'il est devenu orphelin (best-effort).
  let fileRemoved = false;
  let removeError: string | null = null;
  if (rec?.file_orphaned && rec?.bucket_name && rec?.object_path) {
    const { error: rmErr } = await service.storage.from(rec.bucket_name).remove([rec.object_path]);
    if (rmErr) {
      removeError = String(rmErr.message || rmErr); // non bloquant : la ligne est déjà supprimée
    } else {
      fileRemoved = true;
    }
  }

  return json({
    ok: true,
    asset_id: assetId,
    deleted: rec?.deleted ?? false,
    book_id: rec?.book_id ?? null,
    unlinked_received_asset: rec?.unlinked_received_asset ?? null,
    file_orphaned: rec?.file_orphaned ?? false,
    file_removed: fileRemoved,
    file_kept_reason: rec?.file_orphaned ? null : 'fichier partagé avec le catalogue ou un autre asset',
    remove_error: removeError,
  });
});
