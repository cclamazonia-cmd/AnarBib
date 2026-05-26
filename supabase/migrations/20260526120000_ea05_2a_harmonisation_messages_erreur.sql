-- ============================================================================
-- Migration : EA-05 Paquet 2a — harmonisation des messages d'erreur (api.*)
-- Chantier  : A — Lisibilite immediate (audit Painel)
-- ============================================================================
--
-- OBJET
-- -----
-- Les 8 fonctions de circulation ci-dessous levaient des RAISE EXCEPTION avec
-- une PHRASE (portugais) comme message principal. Le frontend ne pouvait pas
-- les traduire : la personne au comptoir voyait un texte technique brut.
--
-- Cette migration substitue, dans les 31 RAISE concernes, un CODE stable
-- (snake_case) au message ; la phrase d'origine est conservee dans le HINT
-- (visible en console pour le diagnostic, jamais affichee a l'usager).
-- Le frontend (Paquet 3) traduira ces codes via i18n.
--
-- Codes introduits : loan_not_found, loan_action_not_allowed, line_required,
-- not_your_loan, library_not_identified. Plus reutilisation de auth_required
-- (code deja present ailleurs dans le schema api).
--
-- PERIMETRE STRICT
-- ----------------
-- SEULES les 31 lignes RAISE sont modifiees. Aucune autre ligne du corps des
-- fonctions ne change. Le champ ERRCODE (SQLSTATE) de chaque RAISE est
-- conserve a l'identique. Signature, LANGUAGE, SET search_path, OWNER :
-- inchanges.
--
-- DOCTRINE
-- --------
-- - Les 8 fonctions sont SECURITY INVOKER : CREATE OR REPLACE preserve leurs
--   GRANT/REVOKE existants, aucun bloc de permissions a reposer. Le hook
--   pre-commit ne se declenche pas (pas de SECURITY DEFINER dans ce fichier).
-- - fn_clear_my_signup_metadata_field (seule fonction SECURITY DEFINER de la
--   famille C) est traitee separement en migration 2b.
-- - Migration appliquee par Woodpecker (supabase db push --linked).
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1/8 — api.clear_loan_return_schedule
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."clear_loan_return_schedule"("p_emprestimo_id" bigint, "p_line_nos" integer[]) RETURNS TABLE("ok" boolean, "message" "text", "return_scheduled_for" timestamp with time zone)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'line_required' USING ERRCODE = 'P0001', HINT = 'Pelo menos uma linha deve ser indicada.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF v_actor_role = 'leitor' AND v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_your_loan' USING ERRCODE = '42501', HINT = 'Voce so pode cancelar o agendamento dos seus proprios emprestimos.';
  END IF;

  IF NOT public.fn_check_loan_action('clear_return_schedule', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_clear_emprestimo_return_schedule(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_actor_role := v_actor_role
  );
END;
$$;


ALTER FUNCTION "api"."clear_loan_return_schedule"("p_emprestimo_id" bigint, "p_line_nos" integer[]) OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- 2/8 — api.create_loan_at_counter
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."create_loan_at_counter"("p_user_id" "uuid", "p_holding_ids" bigint[], "p_due_at" "date" DEFAULT NULL::"date", "p_notes" "text" DEFAULT NULL::"text") RETURNS TABLE("ok" boolean, "emprestimo_id" bigint, "due_at" "date", "message" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_library_id uuid;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  -- Resoudre la bibliotheque active du bibliothecaire via my_access
  -- (la fonction DEFINER fn_v2_create_emprestimo_by_holdings le refait
  -- elle-meme, mais on resout ici pour la validation de role).
  SELECT ma.library_id INTO v_library_id
  FROM public.my_access ma
  LIMIT 1;

  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'library_not_identified' USING ERRCODE = 'P0001', HINT = 'Biblioteca ativa nao identificada.';
  END IF;

  -- Resoudre le role + verifier action autorisee
  v_actor_role := public.fn_resolve_caller_role_for_library(v_library_id);

  IF NOT public.fn_check_loan_action('create_loan_at_counter', NULL, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada para o seu papel (%s).', v_actor_role);
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


ALTER FUNCTION "api"."create_loan_at_counter"("p_user_id" "uuid", "p_holding_ids" bigint[], "p_due_at" "date", "p_notes" "text") OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- 3/8 — api.extend_loan_as_library
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."extend_loan_as_library"("p_emprestimo_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('extend_as_library', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN public.fn_v2_extend_emprestimo_once(p_emprestimo_id := p_emprestimo_id);
END;
$$;


ALTER FUNCTION "api"."extend_loan_as_library"("p_emprestimo_id" bigint) OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- 4/8 — api.mark_loan_return_missed
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."mark_loan_return_missed"("p_emprestimo_id" bigint, "p_line_nos" integer[]) RETURNS TABLE("ok" boolean, "message" "text")
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'line_required' USING ERRCODE = 'P0001', HINT = 'Pelo menos uma linha deve ser indicada.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('mark_return_missed', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN QUERY
  SELECT * FROM public.fn_v2_mark_emprestimo_return_missed(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_actor_role := v_actor_role
  );
END;
$$;


ALTER FUNCTION "api"."mark_loan_return_missed"("p_emprestimo_id" bigint, "p_line_nos" integer[]) OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- 5/8 — api.renew_my_loan
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."renew_my_loan"("p_emprestimo_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  -- Verification ownership avant role : un lecteur ne peut renouveler
  -- qu'un emprunt qui lui appartient.
  IF v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_your_loan' USING ERRCODE = '42501', HINT = 'Voce so pode renovar seus proprios emprestimos.';
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('renew_as_reader', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN public.fn_renew_my_loan(p_emprestimo_id := p_emprestimo_id);
END;
$$;


ALTER FUNCTION "api"."renew_my_loan"("p_emprestimo_id" bigint) OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- 6/8 — api.return_loan_partial
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."return_loan_partial"("p_emprestimo_id" bigint, "p_line_nos" integer[], "p_notes" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'line_required' USING ERRCODE = 'P0001', HINT = 'Pelo menos uma linha deve ser indicada.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('return_partial', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN public.fn_v2_return_emprestimo_linhas(
    p_emprestimo_id := p_emprestimo_id,
    p_line_nos := p_line_nos,
    p_notes := p_notes
  );
END;
$$;


ALTER FUNCTION "api"."return_loan_partial"("p_emprestimo_id" bigint, "p_line_nos" integer[], "p_notes" "text") OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- 7/8 — api.return_loan_total
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."return_loan_total"("p_emprestimo_id" bigint, "p_notes" "text" DEFAULT NULL::"text") RETURNS integer
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  IF NOT public.fn_check_loan_action('return_total', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
  END IF;

  RETURN public.fn_v2_return_emprestimo_total(p_emprestimo_id := p_emprestimo_id, p_notes := p_notes);
END;
$$;


ALTER FUNCTION "api"."return_loan_total"("p_emprestimo_id" bigint, "p_notes" "text") OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- 8/8 — api.schedule_loan_return
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION "api"."schedule_loan_return"("p_emprestimo_id" bigint, "p_line_nos" integer[], "p_return_scheduled_for" timestamp with time zone) RETURNS TABLE("ok" boolean, "message" "text", "return_scheduled_for" timestamp with time zone)
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public', 'api'
    AS $$
DECLARE
  v_caller_uid uuid := auth.uid();
  v_ctx record;
  v_actor_role text;
BEGIN
  IF v_caller_uid IS NULL THEN
    RAISE EXCEPTION 'auth_required' USING ERRCODE = '28000', HINT = 'Authentification obrigatoria.';
  END IF;

  IF p_line_nos IS NULL OR array_length(p_line_nos, 1) = 0 THEN
    RAISE EXCEPTION 'line_required' USING ERRCODE = 'P0001', HINT = 'Pelo menos uma linha deve ser indicada.';
  END IF;

  SELECT * INTO v_ctx FROM public.fn_get_loan_context(p_emprestimo_id);

  IF v_ctx.library_id IS NULL THEN
    RAISE EXCEPTION 'loan_not_found' USING ERRCODE = 'P0001', HINT = format('Emprestimo %s nao encontrado.', p_emprestimo_id);
  END IF;

  v_actor_role := public.fn_resolve_caller_role_for_library(v_ctx.library_id);

  -- Si lecteur, verifier ownership
  IF v_actor_role = 'leitor' AND v_ctx.leitor_user_id <> v_caller_uid THEN
    RAISE EXCEPTION 'not_your_loan' USING ERRCODE = '42501', HINT = 'Voce so pode agendar a devolucao dos seus proprios emprestimos.';
  END IF;

  IF NOT public.fn_check_loan_action('schedule_return', v_ctx.status_global, v_actor_role) THEN
    RAISE EXCEPTION 'loan_action_not_allowed' USING ERRCODE = '42501', HINT = format('Acao nao autorizada (%s/%s) sobre emprestimo %s.', v_actor_role, v_ctx.status_global, p_emprestimo_id);
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


ALTER FUNCTION "api"."schedule_loan_return"("p_emprestimo_id" bigint, "p_line_nos" integer[], "p_return_scheduled_for" timestamp with time zone) OWNER TO "postgres";

-- ----------------------------------------------------------------------------
-- Verification statique en fin de transaction (rollback automatique si echec)
-- ----------------------------------------------------------------------------
-- Interroge pg_get_functiondef() — le code source des fonctions tel
-- qu'enregistre apres le CREATE OR REPLACE ci-dessus — et confirme, pour
-- chacune des 8 fonctions :
--   (a) le code attendu est present dans la definition ;
--   (b) aucune phrase portugaise ne subsiste en position de message de RAISE
--       (les phrases ne doivent apparaitre QUE dans un HINT).
-- Aucun appel runtime : pas de dependance au contexte, pas d'effet de bord.
-- Toute anomalie => RAISE EXCEPTION => rollback de toute la transaction.
DO $verif$
DECLARE
  v_def text;
  v_fn text;
  -- les 8 fonctions et un code qui doit imperativement figurer dans chacune
  v_checks text[][] := ARRAY[
    ['clear_loan_return_schedule', 'not_your_loan'],
    ['create_loan_at_counter',     'library_not_identified'],
    ['extend_loan_as_library',     'loan_not_found'],
    ['mark_loan_return_missed',    'loan_action_not_allowed'],
    ['renew_my_loan',              'not_your_loan'],
    ['return_loan_partial',        'loan_not_found'],
    ['return_loan_total',          'loan_not_found'],
    ['schedule_loan_return',       'not_your_loan']
  ];
  -- motifs interdits : une phrase portugaise immediatement apres RAISE EXCEPTION '
  v_forbidden text[] := ARRAY[
    'RAISE EXCEPTION ''Authentification obrigatoria',
    'RAISE EXCEPTION ''Emprestimo % nao encontrado',
    'RAISE EXCEPTION ''Pelo menos uma linha',
    'RAISE EXCEPTION ''Voce so pode',
    'RAISE EXCEPTION ''Acao nao autorizada',
    'RAISE EXCEPTION ''Biblioteca ativa nao identificada'
  ];
  v_pat text;
  i int;
BEGIN
  FOR i IN 1 .. array_length(v_checks, 1) LOOP
    v_fn := v_checks[i][1];
    v_def := pg_get_functiondef(('api.' || v_fn)::regprocedure);

    -- (a) le code attendu doit etre present
    IF position(v_checks[i][2] IN v_def) = 0 THEN
      RAISE EXCEPTION 'Verification echouee : api.% ne contient pas le code attendu %',
        v_fn, v_checks[i][2];
    END IF;

    -- (b) aucune phrase portugaise en position de message
    FOREACH v_pat IN ARRAY v_forbidden LOOP
      IF position(v_pat IN v_def) > 0 THEN
        RAISE EXCEPTION 'Verification echouee : api.% contient encore une phrase en message de RAISE (%)',
          v_fn, v_pat;
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Verification OK : les 8 fonctions sont harmonisees (codes presents, aucune phrase residuelle).';
END;
$verif$;

COMMIT;
