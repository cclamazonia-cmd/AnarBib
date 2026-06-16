-- =========================================================================
-- Paquet ASSEMBLEIAS P2c — Facilitation sur VOLONTARIAT (status volunteer/designated)
-- =========================================================================
-- Date     : 2026-06-16
-- Chantier : face fédération / assemblée du réseau (cadrage §6quinquies)
-- Auteur   : Claude (assistant)
-- Session  : Fédération — Assemblée du réseau (AG)
-- Réf      : CADRAGE_assembleias_reseau_2026-06-16 §6quinquies (désignation sur volontariat,
--            anti-panoptique FED-7 ; rotativité contre l'épuisement militant) ; REGISTRE §FED.
--
-- Doctrine : on ne « pioche » personne dans un annuaire réseau (refus FED-7 + vie
-- privée). Une personne SE PROPOSE pour faciliter une AG (status='volunteer') ;
-- l'AG / l'admin la DÉSIGNE (passage 'volunteer' -> 'designated'). Seuls les
-- 'designated' ont les droits d'animation.
--
-- Périmètre (sur la base de P2b, migration 20260616214241) :
--   - ALTER assembleia_facilitators : + colonne status ('volunteer'|'designated').
--   - Helper public.fn_caller_is_assembleia_facilitator : droits d'animation = 'designated' SEULEMENT.
--   - Helper public.fn_assembleia_facilitator_name(uuid) : nom d'affichage, SECURITY DEFINER
--     SCOPÉ aux seules personnes inscrites dans assembleia_facilitators (anti-fuite d'annuaire).
--   - Vue api.assembleia_facilitators_v1 : + status + display_name.
--   - RPC fn_assembleia_volunteer / fn_assembleia_unvolunteer (soi-même, membre rattaché).
--   - RPC fn_assembleia_add_facilitator : désigne = upsert -> status='designated'.
--
-- CHECKLIST DOC-OBJ-2 : SECURITY DEFINER + search_path figé ; REVOKE FROM PUBLIC + GRANT ;
-- vue security_invoker ; DO de vérification ; NOTIFY pgrst. Transactionnelle.
-- =========================================================================

BEGIN;

-- =========================================================================
-- SECTION 1 — STATUS (volunteer / designated)
-- =========================================================================
ALTER TABLE public.assembleia_facilitators
    ADD COLUMN status text NOT NULL DEFAULT 'designated'
    CHECK (status IN ('volunteer', 'designated'));
COMMENT ON COLUMN public.assembleia_facilitators.status IS
'volunteer = s''est proposé·e (opt-in) ; designated = désigné·e par l''AG/admin. Seuls les designated ont les droits d''animation (cadrage §6quinquies, désignation sur volontariat).';

-- =========================================================================
-- SECTION 2 — HELPERS
-- =========================================================================

-- 2.1 droits d'animation = facilitateur·rice DÉSIGNÉ·E (pas simple volontaire)
CREATE OR REPLACE FUNCTION public.fn_caller_is_assembleia_facilitator(p_assembleia_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.assembleia_facilitators
        WHERE assembleia_id = p_assembleia_id AND user_id = auth.uid() AND status = 'designated'
    );
$$;
COMMENT ON FUNCTION public.fn_caller_is_assembleia_facilitator(uuid) IS
'TRUE si l''appelant·e est facilitateur·rice DÉSIGNÉ·E (status=designated) de l''assemblée. Un·e simple volontaire n''a pas encore les droits d''animation. SECURITY DEFINER (anti-récursion RLS). Paquet ASSEMBLEIAS P2c.';
REVOKE EXECUTE ON FUNCTION public.fn_caller_is_assembleia_facilitator(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_caller_is_assembleia_facilitator(uuid) TO authenticated;

-- 2.2 nom d'affichage SCOPÉ : ne résout le nom QUE pour les personnes déjà
-- inscrites dans assembleia_facilitators (volontaires/désigné·es) — qui ont choisi
-- ce rôle (semi-)public. Pas un annuaire arbitraire (FED-7 + vie privée).
CREATE OR REPLACE FUNCTION public.fn_assembleia_facilitator_name(p_user_id uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
    SELECT nullif(trim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
    FROM public.profiles p
    WHERE p.id = p_user_id
      AND EXISTS (SELECT 1 FROM public.assembleia_facilitators f WHERE f.user_id = p_user_id);
$$;
COMMENT ON FUNCTION public.fn_assembleia_facilitator_name(uuid) IS
'Nom d''affichage (prénom + nom) d''une personne, UNIQUEMENT si elle est volontaire/désignée dans une assemblée (rôle choisi). SECURITY DEFINER scopé — n''expose pas un annuaire réseau (FED-7). Pas d''e-mail. Paquet ASSEMBLEIAS P2c.';
REVOKE EXECUTE ON FUNCTION public.fn_assembleia_facilitator_name(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_assembleia_facilitator_name(uuid) TO authenticated;

-- =========================================================================
-- SECTION 3 — VUE (+ status + display_name)
-- =========================================================================
-- DROP+CREATE (et non CREATE OR REPLACE) : la vue P2b avait (id, assembleia_id,
-- user_id, designated_at) ; on insère `status` AVANT designated_at + on ajoute
-- display_name → CREATE OR REPLACE refuse de réordonner les colonnes existantes.
-- Aucune dépendance sur cette vue (lue seulement par PostgREST). GRANT ré-accordé ci-dessous.
DROP VIEW IF EXISTS api.assembleia_facilitators_v1;
CREATE VIEW api.assembleia_facilitators_v1
WITH (security_invoker = true) AS
    SELECT f.id, f.assembleia_id, f.user_id, f.status, f.designated_at,
           public.fn_assembleia_facilitator_name(f.user_id) AS display_name
    FROM public.assembleia_facilitators f;
COMMENT ON VIEW api.assembleia_facilitators_v1 IS
'Volontaires (status=volunteer) et facilitateur·rices désigné·es (status=designated) d''une assemblée visible. display_name résolu par helper definer scopé. security_invoker. Paquet ASSEMBLEIAS P2c.';
GRANT SELECT ON api.assembleia_facilitators_v1 TO authenticated;

-- =========================================================================
-- SECTION 4 — RPC
-- =========================================================================

-- 4.1 se proposer (volontariat, opt-in) — tout membre rattaché --
CREATE OR REPLACE FUNCTION api.fn_assembleia_volunteer(p_assembleia_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
    IF NOT public.fn_caller_attached_member() THEN
        RAISE EXCEPTION 'forbidden: only an attached member can volunteer' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.assembleias WHERE id = p_assembleia_id) THEN
        RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO public.assembleia_facilitators (assembleia_id, user_id, designated_by, status)
        VALUES (p_assembleia_id, auth.uid(), auth.uid(), 'volunteer')
        ON CONFLICT (assembleia_id, user_id) DO NOTHING
        RETURNING id INTO v_id;
    RETURN v_id; -- NULL si déjà volontaire ou déjà désigné·e (idempotent)
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_volunteer(uuid) IS
'L''appelant·e se propose pour faciliter une assemblée (status=volunteer). Garde : membre rattaché. Idempotent. Paquet ASSEMBLEIAS P2c.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_volunteer(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_volunteer(uuid) TO authenticated;

-- 4.2 retirer sa proposition (seulement tant que volontaire, pas désigné·e) --
CREATE OR REPLACE FUNCTION api.fn_assembleia_unvolunteer(p_assembleia_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    DELETE FROM public.assembleia_facilitators
        WHERE assembleia_id = p_assembleia_id AND user_id = auth.uid() AND status = 'volunteer';
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_unvolunteer(uuid) IS
'Retire sa propre proposition (status=volunteer uniquement ; une désignation se révoque via remove_facilitator). Paquet ASSEMBLEIAS P2c.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_unvolunteer(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_unvolunteer(uuid) TO authenticated;

-- 4.3 désigner = passage volunteer -> designated (network_admin OU facilitateur·rice désigné·e) --
CREATE OR REPLACE FUNCTION api.fn_assembleia_add_facilitator(p_assembleia_id uuid, p_user_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(p_assembleia_id)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a designated facilitator can designate facilitators' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.assembleias WHERE id = p_assembleia_id) THEN
        RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002';
    END IF;
    INSERT INTO public.assembleia_facilitators (assembleia_id, user_id, designated_by, status)
        VALUES (p_assembleia_id, p_user_id, auth.uid(), 'designated')
        ON CONFLICT (assembleia_id, user_id)
        DO UPDATE SET status = 'designated', designated_by = auth.uid(), designated_at = now()
        RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_add_facilitator(uuid, uuid) IS
'Désigne une·e facilitateur·rice (status=designated ; promeut un·e volontaire ou insère). Garde : network_admin (bootstrap) OU facilitateur·rice désigné·e. Paquet ASSEMBLEIAS P2c (maj de P2b).';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_add_facilitator(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_add_facilitator(uuid, uuid) TO authenticated;

-- (fn_assembleia_remove_facilitator inchangée : supprime la ligne = révocation/retrait.)

-- =========================================================================
-- SECTION 5 — VÉRIFICATION (rollback auto si incohérence)
-- =========================================================================
DO $verify$
DECLARE v_col int; v_name int; v_vstatus int; v_rpc int;
BEGIN
    SELECT count(*) INTO v_col FROM information_schema.columns
        WHERE table_schema='public' AND table_name='assembleia_facilitators' AND column_name='status';
    IF v_col <> 1 THEN RAISE EXCEPTION 'verify: colonne status absente (%)', v_col; END IF;

    SELECT count(*) INTO v_name FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname='fn_assembleia_facilitator_name';
    IF v_name < 1 THEN RAISE EXCEPTION 'verify: helper fn_assembleia_facilitator_name absent'; END IF;

    SELECT count(*) INTO v_vstatus FROM information_schema.columns
        WHERE table_schema='api' AND table_name='assembleia_facilitators_v1' AND column_name IN ('status','display_name');
    IF v_vstatus <> 2 THEN RAISE EXCEPTION 'verify: vue v1 sans status/display_name (%)', v_vstatus; END IF;

    SELECT count(*) INTO v_rpc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='api' AND p.proname IN ('fn_assembleia_volunteer','fn_assembleia_unvolunteer');
    IF v_rpc <> 2 THEN RAISE EXCEPTION 'verify: 2 RPC volontariat attendues, trouvées %', v_rpc; END IF;

    RAISE NOTICE 'paquet ASSEMBLEIAS P2c OK : status (volunteer/designated), helper nom scopé, vue +status/+display_name, RPC volunteer/unvolunteer, add_facilitator -> designated.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (si régression) :
-- =========================================================================
-- BEGIN;
--   DROP FUNCTION IF EXISTS api.fn_assembleia_volunteer(uuid), api.fn_assembleia_unvolunteer(uuid);
--   DROP FUNCTION IF EXISTS public.fn_assembleia_facilitator_name(uuid);
--   -- restaurer les corps P2b de fn_caller_is_assembleia_facilitator (sans status)
--   --   et fn_assembleia_add_facilitator (ON CONFLICT DO NOTHING), + vue v1 sans status/display_name ;
--   ALTER TABLE public.assembleia_facilitators DROP COLUMN IF EXISTS status;
-- COMMIT;
-- =========================================================================
