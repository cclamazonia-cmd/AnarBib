// Edge Function : deposit-fonds-direct (paquet EX-4, niveau 2 — transfert direct fédéré).
//
// Mode a du CADRAGE : remise DIRECTE d'un lot de fonds à une biblioteca companheira,
// sans ZIP. AnarBib étant MONO-PROJET multi-tenant, c'est une copie storage INTRA-projet
// + l'écriture d'un run d'import pour le `library_id` de la réceptrice (dépôt SEMI-AUTO,
// P4 : le lot arrive en `ready_for_review` chez elle). Réutilise toute la réception EX-3
// (staging ingest + received_assets + matching + review→drafts).
//
// Déclenché depuis la face Export (panneau « Exportação de fonds », mode envoi direct)
// par un·e coordenador de la biblio SOURCE. Gates (authoritatifs, SQL) :
//   - fn_export_fonds_records (EX-1) : coordenador de la source + éligibilité P3.
//   - fn_deposit_fonds_direct_prepare (EX-4) : coordenador-source + droit `mutualisation`
//     actif (P2), puis crée la source de dépôt + le run CÔTÉ RÉCEPTRICE (cross-tenant gaté).
// L'EF (service_role) ne fait ensuite que le mécanique : staging + copie des fichiers.
// verify_jwt par défaut (true) : JWT usager requis et relayé aux RPC ci-dessus.

import { createClient } from 'npm:@supabase/supabase-js@2';

const DEPOSIT_BUCKET = 'partner-catalog-deposits';
const PARSER_VERSION = 'fonds_direct_v1';
const INSERT_BATCH = 250;
const MAX_FILES = 150;
const MAX_TOTAL_BYTES = 80 * 1024 * 1024; // 80 Mo (borne MVP, miroir de l'export ZIP)

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
function clean(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).trim();
  return s === '' ? null : s;
}
function sanitize(name: string) {
  return String(name || 'fichier').replace(/[^\w.\-]+/g, '_').slice(0, 80);
}
function basename(path: string) {
  return String(path || '').split('/').pop() || 'fichier';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed. Use POST.' }, 405);

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing Authorization header.' }, 401);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Body must be valid JSON.' }, 400); }
  const sourceLibraryId = body?.source_library_id;
  const targetLibraryId = body?.target_library_id;
  const bookIds = Array.isArray(body?.book_ids) && body.book_ids.length ? body.book_ids : null;
  if (!sourceLibraryId || !targetLibraryId) return json({ error: 'source_library_id et target_library_id requis.' }, 400);
  if (sourceLibraryId === targetLibraryId) return json({ error: 'Origem e destino identicos.' }, 400);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceKey) return json({ error: 'Server misconfigured.' }, 500);

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const ingestRpc = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false }, db: { schema: 'ingest' },
  });

  // 1. Sélection + gate coordenador de la SOURCE + éligibilité P3 (EX-1).
  const { data: recData, error: recErr } = await userClient.rpc('fn_export_fonds_records', {
    p_library_id: sourceLibraryId, p_book_ids: bookIds,
  });
  if (recErr) {
    const restricted = /coordenador|restrito|obrigatorio|mutualiza/i.test(recErr.message || '');
    return json({ error: recErr.message }, restricted ? 403 : 500);
  }
  const records: any[] = Array.isArray(recData?.records) ? recData.records : [];
  if (!records.length) return json({ error: 'Aucune notice éligible (public_domain_confirmed).' }, 422);

  // 2. Prépare le run côté RÉCEPTRICE + gate mutualisation (EX-4, cross-tenant gaté).
  const { data: prep, error: prepErr } = await userClient.rpc('fn_deposit_fonds_direct_prepare', {
    p_source_library_id: sourceLibraryId, p_target_library_id: targetLibraryId,
  });
  if (prepErr) {
    const restricted = /coordenador|restrito|mutualiza|inativo|obrigatorio|identicos/i.test(prepErr.message || '');
    return json({ error: prepErr.message }, restricted ? 403 : 500);
  }
  const runId = prep?.run_id;
  const sourceName = prep?.source_name ?? null;
  if (!runId) return json({ error: 'Run de réception non créé.' }, 500);

  try {
    // 3. Notices → staging rows (mappe la forme serialize.ts), côté réceptrice.
    const entries = records.map((rec, idx) => {
      const title = clean(rec?.title);
      const hasContent = !!(title || clean(rec?.subtitle) || clean(rec?.responsibility) || clean(rec?.publisher)
        || clean(rec?.isbn) || clean(rec?.issn) || (Array.isArray(rec?.subjects) && rec.subjects.length));
      return { rec, rowNo: idx + 1, hasContent };
    });
    const stagingRows = entries.filter((e) => e.hasContent).map((e) => {
      const rec = e.rec;
      const authors = Array.isArray(rec?.authors)
        ? rec.authors.map((a: any) => ({ name: a?.name ?? null, role: a?.role ?? null, ord: a?.ord ?? null }))
        : [];
      const subjects = Array.isArray(rec?.subjects) ? rec.subjects : [];
      const mapped = {
        title: clean(rec?.title), subtitle: clean(rec?.subtitle),
        responsibility_statement: clean(rec?.responsibility), authors,
        publisher: clean(rec?.publisher), place_of_publication: clean(rec?.place),
        publication_year: rec?.year != null ? String(rec.year) : null,
        edition_statement: clean(rec?.edition), language: clean(rec?.language),
        isbn: clean(rec?.isbn), issn: clean(rec?.issn), subjects,
        item_type: clean(rec?.materialType),
        external_key: clean(rec?.bibRef) || (rec?.id != null ? String(rec.id) : null),
      };
      return {
        run_id: runId, row_no: e.rowNo, ...mapped,
        raw_payload: rec,
        normalized_payload: { ...mapped, parser_version: PARSER_VERSION, source_library_id: sourceLibraryId },
        parse_status: 'parsed', match_status: 'unreviewed', review_status: 'pending',
        confidence: 0, warnings: [], editorial_decision: 'pending', selected_for_draft: false,
      };
    });
    for (let i = 0; i < stagingRows.length; i += INSERT_BATCH) {
      const { error } = await service.schema('ingest').from('partner_catalog_staging_rows').insert(stagingRows.slice(i, i + INSERT_BATCH));
      if (error) throw error;
    }

    const rowNoToId = new Map<number, number>();
    const { data: insertedRows } = await service.schema('ingest')
      .from('partner_catalog_staging_rows').select('id, row_no').eq('run_id', runId);
    for (const r of insertedRows ?? []) rowNoToId.set(Number(r.row_no), Number(r.id));

    // 4. Copie INTRA-projet des fichiers (source bucket → dépôt réceptrice) + parking.
    const receivedRows: any[] = [];
    let deposited = 0, metadataOnly = 0, failed = 0, depositedBytes = 0, fileCount = 0, truncated = false;
    for (const e of entries) {
      const assets = Array.isArray(e.rec?.assets) ? e.rec.assets : [];
      const stagingRowId = rowNoToId.get(e.rowNo) ?? null;
      for (const a of assets) {
        const meta: any = {
          run_id: runId, staging_row_id: stagingRowId,
          source_asset_id: a?.asset_id ?? null, asset_kind: clean(a?.kind), title: clean(a?.title),
          mime_type: clean(a?.mime), rights_status: clean(a?.rights_status),
          checksum_sha256: clean(a?.checksum_sha256), source_name: clean(a?.source_name),
          source_license_name: clean(a?.source_license_name), attribution_text: clean(a?.attribution_text),
          manifest_file: a?.bucket && a?.path ? `${a.bucket}/${a.path}` : null,
          deposit_bucket: DEPOSIT_BUCKET,
        };
        const srcBucket = clean(a?.bucket);
        const srcPath = clean(a?.path);
        if (!srcBucket || !srcPath) {
          meta.deposit_status = 'metadata_only';
          metadataOnly += 1;
        } else if (truncated || fileCount >= MAX_FILES || depositedBytes >= MAX_TOTAL_BYTES) {
          truncated = true;
          meta.deposit_status = 'metadata_only';
          meta.deposit_error = 'borne de volumétrie atteinte (lot tronqué)';
          metadataOnly += 1;
        } else {
          try {
            const { data: blob, error: dlErr } = await service.storage.from(srcBucket).download(srcPath);
            if (dlErr || !blob) throw dlErr || new Error('téléchargement source vide');
            const bytes = new Uint8Array(await blob.arrayBuffer());
            const depositPath = `received/${runId}/${a?.asset_id ?? 'x'}_${sanitize(basename(srcPath))}`;
            const { error: upErr } = await service.storage.from(DEPOSIT_BUCKET)
              .upload(depositPath, bytes, { contentType: meta.mime_type || 'application/octet-stream', upsert: true });
            if (upErr) throw upErr;
            meta.deposit_status = 'deposited';
            meta.deposit_path = depositPath;
            meta.file_size_bytes = bytes.byteLength;
            deposited += 1; fileCount += 1; depositedBytes += bytes.byteLength;
          } catch (ue) {
            meta.deposit_status = 'failed';
            meta.deposit_error = String((ue as Error)?.message || ue);
            failed += 1;
          }
        }
        receivedRows.push(meta);
      }
    }
    for (let i = 0; i < receivedRows.length; i += INSERT_BATCH) {
      const { error } = await service.schema('ingest').from('partner_catalog_received_assets').insert(receivedRows.slice(i, i + INSERT_BATCH));
      if (error) throw error;
    }

    // 5. Matching + compteurs + finalisation (run réceptrice en ready_for_review).
    const { error: matchErr } = await ingestRpc.rpc('fn_match_partner_catalog_run', { p_run_id: runId, p_row_ids: null });
    if (matchErr) throw matchErr;
    await ingestRpc.rpc('fn_refresh_partner_catalog_run_counters', { p_run_id: runId });

    const finishedAt = new Date().toISOString();
    const summary = {
      parser: PARSER_VERSION, mode: 'direct', source_library_id: sourceLibraryId, source_name: sourceName,
      target_library_id: targetLibraryId, manifest_notice_count: records.length, inserted_rows: stagingRows.length,
      received_files_deposited: deposited, received_metadata_only: metadataOnly, received_failed: failed,
      deposited_bytes: depositedBytes, truncated, parsed_at: finishedAt,
    };
    const { error: finErr } = await service.schema('ingest').from('partner_catalog_import_runs').update({
      run_status: 'ready_for_review', imported_rows: stagingRows.length, parser_version: PARSER_VERSION,
      summary, finished_at: finishedAt,
    }).eq('id', runId);
    if (finErr) throw finErr;

    return json({
      ok: true, run_id: runId, source_name: sourceName, target_library_id: targetLibraryId,
      inserted_rows: stagingRows.length, received_files_deposited: deposited,
      received_metadata_only: metadataOnly, received_failed: failed, truncated,
      next_step: 'Dépôt en ready_for_review chez la companheira. Fichiers parqués pour le chantier d\'attache.',
    });
  } catch (e) {
    try {
      const { data: run } = await service.schema('ingest').from('partner_catalog_import_runs').select('error_log').eq('id', runId).maybeSingle();
      const log = Array.isArray(run?.error_log) ? run!.error_log : [];
      log.push({ at: new Date().toISOString(), error: String((e as Error)?.message || e) });
      await service.schema('ingest').from('partner_catalog_import_runs').update({ run_status: 'failed', error_log: log }).eq('id', runId);
    } catch (_) { /* la trace d'erreur ne bloque jamais */ }
    return json({ error: String((e as Error)?.message || e) }, 500);
  }
});
