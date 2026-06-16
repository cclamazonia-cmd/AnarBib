-- =========================================================================
-- Paquet ASSEMBLEIAS P2b — Rôle facilitateur·rice (animation hors admins)
-- =========================================================================
-- Date     : 2026-06-16
-- Chantier : face fédération / assemblée du réseau (spec-assembleias §6 ; cadrage §6quinquies)
-- Auteur   : Claude (assistant)
-- Session  : Fédération — Assemblée du réseau (AG)
-- Réf      : CADRAGE_assembleias_reseau_2026-06-16 §6quinquies ; REGISTRE §FED (à canoniser)
--
-- Périmètre (DOC-CLOSE-1) :
--   - 1 table : assembleia_facilitators (qui anime quelle AG ; désigné·e par l'AG).
--   - 1 helper : public.fn_caller_is_assembleia_facilitator(assembleia_id).
--   - 1 vue : api.assembleia_facilitators_v1 (security_invoker).
--   - 2 RPC : fn_assembleia_add_facilitator / fn_assembleia_remove_facilitator
--     (garde : network_admin OU facilitateur·rice déjà désigné·e de cette AG).
--   - MAJ de garde des 4 RPC d'ANIMATION (set_dates / set_status / order_item /
--     defer_item) : `network_admin` -> `network_admin OU facilitateur·rice désigné·e`.
--
-- Doctrine (cadrage §6quinquies) : la facilitation n'est pas une prérogative des
-- admins. Phasage : 1ʳᵉ AG = admins (bootstrap, aucun·e facilitateur·rice désigné·e
-- -> seul le réseau-admin passe la garde), puis facilitateur·rices désigné·es par
-- l'AG (accès propre). `fn_assembleia_create` reste network_admin (convocation neutre).
--
-- CHECKLIST DOC-OBJ-2 : SECURITY DEFINER + search_path figé ; REVOKE FROM PUBLIC + GRANT ;
-- table REVOKE anon/authenticated -> GRANT SELECT ; RLS ON + policy ; vue security_invoker ;
-- DO de vérification ; NOTIFY pgrst. Transactionnelle (rollback total si erreur).
-- =========================================================================

BEGIN;

-- =========================================================================
-- SECTION 1 — TABLE
-- =========================================================================
CREATE TABLE public.assembleia_facilitators (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assembleia_id uuid NOT NULL REFERENCES public.assembleias(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    designated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    designated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (assembleia_id, user_id)
);
COMMENT ON TABLE public.assembleia_facilitators IS
'Facilitateur·rices désigné·es d''une assemblée (cadrage §6quinquies). Accès propre à l''animation (dates/ODJ/ordre), pas une prérogative des admins. Désignation par l''AG ; révocable. 1ʳᵉ AG = aucune ligne (bootstrap admins).';
CREATE INDEX assembleia_facilitators_assembleia_idx ON public.assembleia_facilitators(assembleia_id);
CREATE INDEX assembleia_facilitators_user_idx ON public.assembleia_facilitators(user_id);

-- =========================================================================
-- SECTION 2 — GRANTS + RLS + HELPER
-- =========================================================================
REVOKE ALL ON public.assembleia_facilitators FROM anon, authenticated;
GRANT SELECT ON public.assembleia_facilitators TO authenticated;
GRANT ALL ON public.assembleia_facilitators TO service_role;

ALTER TABLE public.assembleia_facilitators ENABLE ROW LEVEL SECURITY;

CREATE POLICY assembleia_facilitators_select ON public.assembleia_facilitators
    FOR SELECT TO authenticated
    USING (public.fn_caller_attached_member() OR public.fn_caller_is_network_admin());

-- Helper : l'appelant·e est-il·elle facilitateur·rice désigné·e de cette AG ?
-- SECURITY DEFINER pour éviter la récursion RLS sur assembleia_facilitators.
CREATE OR REPLACE FUNCTION public.fn_caller_is_assembleia_facilitator(p_assembleia_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.assembleia_facilitators
        WHERE assembleia_id = p_assembleia_id AND user_id = auth.uid()
    );
$$;
COMMENT ON FUNCTION public.fn_caller_is_assembleia_facilitator(uuid) IS
'TRUE si l''appelant·e est facilitateur·rice désigné·e de l''assemblée. SECURITY DEFINER (anti-récursion RLS). Paquet ASSEMBLEIAS P2b.';
REVOKE EXECUTE ON FUNCTION public.fn_caller_is_assembleia_facilitator(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_caller_is_assembleia_facilitator(uuid) TO authenticated;

-- =========================================================================
-- SECTION 3 — VUE
-- =========================================================================
CREATE OR REPLACE VIEW api.assembleia_facilitators_v1
WITH (security_invoker = true) AS
    SELECT f.id, f.assembleia_id, f.user_id, f.designated_at
    FROM public.assembleia_facilitators f;
COMMENT ON VIEW api.assembleia_facilitators_v1 IS
'Facilitateur·rices d''une assemblée visible (RLS). security_invoker. Paquet ASSEMBLEIAS P2b.';
GRANT SELECT ON api.assembleia_facilitators_v1 TO authenticated;

-- =========================================================================
-- SECTION 4 — RPC
-- =========================================================================

-- 4.1 désigner une·e facilitateur·rice (network_admin OU facilitateur·rice de l'AG) --
CREATE OR REPLACE FUNCTION api.fn_assembleia_add_facilitator(p_assembleia_id uuid, p_user_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(p_assembleia_id)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can designate facilitators' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.assembleias WHERE id = p_assembleia_id) THEN
        RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO public.assembleia_facilitators (assembleia_id, user_id, designated_by)
        VALUES (p_assembleia_id, p_user_id, auth.uid())
        ON CONFLICT (assembleia_id, user_id) DO NOTHING
        RETURNING id INTO v_id;
    RETURN v_id; -- NULL si déjà désigné·e (idempotent)
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_add_facilitator(uuid, uuid) IS
'Désigne une·e facilitateur·rice pour une assemblée. Garde : network_admin (bootstrap) OU facilitateur·rice déjà désigné·e de cette AG. Paquet ASSEMBLEIAS P2b.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_add_facilitator(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_add_facilitator(uuid, uuid) TO authenticated;

-- 4.2 retirer une·e facilitateur·rice --
CREATE OR REPLACE FUNCTION api.fn_assembleia_remove_facilitator(p_assembleia_id uuid, p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(p_assembleia_id)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can remove facilitators' USING ERRCODE = '42501';
    END IF;
    DELETE FROM public.assembleia_facilitators WHERE assembleia_id = p_assembleia_id AND user_id = p_user_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_remove_facilitator(uuid, uuid) IS
'Retire une·e facilitateur·rice d''une assemblée. Garde : network_admin OU facilitateur·rice de cette AG (révocabilité). Paquet ASSEMBLEIAS P2b.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_remove_facilitator(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_remove_facilitator(uuid, uuid) TO authenticated;

-- 4.3 MAJ garde des RPC d'ANIMATION : network_admin OU facilitateur·rice désigné·e --
-- (fn_assembleia_create NON modifiée : créer = convocation neutre = network_admin.)

CREATE OR REPLACE FUNCTION api.fn_assembleia_set_dates(
    p_id uuid, p_convocation_at timestamptz, p_agenda_deadline_at timestamptz,
    p_agenda_published_at timestamptz, p_scheduled_at timestamptz
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(p_id)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can set dates' USING ERRCODE = '42501';
    END IF;
    UPDATE public.assembleias
        SET convocation_at = p_convocation_at, agenda_deadline_at = p_agenda_deadline_at,
            agenda_published_at = p_agenda_published_at, scheduled_at = p_scheduled_at
        WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002'; END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) IS
'Pose/maj les jalons. Garde : network_admin OU facilitateur·rice désigné·e (P2b). Paquet ASSEMBLEIAS.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION api.fn_assembleia_set_status(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(p_id)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can change status' USING ERRCODE = '42501';
    END IF;
    IF p_status NOT IN ('em_preparacao','convocada','em_curso','encerrada','arquivada') THEN
        RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
    END IF;
    UPDATE public.assembleias SET status = p_status WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002'; END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_set_status(uuid, text) IS
'Transition de cycle de vie. Garde : network_admin OU facilitateur·rice désigné·e (P2b). Paquet ASSEMBLEIAS.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_set_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_set_status(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION api.fn_assembleia_order_item(p_item_id uuid, p_display_order integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_ass uuid;
BEGIN
    SELECT assembleia_id INTO v_ass FROM public.assembleia_agenda_items WHERE id = p_item_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'item_not_found' USING ERRCODE = 'P0002'; END IF;
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(v_ass)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can order items' USING ERRCODE = '42501';
    END IF;
    UPDATE public.assembleia_agenda_items SET display_order = p_display_order WHERE id = p_item_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_order_item(uuid, integer) IS
'Ordonne un point d''ODJ (organise sans supprimer). Garde : network_admin OU facilitateur·rice désigné·e (P2b). Paquet ASSEMBLEIAS.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_order_item(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_order_item(uuid, integer) TO authenticated;

CREATE OR REPLACE FUNCTION api.fn_assembleia_defer_item(p_item_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_ass uuid;
BEGIN
    SELECT assembleia_id INTO v_ass FROM public.assembleia_agenda_items WHERE id = p_item_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'item_not_found' USING ERRCODE = 'P0002'; END IF;
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(v_ass)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can defer items' USING ERRCODE = '42501';
    END IF;
    UPDATE public.assembleia_agenda_items SET status = 'diferido' WHERE id = p_item_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_defer_item(uuid) IS
'Diffère un point (status=diferido, jamais DELETE). Garde : network_admin OU facilitateur·rice désigné·e (P2b). Paquet ASSEMBLEIAS.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_defer_item(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_defer_item(uuid) TO authenticated;

-- =========================================================================
-- SECTION 5 — VÉRIFICATION (rollback auto si incohérence)
-- =========================================================================
DO $verify$
DECLARE v_tbl int; v_rls int; v_helper int; v_view int; v_rpc int; v_anim int;
BEGIN
    SELECT count(*) INTO v_tbl FROM information_schema.tables
        WHERE table_schema='public' AND table_name='assembleia_facilitators';
    IF v_tbl <> 1 THEN RAISE EXCEPTION 'verify: table assembleia_facilitators absente (%)', v_tbl; END IF;

    SELECT count(*) INTO v_rls FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname='assembleia_facilitators' AND c.relrowsecurity;
    IF v_rls <> 1 THEN RAISE EXCEPTION 'verify: RLS non activée sur assembleia_facilitators'; END IF;

    SELECT count(*) INTO v_helper FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname='fn_caller_is_assembleia_facilitator';
    IF v_helper < 1 THEN RAISE EXCEPTION 'verify: helper fn_caller_is_assembleia_facilitator absent'; END IF;

    SELECT count(*) INTO v_view FROM information_schema.views
        WHERE table_schema='api' AND table_name='assembleia_facilitators_v1';
    IF v_view <> 1 THEN RAISE EXCEPTION 'verify: vue api.assembleia_facilitators_v1 absente'; END IF;

    SELECT count(*) INTO v_rpc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='api' AND p.proname IN ('fn_assembleia_add_facilitator','fn_assembleia_remove_facilitator');
    IF v_rpc <> 2 THEN RAISE EXCEPTION 'verify: 2 RPC facilitator attendues, trouvées %', v_rpc; END IF;

    SELECT count(*) INTO v_anim FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='api' AND p.proname IN
        ('fn_assembleia_set_dates','fn_assembleia_set_status','fn_assembleia_order_item','fn_assembleia_defer_item');
    IF v_anim <> 4 THEN RAISE EXCEPTION 'verify: 4 RPC animation attendues, trouvées %', v_anim; END IF;

    RAISE NOTICE 'paquet ASSEMBLEIAS P2b OK : table facilitators (RLS), helper, vue, 2 RPC désignation, 4 RPC animation re-gardées.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (si régression) — NB : restaurer aussi la garde network_admin-only
-- des 4 RPC d'animation à partir de la migration 20260616191226 si nécessaire.
-- =========================================================================
-- BEGIN;
--   DROP VIEW IF EXISTS api.assembleia_facilitators_v1;
--   DROP FUNCTION IF EXISTS api.fn_assembleia_add_facilitator(uuid,uuid), api.fn_assembleia_remove_facilitator(uuid,uuid);
--   DROP FUNCTION IF EXISTS public.fn_caller_is_assembleia_facilitator(uuid);
--   DROP TABLE IF EXISTS public.assembleia_facilitators;
--   -- + ré-appliquer les corps network_admin-only des 4 RPC d'animation (cf. 20260616191226).
-- COMMIT;
-- =========================================================================
