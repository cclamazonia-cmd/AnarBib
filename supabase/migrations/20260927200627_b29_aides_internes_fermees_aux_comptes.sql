-- ===========================================================================
-- B29 (suite) — cinq aides internes fermées aux comptes connectés.
--
-- Advisor 0029 relevé le 27/09/2026 (get_advisors, lecture seule) : 448, soit
-- +28 depuis le 16/09 — E14 (2), F12 (2), B29 (13), capas (8), B30 (3). Lues
-- une à une : aucune faille (docs/journal/audits/
-- AUDIT_execute_authenticated_2026-09-01.md, complément du 27/09).
--
-- Parmi les treize aides que 20260927160000 (bloc $droits$) ouvre à
-- authenticated, cinq n'ont AUCUN appelant qui s'exécute sous ce rôle :
--
--   public.fn_caller_can_edit_draft_library(uuid, uuid)
--   public.fn_caller_can_edit_exemplar_draft(bigint)
--   public.fn_caller_can_edit_author_draft(bigint)
--   public.fn_caller_can_edit_batch(bigint, boolean)
--   public.fn_caller_can_see_batch(bigint)
--
-- Appelants cherchés AVANT le REVOKE, en production (REGISTRE « avant un
-- REVOKE, chercher les VUES ») : aucune politique (pg_policy), aucune vue
-- (pg_views), aucune dépendance de catalogue (pg_depend : défaut, contrainte,
-- index, règle), aucune fonction INVOKER (prosrc) ; aucun appel du front ni
-- d'une Edge Function (src/, supabase/functions/). Leurs seuls appelants sont
-- des fonctions SECURITY DEFINER, qui les exécutent sous leur propriétaire :
-- publish_book_draft, publish_exemplar_draft, publish_author_draft,
-- publish_catalog_batch, api.merge_book_drafts, fn_restore_deleted_draft,
-- create_book_draft_from_book, create_exemplar_draft_from_exemplar,
-- fn_batch_caller_can_edit, fn_caller_owns_batch, fn_caller_can_edit_book_draft
-- (et entre elles). Les suites SQL les appellent en postgres, jeton simulé.
--
-- Ce n'étaient pas des fuites : elles ne répondent que sur l'appelant et
-- rendent faux pour un identifiant inexistant. On les ferme parce qu'une
-- ouverture doit servir (DOC-GRANT-1, appliquée ici à authenticated) :
-- le lint 0029 passe de 448 à 443.
--
-- Les huit autres aides de B29 restent ouvertes, chacune parce qu'un appelant
-- s'exécute sous authenticated : des politiques RLS (fn_caller_staff_library_ids,
-- fn_caller_coordinator_library_ids, fn_book_draft_creator_library,
-- fn_exemplar_draft_fallback_library, fn_caller_can_edit_book_draft,
-- fn_caller_owns_batch), le front (fn_caller_staff_library_ids,
-- fn_caller_coordinator_library_ids, fn_caller_owns_batch,
-- fn_caller_coordinates_batch), des déclencheurs INVOKER
-- (fn_caller_staff_library). Idem pour les trois de B30 : fn_caller_batch_library
-- et fn_caller_batch_library_sans_attente (déclencheur INVOKER),
-- fn_batch_delete_blockers (front).
--
-- Rien d'autre ne change : ni corps de fonction, ni politique, ni donnée.
-- Garde : le bloc DO final — les deux camps, et l'absence d'appelant sous
-- authenticated revérifiée au moment du déploiement ; en continu,
-- tests/sql/brouillons_par_bibliotheque_tests.sql T31, qui joue aussi les
-- appelants DEFINER sous le rôle authenticated.
-- ===========================================================================

REVOKE EXECUTE ON FUNCTION public.fn_caller_can_edit_draft_library(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_caller_can_edit_draft_library(uuid, uuid) TO service_role;

REVOKE EXECUTE ON FUNCTION public.fn_caller_can_edit_exemplar_draft(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_caller_can_edit_exemplar_draft(bigint) TO service_role;

REVOKE EXECUTE ON FUNCTION public.fn_caller_can_edit_author_draft(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_caller_can_edit_author_draft(bigint) TO service_role;

REVOKE EXECUTE ON FUNCTION public.fn_caller_can_edit_batch(bigint, boolean) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_caller_can_edit_batch(bigint, boolean) TO service_role;

REVOKE EXECUTE ON FUNCTION public.fn_caller_can_see_batch(bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_caller_can_see_batch(bigint) TO service_role;

-- ---------------------------------------------------------------------------
-- Garde des deux camps. Un appelant apparu entre le relevé et le déploiement
-- (politique, vue, défaut, index, fonction INVOKER) ferait échouer la
-- migration au lieu de casser un écran : c'est lui qu'on redoute.
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE
  v_fermees text[] := ARRAY[
    'public.fn_caller_can_edit_draft_library(uuid, uuid)',
    'public.fn_caller_can_edit_exemplar_draft(bigint)',
    'public.fn_caller_can_edit_author_draft(bigint)',
    'public.fn_caller_can_edit_batch(bigint, boolean)',
    'public.fn_caller_can_see_batch(bigint)'
  ];
  v_servies text[] := ARRAY[
    'public.fn_caller_staff_library_ids()',
    'public.fn_caller_coordinator_library_ids()',
    'public.fn_caller_staff_library()',
    'public.fn_book_draft_creator_library(bigint, uuid)',
    'public.fn_exemplar_draft_fallback_library(bigint, bigint, uuid)',
    'public.fn_caller_can_edit_book_draft(bigint)',
    'public.fn_caller_owns_batch(bigint)',
    'public.fn_caller_coordinates_batch(bigint)',
    'public.fn_caller_batch_library(bigint)',
    'public.fn_caller_batch_library_sans_attente(bigint)',
    'public.fn_batch_delete_blockers(bigint)'
  ];
  v_f      text;
  v_oid    oid;
  v_nom    text;
  v_ecarts text := '';
BEGIN
  FOREACH v_f IN ARRAY v_fermees LOOP
    v_oid := v_f::regprocedure;
    SELECT p.proname INTO v_nom FROM pg_proc p WHERE p.oid = v_oid;
    IF has_function_privilege('authenticated', v_oid, 'EXECUTE')
       OR has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' encore-ouverte:' || v_f;
    END IF;
    IF NOT has_function_privilege('service_role', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' service_role-perdu:' || v_f;
    END IF;
    -- Tout objet du catalogue qui dépend d'elle (politique, vue, défaut,
    -- contrainte, index, corps SQL standard), sauf une fonction DEFINER.
    IF EXISTS (SELECT 1 FROM pg_depend d
                WHERE d.refclassid = 'pg_proc'::regclass AND d.refobjid = v_oid
                  AND (d.classid <> 'pg_proc'::regclass
                       OR NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = d.objid))) THEN
      v_ecarts := v_ecarts || ' dependance:' || v_f;
    END IF;
    -- Les expressions de politique et les vues, par leur texte aussi.
    IF EXISTS (SELECT 1 FROM pg_policy pol
                WHERE (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' '
                       || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~ ('\m' || v_nom || '\M')) THEN
      v_ecarts := v_ecarts || ' politique:' || v_f;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_views v
                WHERE v.schemaname NOT IN ('pg_catalog', 'information_schema')
                  AND v.definition ~ ('\m' || v_nom || '\M')) THEN
      v_ecarts := v_ecarts || ' vue:' || v_f;
    END IF;
    -- Un corps PL/pgSQL ou SQL classique n'est pas dans pg_depend : son texte.
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE NOT p.prosecdef AND p.oid <> v_oid
                  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
                  AND p.prosrc ~ ('\m' || v_nom || '\M')) THEN
      v_ecarts := v_ecarts || ' appelant-invoker:' || v_f;
    END IF;
  END LOOP;

  FOREACH v_f IN ARRAY v_servies LOOP
    v_oid := v_f::regprocedure;
    IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' servie-fermee:' || v_f;
    END IF;
    IF has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' ouverte-a-anon:' || v_f;
    END IF;
  END LOOP;

  IF v_ecarts <> '' THEN
    RAISE EXCEPTION 'B29 aides internes : écart(s) —%', v_ecarts;
  END IF;
  RAISE NOTICE 'B29 aides internes : 5 fermées à authenticated, 11 servies ouvertes, aucun appelant sous authenticated.';
END
$garde$;
