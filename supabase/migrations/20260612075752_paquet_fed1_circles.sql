-- =========================================================================
-- Paquet FED-1 — Primitive « círculo » (fondations backend de la face fédération)
-- =========================================================================
-- Date     : 2026-06-12
-- Chantier : face fédération / outils fédéralistes (spec-outils-federalistes v0.2)
-- Auteur   : Xavier (AnarBib)
-- Session  : Cercles fédéraux — fondations
-- Réf      : REGISTRE §24 `FED` (FED-1..7, FED-O4/O5/O6) ; spec §5 (primitive cercle)
--
-- Périmètre (paquet 1, backend pur — DOC-CLOSE-1, un paquet à la fois) :
--   - 4 tables : circles, circle_memberships, circle_join_requests, circle_join_objections
--   - RLS lecture (FED-1 « voir = tout membre rattaché » ; FED-7 anti-panoptique) ;
--     écriture refusée hors RPC.
--   - 3 vues api.*_v1 (annuaire / 1ʳᵉ personne / membres) — security_invoker.
--   - RPC SECURITY DEFINER gardées coordenador (user_can_manage_library) :
--     create / request_join / object / leave / set_dormancy + resolve_due (maintenance).
--   - Machine d'adhésion FED-O5 : opt-out (silence = consentement), objection motivée
--     tracée, effet anti-blackball (B). Délai d'objection = 14 j.
--
-- HORS périmètre (différé) :
--   - Émission d'events `circle.*` (dispatcher fn_dispatch_notify_event attend un
--     record_id bigint ; cercles = uuid ; handler EF + mail-strings inexistants) +
--     fn_circle_message → sous-paquet 1b.
--   - FED-O7 (gouvernance des autorités partagées) → spec-atelier-autorites.
--   - Frontend (page + onglet Círculos + i18n) → paquet 2.
--
-- CHECKLIST DOCTRINE (DOC-OBJ-2)
--   [x] Fonctions SECURITY DEFINER : SET search_path figé ; REVOKE FROM PUBLIC ; GRANT ciblé
--   [x] Tables : GRANT explicites (REVOKE ALL anon/authenticated → GRANT SELECT) ; RLS ON ;
--       policies SELECT ; GRANT ALL service_role ; écriture seulement via RPC SECURITY DEFINER
--   [x] Bloc DO de vérification (rollback auto) ; NOTIFY pgrst en fin
--
-- Note adhésion : la résolution à l'échéance (open → accepted) est portée par
-- api.fn_circle_resolve_due() (idempotente), planifiée en pg_cron quotidien (3h30,
-- §4.7) et appelable au chargement de la page (lazy). Le refus anti-blackball est
-- immédiat dans fn_circle_object dès la 2ᵉ objection (ou la 1ʳᵉ si cercle ≤ 2 membres).
-- =========================================================================

BEGIN;

-- =========================================================================
-- SECTION 1 — TABLES
-- =========================================================================

-- 1.1 circles ------------------------------------------------------------
CREATE TABLE public.circles (
    id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nature           text NOT NULL CHECK (nature IN ('afinitario','geografico','linguistico','federacao')),
    name             text NOT NULL CHECK (length(trim(name)) > 0),
    description      text,
    status           text NOT NULL DEFAULT 'ativo' CHECK (status IN ('ativo','adormecido','arquivado')),
    is_open          boolean NOT NULL DEFAULT true,
    last_activity_at timestamptz,
    created_by       uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.circles IS
'Primitive cercle (FED-O4) : graphe plat, jamais arbre. Nature déclarée (informative, aucun droit différencié). Réf spec-outils-federalistes §5.';
CREATE INDEX circles_directory_idx ON public.circles(status) WHERE is_open = true AND status = 'ativo';

-- 1.2 circle_memberships -------------------------------------------------
CREATE TABLE public.circle_memberships (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id    uuid NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
    library_id   uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
    status       text NOT NULL CHECK (status IN ('membro','pendente')),
    requested_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    requested_at timestamptz NOT NULL DEFAULT now(),
    joined_at    timestamptz,
    UNIQUE (circle_id, library_id)
);
COMMENT ON TABLE public.circle_memberships IS
'Adhésion d''une bibliothèque à un cercle. membro = effective ; pendente = demande en cours (FED-O5). joined_at rempli au consentement.';
CREATE INDEX circle_memberships_library_idx ON public.circle_memberships(library_id);
CREATE INDEX circle_memberships_circle_status_idx ON public.circle_memberships(circle_id, status);

-- 1.3 circle_join_requests (FED-O5) --------------------------------------
CREATE TABLE public.circle_join_requests (
    id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    circle_id         uuid NOT NULL REFERENCES public.circles(id) ON DELETE CASCADE,
    library_id        uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
    requested_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    requested_at      timestamptz NOT NULL DEFAULT now(),
    decision_deadline timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
    status            text NOT NULL DEFAULT 'open' CHECK (status IN ('open','accepted','refused','withdrawn')),
    resolved_at       timestamptz
);
COMMENT ON TABLE public.circle_join_requests IS
'Demande d''adhésion en régime opt-out (FED-O5). decision_deadline = requested_at + 14 j (ajustable). Une seule demande ouverte par (cercle, biblio).';
CREATE UNIQUE INDEX circle_join_requests_one_open_idx
    ON public.circle_join_requests(circle_id, library_id) WHERE status = 'open';
CREATE INDEX circle_join_requests_due_idx
    ON public.circle_join_requests(decision_deadline) WHERE status = 'open';

-- 1.4 circle_join_objections (FED-O5) ------------------------------------
CREATE TABLE public.circle_join_objections (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id           uuid NOT NULL REFERENCES public.circle_join_requests(id) ON DELETE CASCADE,
    objecting_library_id uuid NOT NULL REFERENCES public.libraries(id) ON DELETE CASCADE,
    objecting_by         uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    reason               text NOT NULL CHECK (length(trim(reason)) >= 20),
    created_at           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (request_id, objecting_library_id)
);
COMMENT ON TABLE public.circle_join_objections IS
'Objection motivée (≥ 20 car.) à une demande d''adhésion. Une par biblio membre. Toujours conservée (mémoire/traçabilité). Effet anti-blackball : voir fn_circle_object.';
CREATE INDEX circle_join_objections_request_idx ON public.circle_join_objections(request_id);

-- =========================================================================
-- SECTION 2 — GRANTS + RLS (lecture ; écriture refusée hors RPC)
-- =========================================================================

REVOKE ALL ON public.circles, public.circle_memberships,
              public.circle_join_requests, public.circle_join_objections
    FROM anon, authenticated;
GRANT SELECT ON public.circles, public.circle_memberships,
                public.circle_join_requests, public.circle_join_objections
    TO authenticated;
GRANT ALL ON public.circles, public.circle_memberships,
             public.circle_join_requests, public.circle_join_objections
    TO service_role;

ALTER TABLE public.circles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_memberships     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_join_requests   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.circle_join_objections ENABLE ROW LEVEL SECURITY;

-- Helpers SECURITY DEFINER (anti-récursion RLS ; lisent les tables comme owner).
CREATE OR REPLACE FUNCTION public.fn_caller_attached_member()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_library_memberships m
        WHERE m.user_id = auth.uid() AND m.status = 'active'
    );
$$;
COMMENT ON FUNCTION public.fn_caller_attached_member() IS
'TRUE si l''appelant a une adhésion active à au moins une bibliothèque (= membre rattaché, accès face fédération — FED-2).';
REVOKE EXECUTE ON FUNCTION public.fn_caller_attached_member() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_caller_attached_member() TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_caller_in_circle(p_circle_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.circle_memberships cm
        JOIN public.user_library_memberships m ON m.library_id = cm.library_id
        WHERE cm.circle_id = p_circle_id
          AND m.user_id = auth.uid() AND m.status = 'active'
    );
$$;
COMMENT ON FUNCTION public.fn_caller_in_circle(uuid) IS
'TRUE si l''appelant est rattaché (adhésion active) à une bibliothèque membre/pendente du cercle. SECURITY DEFINER pour éviter la récursion RLS sur circle_memberships.';
REVOKE EXECUTE ON FUNCTION public.fn_caller_in_circle(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_caller_in_circle(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.fn_caller_attached_library(p_library_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_library_memberships m
        WHERE m.user_id = auth.uid() AND m.status = 'active' AND m.library_id = p_library_id
    );
$$;
REVOKE EXECUTE ON FUNCTION public.fn_caller_attached_library(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_caller_attached_library(uuid) TO authenticated;

-- circles : annuaire (open+ativo) visible aux membres rattachés ; sinon, ses propres cercles.
CREATE POLICY circles_select ON public.circles
    FOR SELECT TO authenticated
    USING (
        (is_open = true AND status = 'ativo' AND public.fn_caller_attached_member())
        OR public.fn_caller_in_circle(id)
    );

-- circle_memberships : visibles aux membres rattachés du même cercle.
CREATE POLICY circle_memberships_select ON public.circle_memberships
    FOR SELECT TO authenticated
    USING (public.fn_caller_in_circle(circle_id));

-- circle_join_requests : visibles aux membres du cercle + à la biblio candidate (transparence FED-O5).
CREATE POLICY circle_join_requests_select ON public.circle_join_requests
    FOR SELECT TO authenticated
    USING (public.fn_caller_in_circle(circle_id) OR public.fn_caller_attached_library(library_id));

-- circle_join_objections : visibles à qui peut voir la demande parente.
CREATE POLICY circle_join_objections_select ON public.circle_join_objections
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.circle_join_requests r
        WHERE r.id = request_id
          AND (public.fn_caller_in_circle(r.circle_id) OR public.fn_caller_attached_library(r.library_id))
    ));

-- (Aucune policy INSERT/UPDATE/DELETE pour authenticated : écriture exclusivement via RPC SECURITY DEFINER.)

-- =========================================================================
-- SECTION 3 — HELPER de comptage + VUES api
-- =========================================================================

-- Compteur de membres : SECURITY DEFINER pour exposer un NOMBRE dans l'annuaire
-- sans révéler les membres nominatifs (« Membros visíveis após a entrada »).
CREATE OR REPLACE FUNCTION public.fn_circle_member_count(p_circle_id uuid)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
    SELECT count(*)::int FROM public.circle_memberships
    WHERE circle_id = p_circle_id AND status = 'membro';
$$;
COMMENT ON FUNCTION public.fn_circle_member_count(uuid) IS
'Nombre de bibliothèques membres (status=membro) d''un cercle. Exposé à l''annuaire (count uniquement, pas de nominatif).';
REVOKE EXECUTE ON FUNCTION public.fn_circle_member_count(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_circle_member_count(uuid) TO authenticated;

-- 3.1 Annuaire des cercles ouverts (membres non nominatifs)
CREATE OR REPLACE VIEW api.circles_directory_v1
WITH (security_invoker = true) AS
    SELECT c.id, c.nature, c.name, c.description,
           public.fn_circle_member_count(c.id) AS members_count
    FROM public.circles c
    WHERE c.is_open = true AND c.status = 'ativo';
COMMENT ON VIEW api.circles_directory_v1 IS
'Annuaire des cercles ouverts & actifs : nom, nature, description, nombre de membres. Membres non nominatifs. Lisible par tout membre rattaché (RLS circles_select). security_invoker depuis sa création (paquet FED-1).';
GRANT SELECT ON api.circles_directory_v1 TO authenticated;

-- 3.2 Mes cercles (vue 1ʳᵉ personne, FED-7) — cercles où une de mes biblios est membro/pendente
CREATE OR REPLACE VIEW api.my_library_circles_v1
WITH (security_invoker = true) AS
    SELECT cm.library_id, cm.status AS membership_status, cm.joined_at,
           c.id AS circle_id, c.nature, c.name, c.description, c.status AS circle_status,
           c.is_open, c.last_activity_at,
           public.fn_circle_member_count(c.id) AS members_count
    FROM public.circle_memberships cm
    JOIN public.circles c ON c.id = cm.circle_id
    WHERE public.fn_caller_attached_library(cm.library_id);
COMMENT ON VIEW api.my_library_circles_v1 IS
'Vue 1ʳᵉ personne (FED-7) : les cercles où une bibliothèque à laquelle l''appelant est rattaché est membre/pendente. Jamais de vue de conjunto du réseau. security_invoker.';
GRANT SELECT ON api.my_library_circles_v1 TO authenticated;

-- 3.3 Membres d'un cercle dont l'appelant est membre
CREATE OR REPLACE VIEW api.circle_members_v1
WITH (security_invoker = true) AS
    SELECT cm.circle_id, cm.library_id, l.name AS library_name, l.slug,
           cm.status AS membership_status, cm.joined_at
    FROM public.circle_memberships cm
    JOIN public.libraries l ON l.id = cm.library_id;
COMMENT ON VIEW api.circle_members_v1 IS
'Membres d''un cercle, visibles uniquement si l''appelant est rattaché à une biblio membre du cercle (RLS circle_memberships_select). security_invoker.';
GRANT SELECT ON api.circle_members_v1 TO authenticated;

-- =========================================================================
-- SECTION 4 — RPC (RPC-first, SECURITY DEFINER, garde coordenador)
-- =========================================================================

-- 4.1 fn_circle_create -----------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_circle_create(
    p_nature text, p_name text, p_description text, p_library_id uuid, p_is_open boolean DEFAULT true
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_circle_id uuid; v_caller uuid := auth.uid();
BEGIN
    IF NOT public.user_can_manage_library(p_library_id) THEN
        RAISE EXCEPTION 'forbidden: only the coordenador of the library can create a circle' USING ERRCODE = '42501';
    END IF;
    IF p_nature NOT IN ('afinitario','geografico','linguistico','federacao') THEN
        RAISE EXCEPTION 'invalid_nature' USING ERRCODE = '22023';
    END IF;
    IF length(trim(coalesce(p_name,''))) = 0 THEN
        RAISE EXCEPTION 'name_required' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.circles (nature, name, description, is_open, last_activity_at, created_by)
        VALUES (p_nature, trim(p_name), nullif(trim(coalesce(p_description,'')),''), coalesce(p_is_open,true), now(), v_caller)
        RETURNING id INTO v_circle_id;

    INSERT INTO public.circle_memberships (circle_id, library_id, status, requested_by, joined_at)
        VALUES (v_circle_id, p_library_id, 'membro', v_caller, now());

    RETURN v_circle_id;
END;
$$;
COMMENT ON FUNCTION api.fn_circle_create(text, text, text, uuid, boolean) IS
'Crée un cercle et y inscrit la bibliothèque proposante comme 1ᵉʳ membre. Garde : coordenador (user_can_manage_library). Paquet FED-1.';
REVOKE EXECUTE ON FUNCTION api.fn_circle_create(text, text, text, uuid, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_circle_create(text, text, text, uuid, boolean) TO authenticated;

-- 4.2 fn_circle_request_join ----------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_circle_request_join(p_circle_id uuid, p_library_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_request_id uuid; v_caller uuid := auth.uid(); v_circle record;
BEGIN
    IF NOT public.user_can_manage_library(p_library_id) THEN
        RAISE EXCEPTION 'forbidden: only the coordenador can request joining' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_circle FROM public.circles WHERE id = p_circle_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'circle_not_found' USING ERRCODE = 'P0002'; END IF;
    IF v_circle.status <> 'ativo' THEN RAISE EXCEPTION 'circle_not_active' USING ERRCODE = '22023'; END IF;
    IF NOT v_circle.is_open THEN
        RAISE EXCEPTION 'invite_only: closed circle, join is on invitation (deferred)' USING ERRCODE = '42501';
    END IF;
    IF EXISTS (SELECT 1 FROM public.circle_memberships WHERE circle_id = p_circle_id AND library_id = p_library_id) THEN
        RAISE EXCEPTION 'already_member_or_pending' USING ERRCODE = '23505';
    END IF;

    INSERT INTO public.circle_memberships (circle_id, library_id, status, requested_by)
        VALUES (p_circle_id, p_library_id, 'pendente', v_caller);
    INSERT INTO public.circle_join_requests (circle_id, library_id, requested_by)
        VALUES (p_circle_id, p_library_id, v_caller)
        RETURNING id INTO v_request_id;

    -- (Event circle.join_requested → sous-paquet 1b.)
    RETURN v_request_id;
END;
$$;
COMMENT ON FUNCTION api.fn_circle_request_join(uuid, uuid) IS
'Demande d''adhésion (opt-out FED-O5) : crée une adhésion pendente + une demande open (deadline +14 j). Garde : coordenador. Paquet FED-1.';
REVOKE EXECUTE ON FUNCTION api.fn_circle_request_join(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_circle_request_join(uuid, uuid) TO authenticated;

-- 4.3 fn_circle_object (anti-blackball B) ---------------------------------
CREATE OR REPLACE FUNCTION api.fn_circle_object(p_request_id uuid, p_library_id uuid, p_reason text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE
    v_req record; v_membro_count int; v_distinct_obj int; v_refuse boolean;
BEGIN
    SELECT * INTO v_req FROM public.circle_join_requests WHERE id = p_request_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;
    IF v_req.status <> 'open' THEN RAISE EXCEPTION 'request_closed' USING ERRCODE = '22023'; END IF;
    IF v_req.decision_deadline < now() THEN RAISE EXCEPTION 'objection_window_closed' USING ERRCODE = '22023'; END IF;
    -- l'objectante doit être coordenador d'une biblio MEMBRE du cercle, et pas la candidate
    IF p_library_id = v_req.library_id THEN
        RAISE EXCEPTION 'candidate_cannot_object' USING ERRCODE = '42501';
    END IF;
    IF NOT public.user_can_manage_library(p_library_id) THEN
        RAISE EXCEPTION 'forbidden: only a coordenador can object' USING ERRCODE = '42501';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.circle_memberships
                   WHERE circle_id = v_req.circle_id AND library_id = p_library_id AND status = 'membro') THEN
        RAISE EXCEPTION 'not_a_member_library' USING ERRCODE = '42501';
    END IF;
    IF length(trim(coalesce(p_reason,''))) < 20 THEN
        RAISE EXCEPTION 'reason_too_short: a long motivation is mandatory' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.circle_join_objections (request_id, objecting_library_id, objecting_by, reason)
        VALUES (p_request_id, p_library_id, auth.uid(), p_reason)
        ON CONFLICT (request_id, objecting_library_id)
        DO NOTHING;
    IF NOT FOUND THEN
        -- ON CONFLICT DO NOTHING n'a rien inséré → cette biblio a déjà objecté
        RAISE EXCEPTION 'already_objected' USING ERRCODE = '23505';
    END IF;

    -- Anti-blackball : refus si (cercle ≤ 2 membres et ≥1 objection) ou (≥2 biblios distinctes ont objecté).
    SELECT count(*)::int INTO v_membro_count
        FROM public.circle_memberships WHERE circle_id = v_req.circle_id AND status = 'membro';
    SELECT count(DISTINCT objecting_library_id)::int INTO v_distinct_obj
        FROM public.circle_join_objections WHERE request_id = p_request_id;

    v_refuse := (v_membro_count <= 2 AND v_distinct_obj >= 1) OR (v_membro_count > 2 AND v_distinct_obj >= 2);

    IF v_refuse THEN
        UPDATE public.circle_join_requests
            SET status = 'refused', resolved_at = now() WHERE id = p_request_id;
        DELETE FROM public.circle_memberships
            WHERE circle_id = v_req.circle_id AND library_id = v_req.library_id AND status = 'pendente';
        RETURN 'refused';
    END IF;

    -- Objection isolée : suspend et ouvre la discussion (consignée), la demande reste open.
    RETURN 'open';
END;
$$;
COMMENT ON FUNCTION api.fn_circle_object(uuid, uuid, text) IS
'Objection motivée (≥20 car.) à une demande d''adhésion par une biblio membre (coordenador). Anti-blackball B : 1 objection isolée suspend sans refuser ; refus si ≥2 biblios objectent (ou ≥1 si cercle ≤2). Paquet FED-1.';
REVOKE EXECUTE ON FUNCTION api.fn_circle_object(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_circle_object(uuid, uuid, text) TO authenticated;

-- 4.4 fn_circle_leave -----------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_circle_leave(p_circle_id uuid, p_library_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    IF NOT public.user_can_manage_library(p_library_id) THEN
        RAISE EXCEPTION 'forbidden: only the coordenador can leave a circle' USING ERRCODE = '42501';
    END IF;
    DELETE FROM public.circle_memberships WHERE circle_id = p_circle_id AND library_id = p_library_id;
    -- demande ouverte éventuelle → retirée
    UPDATE public.circle_join_requests
        SET status = 'withdrawn', resolved_at = now()
        WHERE circle_id = p_circle_id AND library_id = p_library_id AND status = 'open';
END;
$$;
COMMENT ON FUNCTION api.fn_circle_leave(uuid, uuid) IS
'Retire l''adhésion d''une bibliothèque à un cercle (coordenador). Le cercle n''est jamais supprimé (mémoire). Paquet FED-1.';
REVOKE EXECUTE ON FUNCTION api.fn_circle_leave(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_circle_leave(uuid, uuid) TO authenticated;

-- 4.5 fn_circle_set_dormancy ----------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_circle_set_dormancy(p_circle_id uuid, p_action text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_new_status text;
BEGIN
    IF p_action NOT IN ('reativar','adormecer','arquivar') THEN
        RAISE EXCEPTION 'invalid_action' USING ERRCODE = '22023';
    END IF;
    -- garde : coordenador d'une biblio membre du cercle
    IF NOT EXISTS (SELECT 1 FROM public.circle_memberships cm
                   WHERE cm.circle_id = p_circle_id AND cm.status = 'membro'
                     AND public.user_can_manage_library(cm.library_id)) THEN
        RAISE EXCEPTION 'forbidden: only a coordenador of a member library can change dormancy' USING ERRCODE = '42501';
    END IF;
    v_new_status := CASE p_action WHEN 'reativar' THEN 'ativo' WHEN 'adormecer' THEN 'adormecido' ELSE 'arquivado' END;
    UPDATE public.circles
        SET status = v_new_status,
            last_activity_at = CASE WHEN p_action = 'reativar' THEN now() ELSE last_activity_at END
        WHERE id = p_circle_id;
    -- NB : l'archivage « proposition soumise au consentement » (spec §5.5) est un
    -- raffinement ultérieur ; ici action directe et réversible (jamais de suppression).
END;
$$;
COMMENT ON FUNCTION api.fn_circle_set_dormancy(uuid, text) IS
'Cycle de vie du cercle : reativar/adormecer/arquivar par un coordenador d''une biblio membre. Réversible ; jamais de suppression (mémoire). Paquet FED-1 — archivage-par-consentement = raffinement ultérieur (§5.5).';
REVOKE EXECUTE ON FUNCTION api.fn_circle_set_dormancy(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_circle_set_dormancy(uuid, text) TO authenticated;

-- 4.6 fn_circle_resolve_due (maintenance, idempotente) --------------------
CREATE OR REPLACE FUNCTION api.fn_circle_resolve_due()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE r record; v_membro int; v_obj int; v_count int := 0;
BEGIN
    FOR r IN
        SELECT * FROM public.circle_join_requests
        WHERE status = 'open' AND decision_deadline < now()
        FOR UPDATE SKIP LOCKED
    LOOP
        SELECT count(*)::int INTO v_membro
            FROM public.circle_memberships WHERE circle_id = r.circle_id AND status = 'membro';
        SELECT count(DISTINCT objecting_library_id)::int INTO v_obj
            FROM public.circle_join_objections WHERE request_id = r.id;

        IF (v_membro <= 2 AND v_obj >= 1) OR (v_membro > 2 AND v_obj >= 2) THEN
            UPDATE public.circle_join_requests SET status = 'refused', resolved_at = now() WHERE id = r.id;
            DELETE FROM public.circle_memberships
                WHERE circle_id = r.circle_id AND library_id = r.library_id AND status = 'pendente';
        ELSE
            UPDATE public.circle_join_requests SET status = 'accepted', resolved_at = now() WHERE id = r.id;
            UPDATE public.circle_memberships SET status = 'membro', joined_at = now()
                WHERE circle_id = r.circle_id AND library_id = r.library_id AND status = 'pendente';
        END IF;
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$$;
COMMENT ON FUNCTION api.fn_circle_resolve_due() IS
'Résout les demandes d''adhésion échues (deadline dépassée) : accepted si pas d''objection qualifiante (anti-blackball), sinon refused. Idempotente. Appelée au chargement de la page (lazy) et/ou par planificateur. Paquet FED-1.';
REVOKE EXECUTE ON FUNCTION api.fn_circle_resolve_due() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_circle_resolve_due() TO authenticated, service_role;

-- 4.7 Planification pg_cron de la résolution des demandes échues ----------
-- Idempotent (unschedule par nom puis schedule) — cohérent paquets C/D. Job
-- ACTIF d'emblée : fonction DB pure, aucune dépendance Edge Function (≠ jobs
-- C/D créés inactifs car tributaires d'un net.http_post vers une EF). Créneau
-- 3h30 (libre entre collective-removal 3h15 et peb-overdue 3h40).
DO $cron$
BEGIN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'anarbib-circle-resolve-due-daily';
    PERFORM cron.schedule(
        'anarbib-circle-resolve-due-daily',
        '30 3 * * *',
        $job$ SELECT api.fn_circle_resolve_due(); $job$
    );
END
$cron$;

-- =========================================================================
-- SECTION 5 — VÉRIFICATION (rollback auto si incohérence)
-- =========================================================================
DO $verify$
DECLARE v_tables int; v_fns int; v_views int; v_rls int;
BEGIN
    SELECT count(*) INTO v_tables FROM information_schema.tables
        WHERE table_schema='public' AND table_name IN
        ('circles','circle_memberships','circle_join_requests','circle_join_objections');
    IF v_tables <> 4 THEN RAISE EXCEPTION 'verify: expected 4 tables, found %', v_tables; END IF;

    SELECT count(*) INTO v_rls FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='public' AND c.relname IN
        ('circles','circle_memberships','circle_join_requests','circle_join_objections') AND c.relrowsecurity;
    IF v_rls <> 4 THEN RAISE EXCEPTION 'verify: RLS not enabled on all 4 tables (% with RLS)', v_rls; END IF;

    SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='api' AND p.proname IN
        ('fn_circle_create','fn_circle_request_join','fn_circle_object','fn_circle_leave',
         'fn_circle_set_dormancy','fn_circle_resolve_due');
    IF v_fns <> 6 THEN RAISE EXCEPTION 'verify: expected 6 api.fn_circle_* RPC, found %', v_fns; END IF;

    SELECT count(*) INTO v_views FROM information_schema.views
        WHERE table_schema='api' AND table_name IN
        ('circles_directory_v1','my_library_circles_v1','circle_members_v1');
    IF v_views <> 3 THEN RAISE EXCEPTION 'verify: expected 3 api views, found %', v_views; END IF;

    -- En contexte migration (auth.uid() NULL), resolve_due ne doit rien casser.
    PERFORM api.fn_circle_resolve_due();

    -- Le job pg_cron de résolution doit être planifié.
    PERFORM 1 FROM cron.job WHERE jobname = 'anarbib-circle-resolve-due-daily';
    IF NOT FOUND THEN RAISE EXCEPTION 'verify: cron job anarbib-circle-resolve-due-daily not scheduled'; END IF;

    RAISE NOTICE 'paquet FED-1 OK : 4 tables (RLS), 3 vues, 6 RPC, 1 job pg_cron. Tables vides à la création.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (si régression post-déploiement) :
-- =========================================================================
-- BEGIN;
--   PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'anarbib-circle-resolve-due-daily';
--   DROP VIEW IF EXISTS api.circles_directory_v1, api.my_library_circles_v1, api.circle_members_v1;
--   DROP FUNCTION IF EXISTS api.fn_circle_create(text,text,text,uuid,boolean), api.fn_circle_request_join(uuid,uuid),
--     api.fn_circle_object(uuid,uuid,text), api.fn_circle_leave(uuid,uuid), api.fn_circle_set_dormancy(uuid,text),
--     api.fn_circle_resolve_due();
--   DROP FUNCTION IF EXISTS public.fn_caller_in_circle(uuid), public.fn_caller_attached_member(),
--     public.fn_caller_attached_library(uuid), public.fn_circle_member_count(uuid);
--   DROP TABLE IF EXISTS public.circle_join_objections, public.circle_join_requests,
--     public.circle_memberships, public.circles;
-- COMMIT;
-- =========================================================================
