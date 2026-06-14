// Edge Function : receive-fonds-bundle (paquet EX-3, niveau 2 — réception de fonds).
//
// Réceptionne un ZIP d'export de fonds (produit par export-fonds-bundle / EX-2)
// PAR LE PIPELINE INGEST : déballe `manifest.json` + `files/`, crée les staging
// rows (mêmes tables que l'import partenaire → même matching, même review→drafts),
// DÉPOSE les fichiers reçus dans le bucket de réception (partner-catalog-deposits)
// et les PARQUE dans ingest.partner_catalog_received_assets avec leur provenance.
// Le run finit en `ready_for_review` → review/promotion standard → book_drafts.
//
// L'ATTACHE du fichier au livre (création du digital_asset) est VOLONTAIREMENT
// HORS EX-3 (décision 14/06 : brique « gestion des fichiers numériques » dédiée).
//
// Appelée en server-to-server par ingest.fn_dispatch_partner_catalog_import quand
// le run a detected_format='zip'. Auth : x-import-secret (ANARBIB_PARTNER_IMPORT_SECRET).
// verify_jwt=false (cf. config.toml) — l'auth interne custom remplace le JWT.

import { createClient } from 'npm:@supabase/supabase-js@2';
import JSZip from 'npm:jszip@3';

const IMPORT_SECRET_HEADER = 'x-import-secret';
const IMPORT_SECRET_ENV = 'ANARBIB_PARTNER_IMPORT_SECRET';
const DEFAULT_BUCKET = 'catalogos_parceiros_raw';
const DEPOSIT_BUCKET = 'partner-catalog-deposits';
const MANIFEST_SCHEMA = 'anarbib-fonds-export/v1';
const PARSER_VERSION = 'fonds_receive_v1';
const INSERT_BATCH = 250;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-import-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body, null, 2), {
    status, headers: { ...CORS, 'Content-Type': 'application/json; charset=utf-8' },
  });
}
function clean(v: unknown): string | null {
  if (v == null) return null;
  const s = String(v).replace(/\uFEFF/g, '').trim();
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

  // Auth interne (server-to-server depuis le dispatch SQL).
  const expectedSecret = Deno.env.get(IMPORT_SECRET_ENV);
  if (!expectedSecret) return json({ error: `Missing secret ${IMPORT_SECRET_ENV}` }, 500);
  const providedSecret = req.headers.get(IMPORT_SECRET_HEADER);
  if (!providedSecret || providedSecret !== expectedSecret) return json({ error: 'Unauthorized' }, 401);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceKey) return json({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }, 500);

  const admin = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const ingestRpc = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false }, db: { schema: 'ingest' },
  });

  let runId: number | null = null;
  try {
    const body = await req.json();
    runId = Number(body?.run_id);
    const forceReparse = body?.force_reparse === true;
    if (!Number.isInteger(runId) || runId <= 0) return json({ error: 'Body must contain a positive integer run_id.' }, 400);

    const { data: run, error: runError } = await admin.schema('ingest')
      .from('partner_catalog_import_runs').select('*').eq('id', runId).maybeSingle();
    if (runError) throw runError;
    if (!run) return json({ error: `Import run ${runId} not found.` }, 404);

    const bucketId = clean(run.bucket_id) ?? DEFAULT_BUCKET;
    const storagePath = clean(run.storage_path);
    if (!storagePath) return json({ error: `Run ${runId} has no storage_path.` }, 400);

    // Garde idempotence : ne pas ré-empiler des staging rows sans force_reparse.
    const { count: existingCount } = await admin.schema('ingest')
      .from('partner_catalog_staging_rows').select('*', { count: 'exact', head: true }).eq('run_id', runId);
    if ((existingCount ?? 0) > 0 && !forceReparse) {
      return json({ error: `Run ${runId} already has staging rows.`, hint: 'Use {"force_reparse": true} to replace.' }, 409);
    }

    await admin.schema('ingest').from('partner_catalog_import_runs').update({
      run_status: 'processing', started_at: new Date().toISOString(), finished_at: null, parser_version: PARSER_VERSION,
    }).eq('id', runId);
    if ((existingCount ?? 0) > 0 && forceReparse) {
      await admin.schema('ingest').from('partner_catalog_staging_rows').delete().eq('run_id', runId);
      await admin.schema('ingest').from('partner_catalog_received_assets').delete().eq('run_id', runId);
    }

    // ── Déballage du ZIP ──────────────────────────────────────────────────
    const { data: blob, error: dlErr } = await admin.storage.from(bucketId).download(storagePath);
    if (dlErr) throw dlErr;
    if (!blob) throw new Error('Storage download returned no file.');
    const zip = await JSZip.loadAsync(await blob.arrayBuffer());

    const manifestEntry = zip.file('manifest.json');
    if (!manifestEntry) throw new Error('manifest.json absent du ZIP : ce n\'est pas un paquet de fonds.');
    let manifest: any;
    try { manifest = JSON.parse(await manifestEntry.async('string')); }
    catch { throw new Error('manifest.json illisible (JSON invalide).'); }
    if (manifest?.schema !== MANIFEST_SCHEMA) throw new Error(`Schéma de manifeste inattendu : ${manifest?.schema ?? '—'} (attendu ${MANIFEST_SCHEMA}).`);
    const sourceLibraryId = manifest?.library_id ?? null;
    const records: any[] = Array.isArray(manifest?.records) ? manifest.records : [];

    // ── Notices → staging rows (mappe la forme serialize.ts du manifeste) ────
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
      const { error } = await admin.schema('ingest').from('partner_catalog_staging_rows').insert(stagingRows.slice(i, i + INSERT_BATCH));
      if (error) throw error;
    }

    // Carte row_no → staging_row_id (pour rattacher les fichiers à leur notice).
    const rowNoToId = new Map<number, number>();
    const { data: insertedRows } = await admin.schema('ingest')
      .from('partner_catalog_staging_rows').select('id, row_no').eq('run_id', runId);
    for (const r of insertedRows ?? []) rowNoToId.set(Number(r.row_no), Number(r.id));

    // ── Fichiers reçus → dépôt + parking (received_assets) ───────────────────
    const receivedRows: any[] = [];
    let deposited = 0, metadataOnly = 0, failed = 0, depositedBytes = 0;
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
          manifest_file: clean(a?.file), deposit_bucket: DEPOSIT_BUCKET,
        };
        const zipPath = clean(a?.file);
        const zEntry = zipPath ? zip.file(zipPath) : null;
        if (!zipPath || !zEntry) {
          meta.deposit_status = 'metadata_only';
          metadataOnly += 1;
        } else {
          try {
            const bytes = await zEntry.async('uint8array');
            const depositPath = `received/${runId}/${a?.asset_id ?? 'x'}_${sanitize(basename(zipPath))}`;
            const { error: upErr } = await admin.storage.from(DEPOSIT_BUCKET)
              .upload(depositPath, bytes, { contentType: meta.mime_type || 'application/octet-stream', upsert: true });
            if (upErr) throw upErr;
            meta.deposit_status = 'deposited';
            meta.deposit_path = depositPath;
            meta.file_size_bytes = bytes.byteLength;
            deposited += 1; depositedBytes += bytes.byteLength;
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
      const { error } = await admin.schema('ingest').from('partner_catalog_received_assets').insert(receivedRows.slice(i, i + INSERT_BATCH));
      if (error) throw error;
    }

    // ── Matching + compteurs (réutilise la plomberie d'import) ───────────────
    const { error: matchErr } = await ingestRpc.rpc('fn_match_partner_catalog_run', { p_run_id: runId, p_row_ids: null });
    if (matchErr) throw matchErr;
    await ingestRpc.rpc('fn_refresh_partner_catalog_run_counters', { p_run_id: runId });

    // ── Finalisation du run ──────────────────────────────────────────────────
    const finishedAt = new Date().toISOString();
    const summary = {
      parser: PARSER_VERSION, file_kind: 'zip', manifest_schema: MANIFEST_SCHEMA,
      source_library_id: sourceLibraryId, manifest_notice_count: records.length,
      inserted_rows: stagingRows.length, received_files_deposited: deposited,
      received_metadata_only: metadataOnly, received_failed: failed, deposited_bytes: depositedBytes,
      parsed_at: finishedAt,
    };
    const { error: finErr } = await admin.schema('ingest').from('partner_catalog_import_runs').update({
      detected_format: 'zip', run_status: 'ready_for_review', imported_rows: stagingRows.length,
      parser_version: PARSER_VERSION, summary, finished_at: finishedAt,
    }).eq('id', runId);
    if (finErr) throw finErr;

    return json({
      ok: true, run_id: runId, source_library_id: sourceLibraryId,
      inserted_rows: stagingRows.length, received_files_deposited: deposited,
      received_metadata_only: metadataOnly, received_failed: failed,
      next_step: 'Editorial review, then promote to drafts. Files parked for the asset-attach chantier.',
    });
  } catch (e) {
    if (runId) {
      try {
        const { data: run } = await admin.schema('ingest').from('partner_catalog_import_runs').select('error_log').eq('id', runId).maybeSingle();
        const log = Array.isArray(run?.error_log) ? run!.error_log : [];
        log.push({ at: new Date().toISOString(), error: String((e as Error)?.message || e) });
        await admin.schema('ingest').from('partner_catalog_import_runs').update({ run_status: 'failed', error_log: log }).eq('id', runId);
      } catch (_) { /* la trace d'erreur ne bloque jamais */ }
    }
    return json({ error: String((e as Error)?.message || e) }, 500);
  }
});
