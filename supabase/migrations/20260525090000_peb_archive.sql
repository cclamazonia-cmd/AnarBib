-- =============================================================================
-- Migration : peb_archive
-- Chantier  : #ILL-archive — archivage des prêts entre bibliothèques terminés
-- Spec       : docs/decisions/CHANTIER_cloture_ILL_2026-05-24.md (section 4)
-- Date       : 2026-05-25
-- -----------------------------------------------------------------------------
-- Permet au staff d'archiver un PEB terminé : il sort de la file active de la
-- page Biblioteca et devient consultable dans l'onglet Relatórios.
--
-- Décisions de conception :
--   - Déclenchement MANUEL (RPC appelée depuis un bouton), pas de trigger ni
--     de cron. Un garde-fou visuel côté frontend signale les PEB terminés
--     depuis longtemps ; aucun automatisme ne touche les données.
--   - Droit : staff (librarian + coordenador + admin réseau) de l'une OU
--     l'autre des deux bibliothèques du PEB — user_can_act_as_staff_on_library.
--   - Archivage = état unique partagé : la table n'a qu'une colonne
--     archived_at ; archiver vaut pour les deux bibliothèques.
--   - Réversible : fn_peb_unarchive_loan remet le PEB dans la file active.
--
-- Socle existant réutilisé : les colonnes archived_at (timestamptz) et
-- archive_reason (text) existent déjà sur interlibrary_loans_v2. Le cron
-- fn_cron_peb_detect_overdue filtre déjà sur archived_at IS NULL : un PEB
-- archivé est naturellement ignoré par la détection de retard.
--
-- Statuts terminaux (déduits de interlibrary_loan_status_transitions : statut
-- sans transition sortante) : 'devolvido' et 'cancelado'. On n'archive qu'un
-- PEB dans l'un de ces deux statuts.
--
-- Doctrine RPC v3 : écritures par RPC SECURITY INVOKER ; lecture par from()
-- sur la vue api.peb_history_v1 protégée par RLS.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. RPC — archivage
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_peb_archive_loan(
    p_loan_id bigint,
    p_reason  text DEFAULT NULL
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

    -- Déjà archivé : signaler clairement plutôt que réécrire silencieusement
    IF v_loan.archived_at IS NOT NULL THEN
        RAISE EXCEPTION 'already_archived: PEB % is already archived', p_loan_id
            USING ERRCODE = '22023';
    END IF;

    UPDATE public.interlibrary_loans_v2
    SET archived_at    = timezone('utc', now()),
        archive_reason = NULLIF(btrim(p_reason), ''),
        updated_at     = timezone('utc', now()),
        updated_by     = auth.uid()
    WHERE id = p_loan_id
    RETURNING * INTO v_loan;

    RETURN v_loan;
END;
$$;

COMMENT ON FUNCTION public.fn_peb_archive_loan(bigint, text) IS
    'Archive un PEB terminé (devolvido/cancelado) : pose archived_at + archive_reason. '
    'Réservé au staff de l''une ou l''autre des deux bibliothèques. Manuel, doctrine RPC v3.';

-- -----------------------------------------------------------------------------
-- 2. RPC — désarchivage (réversibilité)
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
    'Désarchive un PEB : remet archived_at et archive_reason à NULL, le PEB '
    'réintègre la file active. Réservé au staff de l''une ou l''autre bibliothèque.';

-- Grants : revoke étendu puis grant ciblé sur authenticated (doctrine #150).
REVOKE ALL ON FUNCTION public.fn_peb_archive_loan(bigint, text)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public.fn_peb_unarchive_loan(bigint)
    FROM PUBLIC, anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.fn_peb_archive_loan(bigint, text)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_peb_unarchive_loan(bigint)        TO authenticated;

-- -----------------------------------------------------------------------------
-- 3. VUE DE LECTURE  api.peb_history_v1
-- -----------------------------------------------------------------------------
-- Décalquée sur api.painel_loans_history_v1 : agrégation des items, noms des
-- bibliothèques, date de clôture. security_invoker : la RLS de
-- interlibrary_loans_v2 s'applique au caller (lecture simple, doctrine v3).
-- La vue ne liste QUE les PEB archivés (archived_at IS NOT NULL) ; la file
-- active du frontend lira interlibrary_loans_v2 avec le filtre inverse.
--
-- closed_at = COALESCE(returned_at, updated_at) : returned_at pour les PEB
-- devolvido ; updated_at en repli pour les cancelado (pas de colonne dédiée
-- d'annulation — repli approximatif assumé, cf. spec).
CREATE OR REPLACE VIEW api.peb_history_v1
WITH (security_invoker = true)
AS
WITH items_agg AS (
    SELECT it.interlibrary_loan_id,
           count(*)::integer AS items_count,
           string_agg(it.bib_ref, ' ; ' ORDER BY it.id) AS bib_refs,
           count(*) FILTER (
               WHERE it.item_status IN ('devolvido','perdido','danificado','cancelado')
           )::integer AS items_settled
    FROM public.interlibrary_loan_items_v2 it
    GROUP BY it.interlibrary_loan_id
)
SELECT
    ll.id,
    ll.request_id,
    ll.lender_library_id,
    lend.slug   AS lender_slug,
    lend.name   AS lender_name,
    ll.borrower_library_id,
    borr.slug   AS borrower_slug,
    borr.name   AS borrower_name,
    ll.initiated_by_library_id,
    ll.status_global,
    COALESCE(ia.items_count, 0)   AS items_count,
    COALESCE(ia.items_settled, 0) AS items_settled,
    ia.bib_refs,
    ll.start_date,
    ll.due_date,
    ll.dispatched_at,
    ll.returned_at,
    ll.notes,
    ll.created_at,
    ll.updated_at,
    COALESCE(ll.returned_at, ll.updated_at) AS closed_at,
    ll.archived_at,
    ll.archive_reason
FROM public.interlibrary_loans_v2 ll
JOIN public.libraries lend ON lend.id = ll.lender_library_id
JOIN public.libraries borr ON borr.id = ll.borrower_library_id
LEFT JOIN items_agg ia ON ia.interlibrary_loan_id = ll.id
WHERE ll.archived_at IS NOT NULL
ORDER BY ll.archived_at DESC, ll.id DESC;

COMMENT ON VIEW api.peb_history_v1 IS
    'Historique des PEB archivés, par bibliothèque. security_invoker : la RLS de '
    'interlibrary_loans_v2 s''applique. Ne liste que archived_at IS NOT NULL ; '
    'la file active lit la table directement avec le filtre inverse.';

GRANT SELECT ON api.peb_history_v1 TO authenticated, anon;

-- -----------------------------------------------------------------------------
-- 4. BLOC DE VÉRIFICATION  (RAISE EXCEPTION -> ROLLBACK si invariant cassé)
-- -----------------------------------------------------------------------------
DO $verify$
DECLARE
    v_count int;
BEGIN
    -- 4.1 Les 2 RPC existent et sont SECURITY INVOKER (prosecdef = false)
    SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('fn_peb_archive_loan', 'fn_peb_unarchive_loan')
      AND p.prosecdef = false;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'VERIFY FAILED: % RPC SECURITY INVOKER, 2 attendues', v_count;
    END IF;

    -- 4.2 Aucune RPC exécutable par anon (doctrine #150)
    SELECT count(*) INTO v_count
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('fn_peb_archive_loan', 'fn_peb_unarchive_loan')
      AND has_function_privilege('anon', p.oid, 'EXECUTE');
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'VERIFY FAILED: % RPC exécutables par anon, 0 attendu', v_count;
    END IF;

    -- 4.3 La vue api.peb_history_v1 existe
    SELECT count(*) INTO v_count
    FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'api' AND c.relname = 'peb_history_v1' AND c.relkind = 'v';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'VERIFY FAILED: vue api.peb_history_v1 absente';
    END IF;

    -- 4.4 La vue ne renvoie bien que des PEB archivés
    SELECT count(*) INTO v_count
    FROM api.peb_history_v1
    WHERE archived_at IS NULL;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'VERIFY FAILED: api.peb_history_v1 expose % PEB non archivés', v_count;
    END IF;

    RAISE NOTICE 'VERIFY OK: 2 RPC INVOKER, aucun droit anon, vue api.peb_history_v1.';
END;
$verify$;

COMMIT;
