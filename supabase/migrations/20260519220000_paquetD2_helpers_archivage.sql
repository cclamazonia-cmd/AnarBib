-- ============================================================================
-- Paquet D.2 - Helpers d'archivage SECURITY DEFINER
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.4 (paquet D)
-- Dependance : paquet D.1 (colonnes archived_at + archive_reason).
--
-- 3 fonctions livrees :
--
--   1. fn_archive_library_circulation(p_library_id, p_proposal_id)
--      Archive les transactions vivantes (emprestimos/reservas/consultas/ill)
--      lors d'une transition de profil type 4 (circulation -> off, etc.).
--      Idempotent : ne re-archive pas les lignes deja archivees.
--      Retour jsonb : compteur par table archivee.
--
--   2. fn_unarchive_library_circulation(p_library_id, p_proposal_id)
--      Restaure les lignes archivees par la proposition p_proposal_id donnee.
--      Utilise pour la revocation pendant la carence (annulation d'une proposition).
--      Retour jsonb : compteur par table restauree.
--
--   3. fn_archive_library_cotisations(p_library_id, p_proposal_id)
--      Archive uniquement les cotisations EN COURS (valid_until NULL ou futur).
--      Lors d'une transition full_sigb -> informal qui supprime la notion de cotisation.
--      Les cotisations historiques restent intactes pour la tracabilite comptable.
--
-- Doctrine v2 :
--   - SECURITY DEFINER + SET search_path = public, pg_temp
--   - REVOKE EXECUTE FROM PUBLIC, anon, authenticated, service_role
--   - GRANT TO postgres uniquement (appelees par fn_propose_library_profile_change
--     elle-meme SECURITY DEFINER owned par postgres)
--   - DO block verification fail-fast
--
-- Particularite ILL : la table interlibrary_loans_v2 n'a pas de colonne
-- library_id directe (lender_library_id + borrower_library_id). On archive
-- toutes les lignes ou la biblio cible apparait comme lender OU borrower.
-- Si une biblio passe en off, ses PEB en tant que pretteuse ET en tant que
-- preneuse sont archives - c'est cohérent avec la doctrine triple defense
-- PEB (la biblio sort fonctionnellement du reseau de PEB).
--
-- Statuts vivants par table (selon CHECK constraints D.1) :
--   emprestimos_v2     : aberto, parcialmente_devolvido
--   reservas_v2        : ativa, parcialmente_encerrada
--   consultas_locais_v2 : ativa, parcialmente_encerrada
--   interlibrary_loans_v2 : preparacao, aguardando_saida, emprestado,
--                           parcialmente_devolvido, em_devolucao, atrasado
--   membership_payments : valid_until IS NULL OR valid_until >= current_date
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. fn_archive_library_circulation
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_archive_library_circulation(
  p_library_id uuid,
  p_proposal_id uuid DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_archive_reason text;
  v_now timestamptz := now();
  v_emp_count int := 0;
  v_res_count int := 0;
  v_con_count int := 0;
  v_ill_count int := 0;
BEGIN
  -- Determiner le motif d'archivage : profile_transition si un proposal_id est fourni,
  -- admin_manual sinon (cas d'usage non encore documente mais ouvert pour D.5).
  v_archive_reason := CASE
    WHEN p_proposal_id IS NOT NULL THEN 'profile_transition'
    ELSE 'admin_manual'
  END;

  -- Garde-fou : la biblio doit exister (sinon retour vide pour idempotence)
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = p_library_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'reason', 'library_not_found',
      'library_id', p_library_id
    );
  END IF;

  -- Archivage emprestimos_v2 (statuts vivants : aberto, parcialmente_devolvido)
  WITH archived AS (
    UPDATE public.emprestimos_v2
       SET archived_at = v_now,
           archive_reason = v_archive_reason
     WHERE library_id = p_library_id
       AND archived_at IS NULL
       AND status_global IN ('aberto', 'parcialmente_devolvido')
     RETURNING 1
  )
  SELECT count(*) INTO v_emp_count FROM archived;

  -- Archivage reservas_v2 (statuts vivants : ativa, parcialmente_encerrada)
  WITH archived AS (
    UPDATE public.reservas_v2
       SET archived_at = v_now,
           archive_reason = v_archive_reason
     WHERE library_id = p_library_id
       AND archived_at IS NULL
       AND status_global IN ('ativa', 'parcialmente_encerrada')
     RETURNING 1
  )
  SELECT count(*) INTO v_res_count FROM archived;

  -- Archivage consultas_locais_v2 (statuts vivants : ativa, parcialmente_encerrada)
  WITH archived AS (
    UPDATE public.consultas_locais_v2
       SET archived_at = v_now,
           archive_reason = v_archive_reason
     WHERE library_id = p_library_id
       AND archived_at IS NULL
       AND status_global IN ('ativa', 'parcialmente_encerrada')
     RETURNING 1
  )
  SELECT count(*) INTO v_con_count FROM archived;

  -- Archivage interlibrary_loans_v2 (lender OU borrower, statuts vivants)
  WITH archived AS (
    UPDATE public.interlibrary_loans_v2
       SET archived_at = v_now,
           archive_reason = v_archive_reason
     WHERE (lender_library_id = p_library_id OR borrower_library_id = p_library_id)
       AND archived_at IS NULL
       AND status_global IN ('preparacao', 'aguardando_saida', 'emprestado',
                              'parcialmente_devolvido', 'em_devolucao', 'atrasado')
     RETURNING 1
  )
  SELECT count(*) INTO v_ill_count FROM archived;

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', p_library_id,
    'proposal_id', p_proposal_id,
    'archive_reason', v_archive_reason,
    'archived_at', v_now,
    'counts', jsonb_build_object(
      'emprestimos', v_emp_count,
      'reservas', v_res_count,
      'consultas', v_con_count,
      'interlibrary_loans', v_ill_count,
      'total', v_emp_count + v_res_count + v_con_count + v_ill_count
    )
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_archive_library_circulation(uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_archive_library_circulation(uuid, uuid) TO postgres;

-- ============================================================================
-- 2. fn_unarchive_library_circulation
-- ============================================================================
-- Restaure les lignes archivees pendant la carence d'une proposition.
-- Filtre strict : library_id + (archived_at IS NOT NULL) + archive_reason = 'profile_transition'.
-- On NE TOUCHE PAS les lignes archivees pour 'admin_manual' (celles-ci relevent
-- de fn_unarchive_transaction du paquet D.5 avec audit individuel).
CREATE OR REPLACE FUNCTION public.fn_unarchive_library_circulation(
  p_library_id uuid,
  p_proposal_id uuid DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_emp_count int := 0;
  v_res_count int := 0;
  v_con_count int := 0;
  v_ill_count int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = p_library_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'reason', 'library_not_found',
      'library_id', p_library_id
    );
  END IF;

  -- Restauration emprestimos_v2
  WITH unarchived AS (
    UPDATE public.emprestimos_v2
       SET archived_at = NULL,
           archive_reason = NULL
     WHERE library_id = p_library_id
       AND archived_at IS NOT NULL
       AND archive_reason = 'profile_transition'
     RETURNING 1
  )
  SELECT count(*) INTO v_emp_count FROM unarchived;

  -- Restauration reservas_v2
  WITH unarchived AS (
    UPDATE public.reservas_v2
       SET archived_at = NULL,
           archive_reason = NULL
     WHERE library_id = p_library_id
       AND archived_at IS NOT NULL
       AND archive_reason = 'profile_transition'
     RETURNING 1
  )
  SELECT count(*) INTO v_res_count FROM unarchived;

  -- Restauration consultas_locais_v2
  WITH unarchived AS (
    UPDATE public.consultas_locais_v2
       SET archived_at = NULL,
           archive_reason = NULL
     WHERE library_id = p_library_id
       AND archived_at IS NOT NULL
       AND archive_reason = 'profile_transition'
     RETURNING 1
  )
  SELECT count(*) INTO v_con_count FROM unarchived;

  -- Restauration interlibrary_loans_v2 (lender OU borrower)
  WITH unarchived AS (
    UPDATE public.interlibrary_loans_v2
       SET archived_at = NULL,
           archive_reason = NULL
     WHERE (lender_library_id = p_library_id OR borrower_library_id = p_library_id)
       AND archived_at IS NOT NULL
       AND archive_reason = 'profile_transition'
     RETURNING 1
  )
  SELECT count(*) INTO v_ill_count FROM unarchived;

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', p_library_id,
    'proposal_id', p_proposal_id,
    'counts', jsonb_build_object(
      'emprestimos', v_emp_count,
      'reservas', v_res_count,
      'consultas', v_con_count,
      'interlibrary_loans', v_ill_count,
      'total', v_emp_count + v_res_count + v_con_count + v_ill_count
    )
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_unarchive_library_circulation(uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_unarchive_library_circulation(uuid, uuid) TO postgres;

-- ============================================================================
-- 3. fn_archive_library_cotisations
-- ============================================================================
-- Archive uniquement les cotisations EN COURS (valid_until NULL ou futur).
-- Les cotisations historiques (valid_until depasse) restent inchangees pour
-- la tracabilite comptable (doctrine spec §9.4).
--
-- Cas d'usage : transition full_sigb -> informal qui supprime la notion de
-- cotisation pour la biblio. Pas appelee dans les autres transitions.
CREATE OR REPLACE FUNCTION public.fn_archive_library_cotisations(
  p_library_id uuid,
  p_proposal_id uuid DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_archive_reason text;
  v_now timestamptz := now();
  v_mp_count int := 0;
BEGIN
  v_archive_reason := CASE
    WHEN p_proposal_id IS NOT NULL THEN 'profile_transition'
    ELSE 'admin_manual'
  END;

  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = p_library_id) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'reason', 'library_not_found',
      'library_id', p_library_id
    );
  END IF;

  -- Archivage cotisations EN COURS : valid_until NULL (sans expiration) ou >= today
  WITH archived AS (
    UPDATE public.membership_payments
       SET archived_at = v_now,
           archive_reason = v_archive_reason
     WHERE library_id = p_library_id
       AND archived_at IS NULL
       AND (valid_until IS NULL OR valid_until >= current_date)
     RETURNING 1
  )
  SELECT count(*) INTO v_mp_count FROM archived;

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', p_library_id,
    'proposal_id', p_proposal_id,
    'archive_reason', v_archive_reason,
    'archived_at', v_now,
    'counts', jsonb_build_object(
      'membership_payments_active', v_mp_count
    )
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_archive_library_cotisations(uuid, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_archive_library_cotisations(uuid, uuid) TO postgres;

-- ============================================================================
-- DO block de verification fail-fast
-- ============================================================================
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- Les 3 helpers doivent exister
  SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_archive_library_circulation',
                       'fn_unarchive_library_circulation',
                       'fn_archive_library_cotisations');
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'VERIF_FAIL_A : %/3 helpers d''archivage crees', v_count;
  END IF;

  -- Verifier SECURITY DEFINER sur les 3
  SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_archive_library_circulation',
                       'fn_unarchive_library_circulation',
                       'fn_archive_library_cotisations')
     AND p.prosecdef = true;
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'VERIF_FAIL_B : %/3 helpers SECURITY DEFINER', v_count;
  END IF;

  -- Verifier que anon/authenticated/service_role/PUBLIC n'ont PAS EXECUTE
  SELECT count(*) INTO v_count
    FROM information_schema.routine_privileges
   WHERE routine_schema = 'public'
     AND routine_name IN ('fn_archive_library_circulation',
                          'fn_unarchive_library_circulation',
                          'fn_archive_library_cotisations')
     AND grantee IN ('anon', 'authenticated', 'service_role', 'PUBLIC');
  IF v_count > 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_C : % grants residuels EXECUTE pour anon/authenticated/service_role/PUBLIC', v_count;
  END IF;

  RAISE NOTICE 'Paquet D.2 - Verification OK : 3 helpers SECURITY DEFINER doctrine v2';
END
$verif$;

COMMIT;
