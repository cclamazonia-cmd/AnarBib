-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — la fin de l'atelier active la bibliothèque (21/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Activation de la constitution
--
-- CONSTAT (prod, 21/10). Les deux seules bibliothèques passées par l'atelier
-- de constitution (Solidaires, approuvée le 14/09 ; Anarchief, le 24/09) sont
-- actives alors qu'aucun de leurs ateliers n'est terminé, et leurs deux
-- coordinations sont restées 'coordenador_em_constituicao' : ProtectedRoute
-- les renvoie vers /atelier depuis toute page sauf /conta, Biblioteca et
-- Painel de leur propre bibliothèque compris. Cause : le lot 4 du cadrage
-- ONBO-Q2 (13/06, « activation finale ») n'a jamais été fait.
--   · api.fn_constitution_complete datait completed_at, rien d'autre ;
--   · public.fn_activate_approved_library_request (la bascule complète) n'est
--     appelée par personne et n'est exécutable que par service_role ;
--   · la seule activation possible était donc le bouton « Réactiver » de la
--     page Réseau : un UPDATE libraries.is_active nu, qui ne sort personne de
--     la constitution. Le journal des actions transverses en porte les traces.
-- Le chemin prévu menait à une impasse : terminer l'atelier figeait les volets
-- en lecture seule, laissait la bibliothèque pré-active et la personne
-- enfermée dans /atelier.
--
-- DÉCISION (Xavier, 21/10 — spec onboarding §6.4) : deux portes, et deux
-- seulement, pour activer une bibliothèque en constitution.
--   1. La coordination termine l'atelier : api.fn_constitution_complete
--      exige le profil (volet 0) et le règlement (volet 10), puis active.
--   2. L'administration du réseau active avant la fin, avec un MOTIF
--      obligatoire : api.fn_constitution_activate_early. L'atelier reste
--      ouvert ; le terminer plus tard ne fait que le dater.
-- Les deux portes passent par public.fn_constitution_activer (bascule +
-- axes du volet 0 + appartenance).
--
-- GARDE-FOUS, dans la base, quel que soit le chemin :
--   · AVANT : une bibliothèque dont l'atelier n'est ni terminé ni activé par
--     anticipation ne passe pas à is_active = true (le bouton nu de la page
--     Réseau, un UPDATE à la main). Les bibliothèques sans atelier (les
--     quatre d'avant ONBO) ne sont pas concernées ; désactiver reste libre.
--   · APRÈS : une bibliothèque qui devient active fait sortir sa coordination
--     de la constitution (sauf si elle en constitue une autre) et complète la
--     traçabilité de la demande (approved_membership_ref).
--
-- AUSSI : le volet 0 d'une bibliothèque déjà active s'applique tout de suite
-- à ses axes (sinon le profil voté en collectif resterait lettre morte), et
-- la bascule ne réécrit plus accepts_public_signup quand le volet 6 (adhésion)
-- en a décidé.
--
-- DONNÉES : les ateliers ouverts dont la bibliothèque est déjà active sont
-- régularisés en « activation anticipée », datée et signée d'après le journal
-- des actions transverses, motif de régularisation ; leurs coordinations
-- sortent de la constitution. Rien n'est écrit en dur : la même requête ne
-- trouve rien sur une base neuve.
--
-- Tests : tests/sql/constitution_activation_tests.sql.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. L'activation anticipée laisse sa trace sur l'atelier ─────────────────
ALTER TABLE public.library_constitution_progress
  ADD COLUMN IF NOT EXISTS early_activated_at timestamptz,
  ADD COLUMN IF NOT EXISTS early_activated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS early_activation_reason text;

ALTER TABLE public.library_constitution_progress
  DROP CONSTRAINT IF EXISTS library_constitution_progress_early_reason_chk;
ALTER TABLE public.library_constitution_progress
  ADD CONSTRAINT library_constitution_progress_early_reason_chk
  CHECK (early_activated_at IS NULL OR nullif(btrim(early_activation_reason), '') IS NOT NULL);

-- Index de la clé étrangère (garde fk_sans_index_garde_tests) : l'effacement
-- d'un compte supprime le parent profiles.
CREATE INDEX IF NOT EXISTS idx_library_constitution_progress_early_activated_by
  ON public.library_constitution_progress (early_activated_by);

COMMENT ON COLUMN public.library_constitution_progress.early_activated_at IS
  'Activation de la bibliothèque par l''administration du réseau avant la fin de l''atelier (porte 2). NULL = activée par la fin de l''atelier, ou pas encore active.';
COMMENT ON COLUMN public.library_constitution_progress.early_activation_reason IS
  'Motif obligatoire de l''activation anticipée.';

-- ── 2. Sortir de la constitution (partagé par le trigger et la régularisation)
CREATE OR REPLACE FUNCTION public.fn_constitution_sortir(p_library_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- La coordination quitte l'état de constitution, sauf si elle porte un autre
  -- atelier encore ouvert sur une bibliothèque pré-active.
  UPDATE public.profiles p
     SET solicitante_state = NULL
    FROM public.library_constitution_progress c
   WHERE c.library_id = p_library_id
     AND p.id = c.coordenador_id
     AND p.solicitante_state = 'coordenador_em_constituicao'
     AND NOT EXISTS (
       SELECT 1 FROM public.library_constitution_progress o
         JOIN public.libraries ol ON ol.id = o.library_id
        WHERE o.coordenador_id = c.coordenador_id
          AND o.library_id <> p_library_id
          AND o.completed_at IS NULL
          AND NOT ol.is_active);

  -- Traçabilité de la demande : l'appartenance qui en est née.
  UPDATE public.library_requests r
     SET approved_membership_ref = m.id::text
    FROM public.library_constitution_progress c
    JOIN public.user_library_memberships m
      ON m.user_id = c.coordenador_id AND m.library_id = c.library_id
   WHERE c.library_id = p_library_id
     AND r.id = c.request_id
     AND r.approved_membership_ref IS NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_constitution_sortir(uuid) FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_constitution_sortir(uuid) IS
  'Conséquences de l''activation d''une bibliothèque en constitution : la coordination quitte coordenador_em_constituicao, la demande reçoit approved_membership_ref. Privée (21/10/2026).';

-- ── 3. La bascule, commune aux deux portes ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_constitution_activer(p_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_prog public.library_constitution_progress%rowtype;
  v_status text;
  v_library_id uuid;
BEGIN
  SELECT * INTO v_prog FROM public.library_constitution_progress
   WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'constitution_not_found' USING ERRCODE = 'P0002';
  END IF;

  SELECT request_status INTO v_status FROM public.library_requests WHERE id = p_request_id;
  IF v_status IS DISTINCT FROM 'aprovada' THEN
    RAISE EXCEPTION 'Seule une demande approuvée peut être activée.'
      USING ERRCODE = '23514', HINT = 'error.constitution.request_not_approved';
  END IF;

  -- Idempotent : la biblio pré-active existe déjà (provisionnée à l'approbation).
  v_library_id := coalesce(v_prog.library_id, public.fn_provision_preactive_library(p_request_id));

  -- Déjà active : rien à basculer.
  IF (SELECT l.is_active FROM public.libraries l WHERE l.id = v_library_id) THEN
    RETURN v_library_id;
  END IF;

  -- Bascule + axes du volet 0 (la décision du collectif prime). A3 :
  -- accepts_public_signup suit le mode de catalogue, sauf si le volet 6
  -- (adhésion) en a décidé autrement.
  UPDATE public.libraries l SET
    is_active        = true,
    catalog_mode     = coalesce(v_prog.volet_0_catalog_mode,     l.catalog_mode),
    circulation_mode = coalesce(v_prog.volet_0_circulation_mode, l.circulation_mode),
    network_mode     = coalesce(v_prog.volet_0_network_mode,     l.network_mode),
    governance_mode  = coalesce(v_prog.volet_0_governance_mode,  l.governance_mode),
    accepts_public_signup = CASE WHEN v_prog.volet_6_adhesion_done THEN l.accepts_public_signup
                                 ELSE coalesce(v_prog.volet_0_catalog_mode, l.catalog_mode) = 'network_published' END,
    updated_at = now()
  WHERE l.id = v_library_id;

  -- L'appartenance coordenador créée au provisioning : active, et primaire si
  -- la personne n'en a pas d'autre (ux_user_library_memberships_one_primary_active).
  UPDATE public.user_library_memberships m
     SET status = 'active',
         is_primary = NOT EXISTS (
           SELECT 1 FROM public.user_library_memberships o
            WHERE o.user_id = m.user_id AND o.library_id <> v_library_id
              AND o.is_primary AND o.status = 'active'),
         updated_at = now()
   WHERE m.user_id = v_prog.coordenador_id AND m.library_id = v_library_id;

  -- La sortie de constitution est faite par trg_libraries_constitution_activee.
  RETURN v_library_id;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_constitution_activer(uuid) FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION public.fn_constitution_activer(uuid) IS
  'Bascule d''une bibliothèque en constitution : is_active, axes du volet 0, appartenance coordenador. Privée : appelée par api.fn_constitution_complete et api.fn_constitution_activate_early (21/10/2026).';

-- ── 4. Garde-fous sur libraries ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tg_libraries_activation_par_les_portes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.is_active AND NOT coalesce(OLD.is_active, false)
     AND EXISTS (SELECT 1 FROM public.library_constitution_progress c
                  WHERE c.library_id = NEW.id
                    AND c.completed_at IS NULL
                    AND c.early_activated_at IS NULL) THEN
    RAISE EXCEPTION 'Une bibliothèque en constitution s''active par la fin de son atelier, ou par une activation anticipée motivée.'
      USING ERRCODE = '23514', HINT = 'error.constitution.activation_outside_doors';
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.tg_libraries_constitution_activee()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.is_active AND NOT coalesce(OLD.is_active, false) THEN
    PERFORM public.fn_constitution_sortir(NEW.id);
  END IF;
  RETURN NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.tg_libraries_activation_par_les_portes() FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.tg_libraries_constitution_activee() FROM PUBLIC, anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_libraries_activation_par_les_portes ON public.libraries;
CREATE TRIGGER trg_libraries_activation_par_les_portes
  BEFORE UPDATE OF is_active ON public.libraries
  FOR EACH ROW EXECUTE FUNCTION public.tg_libraries_activation_par_les_portes();

DROP TRIGGER IF EXISTS trg_libraries_constitution_activee ON public.libraries;
CREATE TRIGGER trg_libraries_constitution_activee
  AFTER UPDATE OF is_active ON public.libraries
  FOR EACH ROW EXECUTE FUNCTION public.tg_libraries_constitution_activee();

-- ── 5. Porte 1 : la coordination termine l'atelier ──────────────────────────
CREATE OR REPLACE FUNCTION api.fn_constitution_complete(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_prog public.library_constitution_progress%rowtype;
BEGIN
  v_prog := public.fn_constitution_guard(p_request_id);
  IF v_prog.completed_at IS NOT NULL THEN
    RETURN;
  END IF;
  -- Spec §6.4 : le profil fonde, le règlement porté en assemblée active.
  IF NOT v_prog.volet_0_profil_done THEN
    RAISE EXCEPTION 'Le profil d''adoption (volet 0) n''est pas enregistré.'
      USING ERRCODE = '23514', HINT = 'error.constitution.profile_required';
  END IF;
  IF NOT v_prog.volet_10_regimento_done THEN
    RAISE EXCEPTION 'Le règlement (volet 10) n''est pas déposé.'
      USING ERRCODE = '23514', HINT = 'error.constitution.regimento_required';
  END IF;

  -- completed_at AVANT la bascule : le garde-fou de libraries le lit.
  UPDATE public.library_constitution_progress
     SET completed_at = now(), updated_at = now()
   WHERE request_id = p_request_id;

  PERFORM public.fn_constitution_activer(p_request_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_constitution_complete(uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION api.fn_constitution_complete(uuid) TO authenticated;

COMMENT ON FUNCTION api.fn_constitution_complete(uuid) IS
  'Porte 1 : la coordination termine l''atelier (profil + règlement exigés) et la bibliothèque devient active (spec onboarding §6.4). Idempotente. Activation ajoutée le 21/10/2026.';

-- ── 6. Porte 2 : l'administration du réseau active avant la fin ─────────────
CREATE OR REPLACE FUNCTION api.fn_constitution_activate_early(p_request_id uuid, p_reason text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_prog public.library_constitution_progress%rowtype;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Seule l''administration du réseau peut activer une bibliothèque avant la fin de son atelier.'
      USING ERRCODE = '42501', HINT = 'error.constitution.network_admin_only';
  END IF;
  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'Indique pourquoi la bibliothèque est activée avant la fin de son atelier.'
      USING ERRCODE = '23514', HINT = 'error.constitution.reason_required';
  END IF;

  SELECT * INTO v_prog FROM public.library_constitution_progress
   WHERE request_id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'constitution_not_found' USING ERRCODE = 'P0002';
  END IF;
  IF v_prog.completed_at IS NOT NULL OR v_prog.early_activated_at IS NOT NULL THEN
    RAISE EXCEPTION 'Cette bibliothèque a déjà franchi l''une des deux portes.'
      USING ERRCODE = '23514', HINT = 'error.constitution.already_active';
  END IF;

  -- La trace AVANT la bascule : le garde-fou de libraries la lit.
  UPDATE public.library_constitution_progress
     SET early_activated_at = now(), early_activated_by = auth.uid(),
         early_activation_reason = v_reason, updated_at = now()
   WHERE request_id = p_request_id;

  RETURN public.fn_constitution_activer(p_request_id);
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.fn_constitution_activate_early(uuid, text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION api.fn_constitution_activate_early(uuid, text) TO authenticated;

COMMENT ON FUNCTION api.fn_constitution_activate_early(uuid, text) IS
  'Porte 2 : activation par l''administration du réseau avant la fin de l''atelier, motif obligatoire. L''atelier reste ouvert. 21/10/2026.';

-- ── 7. Le volet 0 d'une bibliothèque déjà active s'applique tout de suite ───
CREATE OR REPLACE FUNCTION api.fn_constitution_set_profile(p_request_id uuid, p_catalog text, p_circulation text, p_network text, p_governance text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_prog public.library_constitution_progress%rowtype;
BEGIN
    v_prog := public.fn_constitution_guard(p_request_id);
    IF p_catalog    NOT IN ('local_only','network_published')         THEN RAISE EXCEPTION 'invalid_catalog_mode' USING ERRCODE='22023'; END IF;
    IF p_circulation NOT IN ('off','informal','full_sigb')            THEN RAISE EXCEPTION 'invalid_circulation_mode' USING ERRCODE='22023'; END IF;
    IF p_network    NOT IN ('isolated','observer','federated')        THEN RAISE EXCEPTION 'invalid_network_mode' USING ERRCODE='22023'; END IF;
    IF p_governance NOT IN ('informal','staff_roles','full_governance') THEN RAISE EXCEPTION 'invalid_governance_mode' USING ERRCODE='22023'; END IF;
    UPDATE public.library_constitution_progress
        SET volet_0_catalog_mode = p_catalog, volet_0_circulation_mode = p_circulation,
            volet_0_network_mode = p_network, volet_0_governance_mode = p_governance,
            volet_0_profil_done = true, updated_at = now()
        WHERE request_id = p_request_id;
    -- Bibliothèque activée avant la fin de l'atelier : la bascule ne repassera
    -- pas, le profil voté s'applique donc maintenant (21/10/2026).
    UPDATE public.libraries l
       SET catalog_mode = p_catalog, circulation_mode = p_circulation,
           network_mode = p_network, governance_mode = p_governance, updated_at = now()
     WHERE l.id = v_prog.library_id AND l.is_active;
END;
$function$;

-- ── 8. La vue de la coordination dit si sa bibliothèque est active ──────────
CREATE OR REPLACE VIEW api.my_constitution_progress_v1
WITH (security_invoker = true) AS
 SELECT cp.id,
    cp.request_id,
    cp.coordenador_id,
    cp.started_at,
    cp.deadline_at,
    cp.completed_at,
    cp.volet_0_profil_done,
    cp.volet_0_catalog_mode,
    cp.volet_0_circulation_mode,
    cp.volet_0_network_mode,
    cp.volet_0_governance_mode,
    cp.volet_1_identite_done,
    cp.volet_2_horaires_done,
    cp.volet_3_pessoas_done,
    cp.volet_4_catalogacao_done,
    cp.volet_5_circulacao_done,
    cp.volet_6_adhesion_done,
    cp.volet_7_emails_done,
    cp.volet_8_visibilidade_done,
    cp.volet_9_dados_done,
    cp.volet_10_regimento_done,
    cp.regimento_pdf_url,
    cp.created_at,
    cp.updated_at,
    r.library_name,
    r.request_status,
    cp.library_id,
    l.slug AS library_slug,
    coalesce(l.is_active, false) AS library_is_active,
    cp.early_activated_at
   FROM public.library_constitution_progress cp
     JOIN public.library_requests r ON r.id = cp.request_id
     LEFT JOIN public.libraries l ON l.id = cp.library_id
  WHERE cp.coordenador_id = (( SELECT auth.uid() AS uid));

-- ── 9. Régularisation des ateliers ouverts dont la bibliothèque est active ──
WITH derniere_activation AS (
  SELECT DISTINCT ON (j.library_id) j.library_id, j.created_at, j.actor_user_id
    FROM public.network_admin_cross_library_actions_log j
   WHERE j.action_type = 'update_library'
     AND j.payload -> 'delta' -> 'is_active' ->> 'new' = 'true'
   ORDER BY j.library_id, j.created_at DESC
)
UPDATE public.library_constitution_progress c
   SET early_activated_at = coalesce(d.created_at, now()),
       early_activated_by = (SELECT p.id FROM public.profiles p WHERE p.id = d.actor_user_id),
       early_activation_reason = 'Régularisation du 21/10/2026 : activée depuis la page Réseau avant la fin de l''atelier, à une époque où l''atelier ne pouvait activer personne ; aucun motif n''avait été demandé.',
       updated_at = now()
  FROM public.libraries lib
  LEFT JOIN derniere_activation d ON d.library_id = lib.id
 WHERE lib.id = c.library_id
   AND lib.is_active
   AND c.completed_at IS NULL
   AND c.early_activated_at IS NULL;

DO $regulariser$
DECLARE
  v_lib uuid;
BEGIN
  FOR v_lib IN
    SELECT c.library_id FROM public.library_constitution_progress c
      JOIN public.libraries l ON l.id = c.library_id
     WHERE l.is_active
  LOOP
    PERFORM public.fn_constitution_sortir(v_lib);
  END LOOP;
END $regulariser$;

-- ── 10. Vérification ────────────────────────────────────────────────────────
DO $verifier$
DECLARE
  v_n int;
BEGIN
  SELECT count(*) INTO v_n
    FROM public.profiles p
    JOIN public.library_constitution_progress c ON c.coordenador_id = p.id
    JOIN public.libraries l ON l.id = c.library_id
   WHERE p.solicitante_state = 'coordenador_em_constituicao' AND l.is_active
     AND NOT EXISTS (
       SELECT 1 FROM public.library_constitution_progress o
         JOIN public.libraries ol ON ol.id = o.library_id
        WHERE o.coordenador_id = p.id AND o.completed_at IS NULL AND NOT ol.is_active);
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Encore % coordination(s) en constitution pour une bibliothèque active', v_n;
  END IF;

  SELECT count(*) INTO v_n
    FROM public.library_constitution_progress c JOIN public.libraries l ON l.id = c.library_id
   WHERE l.is_active AND c.completed_at IS NULL AND c.early_activated_at IS NULL;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Encore % bibliothèque(s) active(s) hors des deux portes', v_n;
  END IF;

  IF has_function_privilege('anon', 'api.fn_constitution_complete(uuid)', 'EXECUTE')
     OR has_function_privilege('anon', 'api.fn_constitution_activate_early(uuid,text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_constitution_activer(uuid)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_constitution_sortir(uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Droits d''exécution trop ouverts sur les fonctions de constitution';
  END IF;
  IF NOT has_function_privilege('authenticated', 'api.fn_constitution_activate_early(uuid,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'api.fn_constitution_activate_early doit rester exécutable par authenticated';
  END IF;
END $verifier$;

NOTIFY pgrst, 'reload schema';

COMMIT;
