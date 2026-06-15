// Edge Function : gc-deposits (chantier fichiers numériques, point 2 — purge des dépôts).
//
// Après attache d'un fonds reçu, l'EF attach-received-asset COPIE le fichier du bucket de
// réception (partner-catalog-deposits) vers le bucket final : le dépôt d'origine devient
// redondant. Le DELETE storage étant interdit en SQL (trigger storage.protect_delete), et la
// policy partner_deposit_delete inopérante côté usager (chemin `received/<run>/…` ≠ library_id),
// la purge passe par cette EF service_role, déclenchée par un cron (ingest.fn_cron_gc_deposits).
//
// Supprime les fichiers de dépôt des received_assets ATTACHÉS depuis > age_days (défaut 30),
// puis met deposit_path à NULL (marque purgé, évite la re-purge). Ne touche JAMAIS aux dépôts
// non attachés (en attente d'attache). verify_jwt=false (cf. config.toml) : auth x-import-secret.

import { createClient } from 'npm:@supabase/supabase-js@2';

const DEPOSIT_BUCKET = 'partner-catalog-deposits';
const IMPORT_SECRET_HEADER = 'x-import-secret';
const IMPORT_SECRET_ENV = 'ANARBIB_PARTNER_IMPORT_SECRET';
const DEFAULT_AGE_DAYS = 30;
const MAX_BATCH = 1000;

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ error: 'Method not allowed. Use POST.' }, 405);

  // Auth interne (server-to-server depuis le cron SQL).
  const expectedSecret = Deno.env.get(IMPORT_SECRET_ENV);
  if (!expectedSecret) return json({ error: `Missing secret ${IMPORT_SECRET_ENV}` }, 500);
  if (req.headers.get(IMPORT_SECRET_HEADER) !== expectedSecret) return json({ error: 'Unauthorized' }, 401);

  let body: any = {};
  try { body = await req.json(); } catch { /* corps optionnel */ }
  const ageDays = Number.isFinite(Number(body?.age_days)) && Number(body.age_days) >= 0 ? Number(body.age_days) : DEFAULT_AGE_DAYS;
  const dryRun = body?.dry_run === true;

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceKey) return json({ error: 'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY' }, 500);
  const service = createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });

  const cutoff = new Date(Date.now() - ageDays * 86400000).toISOString();

  // Candidats : ATTACHÉS, avec un fichier de dépôt encore présent, plus vieux que le seuil.
  const { data: rows, error } = await service.schema('ingest')
    .from('partner_catalog_received_assets')
    .select('id, deposit_bucket, deposit_path, created_at')
    .eq('deposit_status', 'attached')
    .not('deposit_path', 'is', null)
    .lt('created_at', cutoff)
    .limit(MAX_BATCH);
  if (error) return json({ error: error.message }, 500);

  const candidates = rows ?? [];
  if (dryRun) {
    return json({ ok: true, dry_run: true, age_days: ageDays, candidates: candidates.length });
  }

  let removed = 0, failed = 0;
  const purgedIds: number[] = [];
  const errors: string[] = [];
  for (const r of candidates) {
    try {
      const { error: rmErr } = await service.storage.from(r.deposit_bucket || DEPOSIT_BUCKET).remove([r.deposit_path]);
      if (rmErr) throw rmErr;
      removed += 1;
      purgedIds.push(Number(r.id));
    } catch (e) {
      failed += 1;
      if (errors.length < 10) errors.push(`#${r.id}: ${String((e as Error)?.message || e)}`);
    }
  }

  // Marque purgé (deposit_path=NULL) → reflète le fichier retiré + évite la re-purge.
  if (purgedIds.length) {
    await service.schema('ingest').from('partner_catalog_received_assets')
      .update({ deposit_path: null }).in('id', purgedIds);
  }

  return json({ ok: true, age_days: ageDays, candidates: candidates.length, removed, failed, errors });
});
