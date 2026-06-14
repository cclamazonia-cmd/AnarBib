-- =========================================================================
-- Paquet EX-2 (DB) — Table de traçabilité « run d'export de fonds »
-- =========================================================================
-- Date     : 2026-06-14 (UTC 20260614180000)
-- Chantier : Importacoes/Exportacoes — face Export, niveau 2 (export de fonds).
-- Auteur   : Claude (Opus 4.8) pour Xavier Van Welden
--
-- BESOIN : tracer chaque remise de fonds (miroir du run d'import
--   `ingest.partner_catalog_import_runs`) : qui exporte quoi, vers qui, quand,
--   combien de notices/fichiers. Alimentée par l'EF `export-fonds-bundle` (EX-2)
--   en service_role. Lecture staff de la biblio.
-- =========================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.fonds_export_runs (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id         uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,  -- source
  target_kind        text NOT NULL DEFAULT 'download',   -- 'download' (ZIP) | 'companheira' (transfert direct)
  target_library_id  uuid REFERENCES public.libraries(id) ON DELETE SET NULL,
  mode               text NOT NULL DEFAULT 'zip',        -- 'zip' | 'direct'
  eligibility        text NOT NULL DEFAULT 'public_domain_confirmed',
  format             text,                                -- format de sérialisation des notices
  status             text NOT NULL DEFAULT 'preparation',
  notice_count       integer NOT NULL DEFAULT 0,
  file_count         integer NOT NULL DEFAULT 0,
  total_bytes        bigint  NOT NULL DEFAULT 0,
  truncated          boolean NOT NULL DEFAULT false,      -- borne de volumétrie atteinte
  error_log          text,
  created_by         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  packaged_at        timestamptz,
  CONSTRAINT fer_target_kind_chk CHECK (target_kind IN ('download', 'companheira')),
  CONSTRAINT fer_mode_chk        CHECK (mode IN ('zip', 'direct')),
  CONSTRAINT fer_status_chk      CHECK (status IN ('preparation', 'packaged', 'delivered', 'failed', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS fonds_export_runs_library_idx ON public.fonds_export_runs(library_id);
CREATE INDEX IF NOT EXISTS fonds_export_runs_status_idx  ON public.fonds_export_runs(status);

COMMENT ON TABLE public.fonds_export_runs IS
  'Traçabilité des remises de fonds numériques (export niveau 2, paquet EX-2). Miroir du run '
  'd''import ingest.partner_catalog_import_runs. Alimentée par l''EF export-fonds-bundle (service_role) ; '
  'lecture staff de la biblio.';

GRANT SELECT ON public.fonds_export_runs TO authenticated;
GRANT ALL    ON public.fonds_export_runs TO service_role;

ALTER TABLE public.fonds_export_runs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fonds_export_runs_select_staff"
  ON public.fonds_export_runs FOR SELECT TO authenticated
  USING (public.user_can_act_as_staff_on_library(library_id));

CREATE TRIGGER fonds_export_runs_set_updated_at
  BEFORE UPDATE ON public.fonds_export_runs
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_t int; v_rls int;
BEGIN
  SELECT count(*) INTO v_t FROM information_schema.tables
    WHERE table_schema='public' AND table_name='fonds_export_runs';
  IF v_t <> 1 THEN RAISE EXCEPTION 'verify: table fonds_export_runs absente'; END IF;
  SELECT count(*) INTO v_rls FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='fonds_export_runs' AND c.relrowsecurity;
  IF v_rls <> 1 THEN RAISE EXCEPTION 'verify: RLS non activée'; END IF;
  RAISE NOTICE 'paquet EX-2 (DB) OK : table fonds_export_runs (RLS).';
END;
$verify$;

COMMIT;

-- Rollback : DROP TABLE IF EXISTS public.fonds_export_runs;
