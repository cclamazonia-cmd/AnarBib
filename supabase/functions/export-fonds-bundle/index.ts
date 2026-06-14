// Edge Function : export-fonds-bundle (paquet EX-2, niveau 2 — export de fonds).
//
// Remise d'un LOT de matériel gris numérisé (libre de droits) sous forme d'un ZIP
// téléchargeable (mode b du CADRAGE_export_fonds_numeriques) :
//   - notices.<ext>  : notices sérialisées (réutilise export-catalog-lote/serialize.ts)
//   - manifest.json  : notices + liaison notice↔fichier + provenance/licence
//   - files/<id>_<nom> : les fichiers numériques (depuis les buckets, service_role)
//
// Sélection + éligibilité (public_domain_confirmed strict, P3) : RPC SECURITY DEFINER
// fn_export_fonds_records (EX-1, gate coordenador IMP-14, JWT usager relayé). Le run
// est tracé dans public.fonds_export_runs. Borne de volumétrie (MVP synchrone).
//
// Requête : POST { library_id, format?='json'|'csv'|'marcxml', book_ids?, target_library_id? }
// Auth    : JWT requis (verify_jwt par défaut) ; le RPC re-valide le rôle.

import { createClient } from 'npm:@supabase/supabase-js@2';
import JSZip from 'npm:jszip@3';
import { serializeCatalog, SUPPORTED_FORMATS } from '../export-catalog-lote/serialize.ts';

// Bornes MVP synchrone (JSZip garde tout en mémoire → l'EF OOM au-delà). Pour les
// gros fonds, l'empaquetage asynchrone/streaming reste à faire (cf. cadrage).
const MAX_FILES = 150;
const MAX_TOTAL_BYTES = 80 * 1024 * 1024; // 80 Mo

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Expose-Headers': 'Content-Disposition, X-Truncated, X-File-Count',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' } });
}

function sanitize(name: string) {
  return String(name || 'fichier').replace(/[^\w.\-]+/g, '_').slice(0, 80);
}
function basename(path: string) {
  const p = String(path || '').split('/').pop() || '';
  return p || 'fichier';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed. Use POST.' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing Authorization header.' }, 401);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Body must be valid JSON.' }, 400); }
  const libraryId = body?.library_id;
  const format = body?.format ?? 'json';
  const bookIds = Array.isArray(body?.book_ids) && body.book_ids.length ? body.book_ids : null;
  const targetLibraryId = body?.target_library_id || null;
  if (!libraryId || typeof libraryId !== 'string') return json({ error: 'library_id (uuid) is required.' }, 400);
  if (!SUPPORTED_FORMATS.includes(format)) return json({ error: `Unsupported format. Supported: ${SUPPORTED_FORMATS.join(', ')}.` }, 400);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceKey) return json({ error: 'Server misconfigured.' }, 500);

  // Client usager (relaie le JWT) : le RPC gate coordenador via auth.uid().
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });

  // Sélection + éligibilité (EX-1).
  const { data, error } = await userClient.rpc('fn_export_fonds_records', { p_library_id: libraryId, p_book_ids: bookIds });
  if (error) {
    const restricted = /coordenador|restrito|obrigatorio/i.test(error.message || '');
    return json({ error: error.message }, restricted ? 403 : 500);
  }
  const records: any[] = Array.isArray(data?.records) ? data.records : [];

  // Trace du run (service_role ; best-effort).
  let runId: string | null = null;
  try {
    const { data: run } = await service.from('fonds_export_runs').insert({
      library_id: libraryId,
      target_kind: targetLibraryId ? 'companheira' : 'download',
      target_library_id: targetLibraryId,
      mode: 'zip',
      eligibility: 'public_domain_confirmed',
      format,
      status: 'preparation',
      notice_count: records.length,
    }).select('id').single();
    runId = run?.id ?? null;
  } catch (_) { /* la trace ne bloque jamais l'export */ }

  try {
    const zip = new JSZip();

    // 1. Notices sérialisées (serialize.ts ignore le champ `assets`).
    const serialized = serializeCatalog(records, format);
    zip.file(`notices.${serialized.ext}`, serialized.content);

    // 2. Fichiers + manifeste (liaison notice↔fichier + provenance).
    let fileCount = 0, totalBytes = 0, truncated = false;
    const manifestRecords: any[] = [];
    for (const rec of records) {
      const assets = Array.isArray(rec.assets) ? rec.assets : [];
      const manifestAssets: any[] = [];
      for (const a of assets) {
        const meta: any = {
          asset_id: a.asset_id, kind: a.kind, title: a.title, mime: a.mime,
          rights_status: a.rights_status, checksum_sha256: a.checksum_sha256,
          source_name: a.source_name, source_license_name: a.source_license_name,
          attribution_text: a.attribution_text,
        };
        // Pas de fichier (lien externe) → métadonnée seule.
        if (a.bucket && a.path && !truncated) {
          if (fileCount >= MAX_FILES || totalBytes >= MAX_TOTAL_BYTES) {
            truncated = true;
          } else {
            const { data: blob, error: dlErr } = await service.storage.from(a.bucket).download(a.path);
            if (!dlErr && blob) {
              const buf = new Uint8Array(await blob.arrayBuffer());
              const zipPath = `files/${a.asset_id}_${sanitize(basename(a.path))}`;
              zip.file(zipPath, buf);
              meta.file = zipPath;
              fileCount += 1;
              totalBytes += buf.byteLength;
            }
          }
        }
        manifestAssets.push(meta);
      }
      manifestRecords.push({ ...rec, assets: manifestAssets });
    }

    const manifest = {
      schema: 'anarbib-fonds-export/v1',
      library_id: libraryId,
      eligibility: data?.eligibility || 'public_domain_confirmed',
      notice_count: records.length,
      file_count: fileCount,
      truncated,
      records: manifestRecords,
    };
    zip.file('manifest.json', JSON.stringify(manifest, null, 2));

    const content = await zip.generateAsync({ type: 'uint8array' });

    if (runId) {
      await service.from('fonds_export_runs').update({
        status: 'packaged', file_count: fileCount, total_bytes: totalBytes, truncated,
        packaged_at: new Date().toISOString(),
      }).eq('id', runId);
    }

    const today = new Date().toISOString().slice(0, 10);
    return new Response(content, {
      status: 200,
      headers: {
        ...CORS,
        'Content-Type': 'application/zip',
        'Content-Disposition': `attachment; filename="fonds-${libraryId}-${today}.zip"`,
        'X-File-Count': String(fileCount),
        'X-Truncated': String(truncated),
      },
    });
  } catch (e) {
    if (runId) {
      try { await service.from('fonds_export_runs').update({ status: 'failed', error_log: String((e as Error)?.message || e) }).eq('id', runId); } catch (_) { /* no-op */ }
    }
    return json({ error: String((e as Error)?.message || e) }, 500);
  }
});
