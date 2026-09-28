-- ===========================================================================
-- B35 — deux aides de B29 passent dans le schéma `private` : plus de porte RPC.
--
-- fn_book_draft_creator_library(p_draft_id, p_created_by) et
-- fn_exemplar_draft_fallback_library(p_book_draft_id, p_import_staging_row_id,
-- p_created_by) sont SECURITY DEFINER et prennent l'UUID d'un compte
-- arbitraire : appelées par `/rest/v1/rpc/…`, elles rendaient la bibliothèque
-- de staff de n'importe qui — l'oracle que B29 (20260927160000) avait fermé en
-- révoquant fn_user_staff_library. Elles restaient ouvertes à authenticated
-- parce que quatre politiques de book_drafts et exemplar_drafts et deux
-- déclencheurs INVOKER les évaluent sous ce rôle (complément d'audit 0029 du
-- 27/09, « La forme à noter » ; backlog B35).
--
-- PostgREST n'expose que public, graphql_public, api et ingest (vérifié le
-- 28/09 : PGRST106 sur `private`). Dans `private`, EXECUTE reste accordé à
-- authenticated pour les politiques et les déclencheurs, mais il n'y a plus de
-- porte pour l'appeler soi-même — le patron de private.fn_book_work_id (B22).
-- Aucun corps ne change, aucune politique ne change de sens.
--
-- Comment : les deux fonctions sont recréées dans `private` à partir de leur
-- définition RÉELLE (pg_get_functiondef, jamais un corps recopié) ; les quinze
-- fonctions qui les appellent (toutes par `public.fn_…(`, aucune citation nue —
-- relevé du 28/09) sont re-pointées de la même façon ; les quatre politiques
-- par ALTER POLICY sur leur expression réelle ; puis les versions `public` sont
-- supprimées. Un DROP qui échouerait sur une dépendance restante est le premier
-- garde-fou ; le bloc DO final, qui refuse tout appelant resté sur `public`,
-- le second — car un corps PL/pgSQL n'est pas dans pg_depend. Rejouable : si
-- `public` n'a plus la fonction et que `private` l'a, chaque étape passe.
-- ===========================================================================

DO $b35_deplacement$
DECLARE
  v_cibles text[] := ARRAY['fn_book_draft_creator_library', 'fn_exemplar_draft_fallback_library'];
  v_motif  text   := '(^|[^.[:alnum:]_])(public\.)?(fn_book_draft_creator_library|fn_exemplar_draft_fallback_library)\(';
  v_nm  text;
  v_oid oid;
  v_def text;
  v_q   text;
  v_wc  text;
  v_sql text;
  v_n   int := 0;
  r     record;
BEGIN
  -- 1. Les deux aides, recréées dans private depuis leur définition réelle.
  FOREACH v_nm IN ARRAY v_cibles LOOP
    SELECT p.oid INTO v_oid
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_nm;
    IF v_oid IS NULL THEN
      IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                      WHERE n.nspname = 'private' AND p.proname = v_nm) THEN
        RAISE EXCEPTION 'B35 : % introuvable, ni dans public ni dans private', v_nm;
      END IF;
      CONTINUE;  -- déjà déplacée (rejeu)
    END IF;
    v_def := pg_get_functiondef(v_oid);
    IF v_def !~ ('^CREATE OR REPLACE FUNCTION public\.' || v_nm || '\(') THEN
      RAISE EXCEPTION 'B35 : en-tête inattendu pour % : %', v_nm, left(v_def, 90);
    END IF;
    EXECUTE regexp_replace(v_def, '^CREATE OR REPLACE FUNCTION public\.', 'CREATE OR REPLACE FUNCTION private.');
  END LOOP;

  -- 2. Les appelants : chaque `public.fn_…(` (ou un appel nu, s'il en naissait
  --    un) devient `private.fn_…(`, sur la définition réelle de l'appelant.
  FOR r IN
    SELECT p.oid, n.nspname, p.proname
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public', 'api', 'private', 'ingest')
       AND NOT (p.proname = ANY (v_cibles))
       AND p.prosrc ~ v_motif
     ORDER BY n.nspname, p.proname
  LOOP
    v_def := regexp_replace(pg_get_functiondef(r.oid), v_motif, '\1private.\3(', 'g');
    EXECUTE v_def;
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'B35 : % fonction(s) re-pointée(s) vers private', v_n;

  -- 3. Les politiques, sur leur expression réelle.
  FOR r IN
    SELECT pol.polname, pol.polrelid,
           pg_get_expr(pol.polqual, pol.polrelid)      AS q,
           pg_get_expr(pol.polwithcheck, pol.polrelid) AS wc
      FROM pg_policy pol
     WHERE coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' '
           || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~ v_motif
     ORDER BY pol.polrelid, pol.polname
  LOOP
    v_q  := regexp_replace(r.q,  v_motif, '\1private.\3(', 'g');
    v_wc := regexp_replace(r.wc, v_motif, '\1private.\3(', 'g');
    v_sql := format('ALTER POLICY %I ON %s', r.polname, r.polrelid::regclass)
          || CASE WHEN v_q  IS NULL THEN '' ELSE format(' USING (%s)', v_q) END
          || CASE WHEN v_wc IS NULL THEN '' ELSE format(' WITH CHECK (%s)', v_wc) END;
    EXECUTE v_sql;
  END LOOP;

  -- 4. Les versions public disparaissent — sans CASCADE : une dépendance
  --    restante (politique, vue) doit faire échouer la migration, pas tomber.
  FOREACH v_nm IN ARRAY v_cibles LOOP
    SELECT p.oid INTO v_oid
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = v_nm;
    IF v_oid IS NOT NULL THEN
      EXECUTE format('DROP FUNCTION public.%I(%s)', v_nm, pg_get_function_identity_arguments(v_oid));
    END IF;
  END LOOP;
END
$b35_deplacement$;

-- Droits dans private : le défaut natif y ouvre à PUBLIC (aucun ALTER DEFAULT
-- PRIVILEGES sur ce schéma) — on ferme, puis on écrit ce qui sert : les
-- politiques et les déclencheurs s'évaluent sous authenticated.
REVOKE EXECUTE ON FUNCTION private.fn_book_draft_creator_library(bigint, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION private.fn_book_draft_creator_library(bigint, uuid) TO authenticated, service_role;
REVOKE EXECUTE ON FUNCTION private.fn_exemplar_draft_fallback_library(bigint, bigint, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION private.fn_exemplar_draft_fallback_library(bigint, bigint, uuid) TO authenticated, service_role;

COMMENT ON FUNCTION private.fn_book_draft_creator_library(bigint, uuid) IS
  'B29 : bibliothèque de staff du créateur d''un brouillon sans owner (aucune pour un import ou un compte d''administration). B35 : dans private — hors API, aucune porte RPC ; EXECUTE authenticated pour les politiques de book_drafts et les déclencheurs.';
COMMENT ON FUNCTION private.fn_exemplar_draft_fallback_library(bigint, bigint, uuid) IS
  'B29 : bibliothèque résolue d''un brouillon d''exemplaire sans cible (notice, sinon créateur ; aucune pour un rapprochement ou un compte d''administration). B35 : dans private — hors API, aucune porte RPC ; EXECUTE authenticated pour les politiques d''exemplar_drafts et les déclencheurs.';

-- ---------------------------------------------------------------------------
-- Garde : les deux camps, et plus aucun chemin vers `public`.
-- ---------------------------------------------------------------------------
DO $b35_garde$
DECLARE
  v_cibles  text[] := ARRAY['fn_book_draft_creator_library', 'fn_exemplar_draft_fallback_library'];
  v_motif   text   := '(^|[^.[:alnum:]_])(public\.)?(fn_book_draft_creator_library|fn_exemplar_draft_fallback_library)\(';
  -- Les quinze appelants relevés le 28/09 : chacun doit désormais viser private.
  v_appelants text[] := ARRAY[
    'api.suggest_draft_duplicates', 'public.fn_audit_draft_deletion', 'public.fn_b30_lot_bibliotheque_initiale',
    'public.fn_batch_apply_rubric_classes', 'public.fn_batch_assign_bib_refs', 'public.fn_batch_live_drafts',
    'public.fn_batch_reassign_library', 'public.fn_batch_review_report', 'public.fn_batch_rubrics',
    'public.fn_book_draft_library', 'public.fn_caller_can_edit_book_draft', 'public.fn_caller_can_edit_exemplar_draft',
    'public.publish_exemplar_draft', 'public.tg_drafts_batch_guarded', 'public.tg_drafts_library_fixed'
  ];
  v_politiques text[] := ARRAY[
    'book_drafts_catalogacao_librarian_all', 'book_drafts_suppression_definitive_coordination',
    'exemplar_drafts_catalogacao_librarian_all', 'exemplar_drafts_suppression_definitive_coordination'
  ];
  v_nm text; v_f text; v_ecarts text := ''; v_n int; v_oid oid;
BEGIN
  FOREACH v_nm IN ARRAY v_cibles LOOP
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE n.nspname = 'public' AND p.proname = v_nm) THEN
      v_ecarts := v_ecarts || ' encore-dans-public:' || v_nm;
    END IF;
    SELECT p.oid INTO v_oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'private' AND p.proname = v_nm;
    IF v_oid IS NULL THEN
      v_ecarts := v_ecarts || ' absente-de-private:' || v_nm;
      CONTINUE;
    END IF;
    IF NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = v_oid)
       OR NOT EXISTS (SELECT 1 FROM pg_proc p, unnest(p.proconfig) c WHERE p.oid = v_oid AND c LIKE 'search_path=%') THEN
      v_ecarts := v_ecarts || ' definition-alteree:' || v_nm;
    END IF;
    IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN v_ecarts := v_ecarts || ' authenticated-sans-execute:' || v_nm; END IF;
    IF NOT has_function_privilege('service_role', v_oid, 'EXECUTE') THEN v_ecarts := v_ecarts || ' service_role-sans-execute:' || v_nm; END IF;
    IF has_function_privilege('anon', v_oid, 'EXECUTE') THEN v_ecarts := v_ecarts || ' ouverte-a-anon:' || v_nm; END IF;
    IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a WHERE p.oid = v_oid AND a.grantee = 0) THEN
      v_ecarts := v_ecarts || ' ouverte-a-PUBLIC:' || v_nm;
    END IF;
  END LOOP;

  -- Plus un seul appelant vers public (ni appel nu), dans les quatre schémas.
  SELECT string_agg(n.nspname || '.' || p.proname, ',') INTO v_f
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname IN ('public', 'api', 'private', 'ingest')
     AND NOT (p.proname = ANY (v_cibles)) AND p.prosrc ~ v_motif;
  IF v_f IS NOT NULL THEN v_ecarts := v_ecarts || ' appelants-vers-public:' || v_f; END IF;

  -- Les quinze appelants connus visent private.
  FOREACH v_f IN ARRAY v_appelants LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                    WHERE n.nspname = split_part(v_f, '.', 1) AND p.proname = split_part(v_f, '.', 2)
                      AND p.prosrc ~ 'private\.(fn_book_draft_creator_library|fn_exemplar_draft_fallback_library)\(') THEN
      v_ecarts := v_ecarts || ' appelant-non-repointe:' || v_f;
    END IF;
  END LOOP;

  -- Les quatre politiques visent private, et aucune autre ne cite ces noms.
  FOREACH v_f IN ARRAY v_politiques LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_policy pol WHERE pol.polname = v_f
                     AND coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')
                         ~ 'private\.(fn_book_draft_creator_library|fn_exemplar_draft_fallback_library)\(') THEN
      v_ecarts := v_ecarts || ' politique-non-repointee:' || v_f;
    END IF;
  END LOOP;
  SELECT count(*) INTO v_n FROM pg_policy pol
   WHERE coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' ' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '') ~ v_motif;
  IF v_n > 0 THEN v_ecarts := v_ecarts || ' politiques-vers-public:' || v_n; END IF;

  -- Aucune vue ne les cite (aucune au relevé ; une vue security_invoker
  -- exigerait le privilège sous le rôle du lecteur).
  SELECT string_agg(v.schemaname || '.' || v.viewname, ',') INTO v_f
    FROM pg_views v WHERE v.schemaname IN ('public', 'api', 'private', 'ingest') AND v.definition ~ v_motif;
  IF v_f IS NOT NULL THEN v_ecarts := v_ecarts || ' vues-vers-public:' || v_f; END IF;

  IF v_ecarts <> '' THEN
    RAISE EXCEPTION 'B35 : écart(s) —%', v_ecarts;
  END IF;
  RAISE NOTICE 'B35 : deux aides dans private (authenticated, service_role), 15 appelants et 4 politiques re-pointés, public vide.';
END
$b35_garde$;
