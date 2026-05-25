-- =============================================================================
-- Migration : peb_archive_fix
-- Chantier  : #ILL-archive — correctif des RPC d'archivage
-- Date       : 2026-05-25
-- -----------------------------------------------------------------------------
-- Corrige fn_peb_archive_loan, livrée par 20260525090000_peb_archive.sql, qui
-- violait deux CHECK préexistants de interlibrary_loans_v2 :
--
--   archive_consistency_chk : (archived_at IS NULL) = (archive_reason IS NULL)
--       -> archived_at et archive_reason doivent être posés/nuls ENSEMBLE.
--       La RPC initiale posait archived_at seul (reason NULL) -> violation.
--
--   archive_reason_chk : archive_reason IN
--       ('profile_transition', 'admin_manual', 'system_cleanup')
--       -> archive_reason n'est pas du texte libre mais un code de cause.
--
-- Correctif : l'archivage manuel par le staff correspond à la cause
-- 'admin_manual'. La RPC pose désormais archived_at ET archive_reason =
-- 'admin_manual' ensemble. Le paramètre p_reason (texte libre) est supprimé :
-- la cause est déterminée par le canal (ce bouton = archivage manuel), pas
-- saisie. La signature change -> DROP puis CREATE.
--
-- fn_peb_unarchive_loan remettait déjà les deux colonnes à NULL ensemble :
-- conforme à archive_consistency_chk. Reprise ici pour cohérence du fichier,
-- inchangée sur le fond.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Remplacement de fn_peb_archive_loan (changement de signature -> DROP)
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.fn_peb_archive_loan(bigint, text);

CREATE OR REPLACE FUNCTION public.fn_peb_archive_loan(
    p_loan_id bigint
)
RETURNS public.interlibrary_loans_v2
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_loan public.interlibrary_loans_v2;
BEGIN
    SELECT * INTO v_loan
    FROM public.interlibrary_loans_v2
    WHERE id = p_loan_id;

    IF v_loan.id IS NULL THEN
        RAISE EXCEPTION 'not_found: PEB % does not exist', p_loan_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Droit : staff de la prêteuse OU de l'emprunteuse
    IF NOT (
        public.user_can_act_as_staff_on_library(v_loan.lender_library_id)
        OR public.user_can_act_as_staff_on_library(v_loan.borrower_library_id)
    ) THEN
        RAISE EXCEPTION 'forbidden: caller is not staff of either library of PEB %', p_loan_id
            USING ERRCODE = '42501';
    END IF;

    -- Seul un PEB en statut terminal est archivable
    IF v_loan.status_global NOT IN ('devolvido', 'cancelado') THEN
        RAISE EXCEPTION 'invalid_state: PEB % is not terminal (status=%)',
            p_loan_id, v_loan.status_global
            USING ERRCODE = '22023';
    END IF;

    IF v_loan.archived_at IS NOT NULL THEN
        RAISE EXCEPTION 'already_archived: PEB % is already archived', p_loan_id
            USING ERRCODE = '22023';
    END IF;

    -- archived_at ET archive_reason posés ENSEMBLE (archive_consistency_chk).
    -- 'admin_manual' = archivage manuel par le staff (archive_reason_chk).
    UPDATE public.interlibrary_loans_v2
    SET archived_at    = timezone('utc', now()),
        archive_reason = 'admin_manual',
        updated_at     = timezone('utc', now()),
        updated_by     = auth.uid()
    WHERE id = p_loan_id
    RETURNING * INTO v_loan;

    RETURN v_loan;
END;
$$;

COMMENT ON FUNCTION public.fn_peb_archive_loan(bigint) IS
    'Archive un PEB terminé (devolvido/cancelado) : pose archived_at + '
    'archive_reason = ''admin_manual'' (archivage manuel). Réservé au staff de '
    'l''une ou l''autre des deux bibliothèques. Doctrine RPC v3.';

-- -----------------------------------------------------------------------------
-- 2. fn_peb_unarchive_loan — reprise inchangée (conforme aux CHECK)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_peb_unarchive_loan(
    p_loan_id bigint
)
RETURNS public.interlibrary_loans_v2
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
DECLARE
    v_loan public.interlibrary_loans_v2;
BEGIN
    SELECT * INTO v_loan
    FROM public.interlibrary_loans_v2
    WHERE id = p_loan_id;

    IF v_loan.id IS NULL THEN
        RAISE EXCEPTION 'not_found: PEB % does not exist', p_loan_id
            USING ERRCODE = 'P0002';
    END IF;

    IF NOT (
        public.user_can_act_as_staff_on_library(v_loan.lender_library_id)
        OR public.user_can_act_as_staff_on_library(v_loan.borrower_library_id)
    ) THEN
        RAISE EXCEPTION 'forbidden: caller is not staff of either library of PEB %', p_loan_id
            USING ERRCODE = '42501';
    END IF;

    IF v_loan.archived_at IS NULL THEN
        RAISE EXCEPTION 'not_archived: PEB % is not archived', p_loan_id
            USING ERRCODE = '22023';
    END IF;

    -- archived_at ET archive_reason remis à NULL ENSEMBLE (archive_consistency_chk)
    UPDATE public.interlibrary_loans_v2
    SET archived_at    = NULL,
        archive_reason = NULL,
        updated_at     = timezone('utc', now()),
        updated_by     = auth.uid()
    WHERE id = p_loan_id
    RETURNING * INTO v_loan;

    RETURN v_loan;
END;
$$;

COMMENT ON FUNCTION public.fn_peb_unarchive_loan(bigint) IS
    'Désarchive un PEB : remet archived_at et archive_reason à NULL ensemble, '
    'le PEB réintègre la file active. Réservé au staff de l''une ou l''autre '
    'bibliothèque.';

-- Grants : revoke étendu puis grant ciblé. La signature de fn_peb_archive_loan
-- ayant changé, on (re)pose les grants sur la nouvelle.
REVOKE ALL ON FUNCTION public.fn_peb_archive_loan(bigint)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_peb_unarchive_loan(bigint)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.fn_peb_archive_loan(bigint)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_peb_unarchive_loan(bigint) TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. BLOC DE VÉRIFICATION  — teste un VRAI cycle archive/désarchive
-- -----------------------------------------------------------------------------
-- Cette fois la vérification ne se contente pas de constater l'existence des
-- objets : elle exécute un archivage réel sur un PEB terminal de test, dans un
-- sous-bloc, pour confirmer qu'aucun CHECK n'est violé. Tout est annulé en fin
-- de migration (le DO ne COMMIT pas ses INSERT de test ; et même la migration
-- entière peut rollback). L'INSERT de test est nettoyé explicitement.
DO $verify$
DECLARE
    v_count    int;
    v_lib_a    uuid;
    v_lib_b    uuid;
    v_test_id  bigint;
    v_archived public.interlibrary_loans_v2;
BEGIN
    -- 3.1 L'ancienne signature (bigint, text) ne doit plus exister
    SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_peb_archive_loan'
      AND pg_get_function_identity_arguments(p.oid) = 'p_loan_id bigint, p_reason text';
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'VERIFY FAILED: ancienne signature fn_peb_archive_loan(bigint,text) encore présente';
    END IF;

    -- 3.2 La nouvelle signature (bigint) existe, SECURITY INVOKER
    SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_peb_archive_loan'
      AND pg_get_function_identity_arguments(p.oid) = 'p_loan_id bigint'
      AND p.prosecdef = false;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'VERIFY FAILED: fn_peb_archive_loan(bigint) absente ou non INVOKER';
    END IF;

    -- 3.3 Test fonctionnel : archiver un PEB terminal de test ne doit violer
    --     aucun CHECK. On prend deux bibliothèques distinctes existantes.
    SELECT id INTO v_lib_a FROM public.libraries ORDER BY id LIMIT 1;
    SELECT id INTO v_lib_b FROM public.libraries WHERE id <> v_lib_a ORDER BY id LIMIT 1;

    IF v_lib_a IS NOT NULL AND v_lib_b IS NOT NULL THEN
        -- PEB de test en statut terminal 'devolvido'
        INSERT INTO public.interlibrary_loans_v2
            (lender_library_id, borrower_library_id, initiated_by_library_id, status_global)
        VALUES (v_lib_a, v_lib_b, v_lib_a, 'devolvido')
        RETURNING id INTO v_test_id;

        -- archivage direct (UPDATE identique à celui de la RPC) : doit passer
        -- les deux CHECK archive_consistency_chk et archive_reason_chk.
        UPDATE public.interlibrary_loans_v2
        SET archived_at = timezone('utc', now()), archive_reason = 'admin_manual'
        WHERE id = v_test_id
        RETURNING * INTO v_archived;

        IF v_archived.archived_at IS NULL OR v_archived.archive_reason <> 'admin_manual' THEN
            RAISE EXCEPTION 'VERIFY FAILED: archivage de test incohérent';
        END IF;

        -- désarchivage : remet les deux à NULL, doit aussi passer les CHECK
        UPDATE public.interlibrary_loans_v2
        SET archived_at = NULL, archive_reason = NULL
        WHERE id = v_test_id;

        -- nettoyage du PEB de test
        DELETE FROM public.interlibrary_loans_v2 WHERE id = v_test_id;

        RAISE NOTICE 'VERIFY OK: cycle archive/désarchive testé sans violation de CHECK.';
    ELSE
        RAISE NOTICE 'VERIFY OK (partiel): < 2 bibliothèques en base, test fonctionnel sauté.';
    END IF;

    RAISE NOTICE 'VERIFY OK: fn_peb_archive_loan corrigée (signature bigint, archive_reason admin_manual).';
END;
$verify$;

COMMIT;
