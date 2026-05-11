-- =====================================================================
-- AnarBib — Phase 2 spec consultations — livrable 1 : wrappers api.*
-- =====================================================================
-- Fichier : supabase/migrations/20260512130000_consulta_workflow_wrappers.sql
-- Date    : 2026-05-12
-- Auteur  : Xavier (AnarBib)
--
-- Pose les 5 wrappers api.* SECURITY INVOKER de la spec §6 :
--   1) api.create_consulta_local
--   2) api.advance_consulta
--   3) api.reply_consulta_schedule
--   4) api.cancel_consulta_as_reader
--   5) api.dismiss_consulta_cancelled
--
-- Architecture (cf. paquet 19 du chantier emprunts) :
--   - SECURITY INVOKER : la verification se fait dans le wrapper, pas
--     dans les fns DEFINER deja en place.
--   - auth.uid() obligatoire (raise '28000' si NULL).
--   - Resolution du role via fn_resolve_caller_role_for_library.
--   - Verification de la transition via fn_check_consulta_transition.
--   - Ownership check explicite pour les actions lecteur.
--   - Retour structure jsonb pour le frontend.
--
-- Hardenings vs. spec §6 :
--   a) Wrapper create : verification cardinality > 0 et premier holding
--      non-NULL avant lookup library_id, sinon raise propre.
--   b) Wrapper advance : check que TOUTES les lignes du p_line_nos[] sont
--      au meme workflow_stage courant. Si heterogene, raise explicite
--      pour eviter qu'une matrice valide pour la 1ere ligne autorise des
--      transitions illegales sur les autres.
--   c) Wrapper advance : timezone-safe pour le creneau. to_char applique
--      AT TIME ZONE de la biblio (lue depuis library_service_state si
--      p_consultation_timezone est NULL) avant l'extraction date/heure
--      locale, evitant le bug de decalage de date a la frontiere UTC.
--   d) Wrapper reply : check workflow_stage = 'consulta_agendada' avant
--      d'appeler la fn DEFINER (la spec §5.3 le precise, ne pas decouvrir
--      l'erreur dans la fn DEFINER).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) api.create_consulta_local
-- ---------------------------------------------------------------------
-- Wrapper autour de fn_v2_create_consulta_local_by_holdings.
-- Acces : lecteur (pour soi-meme) ou staff (pour un lecteur).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.create_consulta_local(
  p_user_id uuid,
  p_holding_ids bigint[],
  p_expires_at timestamptz DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_first_holding_id bigint;
  v_library_id uuid;
  v_actor_role text;
  v_consulta_id bigint;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_user_id manquant' USING ERRCODE = 'P0001';
  END IF;

  -- Hardening (a) : verifier cardinality et premier holding non-NULL
  IF p_holding_ids IS NULL OR cardinality(p_holding_ids) = 0 THEN
    RAISE EXCEPTION 'not_found: nenhum holding informado' USING ERRCODE = 'P0001';
  END IF;

  SELECT h
    INTO v_first_holding_id
  FROM unnest(p_holding_ids) AS h
  WHERE h IS NOT NULL
  LIMIT 1;

  IF v_first_holding_id IS NULL THEN
    RAISE EXCEPTION 'not_found: nenhum holding valido informado' USING ERRCODE = 'P0001';
  END IF;

  -- Si le lecteur cree pour lui-meme : pas de check de role
  -- Si le staff cree pour un autre : verifier role staff sur la biblio du holding
  IF p_user_id <> v_caller_uid THEN
    SELECT library_id
      INTO v_library_id
    FROM public.book_holdings
    WHERE id = v_first_holding_id;

    IF v_library_id IS NULL THEN
      RAISE EXCEPTION 'not_found: holding % nao encontrado', v_first_holding_id
        USING ERRCODE = 'P0001';
    END IF;

    v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);

    IF v_actor_role NOT IN ('librarian', 'coordenador', 'administrador') THEN
      RAISE EXCEPTION 'not_authorized: criacao para outro leitor requer papel de staff'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Delegation a la fn DEFINER qui gere les invariants metier
  -- (holdings, cross_library, duplicates, emprunt/reservation actifs, etc.)
  v_consulta_id := public.fn_v2_create_consulta_local_by_holdings(
    p_user_id, p_holding_ids, p_expires_at, p_notes
  );

  RETURN jsonb_build_object('ok', true, 'consulta_id', v_consulta_id);
END;
$function$;

COMMENT ON FUNCTION api.create_consulta_local(uuid, bigint[], timestamptz, text) IS
'Wrapper api.* SECURITY INVOKER de fn_v2_create_consulta_local_by_holdings (spec §6.1). '
'Acces : lecteur pour soi-meme, staff pour un autre. Retour : jsonb {ok, consulta_id}.';

GRANT EXECUTE ON FUNCTION api.create_consulta_local(uuid, bigint[], timestamptz, text) TO authenticated;


-- ---------------------------------------------------------------------
-- 2) api.advance_consulta
-- ---------------------------------------------------------------------
-- Wrapper unifie staff pour les transitions operationnelles :
--   solicitada -> em_preparacao
--   em_preparacao -> consulta_agendada (avec creneau)
--   consulta_agendada -> consulta_agendada (re-proposition)
--   consulta_agendada -> consulta_realizada
--   consulta_agendada -> consulta_realizada / nao_compareceu
--   * -> cancelada_biblioteca
--   nao_compareceu -> cancelada_biblioteca (reclassement)
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.advance_consulta(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_target_stage text,
  p_workflow_note text DEFAULT NULL,
  p_consultation_scheduled_for timestamptz DEFAULT NULL,
  p_consultation_starts_at timestamptz DEFAULT NULL,
  p_consultation_ends_at timestamptz DEFAULT NULL,
  p_consultation_timezone text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
  v_current_stage text;
  v_heterogeneous_count int;
  v_effective_tz text;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_consulta_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_consulta_id manquant' USING ERRCODE = 'P0001';
  END IF;

  IF p_line_nos IS NULL OR cardinality(p_line_nos) = 0 THEN
    RAISE EXCEPTION 'not_found: p_line_nos vide' USING ERRCODE = 'P0001';
  END IF;

  IF p_target_stage IS NULL OR p_target_stage = '' THEN
    RAISE EXCEPTION 'invalid_stage: p_target_stage manquant' USING ERRCODE = '42501';
  END IF;

  -- Lookup contexte
  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  -- Resolution du role (fix paquet 20 v2 : retourne 'leitor' / 'librarian' /
  -- 'coordenador' / 'administrador' / NULL)
  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  -- Hardening (b) : verifier que toutes les lignes sont au meme stage courant
  -- Recuperer le stage courant a partir de la 1ere ligne
  SELECT workflow_stage
    INTO v_current_stage
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = p_line_nos[1];

  IF v_current_stage IS NULL THEN
    RAISE EXCEPTION 'not_found: linha % da consulta % nao encontrada',
      p_line_nos[1], p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  -- Compter combien de lignes du tableau ont un stage different
  SELECT count(*)
    INTO v_heterogeneous_count
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = ANY(p_line_nos)
    AND workflow_stage IS DISTINCT FROM v_current_stage;

  IF v_heterogeneous_count > 0 THEN
    RAISE EXCEPTION 'invalid_stage: linhas com etapas heterogeneas (esperado %, % linhas diferentes)',
      v_current_stage, v_heterogeneous_count
      USING ERRCODE = '42501';
  END IF;

  -- Verification de la transition via la matrice §5.2
  IF NOT public.fn_check_consulta_transition(v_current_stage, p_target_stage, v_actor_role) THEN
    RAISE EXCEPTION 'invalid_stage: transicao % -> % nao permitida para %',
      v_current_stage, p_target_stage, COALESCE(v_actor_role, '(null)')
      USING ERRCODE = '42501';
  END IF;

  -- Dispatch selon presence de params de creneau
  IF p_target_stage = 'consulta_agendada' AND p_consultation_starts_at IS NOT NULL THEN
    -- Hardening (c) : timezone-safe pour le creneau
    -- Si p_consultation_timezone NULL, fallback sur la timezone de la biblio
    v_effective_tz := COALESCE(
      p_consultation_timezone,
      (SELECT consultation_timezone FROM public.library_service_state
        WHERE library_id = v_ctx.library_id),
      'UTC'
    );

    IF p_consultation_ends_at IS NULL THEN
      RAISE EXCEPTION 'schedule_missing: p_consultation_ends_at obrigatorio com p_consultation_starts_at'
        USING ERRCODE = 'P0001';
    END IF;

    v_updated := public.fn_v2_set_consulta_linhas_workflow_slot(
      p_consulta_id,
      p_line_nos,
      p_target_stage,
      p_workflow_note,
      to_char(p_consultation_starts_at AT TIME ZONE v_effective_tz, 'YYYY-MM-DD'),
      to_char(p_consultation_starts_at AT TIME ZONE v_effective_tz, 'HH24:MI'),
      to_char(p_consultation_ends_at   AT TIME ZONE v_effective_tz, 'HH24:MI'),
      v_effective_tz
    );

  ELSIF p_target_stage = 'consulta_agendada' AND p_consultation_scheduled_for IS NULL THEN
    RAISE EXCEPTION 'schedule_missing: p_consultation_scheduled_for ou p_consultation_starts_at obrigatorio'
      USING ERRCODE = 'P0001';

  ELSE
    -- Toutes les autres transitions (em_preparacao, realizada, nao_compareceu,
    -- cancelada_biblioteca) + agendamento "ponctuel" via scheduled_for
    v_updated := public.fn_v2_set_consulta_linhas_workflow(
      p_consulta_id,
      p_line_nos,
      p_target_stage,
      p_workflow_note,
      p_consultation_scheduled_for
    );
  END IF;

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$function$;

COMMENT ON FUNCTION api.advance_consulta(bigint, integer[], text, text, timestamptz, timestamptz, timestamptz, text) IS
'Wrapper api.* SECURITY INVOKER unifie pour les transitions staff du workflow consultations (spec §6.2). '
'Dispatch selon presence de creneau : fn_v2_set_consulta_linhas_workflow_slot (avec fenetre) ou fn_v2_set_consulta_linhas_workflow (ponctuel). '
'Hardenings : lignes heterogenes rejetees, timezone-safe pour extraction date/heure locale. Retour : jsonb {ok, updated_count}.';

GRANT EXECUTE ON FUNCTION api.advance_consulta(bigint, integer[], text, text, timestamptz, timestamptz, timestamptz, text) TO authenticated;


-- ---------------------------------------------------------------------
-- 3) api.reply_consulta_schedule
-- ---------------------------------------------------------------------
-- Wrapper lecteur pour repondre a une proposition de creneau.
-- Ownership check + check stage courant = 'consulta_agendada'.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.reply_consulta_schedule(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_reply text,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_current_stage text;
  v_heterogeneous_count int;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_consulta_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_consulta_id manquant' USING ERRCODE = 'P0001';
  END IF;

  IF p_line_nos IS NULL OR cardinality(p_line_nos) = 0 THEN
    RAISE EXCEPTION 'not_found: p_line_nos vide' USING ERRCODE = 'P0001';
  END IF;

  IF p_reply NOT IN ('confirmado_leitor', 'recusado_leitor') THEN
    RAISE EXCEPTION 'invalid_stage: reply % invalido (esperado confirmado_leitor ou recusado_leitor)', p_reply
      USING ERRCODE = 'P0001';
  END IF;

  -- Lookup contexte
  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  -- Ownership : seul le proprietaire peut repondre
  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_owner: voce so pode responder sobre suas consultas'
      USING ERRCODE = '42501';
  END IF;

  -- Hardening (d) : verifier que toutes les lignes sont a consulta_agendada
  SELECT workflow_stage
    INTO v_current_stage
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = p_line_nos[1];

  IF v_current_stage IS NULL THEN
    RAISE EXCEPTION 'not_found: linha % nao encontrada', p_line_nos[1]
      USING ERRCODE = 'P0001';
  END IF;

  IF v_current_stage <> 'consulta_agendada' THEN
    RAISE EXCEPTION 'invalid_stage: reposta ao agendamento so e possivel em consulta_agendada (atual: %)',
      v_current_stage
      USING ERRCODE = '42501';
  END IF;

  SELECT count(*)
    INTO v_heterogeneous_count
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = p_consulta_id
    AND line_no = ANY(p_line_nos)
    AND workflow_stage IS DISTINCT FROM 'consulta_agendada';

  IF v_heterogeneous_count > 0 THEN
    RAISE EXCEPTION 'invalid_stage: linhas com etapas heterogeneas (% linhas fora de consulta_agendada)',
      v_heterogeneous_count
      USING ERRCODE = '42501';
  END IF;

  -- Delegation a la fn DEFINER
  v_updated := public.fn_v2_set_consulta_linhas_schedule_reply(
    p_consulta_id, p_line_nos, p_reply, p_note
  );

  RETURN jsonb_build_object('ok', true, 'updated_count', v_updated);
END;
$function$;

COMMENT ON FUNCTION api.reply_consulta_schedule(bigint, integer[], text, text) IS
'Wrapper api.* SECURITY INVOKER pour la reponse du lecteur a un creneau propose (spec §6.3). '
'Ownership check + verification stage courant = consulta_agendada. Retour : jsonb {ok, updated_count}.';

GRANT EXECUTE ON FUNCTION api.reply_consulta_schedule(bigint, integer[], text, text) TO authenticated;


-- ---------------------------------------------------------------------
-- 4) api.cancel_consulta_as_reader
-- ---------------------------------------------------------------------
-- Wrapper lecteur pour annuler ses propres consultations.
-- Ownership check explicite dans le wrapper (en plus de la fn DEFINER).
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.cancel_consulta_as_reader(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_consulta_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_consulta_id manquant' USING ERRCODE = 'P0001';
  END IF;

  IF p_line_nos IS NULL OR cardinality(p_line_nos) = 0 THEN
    RAISE EXCEPTION 'not_found: p_line_nos vide' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  -- Ownership strict : invariant §11.1 #3 (eviter regression bug paquet 20 v2)
  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_owner: voce so pode cancelar suas proprias consultas'
      USING ERRCODE = '42501';
  END IF;

  v_updated := public.fn_v2_cancel_consulta_linhas_as_leitor(
    p_consulta_id, p_line_nos, p_notes
  );

  RETURN jsonb_build_object('ok', true, 'cancelled_count', v_updated);
END;
$function$;

COMMENT ON FUNCTION api.cancel_consulta_as_reader(bigint, integer[], text) IS
'Wrapper api.* SECURITY INVOKER pour l''annulation par le lecteur (spec §6.4). '
'Ownership check explicite. Retour : jsonb {ok, cancelled_count}.';

GRANT EXECUTE ON FUNCTION api.cancel_consulta_as_reader(bigint, integer[], text) TO authenticated;


-- ---------------------------------------------------------------------
-- 5) api.dismiss_consulta_cancelled
-- ---------------------------------------------------------------------
-- Wrapper lecteur pour "fermer" une ligne annulee par la biblio.
-- Pas de changement d'etat metier, juste set dismissed_by_reader_at.
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION api.dismiss_consulta_cancelled(
  p_consulta_id bigint,
  p_line_nos integer[],
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'public', 'api'
AS $function$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_updated int;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated' USING ERRCODE = '28000';
  END IF;

  IF p_consulta_id IS NULL THEN
    RAISE EXCEPTION 'not_found: p_consulta_id manquant' USING ERRCODE = 'P0001';
  END IF;

  IF p_line_nos IS NULL OR cardinality(p_line_nos) = 0 THEN
    RAISE EXCEPTION 'not_found: p_line_nos vide' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_consulta_context(p_consulta_id);
  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'not_found: consulta % nao encontrada', p_consulta_id
      USING ERRCODE = 'P0001';
  END IF;

  -- Ownership strict
  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_owner: voce so pode fechar suas proprias consultas'
      USING ERRCODE = '42501';
  END IF;

  v_updated := public.fn_v2_dismiss_consulta_cancelled_as_leitor(
    p_consulta_id, p_line_nos, p_note
  );

  RETURN jsonb_build_object('ok', true, 'dismissed_count', v_updated);
END;
$function$;

COMMENT ON FUNCTION api.dismiss_consulta_cancelled(bigint, integer[], text) IS
'Wrapper api.* SECURITY INVOKER pour la fermeture (dismiss) par le lecteur d''une ligne annulee par la biblio (spec §6.5). '
'Ownership check. Pas de changement d''etat metier (item_status reste cancelada_biblioteca), juste dismissed_by_reader_at = now(). '
'Retour : jsonb {ok, dismissed_count}.';

GRANT EXECUTE ON FUNCTION api.dismiss_consulta_cancelled(bigint, integer[], text) TO authenticated;


-- =====================================================================
-- Fin migration wrappers consultations.
-- =====================================================================
