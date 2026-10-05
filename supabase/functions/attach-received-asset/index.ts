// Edge Function : attach-received-asset (chantier « gestion des fichiers numériques », entrée b).
//
// Attache un fichier de fonds REÇU (EX-3 ZIP / EX-4 direct), parqué dans
// `ingest.partner_catalog_received_assets` (bucket de réception partner-catalog-deposits),
// à un LIVRE de la réceptrice : DÉPLACE le fichier vers un bucket final RESTREINT puis crée le
// `digital_asset` en review_state=to_review via la RPC gatée fn_attach_received_asset_record
// (point 1 : la confirmation « domaine public » est un acte séparé du coordenador).
//
// Déclenché depuis le panneau « Attacher les fichiers reçus » (face Export) par un·e
// coordenador. verify_jwt par défaut (true) : JWT usager requis et relayé à la RPC (gate).

import { secretKey } from '../_shared/core/secret-key.ts';
import { createClient } from '../_shared/deps.ts';

const DEPOSIT_BUCKET = 'partner-catalog-deposits';

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
// E24 (05/10/2026) : chaque refus porte un `code` stable que l'écran traduit
// (src/lib/edgeError.js → clé error.edge.<code>, dix locales) ; le texte reste
// en repli. Un refus de la base relaie son HINT (clé error.*, E23).
function refus(code: string, error: string, status: number, extra: Record<string, unknown> = {}) {
  return json({ error, code, ...extra }, status);
}
function sanitize(name: string) {
  return String(name || 'fichier').replace(/[^\w.\-]+/g, '_').slice(0, 80);
}
function basename(path: string) {
  return String(path || '').split('/').pop() || 'fichier';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return refus('bad_request', 'Method not allowed. Use POST.', 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return refus('auth_required', 'Missing Authorization header.', 401);

  let body: any;
  try { body = await req.json(); } catch { return refus('bad_request', 'Body must be valid JSON.', 400); }
  const receivedAssetId = Number(body?.received_asset_id);
  const bookId = Number(body?.book_id);
  // Destination (point 6) : export (digital_asset) / read (book_digital_resources) / both.
  const mode = ['export', 'read', 'both'].includes(body?.mode) ? body.mode : 'both';
  if (!Number.isInteger(receivedAssetId) || receivedAssetId <= 0) return refus('bad_request', 'received_asset_id requis.', 400);
  if (!Number.isInteger(bookId) || bookId <= 0) return refus('bad_request', 'book_id requis.', 400);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = secretKey();
  if (!supabaseUrl || !anonKey || !serviceKey) return refus('server_error', 'Server misconfigured.', 500);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });

  // Lecture du fichier parqué (service_role).
  const { data: ra, error: raErr } = await service.schema('ingest')
    .from('partner_catalog_received_assets').select('*').eq('id', receivedAssetId).maybeSingle();
  if (raErr) return refus('server_error', raErr.message, 500);
  if (!ra) return refus('received_asset_not_found', `Fichier reçu ${receivedAssetId} introuvable.`, 404);
  if (ra.attached_digital_asset_id) return refus('already_attached', 'Fichier déjà attaché.', 409, { asset_id: ra.attached_digital_asset_id });
  if (ra.deposit_status !== 'deposited' || !ra.deposit_path) return refus('nothing_deposited', 'Aucun fichier déposé à attacher.', 422);

  // Bucket final RESTREINT (point 1 : fonds reçu en to_review) + type selon le MIME (CHECK digital_assets).
  const mime: string = ra.mime_type || '';
  let finalBucket: string | null = null;
  if (mime === 'application/pdf') finalBucket = 'pdf-restrito';
  else if (mime.startsWith('image/') || mime.startsWith('audio/') || mime.startsWith('video/')) finalBucket = 'anarbib-media-restricted';
  if (!finalBucket) return refus('unsupported_mime', `Type MIME « ${mime || '—'} » non supporté pour un asset.`, 422, { mime });

  // Déplacement intra-projet : dépôt → bucket final.
  const { data: blob, error: dlErr } = await service.storage.from(ra.deposit_bucket || DEPOSIT_BUCKET).download(ra.deposit_path);
  if (dlErr || !blob) return refus('server_error', `Téléchargement du dépôt échoué : ${dlErr?.message || 'vide'}`, 500);
  const bytes = new Uint8Array(await blob.arrayBuffer());
  const finalPath = `attached/${bookId}/${receivedAssetId}_${sanitize(basename(ra.deposit_path))}`;
  const { error: upErr } = await service.storage.from(finalBucket).upload(finalPath, bytes, {
    contentType: mime || 'application/octet-stream', upsert: true,
  });
  if (upErr) return refus('server_error', `Dépôt dans le bucket final échoué : ${upErr.message}`, 500);

  // Création de l'asset et/ou de la ressource catalogue selon le mode (RPC gatée, JWT usager).
  const { data: rec, error: recErr } = await userClient.rpc('fn_attach_received_asset_record', {
    p_received_asset_id: receivedAssetId, p_book_id: bookId,
    p_bucket_name: finalBucket, p_object_path: finalPath, p_mode: mode,
  });
  if (recErr) {
    // Nettoyage best-effort du fichier déplacé si la création a échoué.
    try { await service.storage.from(finalBucket).remove([finalPath]); } catch (_) { /* no-op */ }
    const restricted = /coordenador|restrito|pertence|inválid|obrigatori/i.test(recErr.message || '');
    return refus(restricted ? 'forbidden' : 'server_error', recErr.message, restricted ? 403 : 500, { hint: recErr.hint ?? null });
  }

  return json({ ok: true, mode, asset_id: rec?.asset_id ?? null, resource_id: rec?.resource_id ?? null, book_id: bookId, bucket: finalBucket, path: finalPath });
});
