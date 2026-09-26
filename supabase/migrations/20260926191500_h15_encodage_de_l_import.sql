-- =====================================================================
-- H15 — l'encodage d'un fichier importé se règle, et un import se retraite
-- sans détruire ce qu'il a produit.
-- Date : 2026-09-26 · Backlog v34 H15 · Aller-retour PMB (G15, H14)
--
-- L'EF process-partner-catalog-import décode désormais en UTF-8 STRICT, se
-- replie sur windows-1252 (SUPPOSÉ, dit au run) et honore
-- adapter_overrides.forced_encoding (encoding.ts). Cette migration donne à
-- l'écran les deux gestes qui vont avec :
--
-- 1. fn_import_set_adapter_overrides gagne p_forced_encoding
--    (utf-8 | windows-1252 | iso-8859-1 | NULL = auto) ET devient une FUSION :
--    elle ne réécrit que les trois clés qu'elle gère. Jusqu'ici elle
--    REMPLAÇAIT tout adapter_overrides — profile_id compris (l'écran s'en
--    tirait en appelant fn_import_set_profile APRÈS). Partie de la définition
--    RÉELLE (pg_get_functiondef en prod, 26/09/2026). DROP + CREATE et non
--    une surcharge : oracle_existence_ordre_tests compte les fonctions par nom.
--    Même garde, même message ('Run introuvável.', sans dire si le run existe).
--
-- 2. fn_import_dispatch refuse de RETRAITER (p_force_reparse) un run dont des
--    lignes sont déjà devenues des brouillons : l'EF efface les lignes de
--    staging avant de relire, et ingest.partner_catalog_row_to_draft les suit
--    en ON DELETE CASCADE — les brouillons perdraient le lien vers leur import
--    (provenance, révision de lot). Constat du 26/09 : 2 runs sur 8 ont des
--    brouillons. HINT error.import.reparse_after_promotion (10 locales).
--    Partie de la définition RÉELLE, garde ajoutée par ancrage.
-- =====================================================================

-- ── 1. fn_import_set_adapter_overrides ────────────────────────────────
DROP FUNCTION IF EXISTS public.fn_import_set_adapter_overrides(bigint, text, text);

CREATE FUNCTION public.fn_import_set_adapter_overrides(
  p_run_id bigint,
  p_forced_format text DEFAULT NULL::text,
  p_forced_vocabulary text DEFAULT NULL::text,
  p_forced_encoding text DEFAULT NULL::text
) RETURNS jsonb
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path TO 'public', 'ingest', 'auth', 'pg_catalog'
AS $function$
DECLARE
  v_run ingest.partner_catalog_import_runs%rowtype;
  v_fmt text;
  v_voc text;
  v_enc text;
  v_ov  jsonb;
BEGIN
  IF p_run_id IS NULL THEN RAISE EXCEPTION 'run_id obrigatorio.'; END IF;
  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Run introuvável.'; END IF;

  -- Garde : coordenador de la biblio du run (ou admin réseau) — miroir IMP-14.
  IF NOT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = v_run.library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) THEN
    RAISE EXCEPTION 'Run introuvável.';
  END IF;

  -- Normalisation : NULL/'' = auto (axe non forcé).
  v_fmt := nullif(lower(btrim(coalesce(p_forced_format, ''))), '');
  v_voc := nullif(lower(btrim(coalesce(p_forced_vocabulary, ''))), '');
  v_enc := nullif(lower(btrim(coalesce(p_forced_encoding, ''))), '');
  IF v_fmt IS NOT NULL AND v_fmt NOT IN ('marc', 'ris', 'csv', 'tsv') THEN
    RAISE EXCEPTION 'forced_format inválido (%). Esperado: marc/ris/csv/tsv ou auto.', v_fmt;
  END IF;
  IF v_voc IS NOT NULL AND v_voc NOT IN ('unimarc', 'marc21') THEN
    RAISE EXCEPTION 'forced_vocabulary inválido (%). Esperado: unimarc/marc21 ou auto.', v_voc;
  END IF;
  -- Même liste fermée que IMPORT_ENCODINGS (encoding.ts) ; iso-8859-1 est lu
  -- par le décodeur windows-1252 (WHATWG), qui le contient.
  IF v_enc IS NOT NULL AND v_enc NOT IN ('utf-8', 'windows-1252', 'iso-8859-1') THEN
    RAISE EXCEPTION 'forced_encoding inválido (%). Esperado: utf-8/windows-1252/iso-8859-1 ou auto.', v_enc;
  END IF;

  -- FUSION : seules les trois clés gérées ici sont réécrites ; profile_id
  -- (fn_import_set_profile) et toute autre clé restent.
  v_ov := (coalesce(v_run.adapter_overrides, '{}'::jsonb)
            - 'forced_format' - 'forced_vocabulary' - 'forced_encoding')
          || jsonb_strip_nulls(jsonb_build_object(
               'forced_format', v_fmt, 'forced_vocabulary', v_voc, 'forced_encoding', v_enc));
  UPDATE ingest.partner_catalog_import_runs SET adapter_overrides = v_ov WHERE id = p_run_id;

  RETURN jsonb_build_object('ok', true, 'run_id', p_run_id, 'adapter_overrides', v_ov);
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_set_adapter_overrides(bigint, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_import_set_adapter_overrides(bigint, text, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_import_set_adapter_overrides(bigint, text, text, text) IS
  'Adaptateur d''import (overrides). Fixe forced_format (marc/ris/csv/tsv), '
  'forced_vocabulary (unimarc/marc21) et/ou forced_encoding (utf-8/windows-1252/'
  'iso-8859-1) sur un run, entre fn_import_create et fn_import_dispatch — ou avant '
  'un retraitement. NULL/auto = laisser l''auto-détection. FUSION depuis le '
  '26/09/2026 (H15) : profile_id et les autres clés sont conservés. Gardée '
  'coordenador de la biblio du run / admin réseau.';

-- ── 2. fn_import_dispatch : pas de retraitement après promotion ───────
CREATE OR REPLACE FUNCTION public.fn_import_dispatch(p_run_id bigint, p_force_reparse boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor public.my_access%rowtype;
  v_run_library_id uuid;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT r.library_id INTO v_run_library_id
  FROM ingest.partner_catalog_import_runs r
  WHERE r.id = p_run_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  IF v_run_library_id IS DISTINCT FROM v_actor.library_id THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;

  -- H15 (26/09/2026) : retraiter efface les lignes de staging, et le lien
  -- ligne → brouillon les suit (ON DELETE CASCADE). Un run déjà promu ne se
  -- relit donc plus : on importe à nouveau le fichier.
  IF coalesce(p_force_reparse, false)
     AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = p_run_id) THEN
    RAISE EXCEPTION 'Import % ja promovido em rascunhos : nao pode ser reprocessado.', p_run_id
      USING HINT = 'error.import.reparse_after_promotion';
  END IF;

  RETURN ingest.fn_dispatch_partner_catalog_import(
    p_run_id       := p_run_id,
    p_force_reparse := p_force_reparse
  );
END;
$function$;

-- Droits inchangés (CREATE OR REPLACE les conserve) ; réaffirmés pour la
-- garde grants_herites (T10/T12).
REVOKE EXECUTE ON FUNCTION public.fn_import_dispatch(bigint, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_import_dispatch(bigint, boolean) TO authenticated, service_role;
