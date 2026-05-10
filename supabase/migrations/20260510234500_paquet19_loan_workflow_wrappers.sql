-- =====================================================================
-- AnarBib — Paquet 19 : helper fn_check_loan_action + 8 wrappers api.*
-- Date : 2026-05-10
-- Spec : Phase 2 spec-flux-emprunts.md (clore phase 2)
--
-- Cree un helper SQL pour la matrice action x acteur x statut emprunts,
-- puis 8 wrappers api.* SECURITY INVOKER qui valident l'auth, le role
-- et le statut avant d'appeler les fonctions fn_v2_*_emprestimo* DEFINER.
--
-- Pattern (issu de la phase 2 reservations) :
--   1. auth.uid() requis
--   2. Resoudre le contexte (emprestimo + library + user_id)
--   3. Resoudre le role de l'appelant via fn_resolve_caller_role_for_library
--   4. Verifier action autorisee via fn_check_loan_action
--   5. Invoquer la fn_v2_* DEFINER correspondante
--   6. Retour structure pour le frontend
--
-- Avantages :
-- - Centralisation des controles d'acces dans les wrappers api.*
-- - Frontend pourra appeler api.create_loan_at_counter au lieu de
--   fn_v2_create_emprestimo_by_holdings (langage metier)
-- - SECURITY INVOKER => RLS s'applique, pas de bypass
-- =====================================================================

BEGIN;

-- =====================================================================
-- 1. Helper : fn_check_loan_action
-- =====================================================================
-- Retourne true si l'action est autorisee pour le role + statut donnes.
-- Statut peut etre null pour les actions de creation.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_check_loan_action(
  p_action text,
  p_current_status text,
  p_actor_role text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_action text := lower(trim(coalesce(p_action, '')));
  v_status text := lower(trim(coalesce(p_current_status, '')));
  v_role text := lower(trim(coalesce(p_actor_role, '')));
  v_is_library boolean := v_role IN ('librarian', 'coordenador', 'administrador');
  v_is_reader boolean := v_role = 'leitor';
  v_is_system boolean := v_role = 'system';
  v_active_status boolean := v_status IN ('aberto', 'parcialmente_devolvido');
BEGIN
  IF v_action = '' OR v_role = '' THEN
    RETURN false;
  END IF;

  CASE v_action
    -- Creation : pas de statut requis (l'emprunt n'existe pas encore)
    WHEN 'create_loan_at_counter' THEN
      RETURN v_is_library;

    -- Retours et prolongations cote biblio : sur emprunts actifs
    WHEN 'return_total', 'return_partial', 'extend_as_library', 'mark_return_missed' THEN
      RETURN v_is_library AND v_active_status;

    -- Renouvellement par le lecteur : sur ses emprunts actifs
    WHEN 'renew_as_reader' THEN
      RETURN v_is_reader AND v_active_status;

    -- Planning de retour : lecteur OU biblio sur emprunts actifs
    WHEN 'schedule_return', 'clear_return_schedule' THEN
      RETURN (v_is_library OR v_is_reader) AND v_active_status;

    -- Mark missed est aussi declenchable par le system (cron)
    WHEN 'mark_return_missed_by_system' THEN
      RETURN v_is_system AND v_active_status;

    ELSE
      RETURN false;
  END CASE;
END;
$$;

ALTER FUNCTION public.fn_check_loan_action(text, text, text) OWNER TO postgres;

COMMENT ON FUNCTION public.fn_check_loan_action(text, text, text) IS
'Paquet 19 (10/05/2026) : matrice action x acteur x statut pour les emprunts.
Equivalent emprunts du fn_check_workflow_transition pour les reservations.
Helper IMMUTABLE utilise par les wrappers api.* (Phase 2 spec emprunts).
Actions : create_loan_at_counter, return_total, return_partial,
extend_as_library, renew_as_reader, schedule_return, clear_return_schedule,
mark_return_missed, mark_return_missed_by_system.
Statuts : aberto, parcialmente_devolvido (actifs) ou null (creation).
Roles : leitor, librarian, coordenador, administrador, system.';

GRANT EXECUTE ON FUNCTION public.fn_check_loan_action(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_check_loan_action(text, text, text) TO service_role;

-- =====================================================================
-- 2. Helper interne : recuperer le contexte d'un emprunt
-- =====================================================================
-- Resout library_id + user_id (proprio) + status_global a partir d'un id.
-- Utilise par tous les wrappers de retour/extension/renouvellement.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_get_loan_context(p_emprestimo_id bigint)
RETURNS TABLE(library_id uuid, leitor_user_id uuid, status_global text)
LANGUAGE sql
STABLE
AS $$
  SELECT library_id, user_id, status_global
  FROM public.emprestimos_v2
  WHERE id = p_emprestimo_id;
$$;

ALTER FUNCTION public.fn_get_loan_context(bigint) OWNER TO postgres;

COMMENT ON FUNCTION public.fn_get_loan_context(bigint) IS
'Paquet 19 (10/05/2026) : helper de lookup pour resoudre library_id +
user_id (proprio) + status_global a partir d''un emprestimo_id.
Utilise par les wrappers api.* avant validation rôle/action.';

GRANT EXECUTE ON FUNCTION public.fn_get_loan_context(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_loan_context(bigint) TO service_role;

-- =====================================================================
-- 3. Wrapper api.create_loan_at_counter
-- =====================================================================
-- Wrapper de fn_v2_create_emprestimo_by_holdings.
-- Appele par le bibliothecaire depuis /painel pour creer un emprunt.
-- =====================================================================

CREATE OR REPLACE FUNCTION api.create_loan_at_counter(
  p_user_id uuid,
  p_holding_ids bigint[],
  p_due_at date DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS TABLE(ok boolean, emprestimo_id bigint, due_at date, message text)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_library_id uuid;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  -- Resoudre la bibliotheque active du bibliothecaire via my_access
  -- (la fonction DEFINER fn_v2_create_emprestimo_by_holdings le refait
  -- elle-meme, mais on resout ici pour la validation de role).
  SELECT ma.library_id INTO v_library_id
  FROM public.my_access ma
  LIMIT 1;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'Biblioteca ativa nao identificada.' USING ERRCODE = 'P0001';
  END IF;

  -- Resoudre le role + verifier action autorisee
  v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);

  IF NOT public.fn_check_loan_action('create_loan_at_counter', NULL, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada para o seu papel (%).', v_actor_role USING ERRCODE = '42501';
  END IF;

  -- Invoquer la fn DEFINER existante
  RETURN QUERY
  SELECT * FROM public.fn_v2_create_emprestimo_by_holdings(
    p_user_id := p_user_id,
    p_holding_ids := p_holding_ids,
    p_due_at := p_due_at,
    p_notes := p_notes
  );
END;
$$;

ALTER FUNCTION api.create_loan_at_counter(uuid, bigint[], date, text) OWNER TO postgres;

COMMENT ON FUNCTION api.create_loan_at_counter(uuid, bigint[], date, text) IS
'Paquet 19 (10/05/2026) : wrapper de fn_v2_create_emprestimo_by_holdings.
Appele depuis /painel par les bibliothecaires pour creer un emprunt
au comptoir.';

REVOKE ALL ON FUNCTION api.create_loan_at_counter(uuid, bigint[], date, text) FROM anon;
GRANT EXECUTE ON FUNCTION api.create_loan_at_counter(uuid, bigint[], date, text) TO authenticated;

-- =====================================================================
-- 4. Wrapper api.return_loan_total
-- =====================================================================

CREATE OR REPLACE FUNCTION api.return_loan_total(
  p_emprestimo_id bigint,
  p_notes text DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'Emprestimo % nao encontrado.', p_emprestimo_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('return_total', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada (%/%) sobre emprestimo %.', v_actor_role, v_ctx.status_global, p_emprestimo_id USING ERRCODE = '42501';
  END IF;

  RETURN public.fn_v2_return_emprestimo_total(p_emprestimo_id := p_emprestimo_id, p_notes := p_notes);
END;
$$;

ALTER FUNCTION api.return_loan_total(bigint, text) OWNER TO postgres;

COMMENT ON FUNCTION api.return_loan_total(bigint, text) IS
'Paquet 19 (10/05/2026) : wrapper de fn_v2_return_emprestimo_total.
Retour total d''un emprunt par le bibliothecaire.';

REVOKE ALL ON FUNCTION api.return_loan_total(bigint, text) FROM anon;
GRANT EXECUTE ON FUNCTION api.return_loan_total(bigint, text) TO authenticated;

-- =====================================================================
-- 5. Wrapper api.return_loan_partial
-- =====================================================================

CREATE OR REPLACE FUNCTION api.return_loan_partial(
  p_emprestimo_id bigint,
  p_line_nos integer[],
  p_notes text DEFAULT NULL
)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'Pelo menos uma linha deve ser indicada.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'Emprestimo % nao encontrado.', p_emprestimo_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('return_partial', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada (%/%) sobre emprestimo %.', v_actor_role, v_ctx.status_global, p_emprestimo_id USING ERRCODE = '42501';
  END IF;

  RETURN public.fn_v2_return_emprestimo_linhas(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_notes := p_notes
  );
END;
$$;

ALTER FUNCTION api.return_loan_partial(bigint, integer[], text) OWNER TO postgres;

COMMENT ON FUNCTION api.return_loan_partial(bigint, integer[], text) IS
'Paquet 19 (10/05/2026) : wrapper de fn_v2_return_emprestimo_linhas.
Retour partiel (selection de lignes) par le bibliothecaire.';

REVOKE ALL ON FUNCTION api.return_loan_partial(bigint, integer[], text) FROM anon;
GRANT EXECUTE ON FUNCTION api.return_loan_partial(bigint, integer[], text) TO authenticated;

-- =====================================================================
-- 6. Wrapper api.extend_loan_as_library
-- =====================================================================

CREATE OR REPLACE FUNCTION api.extend_loan_as_library(p_emprestimo_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'Emprestimo % nao encontrado.', p_emprestimo_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('extend_as_library', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada (%/%) sobre emprestimo %.', v_actor_role, v_ctx.status_global, p_emprestimo_id USING ERRCODE = '42501';
  END IF;

  RETURN public.fn_v2_extend_emprestimo_once(p_emprestimo_id := p_emprestimo_id);
END;
$$;

ALTER FUNCTION api.extend_loan_as_library(bigint) OWNER TO postgres;

COMMENT ON FUNCTION api.extend_loan_as_library(bigint) IS
'Paquet 19 (10/05/2026) : wrapper de fn_v2_extend_emprestimo_once.
Prolongation d''un emprunt par le bibliothecaire (action Prorrogar).';

REVOKE ALL ON FUNCTION api.extend_loan_as_library(bigint) FROM anon;
GRANT EXECUTE ON FUNCTION api.extend_loan_as_library(bigint) TO authenticated;

-- =====================================================================
-- 7. Wrapper api.renew_my_loan
-- =====================================================================
-- Renouvellement par le lecteur lui-meme. Verifie en plus que l'emprunt
-- appartient bien au lecteur connecte.
-- =====================================================================

CREATE OR REPLACE FUNCTION api.renew_my_loan(p_emprestimo_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'Emprestimo % nao encontrado.', p_emprestimo_id USING ERRCODE = 'P0001';
  END IF;

  -- Verification ownership avant role : un lecteur ne peut renouveler
  -- qu'un emprunt qui lui appartient.
  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'Voce so pode renovar seus proprios emprestimos.' USING ERRCODE = '42501';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('renew_as_reader', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada (%/%) sobre emprestimo %.', v_actor_role, v_ctx.status_global, p_emprestimo_id USING ERRCODE = '42501';
  END IF;

  RETURN public.fn_renew_my_loan(p_emprestimo_id := p_emprestimo_id);
END;
$$;

ALTER FUNCTION api.renew_my_loan(bigint) OWNER TO postgres;

COMMENT ON FUNCTION api.renew_my_loan(bigint) IS
'Paquet 19 (10/05/2026) : wrapper de fn_renew_my_loan.
Renouvellement d''un emprunt par le lecteur lui-meme. Verifie ownership.';

REVOKE ALL ON FUNCTION api.renew_my_loan(bigint) FROM anon;
GRANT EXECUTE ON FUNCTION api.renew_my_loan(bigint) TO authenticated;

-- =====================================================================
-- 8. Wrapper api.schedule_loan_return
-- =====================================================================
-- Lecteur OU biblio planifient un retour. Le lecteur ne peut planifier
-- que ses propres emprunts (ownership check).
-- =====================================================================

CREATE OR REPLACE FUNCTION api.schedule_loan_return(
  p_emprestimo_id bigint,
  p_line_nos integer[],
  p_return_scheduled_for timestamp with time zone
)
RETURNS TABLE(ok boolean, message text, return_scheduled_for timestamp with time zone)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'Pelo menos uma linha deve ser indicada.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'Emprestimo % nao encontrado.', p_emprestimo_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  -- Si lecteur, verifier ownership
  IF v_actor_role = 'leitor' AND v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'Voce so pode agendar a devolucao dos seus proprios emprestimos.' USING ERRCODE = '42501';
  END IF;

  IF NOT public.fn_check_loan_action('schedule_return', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada (%/%) sobre emprestimo %.', v_actor_role, v_ctx.status_global, p_emprestimo_id USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_schedule_emprestimo_return(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_return_scheduled_for := p_return_scheduled_for,
    p_actor_role := v_actor_role
  );
END;
$$;

ALTER FUNCTION api.schedule_loan_return(bigint, integer[], timestamp with time zone) OWNER TO postgres;

COMMENT ON FUNCTION api.schedule_loan_return(bigint, integer[], timestamp with time zone) IS
'Paquet 19 (10/05/2026) : wrapper de fn_v2_schedule_emprestimo_return.
Planification d''un retour, par le lecteur (ses emprunts) ou la biblio.';

REVOKE ALL ON FUNCTION api.schedule_loan_return(bigint, integer[], timestamp with time zone) FROM anon;
GRANT EXECUTE ON FUNCTION api.schedule_loan_return(bigint, integer[], timestamp with time zone) TO authenticated;

-- =====================================================================
-- 9. Wrapper api.clear_loan_return_schedule
-- =====================================================================

CREATE OR REPLACE FUNCTION api.clear_loan_return_schedule(
  p_emprestimo_id bigint,
  p_line_nos integer[]
)
RETURNS TABLE(ok boolean, message text, return_scheduled_for timestamp with time zone)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'Pelo menos uma linha deve ser indicada.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'Emprestimo % nao encontrado.', p_emprestimo_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF v_actor_role = 'leitor' AND v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'Voce so pode cancelar o agendamento dos seus proprios emprestimos.' USING ERRCODE = '42501';
  END IF;

  IF NOT public.fn_check_loan_action('clear_return_schedule', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada (%/%) sobre emprestimo %.', v_actor_role, v_ctx.status_global, p_emprestimo_id USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_clear_emprestimo_return_schedule(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_actor_role := v_actor_role
  );
END;
$$;

ALTER FUNCTION api.clear_loan_return_schedule(bigint, integer[]) OWNER TO postgres;

COMMENT ON FUNCTION api.clear_loan_return_schedule(bigint, integer[]) IS
'Paquet 19 (10/05/2026) : wrapper de fn_v2_clear_emprestimo_return_schedule.
Annulation d''un agendamento de retour.';

REVOKE ALL ON FUNCTION api.clear_loan_return_schedule(bigint, integer[]) FROM anon;
GRANT EXECUTE ON FUNCTION api.clear_loan_return_schedule(bigint, integer[]) TO authenticated;

-- =====================================================================
-- 10. Wrapper api.mark_loan_return_missed
-- =====================================================================
-- Biblio uniquement. Le cron system passe directement par la fn DEFINER
-- avec son propre contexte.
-- =====================================================================

CREATE OR REPLACE FUNCTION api.mark_loan_return_missed(
  p_emprestimo_id bigint,
  p_line_nos integer[]
)
RETURNS TABLE(ok boolean, message text)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, api
AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'Authentification obrigatoria.' USING ERRCODE = '28000';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'Pelo menos uma linha deve ser indicada.' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'Emprestimo % nao encontrado.', p_emprestimo_id USING ERRCODE = 'P0001';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('mark_return_missed', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'Acao nao autorizada (%/%) sobre emprestimo %.', v_actor_role, v_ctx.status_global, p_emprestimo_id USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_mark_emprestimo_return_missed(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_actor_role := v_actor_role
  );
END;
$$;

ALTER FUNCTION api.mark_loan_return_missed(bigint, integer[]) OWNER TO postgres;

COMMENT ON FUNCTION api.mark_loan_return_missed(bigint, integer[]) IS
'Paquet 19 (10/05/2026) : wrapper de fn_v2_mark_emprestimo_return_missed.
Marquer un retour comme non realise par la biblio.';

REVOKE ALL ON FUNCTION api.mark_loan_return_missed(bigint, integer[]) FROM anon;
GRANT EXECUTE ON FUNCTION api.mark_loan_return_missed(bigint, integer[]) TO authenticated;

COMMIT;

-- =====================================================================
-- Tests post-deploiement :
--
-- 1. Helper retourne les bonnes valeurs :
--   SELECT public.fn_check_loan_action('create_loan_at_counter', NULL, 'librarian');  -- true
--   SELECT public.fn_check_loan_action('renew_as_reader', 'aberto', 'leitor');        -- true
--   SELECT public.fn_check_loan_action('return_total', 'encerrado', 'librarian');     -- false (deja cloture)
--   SELECT public.fn_check_loan_action('return_total', 'aberto', 'leitor');           -- false (lecteur ne rend pas)
--
-- 2. Wrappers existent dans le schema api :
--   SELECT proname FROM pg_proc WHERE pronamespace = 'api'::regnamespace
--     AND proname IN ('create_loan_at_counter', 'return_loan_total', 'return_loan_partial',
--                     'extend_loan_as_library', 'renew_my_loan', 'schedule_loan_return',
--                     'clear_loan_return_schedule', 'mark_loan_return_missed');
--   -- 8 lignes attendues
--
-- 3. Test acceptation cote lecteur (anon) -> bloque :
--   Sans auth, l'appel doit echouer avec '28000 Authentification obrigatoria'.
-- =====================================================================
