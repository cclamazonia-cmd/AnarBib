-- =========================================================================
-- Paquet ASSEMBLEIAS — Assemblée du réseau : objet + dépôt ODJ (v0.1)
-- =========================================================================
-- Date     : 2026-06-16
-- Chantier : face fédération / assemblée du réseau (spec-assembleias v0.1)
-- Auteur   : Claude (assistant)
-- Session  : Fédération — Assemblée du réseau (AG)
-- Réf      : spec-assembleias §4-7 ; CADRAGE_assembleias_reseau_2026-06-16 ; REGISTRE §FED (à canoniser)
--
-- Périmètre (DOC-CLOSE-1, un paquet à la fois) :
--   - 2 tables : assembleias, assembleia_agenda_items
--   - RLS lecture (membre rattaché OU facilitation réseau) ; écriture refusée hors RPC.
--   - 2 vues api.*_v1 (assemblées / ODJ) — security_invoker.
--   - 7 RPC SECURITY DEFINER :
--       facilitation (fn_caller_is_network_admin) : create / set_dates / set_status / order_item / defer_item
--       coordenador  (user_can_manage_library)    : propose_item / withdraw_item
--   - Modèle ODJ « pas de gardien » (cadrage §6bis) : le dépôt inscrit le point ;
--     bascule `varia` après agenda_deadline_at (J-15) ; JAMAIS de DELETE (diferido/retirado).
--
-- HORS périmètre (différé — spec §11) :
--   - Choix de date (slots + disponibilité/préférence), quorum 60/50 (liste des zones),
--     vote/consentement, ratification asynchrone, events notify-event → paquets ultérieurs.
--   - Frontend (formulaire de dépôt dans AssembleiasTab) → paquet P2.
--
-- CHECKLIST DOCTRINE (DOC-OBJ-2)
--   [x] Fonctions SECURITY DEFINER : SET search_path figé ; REVOKE EXECUTE FROM PUBLIC ;
--       GRANT EXECUTE TO authenticated ; garde interne (network_admin / coordenador)
--   [x] Tables : REVOKE ALL anon/authenticated → GRANT SELECT ; RLS ON ; policy SELECT ;
--       GRANT ALL service_role ; écriture seulement via RPC SECURITY DEFINER
--   [x] Vues security_invoker ; bloc DO de vérification (rollback auto) ; NOTIFY pgrst en fin
-- =========================================================================

BEGIN;

-- =========================================================================
-- SECTION 1 — TABLES
-- =========================================================================

-- 1.1 assembleias --------------------------------------------------------
CREATE TABLE public.assembleias (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title               text NOT NULL CHECK (length(trim(title)) > 0),
    kind                text NOT NULL CHECK (kind IN ('constituinte','ordinaria')),
    status              text NOT NULL DEFAULT 'em_preparacao'
                            CHECK (status IN ('em_preparacao','convocada','em_curso','encerrada','arquivada')),
    convocation_at      timestamptz,
    agenda_deadline_at  timestamptz,
    agenda_published_at timestamptz,
    scheduled_at        timestamptz,
    created_by          uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at          timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.assembleias IS
'Assemblée du réseau (spec-assembleias v0.1). kind constituinte = quorum allégé (cadrage §6ter). Salle Jitsi = anarbib-assembleia-<id>. Jalons : convocation J-30, agenda_deadline J-15, agenda_published ~J-10, scheduled J-0 (UTC, choix de date = v0.2).';
CREATE INDEX assembleias_status_idx ON public.assembleias(status);

-- 1.2 assembleia_agenda_items --------------------------------------------
CREATE TABLE public.assembleia_agenda_items (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    assembleia_id        uuid NOT NULL REFERENCES public.assembleias(id) ON DELETE CASCADE,
    title                text NOT NULL CHECK (length(trim(title)) > 0),
    rationale            text,
    proposing_library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
    proposed_by          uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    status               text NOT NULL DEFAULT 'proposto'
                            CHECK (status IN ('proposto','varia','diferido','retirado')),
    display_order        integer,
    created_at           timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.assembleia_agenda_items IS
'Points proposés à l''ODJ d''une assemblée (cadrage §6bis, modèle « pas de gardien »). proposto = dans les délais ; varia = déposé après J-15 ; diferido = renvoyé par l''AG ; retirado = retiré par le collectif proposant. JAMAIS de DELETE (mémoire).';
CREATE INDEX assembleia_agenda_items_assembleia_idx ON public.assembleia_agenda_items(assembleia_id);
CREATE INDEX assembleia_agenda_items_library_idx ON public.assembleia_agenda_items(proposing_library_id);

-- =========================================================================
-- SECTION 2 — GRANTS + RLS (lecture ; écriture refusée hors RPC)
-- =========================================================================

REVOKE ALL ON public.assembleias, public.assembleia_agenda_items FROM anon, authenticated;
GRANT SELECT ON public.assembleias, public.assembleia_agenda_items TO authenticated;
GRANT ALL ON public.assembleias, public.assembleia_agenda_items TO service_role;

ALTER TABLE public.assembleias             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assembleia_agenda_items ENABLE ROW LEVEL SECURITY;

-- Lecture : tout membre rattaché (FED — voir ≠ agir) OU la facilitation réseau.
-- Réutilise les helpers SECURITY DEFINER existants (paquet FED-1 / rede).
CREATE POLICY assembleias_select ON public.assembleias
    FOR SELECT TO authenticated
    USING (public.fn_caller_attached_member() OR public.fn_caller_is_network_admin());

CREATE POLICY assembleia_agenda_items_select ON public.assembleia_agenda_items
    FOR SELECT TO authenticated
    USING (public.fn_caller_attached_member() OR public.fn_caller_is_network_admin());

-- (Aucune policy INSERT/UPDATE/DELETE pour authenticated : écriture exclusivement via RPC SECURITY DEFINER.)

-- =========================================================================
-- SECTION 3 — VUES api (security_invoker)
-- =========================================================================

CREATE OR REPLACE VIEW api.assembleias_v1
WITH (security_invoker = true) AS
    SELECT a.id, a.title, a.kind, a.status,
           a.convocation_at, a.agenda_deadline_at, a.agenda_published_at, a.scheduled_at,
           a.created_at
    FROM public.assembleias a;
COMMENT ON VIEW api.assembleias_v1 IS
'Assemblées visibles (RLS assembleias_select : membre rattaché ou facilitation). security_invoker. Paquet ASSEMBLEIAS v0.1.';
GRANT SELECT ON api.assembleias_v1 TO authenticated;

CREATE OR REPLACE VIEW api.assembleia_agenda_v1
WITH (security_invoker = true) AS
    SELECT ai.id, ai.assembleia_id, ai.title, ai.rationale,
           ai.proposing_library_id, l.name AS proposing_library_name,
           ai.status, ai.display_order, ai.created_at
    FROM public.assembleia_agenda_items ai
    JOIN public.libraries l ON l.id = ai.proposing_library_id;
COMMENT ON VIEW api.assembleia_agenda_v1 IS
'Points d''ODJ d''une assemblée visible. La bibliothèque proposante est exposée par NOM (transparence, cadrage §6bis), jamais l''utilisateur·rice. security_invoker. Paquet ASSEMBLEIAS v0.1.';
GRANT SELECT ON api.assembleia_agenda_v1 TO authenticated;

-- =========================================================================
-- SECTION 4 — RPC (RPC-first, SECURITY DEFINER)
-- =========================================================================

-- 4.1 fn_assembleia_create (facilitation) ---------------------------------
CREATE OR REPLACE FUNCTION api.fn_assembleia_create(p_title text, p_kind text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_id uuid;
BEGIN
    IF NOT public.fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only network facilitation can create an assembly' USING ERRCODE = '42501';
    END IF;
    IF p_kind NOT IN ('constituinte','ordinaria') THEN
        RAISE EXCEPTION 'invalid_kind' USING ERRCODE = '22023';
    END IF;
    IF length(trim(coalesce(p_title,''))) = 0 THEN
        RAISE EXCEPTION 'title_required' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.assembleias (title, kind, created_by)
        VALUES (trim(p_title), p_kind, auth.uid())
        RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_create(text, text) IS
'Crée une assemblée (em_preparacao). Garde : facilitation réseau (fn_caller_is_network_admin). Paquet ASSEMBLEIAS v0.1.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_create(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_create(text, text) TO authenticated;

-- 4.2 fn_assembleia_set_dates (facilitation) ------------------------------
CREATE OR REPLACE FUNCTION api.fn_assembleia_set_dates(
    p_id uuid, p_convocation_at timestamptz, p_agenda_deadline_at timestamptz,
    p_agenda_published_at timestamptz, p_scheduled_at timestamptz
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT public.fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only network facilitation can set assembly dates' USING ERRCODE = '42501';
    END IF;
    UPDATE public.assembleias
        SET convocation_at = p_convocation_at,
            agenda_deadline_at = p_agenda_deadline_at,
            agenda_published_at = p_agenda_published_at,
            scheduled_at = p_scheduled_at
        WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002'; END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) IS
'Pose/maj les jalons (convocation J-30, dépôt J-15, publication ~J-10, tenue J-0). Garde : facilitation réseau. Paquet ASSEMBLEIAS v0.1.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) TO authenticated;

-- 4.3 fn_assembleia_set_status (facilitation) -----------------------------
CREATE OR REPLACE FUNCTION api.fn_assembleia_set_status(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT public.fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only network facilitation can change assembly status' USING ERRCODE = '42501';
    END IF;
    IF p_status NOT IN ('em_preparacao','convocada','em_curso','encerrada','arquivada') THEN
        RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
    END IF;
    UPDATE public.assembleias SET status = p_status WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002'; END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_set_status(uuid, text) IS
'Transition de cycle de vie de l''assemblée. Garde : facilitation réseau. Paquet ASSEMBLEIAS v0.1.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_set_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_set_status(uuid, text) TO authenticated;

-- 4.4 fn_assembleia_propose_item (coordenador — « pas de gardien ») -------
CREATE OR REPLACE FUNCTION api.fn_assembleia_propose_item(
    p_assembleia_id uuid, p_library_id uuid, p_title text, p_rationale text DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_item_id uuid; v_ass record; v_status text;
BEGIN
    IF NOT public.user_can_manage_library(p_library_id) THEN
        RAISE EXCEPTION 'forbidden: only the coordenador of the library can propose an item' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_ass FROM public.assembleias WHERE id = p_assembleia_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002'; END IF;
    IF v_ass.status IN ('encerrada','arquivada') THEN
        RAISE EXCEPTION 'assembly_closed' USING ERRCODE = '22023';
    END IF;
    IF length(trim(coalesce(p_title,''))) = 0 THEN
        RAISE EXCEPTION 'title_required' USING ERRCODE = '22023';
    END IF;

    -- « Pas de gardien » : le dépôt inscrit le point. Le délai n'est pas un filtre :
    -- après l'échéance J-15, le point bascule en `varia` (cadrage §6bis), il n'est pas refusé.
    v_status := CASE
        WHEN v_ass.agenda_deadline_at IS NOT NULL AND now() > v_ass.agenda_deadline_at THEN 'varia'
        ELSE 'proposto'
    END;

    INSERT INTO public.assembleia_agenda_items
        (assembleia_id, title, rationale, proposing_library_id, proposed_by, status)
        VALUES (p_assembleia_id, trim(p_title), nullif(trim(coalesce(p_rationale,'')),''),
                p_library_id, auth.uid(), v_status)
        RETURNING id INTO v_item_id;
    RETURN v_item_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_propose_item(uuid, uuid, text, text) IS
'Dépose un point à l''ODJ au nom d''une bibliothèque (cadrage §6bis, « pas de gardien »). proposto si avant agenda_deadline_at, sinon varia. Aucun critère d''admission. Garde : coordenador (user_can_manage_library). Paquet ASSEMBLEIAS v0.1.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_propose_item(uuid, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_propose_item(uuid, uuid, text, text) TO authenticated;

-- 4.5 fn_assembleia_order_item (facilitation — organise sans supprimer) ---
CREATE OR REPLACE FUNCTION api.fn_assembleia_order_item(p_item_id uuid, p_display_order integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT public.fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only network facilitation can order agenda items' USING ERRCODE = '42501';
    END IF;
    UPDATE public.assembleia_agenda_items SET display_order = p_display_order WHERE id = p_item_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'item_not_found' USING ERRCODE = 'P0002'; END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_order_item(uuid, integer) IS
'Ordonne un point d''ODJ (facilitation organise, ne supprime jamais — cadrage §6bis). Garde : facilitation réseau. Paquet ASSEMBLEIAS v0.1.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_order_item(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_order_item(uuid, integer) TO authenticated;

-- 4.6 fn_assembleia_defer_item (facilitation — diferido, jamais DELETE) ----
CREATE OR REPLACE FUNCTION api.fn_assembleia_defer_item(p_item_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT public.fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only network facilitation can defer agenda items' USING ERRCODE = '42501';
    END IF;
    UPDATE public.assembleia_agenda_items SET status = 'diferido' WHERE id = p_item_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'item_not_found' USING ERRCODE = 'P0002'; END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_defer_item(uuid) IS
'Diffère un point (status=diferido) — la facilitation ne supprime jamais (mémoire, cadrage §6bis). Garde : facilitation réseau. Paquet ASSEMBLEIAS v0.1.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_defer_item(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_defer_item(uuid) TO authenticated;

-- 4.7 fn_assembleia_withdraw_item (coordenador proposant) -----------------
CREATE OR REPLACE FUNCTION api.fn_assembleia_withdraw_item(p_item_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_item record;
BEGIN
    SELECT * INTO v_item FROM public.assembleia_agenda_items WHERE id = p_item_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'item_not_found' USING ERRCODE = 'P0002'; END IF;
    IF NOT public.user_can_manage_library(v_item.proposing_library_id) THEN
        RAISE EXCEPTION 'forbidden: only the proposing library''s coordenador can withdraw' USING ERRCODE = '42501';
    END IF;
    UPDATE public.assembleia_agenda_items SET status = 'retirado' WHERE id = p_item_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_withdraw_item(uuid) IS
'Le collectif proposant retire son point (status=retirado). Garde : coordenador de la biblio proposante. Paquet ASSEMBLEIAS v0.1.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_withdraw_item(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_withdraw_item(uuid) TO authenticated;

-- =========================================================================
-- SECTION 5 — VÉRIFICATION (rollback auto si incohérence)
-- =========================================================================
DO $verify$
DECLARE v_tables int; v_rls int; v_fns int; v_views int;
BEGIN
    SELECT count(*) INTO v_tables FROM information_schema.tables
        WHERE table_schema='public' AND table_name IN ('assembleias','assembleia_agenda_items');
    IF v_tables <> 2 THEN RAISE EXCEPTION 'verify: expected 2 tables, found %', v_tables; END IF;

    SELECT count(*) INTO v_rls FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname IN ('assembleias','assembleia_agenda_items') AND c.relrowsecurity;
    IF v_rls <> 2 THEN RAISE EXCEPTION 'verify: RLS not enabled on both tables (% with RLS)', v_rls; END IF;

    SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='api' AND p.proname IN
        ('fn_assembleia_create','fn_assembleia_set_dates','fn_assembleia_set_status',
         'fn_assembleia_propose_item','fn_assembleia_order_item','fn_assembleia_defer_item',
         'fn_assembleia_withdraw_item');
    IF v_fns <> 7 THEN RAISE EXCEPTION 'verify: expected 7 api.fn_assembleia_* RPC, found %', v_fns; END IF;

    SELECT count(*) INTO v_views FROM information_schema.views
        WHERE table_schema='api' AND table_name IN ('assembleias_v1','assembleia_agenda_v1');
    IF v_views <> 2 THEN RAISE EXCEPTION 'verify: expected 2 api views, found %', v_views; END IF;

    RAISE NOTICE 'paquet ASSEMBLEIAS v0.1 OK : 2 tables (RLS), 2 vues, 7 RPC. Tables vides à la création.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (si régression post-déploiement) :
-- =========================================================================
-- BEGIN;
--   DROP VIEW IF EXISTS api.assembleias_v1, api.assembleia_agenda_v1;
--   DROP FUNCTION IF EXISTS api.fn_assembleia_create(text,text),
--     api.fn_assembleia_set_dates(uuid,timestamptz,timestamptz,timestamptz,timestamptz),
--     api.fn_assembleia_set_status(uuid,text), api.fn_assembleia_propose_item(uuid,uuid,text,text),
--     api.fn_assembleia_order_item(uuid,integer), api.fn_assembleia_defer_item(uuid),
--     api.fn_assembleia_withdraw_item(uuid);
--   DROP TABLE IF EXISTS public.assembleia_agenda_items, public.assembleias;
-- COMMIT;
-- =========================================================================
