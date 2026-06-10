// Edge Function : export-catalog-lote (Lot 5, IMP-13).
//
// Session : Lot 5 — Export de lote
// Auteur  : Claude Opus 4.8
//
// Sérialise le catalogue d'une bibliothèque vers un fichier téléchargeable.
// Chaîne : contrôle d'accès + requête catalogue dans le RPC SECURITY DEFINER
// public.fn_export_catalog_lote (coordenador de la biblio, IMP-14) -> notices
// normalisées (JSON) -> serializeCatalog() -> fichier (Content-Disposition).
//
// Requête : POST { library_id: uuid, format: 'csv'|'marcxml'|'json' }
// Auth    : JWT requis (verify_jwt par défaut). Le RPC re-valide le rôle.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { serializeCatalog, SUPPORTED_FORMATS } from './serialize.ts';

// CORS : l'export est appele en fetch cross-origin depuis app.anarbib.org (POST
// avec en-tetes Authorization/apikey -> preflight OPTIONS). Sans ces headers, le
// navigateur bloque la requete avant meme qu'elle atteigne la fonction.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Expose-Headers': 'Content-Disposition',
};

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed. Use POST.' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'Missing Authorization header.' }, 401);
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Body must be valid JSON.' }, 400);
  }

  const libraryId = body?.library_id;
  const format = body?.format ?? 'csv';
  if (!libraryId || typeof libraryId !== 'string') {
    return json({ error: 'library_id (uuid) is required.' }, 400);
  }
  if (!SUPPORTED_FORMATS.includes(format)) {
    return json({ error: `Unsupported format. Supported: ${SUPPORTED_FORMATS.join(', ')}.` }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  if (!supabaseUrl || !anonKey) {
    return json({ error: 'Server misconfigured (missing SUPABASE_URL/ANON_KEY).' }, 500);
  }

  // Client scopé à l'appelant·e (on relaie son JWT) : auth.uid() dans le RPC
  // = l'usager, donc le contrôle de rôle coordenador s'applique réellement.
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await supabase.rpc('fn_export_catalog_lote', {
    p_library_id: libraryId,
  });
  if (error) {
    // Erreur de rôle (RAISE EXCEPTION) ou autre : 403 (accès) sinon 500.
    const restricted = /coordenador|restrito|obrigatorio/i.test(error.message || '');
    return json({ error: error.message }, restricted ? 403 : 500);
  }

  const records = Array.isArray(data?.records) ? data.records : [];
  let serialized;
  try {
    serialized = serializeCatalog(records, format);
  } catch (e) {
    return json({ error: String(e?.message || e) }, 400);
  }

  const today = new Date().toISOString().slice(0, 10);
  const filename = `catalogo-${libraryId}-${today}.${serialized.ext}`;
  // UTF-8 BOM pour le CSV (compat Excel / accents).
  const content = serialized.ext === 'csv' ? '﻿' + serialized.content : serialized.content;

  return new Response(content, {
    status: 200,
    headers: {
      ...CORS,
      'Content-Type': serialized.mime,
      'Content-Disposition': `attachment; filename="${filename}"`,
      'X-Record-Count': String(records.length),
    },
  });
});
