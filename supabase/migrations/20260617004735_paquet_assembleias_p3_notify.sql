-- =========================================================================
-- Paquet ASSEMBLEIAS P3 — émission des events de notification (push)
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : face fédération / assemblée du réseau (cadrage §7bis)
-- Auteur   : Claude (assistant)
-- Session  : Fédération — Assemblée du réseau (AG)
-- Réf      : CADRAGE_assembleias_reseau_2026-06-16 §7bis ; REGISTRE §FED.
--
-- Objet : ajoute l'ÉMISSION de 3 events de notification (best-effort) dans les RPC
-- existantes, via la voie outbox jsonb fn_network_notify_event (préfixe network.%,
-- l'uuid voyage dans le payload — aucun record_id bigint). Le handler côté EF
-- (notify-event / domain/network.ts) résout destinataires + mail-strings (paquet P3-EF).
--   - fn_assembleia_set_status : statut → 'convocada' (transition) → network.assembleia.convocada
--   - fn_assembleia_set_dates  : agenda_published_at null→non-null → network.assembleia.agenda_published
--   - fn_assembleia_propose_item : dépôt d'un point → network.assembleia.item_proposed
--
-- Best-effort : fn_network_notify_event avale ses propres erreurs (RETURN NULL) ;
-- un échec de notification ne casse JAMAIS la RPC métier. CREATE OR REPLACE des 3
-- RPC (corps inchangé hormis l'émission + chargements nécessaires). Transactionnelle.
-- =========================================================================

BEGIN;

-- 1. set_status → émet convocada à la TRANSITION vers 'convocada' ----------
CREATE OR REPLACE FUNCTION api.fn_assembleia_set_status(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_old text; v_title text; v_deadline timestamptz;
BEGIN
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(p_id)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can change status' USING ERRCODE = '42501';
    END IF;
    IF p_status NOT IN ('em_preparacao','convocada','em_curso','encerrada','arquivada') THEN
        RAISE EXCEPTION 'invalid_status' USING ERRCODE = '22023';
    END IF;
    SELECT status, title, agenda_deadline_at INTO v_old, v_title, v_deadline FROM public.assembleias WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002'; END IF;
    UPDATE public.assembleias SET status = p_status WHERE id = p_id;
    -- P3 : convocation (push réseau) à la transition vers 'convocada' uniquement.
    IF p_status = 'convocada' AND v_old IS DISTINCT FROM 'convocada' THEN
        PERFORM public.fn_network_notify_event('network.assembleia.convocada',
            jsonb_build_object('assembleia_id', p_id, 'title', v_title, 'agenda_deadline_at', v_deadline));
    END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_set_status(uuid, text) IS
'Transition de cycle de vie. Garde : network_admin OU facilitateur·rice désigné·e. P3 : émet network.assembleia.convocada à la transition vers convocada (best-effort). Paquet ASSEMBLEIAS.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_set_status(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_set_status(uuid, text) TO authenticated;

-- 2. set_dates → émet agenda_published quand agenda_published_at null→non-null
CREATE OR REPLACE FUNCTION api.fn_assembleia_set_dates(
    p_id uuid, p_convocation_at timestamptz, p_agenda_deadline_at timestamptz,
    p_agenda_published_at timestamptz, p_scheduled_at timestamptz
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_old_pub timestamptz; v_title text;
BEGIN
    IF NOT (public.fn_caller_is_network_admin() OR public.fn_caller_is_assembleia_facilitator(p_id)) THEN
        RAISE EXCEPTION 'forbidden: only network admin or a facilitator of this assembly can set dates' USING ERRCODE = '42501';
    END IF;
    SELECT agenda_published_at, title INTO v_old_pub, v_title FROM public.assembleias WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'assembly_not_found' USING ERRCODE = 'P0002'; END IF;
    UPDATE public.assembleias
        SET convocation_at = p_convocation_at, agenda_deadline_at = p_agenda_deadline_at,
            agenda_published_at = p_agenda_published_at, scheduled_at = p_scheduled_at
        WHERE id = p_id;
    -- P3 : publication de l'ODJ (push réseau) à la 1ʳᵉ pose de agenda_published_at.
    IF p_agenda_published_at IS NOT NULL AND v_old_pub IS NULL THEN
        PERFORM public.fn_network_notify_event('network.assembleia.agenda_published',
            jsonb_build_object('assembleia_id', p_id, 'title', v_title, 'scheduled_at', p_scheduled_at));
    END IF;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) IS
'Pose/maj les jalons. Garde : network_admin OU facilitateur·rice. P3 : émet network.assembleia.agenda_published à la 1ʳᵉ publication (best-effort). Paquet ASSEMBLEIAS.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_set_dates(uuid, timestamptz, timestamptz, timestamptz, timestamptz) TO authenticated;

-- 3. propose_item → émet item_proposed vers la facilitation ----------------
CREATE OR REPLACE FUNCTION api.fn_assembleia_propose_item(
    p_assembleia_id uuid, p_library_id uuid, p_title text, p_rationale text DEFAULT NULL
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_item_id uuid; v_ass record; v_status text; v_lib_name text;
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

    v_status := CASE
        WHEN v_ass.agenda_deadline_at IS NOT NULL AND now() > v_ass.agenda_deadline_at THEN 'varia'
        ELSE 'proposto'
    END;

    INSERT INTO public.assembleia_agenda_items
        (assembleia_id, title, rationale, proposing_library_id, proposed_by, status)
        VALUES (p_assembleia_id, trim(p_title), nullif(trim(coalesce(p_rationale,'')),''),
                p_library_id, auth.uid(), v_status)
        RETURNING id INTO v_item_id;

    -- P3 : notifier la facilitation (best-effort, DOC-NOTIF-1).
    SELECT name INTO v_lib_name FROM public.libraries WHERE id = p_library_id;
    PERFORM public.fn_network_notify_event('network.assembleia.item_proposed',
        jsonb_build_object('assembleia_id', p_assembleia_id, 'assembly_title', v_ass.title,
            'item_title', trim(p_title), 'proposing_library_name', v_lib_name));

    RETURN v_item_id;
END;
$$;
COMMENT ON FUNCTION api.fn_assembleia_propose_item(uuid, uuid, text, text) IS
'Dépose un point à l''ODJ (« pas de gardien », bascule varia après J-15). Garde : coordenador. P3 : émet network.assembleia.item_proposed vers la facilitation (best-effort). Paquet ASSEMBLEIAS.';
REVOKE EXECUTE ON FUNCTION api.fn_assembleia_propose_item(uuid, uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_assembleia_propose_item(uuid, uuid, text, text) TO authenticated;

-- =========================================================================
-- VÉRIFICATION
-- =========================================================================
DO $verify$
DECLARE v_fns int; v_emit int;
BEGIN
    SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='api' AND p.proname IN
        ('fn_assembleia_set_status','fn_assembleia_set_dates','fn_assembleia_propose_item');
    IF v_fns <> 3 THEN RAISE EXCEPTION 'verify: 3 RPC attendues, trouvées %', v_fns; END IF;

    SELECT count(*) INTO v_emit FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname='fn_network_notify_event';
    IF v_emit < 1 THEN RAISE EXCEPTION 'verify: fn_network_notify_event absent (émission impossible)'; END IF;

    RAISE NOTICE 'paquet ASSEMBLEIAS P3 OK : émission convocada / agenda_published / item_proposed câblée (best-effort).';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : restaurer les corps P2b/P2c des 3 RPC (sans l'émission). Le handler
-- EF des network.assembleia.* (domain/network.ts) ignore simplement les events
-- qui ne sont plus émis. Aucune table créée par ce paquet.
-- =========================================================================
