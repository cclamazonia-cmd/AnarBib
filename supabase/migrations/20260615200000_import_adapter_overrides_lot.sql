-- =========================================================================
-- Adaptateur d'import « orthogonal » — câblage des overrides (axes Estrutura + Vocabulário).
--
-- Le parseur process-partner-catalog-import auto-détecte DÉJÀ la structure (MARC
-- ISO2709/XML, RIS, CSV+délimiteur) ET le vocabulaire MARC (UNIMARC vs MARC21, par
-- enregistrement via detectDialect). Ce lot permet à l'usager de FORCER un axe quand
-- l'auto se trompe : on stocke le choix sur le run, le parseur l'honore (saute la
-- détection correspondante). L'axe « Perfil » (preset de mapping) reste un chantier
-- séparé non implémenté ici.
--
--   1. colonne ingest.partner_catalog_import_runs.adapter_overrides (jsonb)
--   2. fn_import_set_adapter_overrides(run, format, vocabulary) — gardée coordenador,
--      appelée entre fn_import_create et fn_import_dispatch.
-- =========================================================================
BEGIN;

ALTER TABLE ingest.partner_catalog_import_runs
  ADD COLUMN IF NOT EXISTS adapter_overrides jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN ingest.partner_catalog_import_runs.adapter_overrides IS
  'Overrides de l''adaptateur d''import (axes orthogonaux). Clés optionnelles : '
  'forced_format (marc/ris/csv/tsv) et forced_vocabulary (unimarc/marc21). Absentes = auto. '
  'Lu par le parseur process-partner-catalog-import pour sauter l''auto-détection correspondante.';

CREATE OR REPLACE FUNCTION public.fn_import_set_adapter_overrides(
  p_run_id            bigint,
  p_forced_format     text DEFAULT NULL,
  p_forced_vocabulary text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth, pg_catalog
AS $$
DECLARE
  v_run ingest.partner_catalog_import_runs%rowtype;
  v_fmt text;
  v_voc text;
  v_ov  jsonb;
BEGIN
  IF p_run_id IS NULL THEN RAISE EXCEPTION 'run_id obrigatorio.'; END IF;
  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Run % introuvável.', p_run_id; END IF;

  -- Garde : coordenador de la biblio du run (ou admin réseau) — miroir IMP-14.
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = v_run.library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  -- Normalisation : NULL/'' = auto (axe non forcé).
  v_fmt := nullif(lower(btrim(coalesce(p_forced_format, ''))), '');
  v_voc := nullif(lower(btrim(coalesce(p_forced_vocabulary, ''))), '');
  IF v_fmt IS NOT NULL AND v_fmt NOT IN ('marc', 'ris', 'csv', 'tsv') THEN
    RAISE EXCEPTION 'forced_format inválido (%). Esperado: marc/ris/csv/tsv ou auto.', v_fmt;
  END IF;
  IF v_voc IS NOT NULL AND v_voc NOT IN ('unimarc', 'marc21') THEN
    RAISE EXCEPTION 'forced_vocabulary inválido (%). Esperado: unimarc/marc21 ou auto.', v_voc;
  END IF;

  v_ov := jsonb_strip_nulls(jsonb_build_object('forced_format', v_fmt, 'forced_vocabulary', v_voc));
  UPDATE ingest.partner_catalog_import_runs SET adapter_overrides = v_ov WHERE id = p_run_id;

  RETURN jsonb_build_object('ok', true, 'run_id', p_run_id, 'adapter_overrides', v_ov);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_import_set_adapter_overrides(bigint, text, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.fn_import_set_adapter_overrides(bigint, text, text) TO authenticated;

COMMENT ON FUNCTION public.fn_import_set_adapter_overrides(bigint, text, text) IS
  'Adaptateur d''import (overrides). Fixe forced_format (marc/ris/csv/tsv) et/ou forced_vocabulary '
  '(unimarc/marc21) sur un run, entre fn_import_create et fn_import_dispatch. NULL/auto = laisser '
  'l''auto-détection. Gardée coordenador de la biblio du run / admin réseau.';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='ingest' AND table_name='partner_catalog_import_runs'
                    AND column_name='adapter_overrides') THEN
    RAISE EXCEPTION 'verify: colonne adapter_overrides manquante';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                  WHERE n.nspname='public' AND p.proname='fn_import_set_adapter_overrides') THEN
    RAISE EXCEPTION 'verify: fn_import_set_adapter_overrides manquante';
  END IF;
  IF has_function_privilege('anon','public.fn_import_set_adapter_overrides(bigint,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'verify: set_adapter_overrides ne doit pas être exécutable par anon';
  END IF;
  RAISE NOTICE 'adaptateur overrides OK : colonne + RPC.';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_import_set_adapter_overrides(bigint, text, text);
--   ALTER TABLE ingest.partner_catalog_import_runs DROP COLUMN IF EXISTS adapter_overrides;
-- =========================================================================
