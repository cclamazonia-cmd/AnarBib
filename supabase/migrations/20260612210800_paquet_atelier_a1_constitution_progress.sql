-- =========================================================================
-- Paquet ATELIER-A1 — Fondation « Oficina de constituição » (constitution_progress)
-- =========================================================================
-- Date     : 2026-06-12
-- Chantier : onboarding biblioteca #111 (spec-onboarding-biblioteca v2.0 §3, §6)
-- Auteur   : Xavier (AnarBib)
-- Session  : Wizards onboarding & federation
-- Réf      : REGISTRE §26 ONBO (ONBO-Q1/Q2/Q5/Q6) ; spec §3.1 (constitution_progress),
--            §3.3 (activation à l'approbation), §6 (volet 0 + 10 volets).
--
-- Périmètre (A1, fondation backend du wizard de constitution — DOC-CLOSE-1) :
--   - profiles.solicitante_state (enum applicatif, nullable).
--   - public.library_constitution_progress (clé request_id, conforme spec §3.1).
--   - RLS : solicitante voit sa progression ; admin réseau voit tout. Écriture RPC.
--   - Policy SELECT admin réseau sur library_requests (les admins doivent voir
--     TOUTES les demandes — aujourd'hui seules select_own/insert_own existent).
--   - RPC RPC-first (DOC-RPC-3) :
--       api.fn_approve_library_request   (admin réseau) → aprovada + crée la
--                                         constitution + bascule solicitante_state.
--       api.fn_constitution_set_profile  (coordenador = solicitante) → volet 0.
--       api.fn_constitution_set_volet     "        " → bascule un volet.
--       api.fn_constitution_set_regimento "        " → URL PDF + volet 10.
--       api.fn_constitution_complete      "        " → completed_at.
--   - Vue api.my_constitution_progress_v1 (security_invoker, 1ʳᵉ personne).
--
-- HORS périmètre (lots ultérieurs, NON bloquants pour l'atelier) :
--   - Workflow de vote/review admin enrichi (statuts proposta_*/aguardando_info,
--     library_request_votes/comments/messages/invitations, trigger d'unanimité) → A-rede.
--   - Mode redéfinition (biblio active, sans request_id) → lot dédié.
--   - PDF regimento (génération front), notifications mail, crons d'expiration.
--
-- CHECKLIST DOCTRINE (DOC-OBJ-2)
--   [x] Fonctions SECURITY DEFINER : search_path figé ; REVOKE FROM PUBLIC, anon,
--       authenticated, service_role ; GRANT EXECUTE ciblé authenticated.
--   [x] Table : REVOKE ALL anon/authenticated → GRANT SELECT ; RLS ON ; policies ;
--       GRANT ALL service_role ; écriture seulement via RPC SECURITY DEFINER.
--   [x] Bloc DO de vérification (rollback auto) ; NOTIFY pgrst en fin.
-- =========================================================================

BEGIN;

-- =========================================================================
-- SECTION 1 — profiles.solicitante_state (spec §2.2)
-- =========================================================================
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS solicitante_state text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_solicitante_state_chk'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_solicitante_state_chk CHECK (
                solicitante_state IS NULL OR solicitante_state IN (
                    'solicitante_inicial', 'solicitante_pendente', 'solicitante_recusada',
                    'coordenador_em_constituicao', 'limbo_fechamento'
                )
            );
    END IF;
END
$$;
COMMENT ON COLUMN public.profiles.solicitante_state IS
'État du parcours solicitante (spec onboarding §2.2). NULL = compte standard rattaché à une biblio. Distinct de signup_intent (intention d''inscription).';

-- =========================================================================
-- SECTION 2 — public.library_constitution_progress (spec §3.1)
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.library_constitution_progress (
    id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id               uuid NOT NULL UNIQUE REFERENCES public.library_requests(id) ON DELETE CASCADE,
    coordenador_id           uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    started_at               timestamptz NOT NULL DEFAULT now(),
    deadline_at              timestamptz NOT NULL DEFAULT (now() + interval '60 days'),
    completed_at             timestamptz,
    -- Volet 0 — profil d'adoption (4 axes orthogonaux)
    volet_0_profil_done      boolean NOT NULL DEFAULT false,
    volet_0_catalog_mode     text CHECK (volet_0_catalog_mode IS NULL OR volet_0_catalog_mode IN ('local_only','network_published')),
    volet_0_circulation_mode text CHECK (volet_0_circulation_mode IS NULL OR volet_0_circulation_mode IN ('off','informal','full_sigb')),
    volet_0_network_mode     text CHECK (volet_0_network_mode IS NULL OR volet_0_network_mode IN ('isolated','observer','federated')),
    volet_0_governance_mode  text CHECK (volet_0_governance_mode IS NULL OR volet_0_governance_mode IN ('informal','staff_roles','full_governance')),
    -- Volets 1-10
    volet_1_identite_done    boolean NOT NULL DEFAULT false,
    volet_2_horaires_done    boolean NOT NULL DEFAULT false,
    volet_3_pessoas_done     boolean NOT NULL DEFAULT false,
    volet_4_catalogacao_done boolean NOT NULL DEFAULT false,
    volet_5_circulacao_done  boolean NOT NULL DEFAULT false,
    volet_6_adhesion_done    boolean NOT NULL DEFAULT false,
    volet_7_emails_done      boolean NOT NULL DEFAULT false,
    volet_8_visibilidade_done boolean NOT NULL DEFAULT false,
    volet_9_dados_done       boolean NOT NULL DEFAULT false,
    volet_10_regimento_done  boolean NOT NULL DEFAULT false,
    regimento_pdf_url        text,
    created_at               timestamptz NOT NULL DEFAULT now(),
    updated_at               timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.library_constitution_progress IS
'Avancement du wizard de constitution d''une biblio (spec onboarding §3.1). Une ligne par demande approuvée (request_id unique). Créée par api.fn_approve_library_request ; éditée par les RPC fn_constitution_*. Deadline = started_at + 60 j (ONBO-Q5).';
CREATE INDEX IF NOT EXISTS library_constitution_progress_coord_idx
    ON public.library_constitution_progress(coordenador_id);

REVOKE ALL ON public.library_constitution_progress FROM anon, authenticated;
GRANT SELECT ON public.library_constitution_progress TO authenticated;
GRANT ALL ON public.library_constitution_progress TO service_role;

ALTER TABLE public.library_constitution_progress ENABLE ROW LEVEL SECURITY;

-- Le·la solicitante voit SA progression ; l'admin réseau voit tout.
CREATE POLICY library_constitution_progress_select ON public.library_constitution_progress
    FOR SELECT TO authenticated
    USING (coordenador_id = (SELECT auth.uid()) OR public.fn_caller_is_network_admin());
-- (Aucune policy INSERT/UPDATE/DELETE : écriture exclusivement via RPC SECURITY DEFINER.)

-- =========================================================================
-- SECTION 3 — library_requests : policy SELECT admin réseau (spec §3.2)
-- =========================================================================
-- Aujourd'hui seules select_own/insert_own existent → les admins réseau ne
-- voient pas les demandes d'autrui. On ajoute la lecture admin (additif).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policy
        WHERE polrelid = 'public.library_requests'::regclass AND polname = 'library_requests_admin_read'
    ) THEN
        CREATE POLICY library_requests_admin_read ON public.library_requests
            FOR SELECT TO authenticated
            USING (public.fn_caller_is_network_admin());
    END IF;
END
$$;

-- =========================================================================
-- SECTION 4 — RPC (RPC-first, SECURITY DEFINER)
-- =========================================================================

-- 4.1 fn_approve_library_request (admin réseau) -------------------------------
-- Remplace l'UPDATE direct de RedePage (RLS le bloquait : DOC-RPC-3). Approuve
-- la demande ET crée la constitution (idempotent) + bascule solicitante_state.
CREATE OR REPLACE FUNCTION api.fn_approve_library_request(p_request_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_req record; v_progress_id uuid;
BEGIN
    IF NOT public.fn_caller_is_network_admin() THEN
        RAISE EXCEPTION 'forbidden: only a network admin can approve a request' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO v_req FROM public.library_requests WHERE id = p_request_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'request_not_found' USING ERRCODE = 'P0002'; END IF;

    UPDATE public.library_requests
        SET request_status = 'aprovada', reviewed_at = now(), reviewed_by_user_id = auth.uid()
        WHERE id = p_request_id;

    -- Crée la constitution si absente (deadline +60 j, volet 0 laissé à faire — §3.3).
    INSERT INTO public.library_constitution_progress (request_id, coordenador_id)
        VALUES (p_request_id, v_req.submitted_by_user_id)
        ON CONFLICT (request_id) DO NOTHING
        RETURNING id INTO v_progress_id;
    IF v_progress_id IS NULL THEN
        SELECT id INTO v_progress_id FROM public.library_constitution_progress WHERE request_id = p_request_id;
    END IF;

    UPDATE public.profiles
        SET solicitante_state = 'coordenador_em_constituicao'
        WHERE id = v_req.submitted_by_user_id;

    RETURN v_progress_id;
END;
$$;
COMMENT ON FUNCTION api.fn_approve_library_request(uuid) IS
'Approuve une demande (admin réseau) : status=aprovada + crée library_constitution_progress (idempotent, deadline +60 j) + solicitante_state=coordenador_em_constituicao. RPC-first (DOC-RPC-3). Paquet ATELIER-A1.';
REVOKE EXECUTE ON FUNCTION api.fn_approve_library_request(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_approve_library_request(uuid) TO authenticated;

-- Garde commune wizard : l'appelant est le·la solicitante d'une demande approuvée
-- dont la constitution n'est pas close. Renvoie le record progress (FOR UPDATE).
CREATE OR REPLACE FUNCTION public.fn_constitution_guard(p_request_id uuid)
RETURNS public.library_constitution_progress LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_row public.library_constitution_progress;
BEGIN
    SELECT * INTO v_row FROM public.library_constitution_progress WHERE request_id = p_request_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'constitution_not_found' USING ERRCODE = 'P0002'; END IF;
    IF v_row.coordenador_id <> auth.uid() THEN
        RAISE EXCEPTION 'forbidden: not the coordenador of this constitution' USING ERRCODE = '42501';
    END IF;
    RETURN v_row;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_constitution_guard(uuid) FROM PUBLIC, anon, authenticated, service_role;

-- 4.2 fn_constitution_set_profile (volet 0) -----------------------------------
CREATE OR REPLACE FUNCTION api.fn_constitution_set_profile(
    p_request_id uuid, p_catalog text, p_circulation text, p_network text, p_governance text
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    PERFORM public.fn_constitution_guard(p_request_id);
    IF p_catalog    NOT IN ('local_only','network_published')         THEN RAISE EXCEPTION 'invalid_catalog_mode' USING ERRCODE='22023'; END IF;
    IF p_circulation NOT IN ('off','informal','full_sigb')            THEN RAISE EXCEPTION 'invalid_circulation_mode' USING ERRCODE='22023'; END IF;
    IF p_network    NOT IN ('isolated','observer','federated')        THEN RAISE EXCEPTION 'invalid_network_mode' USING ERRCODE='22023'; END IF;
    IF p_governance NOT IN ('informal','staff_roles','full_governance') THEN RAISE EXCEPTION 'invalid_governance_mode' USING ERRCODE='22023'; END IF;
    UPDATE public.library_constitution_progress
        SET volet_0_catalog_mode = p_catalog, volet_0_circulation_mode = p_circulation,
            volet_0_network_mode = p_network, volet_0_governance_mode = p_governance,
            volet_0_profil_done = true, updated_at = now()
        WHERE request_id = p_request_id;
END;
$$;
COMMENT ON FUNCTION api.fn_constitution_set_profile(uuid,text,text,text,text) IS
'Volet 0 : fixe les 4 axes du profil d''adoption et marque le volet fait. Garde : solicitante de la demande. Paquet ATELIER-A1.';
REVOKE EXECUTE ON FUNCTION api.fn_constitution_set_profile(uuid,text,text,text,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_constitution_set_profile(uuid,text,text,text,text) TO authenticated;

-- 4.3 fn_constitution_set_volet (bascule d'un volet 1-9) ----------------------
CREATE OR REPLACE FUNCTION api.fn_constitution_set_volet(p_request_id uuid, p_volet text, p_done boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
DECLARE v_col text;
BEGIN
    PERFORM public.fn_constitution_guard(p_request_id);
    -- Whitelist stricte (anti-injection) : volet -> colonne.
    v_col := CASE p_volet
        WHEN 'volet_1_identite'     THEN 'volet_1_identite_done'
        WHEN 'volet_2_horaires'     THEN 'volet_2_horaires_done'
        WHEN 'volet_3_pessoas'      THEN 'volet_3_pessoas_done'
        WHEN 'volet_4_catalogacao'  THEN 'volet_4_catalogacao_done'
        WHEN 'volet_5_circulacao'   THEN 'volet_5_circulacao_done'
        WHEN 'volet_6_adhesion'     THEN 'volet_6_adhesion_done'
        WHEN 'volet_7_emails'       THEN 'volet_7_emails_done'
        WHEN 'volet_8_visibilidade' THEN 'volet_8_visibilidade_done'
        WHEN 'volet_9_dados'        THEN 'volet_9_dados_done'
        ELSE NULL END;
    IF v_col IS NULL THEN RAISE EXCEPTION 'invalid_volet: %', p_volet USING ERRCODE='22023'; END IF;
    EXECUTE format('UPDATE public.library_constitution_progress SET %I = $1, updated_at = now() WHERE request_id = $2', v_col)
        USING p_done, p_request_id;
END;
$$;
COMMENT ON FUNCTION api.fn_constitution_set_volet(uuid,text,boolean) IS
'Marque un volet (1-9) « discuté en collectif » ou non. Whitelist stricte volet->colonne. Garde : solicitante. Volet 0 = fn_constitution_set_profile, volet 10 = fn_constitution_set_regimento. Paquet ATELIER-A1.';
REVOKE EXECUTE ON FUNCTION api.fn_constitution_set_volet(uuid,text,boolean) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_constitution_set_volet(uuid,text,boolean) TO authenticated;

-- 4.4 fn_constitution_set_regimento (volet 10) --------------------------------
CREATE OR REPLACE FUNCTION api.fn_constitution_set_regimento(p_request_id uuid, p_url text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    PERFORM public.fn_constitution_guard(p_request_id);
    UPDATE public.library_constitution_progress
        SET regimento_pdf_url = nullif(trim(coalesce(p_url,'')), ''),
            volet_10_regimento_done = (nullif(trim(coalesce(p_url,'')), '') IS NOT NULL),
            updated_at = now()
        WHERE request_id = p_request_id;
END;
$$;
COMMENT ON FUNCTION api.fn_constitution_set_regimento(uuid,text) IS
'Volet 10 : enregistre l''URL du regimento re-uploadé et marque le volet fait (artefact de délibération §6.6). Garde : solicitante. Paquet ATELIER-A1.';
REVOKE EXECUTE ON FUNCTION api.fn_constitution_set_regimento(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_constitution_set_regimento(uuid,text) TO authenticated;

-- 4.5 fn_constitution_complete -------------------------------------------------
CREATE OR REPLACE FUNCTION api.fn_constitution_complete(p_request_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth, pg_temp AS $$
BEGIN
    PERFORM public.fn_constitution_guard(p_request_id);
    UPDATE public.library_constitution_progress
        SET completed_at = now(), updated_at = now()
        WHERE request_id = p_request_id;
END;
$$;
COMMENT ON FUNCTION api.fn_constitution_complete(uuid) IS
'Marque la constitution comme complétée (completed_at). L''applicabilité des volets est gardée côté UI. Garde : solicitante. Paquet ATELIER-A1.';
REVOKE EXECUTE ON FUNCTION api.fn_constitution_complete(uuid) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION api.fn_constitution_complete(uuid) TO authenticated;

-- =========================================================================
-- SECTION 5 — Vue 1ʳᵉ personne (lecture, DOC-RPC-3)
-- =========================================================================
CREATE OR REPLACE VIEW api.my_constitution_progress_v1
WITH (security_invoker = true) AS
    SELECT cp.*, r.library_name, r.request_status
    FROM public.library_constitution_progress cp
    JOIN public.library_requests r ON r.id = cp.request_id
    WHERE cp.coordenador_id = (SELECT auth.uid());
COMMENT ON VIEW api.my_constitution_progress_v1 IS
'Constitution(s) dont l''appelant·e est le·la coordenador·a (1ʳᵉ personne). security_invoker. Paquet ATELIER-A1.';
GRANT SELECT ON api.my_constitution_progress_v1 TO authenticated;

-- =========================================================================
-- SECTION 6 — VÉRIFICATION (rollback auto si incohérence)
-- =========================================================================
DO $verify$
DECLARE v_cols int; v_fns int; v_rls boolean;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
        WHERE table_schema='public' AND table_name='library_constitution_progress') THEN
        RAISE EXCEPTION 'verify: table library_constitution_progress absente';
    END IF;
    SELECT relrowsecurity INTO v_rls FROM pg_class WHERE oid='public.library_constitution_progress'::regclass;
    IF NOT v_rls THEN RAISE EXCEPTION 'verify: RLS non activée sur library_constitution_progress'; END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
        WHERE table_schema='public' AND table_name='profiles' AND column_name='solicitante_state') THEN
        RAISE EXCEPTION 'verify: colonne profiles.solicitante_state absente';
    END IF;

    SELECT count(*) INTO v_fns FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='api' AND p.proname IN
        ('fn_approve_library_request','fn_constitution_set_profile','fn_constitution_set_volet',
         'fn_constitution_set_regimento','fn_constitution_complete');
    IF v_fns <> 5 THEN RAISE EXCEPTION 'verify: 5 RPC api attendues, % trouvées', v_fns; END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.views
        WHERE table_schema='api' AND table_name='my_constitution_progress_v1') THEN
        RAISE EXCEPTION 'verify: vue api.my_constitution_progress_v1 absente';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policy
        WHERE polrelid='public.library_requests'::regclass AND polname='library_requests_admin_read') THEN
        RAISE EXCEPTION 'verify: policy library_requests_admin_read absente';
    END IF;

    SELECT count(*) INTO v_cols FROM information_schema.columns
        WHERE table_schema='public' AND table_name='library_constitution_progress'
          AND column_name LIKE 'volet_%_done';
    IF v_cols <> 11 THEN RAISE EXCEPTION 'verify: 11 flags volet_*_done attendus, % trouvés', v_cols; END IF;

    RAISE NOTICE 'paquet ATELIER-A1 OK : constitution_progress (RLS), solicitante_state, 5 RPC, 1 vue, policy admin.';
END;
$verify$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (si régression post-déploiement) :
-- =========================================================================
-- BEGIN;
--   DROP VIEW IF EXISTS api.my_constitution_progress_v1;
--   DROP FUNCTION IF EXISTS api.fn_approve_library_request(uuid), api.fn_constitution_set_profile(uuid,text,text,text,text),
--     api.fn_constitution_set_volet(uuid,text,boolean), api.fn_constitution_set_regimento(uuid,text),
--     api.fn_constitution_complete(uuid), public.fn_constitution_guard(uuid);
--   DROP POLICY IF EXISTS library_requests_admin_read ON public.library_requests;
--   DROP TABLE IF EXISTS public.library_constitution_progress;
--   ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_solicitante_state_chk;
--   ALTER TABLE public.profiles DROP COLUMN IF EXISTS solicitante_state;
-- COMMIT;
-- =========================================================================
