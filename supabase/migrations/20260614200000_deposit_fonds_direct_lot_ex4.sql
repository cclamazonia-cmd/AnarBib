-- =========================================================================
-- Paquet EX-4 (transfert direct fédéré d'un lot de fonds — niveau 2, mode a).
--
-- Reframing (cf. CADRAGE_EX4_…) : AnarBib est MONO-PROJET multi-tenant → le
-- « transfert direct fédéré » n'est PAS du storage cross-projet, mais une copie
-- INTRA-projet + l'écriture d'un run d'import pour le `library_id` de la companheira
-- réceptrice. Dépôt SEMI-AUTO (P4) : le lot arrive en `ready_for_review` chez elle.
--
-- Cette migration pose le point CROSS-TENANT gaté : une RPC SECURITY DEFINER qui,
-- déclenchée par un·e coordenador de la biblio SOURCE, crée (côté RÉCEPTRICE) la
-- source de dépôt + le run d'import — APRÈS double garde : coordenador-source ET
-- droit `mutualisation` actif entre les deux biblios (P2). L'EF deposit-fonds-direct
-- remplit ensuite ce run (staging + copie des fichiers) en service_role.
-- =========================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_deposit_fonds_direct_prepare(
  p_source_library_id uuid,
  p_target_library_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth, pg_catalog
AS $$
DECLARE
  v_authorized boolean;
  v_source_name text;
  v_source_id bigint;
  v_run_id bigint;
BEGIN
  IF p_source_library_id IS NULL OR p_target_library_id IS NULL THEN
    RAISE EXCEPTION 'library ids obrigatorios.';
  END IF;
  IF p_source_library_id = p_target_library_id THEN
    RAISE EXCEPTION 'Origem e destino identicos.';
  END IF;

  -- Garde 1 : acte de coordenador de la biblio SOURCE (IMP-14) ou admin réseau.
  SELECT (
    EXISTS (SELECT 1 FROM public.user_library_memberships m
             WHERE m.user_id = auth.uid() AND m.library_id = p_source_library_id
               AND m.status = 'active' AND m.role = 'coordenador')
    OR public.fn_caller_is_network_admin()
  ) INTO v_authorized;
  IF NOT v_authorized THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca de origem.';
  END IF;

  -- Garde 2 : droit `mutualisation` ACTIF entre les deux biblios (P2, symétrique).
  IF NOT public.fn_partnership_has_active_right(p_source_library_id, p_target_library_id, 'mutualisation') THEN
    RAISE EXCEPTION 'Direito de mutualizacao inativo entre as bibliotecas.';
  END IF;

  -- Nom de la donatrice (voyage avec le lot — provenance).
  SELECT coalesce(nullif(trim(l.name), ''), nullif(trim(l.short_name), ''), 'Biblioteca de origem')
    INTO v_source_name
    FROM public.libraries l WHERE l.id = p_source_library_id;
  IF v_source_name IS NULL THEN
    RAISE EXCEPTION 'Biblioteca de origem % introuvable.', p_source_library_id;
  END IF;

  -- Source de dépôt côté RÉCEPTRICE (library_id = cible) — dédup par nom.
  SELECT id INTO v_source_id
    FROM ingest.partner_catalog_sources
   WHERE library_id = p_target_library_id
     AND source_kind = 'partner_deposit'
     AND partner_name = v_source_name
   LIMIT 1;
  IF v_source_id IS NULL THEN
    INSERT INTO ingest.partner_catalog_sources
      (partner_name, library_id, relation_status, source_kind, import_enabled, notes)
    VALUES
      (v_source_name, p_target_library_id, 'mutualizacao_autorizada', 'partner_deposit', true,
       'Dépôt direct de fonds mutualisé (EX-4) depuis ' || v_source_name)
    RETURNING id INTO v_source_id;
  END IF;

  -- Run d'import côté réceptrice (sera rempli par l'EF en service_role).
  INSERT INTO ingest.partner_catalog_import_runs
    (source_id, requested_by, bucket_id, storage_path, original_filename,
     run_status, parser_version, library_id, summary)
  VALUES
    (v_source_id, auth.uid(), 'partner-catalog-deposits',
     'direct/' || p_source_library_id::text || '/' || p_target_library_id::text,
     'fonds-direct-' || v_source_name, 'processing', 'fonds_direct_v1', p_target_library_id,
     jsonb_build_object('mode', 'direct', 'source_library_id', p_source_library_id))
  RETURNING id INTO v_run_id;

  RETURN jsonb_build_object(
    'ok', true, 'run_id', v_run_id, 'target_source_id', v_source_id,
    'source_name', v_source_name, 'target_library_id', p_target_library_id
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_deposit_fonds_direct_prepare(uuid, uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_deposit_fonds_direct_prepare(uuid, uuid) TO authenticated, service_role;

COMMENT ON FUNCTION public.fn_deposit_fonds_direct_prepare(uuid, uuid) IS
  'Paquet EX-4 (transfert direct de fonds, mode a). Point cross-tenant GATÉ : déclenché par un '
  'coordenador de la biblio source, crée la source de dépôt + le run d''import CÔTÉ RÉCEPTRICE '
  '(library_id=cible) après double garde coordenador-source + droit mutualisation actif (symétrique). '
  'L''EF deposit-fonds-direct remplit ensuite le run (staging + copie intra-projet des fichiers).';

-- ─── Vérification ───────────────────────────────────────────────────────────
DO $verify$
DECLARE v_fn int;
BEGIN
  SELECT count(*) INTO v_fn FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname='public' AND p.proname='fn_deposit_fonds_direct_prepare';
  IF v_fn <> 1 THEN RAISE EXCEPTION 'verify EX-4: fn_deposit_fonds_direct_prepare manquante'; END IF;
  RAISE NOTICE 'paquet EX-4 OK : RPC prepare (cross-tenant gaté mutualisation).';
END;
$verify$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
--   DROP FUNCTION IF EXISTS public.fn_deposit_fonds_direct_prepare(uuid, uuid);
-- =========================================================================
