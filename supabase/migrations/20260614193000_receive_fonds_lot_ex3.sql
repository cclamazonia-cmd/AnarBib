-- =========================================================================
-- Paquet EX-3 (réception d'un lot de fonds — niveau 2). Piste A « dépôt + report ».
--
-- La companheira réceptrice ré-importe le ZIP d'export de fonds (produit par
-- EX-2 / export-fonds-bundle) PAR LE PIPELINE INGEST EXISTANT : le ZIP devient
-- un run d'import normal (mêmes tables, même matching, même review→drafts).
-- L'EF sœur `receive-fonds-bundle` déballe le manifeste et, EN PLUS des notices,
-- DÉPOSE les fichiers reçus (bucket partner-catalog-deposits) et les PARQUE ici
-- avec leur provenance — prêts pour le futur chantier « attache d'asset » (la
-- création/liaison du digital_asset est volontairement HORS EX-3, cf. décision
-- 14/06 : brique sortie en chantier dédié).
--
-- Contenu :
--   1. Table ingest.partner_catalog_received_assets (parking des fichiers reçus).
--   2. fn_dispatch_partner_catalog_import : route un run detected_format='zip'
--      vers receive-fonds-bundle (sinon process-partner-catalog-import, inchangé).
-- =========================================================================
BEGIN;

-- ─── 1. Parking des fichiers reçus (un par asset du manifeste) ──────────────
CREATE TABLE IF NOT EXISTS ingest.partner_catalog_received_assets (
  id                        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_id                    bigint NOT NULL
                              REFERENCES ingest.partner_catalog_import_runs(id) ON DELETE CASCADE,
  staging_row_id            bigint
                              REFERENCES ingest.partner_catalog_staging_rows(id) ON DELETE SET NULL,
  -- Identité d'origine (chez la donatrice) + provenance portée par le manifeste.
  source_asset_id           bigint,
  asset_kind                text,
  title                     text,
  mime_type                 text,
  rights_status             text,
  checksum_sha256           text,
  source_name               text,
  source_license_name       text,
  attribution_text          text,
  -- Localisation : chemin dans le ZIP + dépôt effectif (bucket de réception).
  manifest_file             text,
  deposit_bucket            text NOT NULL DEFAULT 'partner-catalog-deposits',
  deposit_path              text,
  file_size_bytes           bigint,
  deposit_status            text NOT NULL DEFAULT 'deposited'
                              CHECK (deposit_status IN ('deposited','metadata_only','attached','failed')),
  deposit_error             text,
  -- Rempli par le futur chantier « attache d'asset » (création du digital_asset).
  attached_digital_asset_id bigint,
  created_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pcra_run        ON ingest.partner_catalog_received_assets(run_id);
CREATE INDEX IF NOT EXISTS idx_pcra_staging    ON ingest.partner_catalog_received_assets(staging_row_id);
CREATE INDEX IF NOT EXISTS idx_pcra_unattached ON ingest.partner_catalog_received_assets(run_id)
  WHERE attached_digital_asset_id IS NULL AND deposit_status = 'deposited';

COMMENT ON TABLE ingest.partner_catalog_received_assets IS
  'Paquet EX-3. Fichiers reçus dans un ZIP d''export de fonds : déposés dans le bucket de '
  'réception et parqués avec leur provenance (manifeste). L''attache au livre (création du '
  'digital_asset) est faite plus tard par le chantier « gestion des fichiers numériques ».';

-- Accès : écrit par l'EF (service_role) ; lecture client via futures RPC SECURITY
-- DEFINER. RLS activé sans policy permissive → aucun accès direct authenticated.
ALTER TABLE ingest.partner_catalog_received_assets ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON ingest.partner_catalog_received_assets TO service_role;

-- ─── 2. Dispatch : router le ZIP de fonds vers l'EF sœur ────────────────────
-- Réécrit fn_dispatch_partner_catalog_import (baseline) à l'identique, en routant
-- les runs detected_format='zip' vers receive-fonds-bundle (EX-3). Les autres
-- formats restent dirigés vers process-partner-catalog-import (inchangé).
CREATE OR REPLACE FUNCTION ingest.fn_dispatch_partner_catalog_import(
  p_run_id bigint, p_force_reparse boolean DEFAULT false
) RETURNS jsonb
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'ingest', 'public', 'auth'
AS $$
declare
  v_run ingest.partner_catalog_import_runs%rowtype;
  v_secret text;
  v_request_id bigint;
  v_body jsonb;
  v_log_id bigint;
  v_base text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/';
  v_function_url text;
begin
  select * into v_run from ingest.partner_catalog_import_runs where id = p_run_id;
  if not found then
    raise exception 'Run % introuvable', p_run_id;
  end if;

  -- EX-3 : un ZIP de fonds est déballé/parqué par l'EF sœur receive-fonds-bundle ;
  -- tout autre format suit le pipeline d'import standard.
  v_function_url := v_base || case when v_run.detected_format = 'zip'
                                   then 'receive-fonds-bundle'
                                   else 'process-partner-catalog-import' end;

  select ds.decrypted_secret into v_secret
  from vault.decrypted_secrets ds
  where ds.name = 'ANARBIB_PARTNER_IMPORT_SECRET'
  order by ds.created_at desc limit 1;

  if coalesce(v_secret, '') = '' then
    raise exception 'Secret ANARBIB_PARTNER_IMPORT_SECRET introuvable dans vault.decrypted_secrets';
  end if;

  v_body := jsonb_build_object('run_id', p_run_id, 'force_reparse', p_force_reparse);

  insert into ingest.partner_catalog_import_dispatch_log
    (run_id, force_reparse, request_body, requested_by, dispatch_status)
  values (p_run_id, p_force_reparse, v_body, auth.uid(), 'queued')
  returning id into v_log_id;

  v_request_id := net.http_post(
    url := v_function_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-import-secret', v_secret),
    body := v_body,
    timeout_milliseconds := 60000
  );

  update ingest.partner_catalog_import_dispatch_log
     set request_id = v_request_id, dispatch_status = 'sent'
   where id = v_log_id;

  return jsonb_build_object('ok', true, 'run_id', p_run_id, 'dispatch_log_id', v_log_id,
    'request_id', v_request_id, 'force_reparse', p_force_reparse, 'function_url', v_function_url);
exception
  when others then
    if v_log_id is not null then
      update ingest.partner_catalog_import_dispatch_log
         set dispatch_status = 'failed', error_text = sqlerrm
       where id = v_log_id;
    end if;
    raise;
end;
$$;

ALTER FUNCTION ingest.fn_dispatch_partner_catalog_import(bigint, boolean) OWNER TO postgres;
REVOKE ALL    ON FUNCTION ingest.fn_dispatch_partner_catalog_import(bigint, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_dispatch_partner_catalog_import(bigint, boolean) TO service_role;

COMMENT ON FUNCTION ingest.fn_dispatch_partner_catalog_import(bigint, boolean) IS
  'Dispatch backend explicite (pg_net). EX-3 : route detected_format=zip vers receive-fonds-bundle '
  '(déballage manifeste + dépôt fichiers reçus), sinon process-partner-catalog-import. S4 : non chaîné.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_tbl int; v_fn int;
BEGIN
  SELECT count(*) INTO v_tbl FROM pg_tables
    WHERE schemaname='ingest' AND tablename='partner_catalog_received_assets';
  IF v_tbl <> 1 THEN RAISE EXCEPTION 'verify EX-3: table received_assets manquante'; END IF;
  SELECT count(*) INTO v_fn FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='ingest' AND p.proname='fn_dispatch_partner_catalog_import';
  IF v_fn < 1 THEN RAISE EXCEPTION 'verify EX-3: fn_dispatch manquante'; END IF;
  RAISE NOTICE 'paquet EX-3 OK : received_assets + dispatch routé zip.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP TABLE IF EXISTS ingest.partner_catalog_received_assets;
--   -- + restaurer fn_dispatch_partner_catalog_import depuis le baseline.
-- =========================================================================
