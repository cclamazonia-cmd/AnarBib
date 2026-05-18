-- ============================================================================
-- Paquet D.5 - Desarchivage manuel : table audit + RPC + vue de listing
-- ============================================================================
-- Spec : docs/specs/spec-profils-bibliotheque.md v0.4 §9.4 (paquet D, couche desarchivage)
-- Dependance : paquet D.1 (colonnes archived_at).
--
-- Objectif : permettre aux administrador-as d'une biblio de restaurer
-- manuellement une transaction archivee, avec audit immuable et garde-fous.
--
-- Cas d'usage typique : un collectif qui revient a la circulation apres 6 mois
-- veut reactiver les prets en cours quand il a bascule en off, parce que
-- les exemplaires sont toujours physiquement chez les lecteur-rices.
--
-- 4 livrables :
--   1. Table public.library_unarchive_log (audit immuable)
--   2. Helper fn_table_unarchive_eligible (white-list + check 90j)
--   3. RPC public.fn_unarchive_transaction (RPC publique, SECURITY DEFINER)
--   4. Vue api.library_archived_transactions (listing pour UI staff)
--
-- Doctrine v2 : SECURITY DEFINER + REVOKE PUBLIC + GRANT authenticated (pour
-- la RPC publique ; helpers restent en GRANT postgres uniquement).
--
-- Tables blanches accept-ees pour desarchivage :
--   - emprestimos_v2          (verif 90j sur due_at)
--   - reservas_v2             (pas de verif 90j, header sans echeance)
--   - consultas_locais_v2     (pas de verif 90j, header sans echeance)
--   - interlibrary_loans_v2   (verif 90j sur due_date)
--   - membership_payments     (pas de verif 90j, comptabilite)
--
-- Doctrine 90j : politique conservatrice par defaut. Si la transaction avait
-- son echeance prevue il y a plus de 90 jours, on refuse le desarchivage
-- (la situation est trop ancienne pour reactiver proprement). Pour l'instant
-- HARDCODE, ajustable plus tard par colonne libraries.unarchive_grace_days
-- si besoin (cf. backlog).
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Table library_unarchive_log
-- ============================================================================
CREATE TABLE public.library_unarchive_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  library_id      uuid NOT NULL REFERENCES public.libraries(id),
  table_name      text NOT NULL,
  record_id       uuid NOT NULL,
  unarchived_by   uuid NOT NULL REFERENCES auth.users(id),
  unarchived_at   timestamptz NOT NULL DEFAULT now(),
  motivation      text NOT NULL,
  -- Snapshot des metadonnees archived_at + archive_reason d'origine (audit fort)
  prev_archived_at    timestamptz NOT NULL,
  prev_archive_reason text NOT NULL,
  CONSTRAINT library_unarchive_log_table_name_chk
    CHECK (table_name IN ('emprestimos_v2','reservas_v2','consultas_locais_v2','interlibrary_loans_v2','membership_payments')),
  CONSTRAINT library_unarchive_log_motivation_chk
    CHECK (length(trim(motivation)) >= 5)
);

CREATE INDEX library_unarchive_log_library_idx
  ON public.library_unarchive_log (library_id, unarchived_at DESC);

CREATE INDEX library_unarchive_log_record_idx
  ON public.library_unarchive_log (table_name, record_id);

-- Audit immuable : RLS + REVOKE writes
ALTER TABLE public.library_unarchive_log ENABLE ROW LEVEL SECURITY;

-- Lecture pour staff de la biblio + network admins
CREATE POLICY library_unarchive_log_select_staff
  ON public.library_unarchive_log
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.user_library_memberships m
       WHERE m.library_id = library_unarchive_log.library_id
         AND m.user_id    = auth.uid()
         AND m.status     = 'active'
         AND m.role IN ('librarian', 'coordenador')
    )
  );

-- Pas d'INSERT/UPDATE/DELETE directs : passage obligatoire par fn_unarchive_transaction
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.library_unarchive_log FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON public.library_unarchive_log TO authenticated;

-- ============================================================================
-- 2. Helper interne : verifier si une table est elligible au desarchivage
-- ============================================================================
-- Retourne un jsonb avec ok/reason/library_id/age_days
CREATE OR REPLACE FUNCTION public.fn_check_unarchive_eligibility(
  p_table_name text,
  p_record_id uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_grace_days int := 90;  -- HARDCODE doctrinal, ajustable plus tard
  v_library_id uuid;
  v_archived_at timestamptz;
  v_archive_reason text;
  v_due_at date;
  v_age_days int;
BEGIN
  -- Validation white-list de tables
  IF p_table_name NOT IN ('emprestimos_v2','reservas_v2','consultas_locais_v2','interlibrary_loans_v2','membership_payments') THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_table_name');
  END IF;

  -- Recuperer library_id + archived_at + due_at selon la table
  IF p_table_name = 'emprestimos_v2' THEN
    SELECT library_id, archived_at, archive_reason, due_at
      INTO v_library_id, v_archived_at, v_archive_reason, v_due_at
      FROM public.emprestimos_v2 WHERE id = p_record_id;
  ELSIF p_table_name = 'reservas_v2' THEN
    SELECT library_id, archived_at, archive_reason, NULL::date
      INTO v_library_id, v_archived_at, v_archive_reason, v_due_at
      FROM public.reservas_v2 WHERE id = p_record_id;
  ELSIF p_table_name = 'consultas_locais_v2' THEN
    SELECT library_id, archived_at, archive_reason, NULL::date
      INTO v_library_id, v_archived_at, v_archive_reason, v_due_at
      FROM public.consultas_locais_v2 WHERE id = p_record_id;
  ELSIF p_table_name = 'interlibrary_loans_v2' THEN
    -- Pour ILL, library_id n'existe pas : on prend lender_library_id par convention
    -- (la biblio qui doit etre en circulation pour reactiver est typiquement la lender)
    SELECT lender_library_id, archived_at, archive_reason, due_date
      INTO v_library_id, v_archived_at, v_archive_reason, v_due_at
      FROM public.interlibrary_loans_v2 WHERE id = p_record_id;
  ELSIF p_table_name = 'membership_payments' THEN
    SELECT library_id, archived_at, archive_reason, NULL::date
      INTO v_library_id, v_archived_at, v_archive_reason, v_due_at
      FROM public.membership_payments WHERE id = p_record_id;
  END IF;

  -- Record introuvable
  IF v_library_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'record_not_found');
  END IF;

  -- Record non archive
  IF v_archived_at IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'not_archived', 'library_id', v_library_id);
  END IF;

  -- Garde-fou 1 : la biblio doit etre revenue en circulation_mode <> 'off'
  IF NOT EXISTS (
    SELECT 1 FROM public.libraries
     WHERE id = v_library_id AND circulation_mode <> 'off'
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'reason', 'library_still_off',
      'library_id', v_library_id
    );
  END IF;

  -- Garde-fou 2 : verif 90j sur l'echeance theorique (uniquement si due_at present)
  IF v_due_at IS NOT NULL THEN
    v_age_days := (current_date - v_due_at)::int;
    IF v_age_days > v_grace_days THEN
      RETURN jsonb_build_object(
        'ok', false,
        'reason', 'too_old',
        'library_id', v_library_id,
        'age_days', v_age_days,
        'grace_days', v_grace_days
      );
    END IF;
  END IF;

  -- Tout bon : retour des metadonnees pour audit log
  RETURN jsonb_build_object(
    'ok', true,
    'library_id', v_library_id,
    'archived_at', v_archived_at,
    'archive_reason', v_archive_reason,
    'age_days', COALESCE(v_age_days, 0)
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_check_unarchive_eligibility(text, uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_check_unarchive_eligibility(text, uuid) TO postgres;

-- ============================================================================
-- 3. RPC publique : fn_unarchive_transaction
-- ============================================================================
CREATE OR REPLACE FUNCTION public.fn_unarchive_transaction(
  p_table_name text,
  p_record_id uuid,
  p_motivation text
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $function$
DECLARE
  v_caller_id uuid := auth.uid();
  v_eligibility jsonb;
  v_library_id uuid;
  v_archived_at timestamptz;
  v_archive_reason text;
BEGIN
  -- Garde-fou 1 : authentification
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'UNARCHIVE_AUTH_REQUIRED : authentification requise'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.unarchive.auth_required';
  END IF;

  -- Garde-fou 2 : motivation substantielle
  IF p_motivation IS NULL OR length(trim(p_motivation)) < 5 THEN
    RAISE EXCEPTION 'UNARCHIVE_MOTIVATION_TOO_SHORT : la motivation doit faire au moins 5 caracteres'
      USING ERRCODE = 'check_violation',
            HINT    = 'error.unarchive.motivation_too_short';
  END IF;

  -- Verifier l'eligibilite (table + record + 90j + circulation_mode)
  v_eligibility := public.fn_check_unarchive_eligibility(p_table_name, p_record_id);

  IF (v_eligibility->>'ok')::boolean IS NOT TRUE THEN
    -- Mapper la raison vers une erreur i18n
    CASE v_eligibility->>'reason'
      WHEN 'invalid_table_name' THEN
        RAISE EXCEPTION 'UNARCHIVE_INVALID_TABLE : table % non eligible', p_table_name
          USING ERRCODE = 'check_violation',
                HINT    = 'error.unarchive.invalid_table';
      WHEN 'record_not_found' THEN
        RAISE EXCEPTION 'UNARCHIVE_RECORD_NOT_FOUND : enregistrement % introuvable', p_record_id
          USING ERRCODE = 'no_data_found',
                HINT    = 'error.unarchive.record_not_found';
      WHEN 'not_archived' THEN
        RAISE EXCEPTION 'UNARCHIVE_NOT_ARCHIVED : enregistrement deja actif (non archive)'
          USING ERRCODE = 'check_violation',
                HINT    = 'error.unarchive.not_archived';
      WHEN 'library_still_off' THEN
        RAISE EXCEPTION 'UNARCHIVE_LIBRARY_STILL_OFF : la biblio doit etre revenue en circulation pour reactiver'
          USING ERRCODE = 'check_violation',
                HINT    = 'error.unarchive.library_still_off';
      WHEN 'too_old' THEN
        RAISE EXCEPTION 'UNARCHIVE_TOO_OLD : echeance theorique depassee de % jours (max % jours)',
          v_eligibility->>'age_days', v_eligibility->>'grace_days'
          USING ERRCODE = 'check_violation',
                HINT    = 'error.unarchive.too_old';
      ELSE
        RAISE EXCEPTION 'UNARCHIVE_INELIGIBLE : %', v_eligibility->>'reason'
          USING ERRCODE = 'check_violation',
                HINT    = 'error.unarchive.ineligible';
    END CASE;
  END IF;

  v_library_id     := (v_eligibility->>'library_id')::uuid;
  v_archived_at    := (v_eligibility->>'archived_at')::timestamptz;
  v_archive_reason := v_eligibility->>'archive_reason';

  -- Garde-fou 3 : caller doit etre staff actif de la biblio
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships
     WHERE library_id = v_library_id
       AND user_id    = v_caller_id
       AND status     = 'active'
       AND role IN ('librarian', 'coordenador')
  ) THEN
    RAISE EXCEPTION 'UNARCHIVE_NOT_STAFF : caller n''est pas staff actif de la biblio'
      USING ERRCODE = 'insufficient_privilege',
            HINT    = 'error.unarchive.not_staff';
  END IF;

  -- Doctrine #141.2.E : INSERT audit log AVANT UPDATE de l'etat
  -- (le log est la source de verite narrative)
  INSERT INTO public.library_unarchive_log (
    library_id, table_name, record_id, unarchived_by, motivation,
    prev_archived_at, prev_archive_reason
  )
  VALUES (
    v_library_id, p_table_name, p_record_id, v_caller_id, trim(p_motivation),
    v_archived_at, v_archive_reason
  );

  -- Maintenant UPDATE le record (etat) selon la table
  IF p_table_name = 'emprestimos_v2' THEN
    UPDATE public.emprestimos_v2 SET archived_at = NULL, archive_reason = NULL WHERE id = p_record_id;
  ELSIF p_table_name = 'reservas_v2' THEN
    UPDATE public.reservas_v2 SET archived_at = NULL, archive_reason = NULL WHERE id = p_record_id;
  ELSIF p_table_name = 'consultas_locais_v2' THEN
    UPDATE public.consultas_locais_v2 SET archived_at = NULL, archive_reason = NULL WHERE id = p_record_id;
  ELSIF p_table_name = 'interlibrary_loans_v2' THEN
    UPDATE public.interlibrary_loans_v2 SET archived_at = NULL, archive_reason = NULL WHERE id = p_record_id;
  ELSIF p_table_name = 'membership_payments' THEN
    UPDATE public.membership_payments SET archived_at = NULL, archive_reason = NULL WHERE id = p_record_id;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'library_id', v_library_id,
    'table_name', p_table_name,
    'record_id', p_record_id,
    'unarchived_at', now(),
    'prev_archive_reason', v_archive_reason
  );
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_unarchive_transaction(text, uuid, text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fn_unarchive_transaction(text, uuid, text) TO authenticated;

-- ============================================================================
-- 4. Vue api.library_archived_transactions
-- ============================================================================
-- Liste toutes les transactions archivees d'une biblio, accessible aux staff.
-- Union de 5 SELECT (un par table transactionnelle).
CREATE OR REPLACE VIEW api.library_archived_transactions WITH (security_invoker=true) AS
 SELECT 'emprestimos_v2'::text AS table_name,
        e.id AS record_id,
        e.library_id,
        e.archived_at,
        e.archive_reason,
        e.due_at::text AS due_reference,
        e.status_global AS original_status,
        e.created_at AS originally_created_at,
        e.user_id AS related_user_id
   FROM public.emprestimos_v2 e
  WHERE e.archived_at IS NOT NULL

  UNION ALL

 SELECT 'reservas_v2'::text,
        r.id,
        r.library_id,
        r.archived_at,
        r.archive_reason,
        NULL::text AS due_reference,
        r.status_global,
        r.created_at,
        r.user_id
   FROM public.reservas_v2 r
  WHERE r.archived_at IS NOT NULL

  UNION ALL

 SELECT 'consultas_locais_v2'::text,
        c.id,
        c.library_id,
        c.archived_at,
        c.archive_reason,
        NULL::text,
        c.status_global,
        c.created_at,
        c.user_id
   FROM public.consultas_locais_v2 c
  WHERE c.archived_at IS NOT NULL

  UNION ALL

 SELECT 'interlibrary_loans_v2'::text,
        h.id,
        h.lender_library_id AS library_id,  -- convention : on attache au lender
        h.archived_at,
        h.archive_reason,
        h.due_date::text,
        h.status_global,
        h.created_at,
        NULL::uuid AS related_user_id
   FROM public.interlibrary_loans_v2 h
  WHERE h.archived_at IS NOT NULL

  UNION ALL

 SELECT 'membership_payments'::text,
        mp.id,
        mp.library_id,
        mp.archived_at,
        mp.archive_reason,
        mp.valid_until::text,
        'cotisation_archived'::text AS original_status,
        mp.created_at,
        mp.user_id
   FROM public.membership_payments mp
  WHERE mp.archived_at IS NOT NULL;

GRANT SELECT ON api.library_archived_transactions TO authenticated;

-- ============================================================================
-- DO block de verification fail-fast
-- ============================================================================
DO $verif$
DECLARE
  v_count int;
BEGIN
  -- 1 table + 2 fonctions + 1 vue
  SELECT count(*) INTO v_count FROM information_schema.tables
   WHERE table_schema = 'public' AND table_name = 'library_unarchive_log';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_A : table library_unarchive_log non creee';
  END IF;

  SELECT count(*) INTO v_count FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_check_unarchive_eligibility', 'fn_unarchive_transaction');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'VERIF_FAIL_B : %/2 fonctions creees', v_count;
  END IF;

  SELECT count(*) INTO v_count FROM information_schema.views
   WHERE table_schema = 'api' AND table_name = 'library_archived_transactions';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_C : vue api.library_archived_transactions non creee';
  END IF;

  -- Grants RPC publique
  SELECT count(*) INTO v_count FROM information_schema.routine_privileges
   WHERE routine_schema = 'public'
     AND routine_name = 'fn_unarchive_transaction'
     AND grantee = 'authenticated'
     AND privilege_type = 'EXECUTE';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_D : fn_unarchive_transaction sans grant EXECUTE authenticated';
  END IF;

  -- Helper interne doit etre fermee a authenticated
  SELECT count(*) INTO v_count FROM information_schema.routine_privileges
   WHERE routine_schema = 'public'
     AND routine_name = 'fn_check_unarchive_eligibility'
     AND grantee IN ('anon','authenticated','service_role');
  IF v_count > 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_E : helper fn_check_unarchive_eligibility a des grants residuels';
  END IF;

  RAISE NOTICE 'Paquet D.5 - Verification OK : table + 2 fonctions + 1 vue, grants conformes';
END
$verif$;

COMMIT;
