// Edge Function : read-ill-shared-asset (paquet ILL-I2, 12/06/2026).
//
// Accès au reçu d'un PARTAGE NUMÉRIQUE inter-biblios (mode ponctuel §4 de
// spec-flux-partage-numerique). Jumelle de read-digital-asset, mais l'autorisation
// passe par fn_ill_signed_url(share_id) qui RE-VALIDE à chaque appel : staff
// récepteur + partenariat actif + droit digital_share + état transmis. L'URL
// signée est régénérée à TTL court (aucune URL durable, aucune copie persistante).
//
// Entrée : ?share_id=<uuid> (ou POST { share_id }). Auth : JWT de l'usager·ère
// relayé (verify_jwt=false ; c'est le RPC qui contrôle via auth.uid()).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SIGNED_URL_TTL_SECONDS = Number(Deno.env.get('ILL_SIGNED_URL_TTL_SECONDS') ?? '600');

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'authorization, content-type',
      'access-control-allow-methods': 'GET, POST, OPTIONS',
    },
  });
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function inferViewerKind(assetKind: string, mime: string): string {
  const k = String(assetKind || '').toLowerCase();
  const m = String(mime || '').toLowerCase();
  if (k === 'audio' || m.startsWith('audio/')) return 'audio';
  if (k === 'video' || m.startsWith('video/')) return 'video';
  if (k === 'image' || m.startsWith('image/')) return 'image';
  if (k === 'pdf' || m === 'application/pdf') return 'pdf';
  if (k === 'external_link') return 'external_link';
  return 'generic';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return json({ ok: true }, 200);
  try {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({ ok: false, error: 'Missing Supabase env vars' }, 500);
    }
    const authHeader = req.headers.get('authorization') ?? '';

    const url = new URL(req.url);
    let shareId = url.searchParams.get('share_id') ?? url.searchParams.get('shareId') ?? '';
    if (!shareId && req.method !== 'GET') {
      try {
        const body = await req.json();
        shareId = String(body?.share_id ?? body?.shareId ?? '');
      } catch { /* no-op */ }
    }
    if (!UUID_RE.test(shareId)) {
      return json({ ok: false, error: 'Missing or invalid share_id' }, 400);
    }

    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: authHeader ? { authorization: authHeader } : {} },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Autorisation + métadonnées (re-validation à chaque appel).
    const { data, error } = await userClient.rpc('fn_ill_signed_url', { p_share_id: shareId });
    if (error) return json({ ok: false, error: error.message }, 403);
    const row = Array.isArray(data) ? data[0] : data;
    if (!row?.ok) return json({ ok: false, error: 'Share not accessible' }, 404);

    const bucket = row.bucket_name ? String(row.bucket_name) : null;
    const path = row.object_path ? String(row.object_path) : null;
    if (!bucket || !path) return json({ ok: false, error: 'No storage asset on this share' }, 404);

    const { data: signed, error: signedError } =
      await serviceClient.storage.from(bucket).createSignedUrl(path, SIGNED_URL_TTL_SECONDS);
    if (signedError || !signed?.signedUrl) {
      return json({ ok: false, error: signedError?.message || 'Unable to create signed URL' }, 500);
    }

    return json({
      ok: true,
      asset: {
        share_id: row.share_id,
        title: row.title,
        mime_type: row.mime_type,
        asset_kind: row.asset_kind,
        plafond: row.plafond,
      },
      viewer_kind: inferViewerKind(row.asset_kind, row.mime_type),
      access_mode: 'storage_signed',
      access_url: signed.signedUrl,
      expires_in_seconds: SIGNED_URL_TTL_SECONDS,
    });
  } catch (error) {
    return json({ ok: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});
