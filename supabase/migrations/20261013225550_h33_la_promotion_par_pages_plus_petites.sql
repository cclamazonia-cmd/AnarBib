-- =====================================================================
-- H33, suite (14/10/2026) : la promotion va par pages plus petites.
--
-- La note de H33 (clos le 12/10, décision de Xavier) : « réduire la page de
-- promotion si T08 rougit ». T08 a rougi le 13/10 au soir : « Promouvoir »
-- 200 lignes x 25 exemplaires = 8 099 ms pour 8 s, job sql-tests du commit
-- 090e0350, sous la charge d'un second job sur la machine du runner (3,0 s au
-- calme). Les 8 s ne sont pas une marge de banc : c'est la coupure des appels
-- de l'API — le seuil ne se relâche pas, la page se réduit.
--
-- Une page d'appel de PROMOTION porte désormais au plus 100 lignes et 2 500
-- exemplaires du fichier (la moitié), avec ses propres HINT :
--   error.import.promotion_page_too_large, error.import.promotion_page_too_many_items
-- (les messages d'avant annoncent « 200 lignes » et « 5 000 exemplaires » :
-- toujours vrais pour « Rapprocher », « Préparer la mise à jour » et le
-- recalcul, qui ne changent pas — ingest.fn_h21_exemplaires_par_appel()
-- reste à 5 000). L'écran et l'assistant découpent la sélection par
-- pagesDePromotion (src/lib/importItemUpdates.js, mêmes nombres, vérifiés par
-- src/tests/h33-promotion-par-pages.test.js).
--
-- Seule ingest.fn_create_book_drafts_from_import_rows change : sa seule voie
-- d'appel est la promotion (public.fn_import_promote →
-- ingest.fn_bulk_create_book_drafts_from_run → elle ; public.fn_batch_reassign_library
-- ne la cite qu'en commentaire, lu le 14/10).
--
-- Définition de départ : production (uflwmikiyjfnikiphtcp, lue le 14/10/2026
-- par pg_get_functiondef, \r ôtés) :
--   ingest.fn_create_book_drafts_from_import_rows  8325246d7f15c957fc5000033f1f6151
--   lues, inchangées : public.fn_import_promote 765bd7201d6c2b4d0cae97e68d0ade43,
--   ingest.fn_bulk_create_book_drafts_from_run b06ec46b9f6731f59dad3936f1f791d1.
-- Méthode de H33 (20261012123726) : l'ancre remplacée doit figurer une fois
-- et une seule, sinon la migration s'arrête. CREATE OR REPLACE garde les droits
-- (DEFINER, search_path, fermée à l'API) ; vérifiés à la fin.
-- Garde CI : tests/sql/h33_rapprocher_gros_fichier_tests.sql (T08, T09).
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.h33p_remplacer(p_quoi text, p_def text, p_old text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'H33 promotion — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'H33 promotion — % : ancre trouvée % fois (attendu 1) — relire la définition réelle', p_quoi, v_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

DO $h33_promotion_page$
DECLARE v_def text;
BEGIN
  v_def := replace(pg_get_functiondef('ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure), E'\r', '');
  v_def := pg_temp.h33p_remplacer('promotion : la page', v_def,
$a$  -- H33 (12/10/2026) : une page d'appel porte au plus 200 lignes et 5 000
  -- exemplaires du fichier, comme « Préparer la mise à jour » (lot 6b) ;
  -- l'écran et l'assistant découpent la sélection (pagesParExemplaires).
  -- Au-delà, le plafond de 8 s des appels de l'API ne tient plus (au banc :
  -- 1 000 lignes nouvelles, 4 à 5 s pour les seules notices ; x 25
  -- exemplaires, 17,8 s).
  if v_requested_count > 200 then
    raise exception 'No maximo 200 linhas por chamada (%).', v_requested_count
      using hint = 'error.import.page_too_large';
  end if;
  if v_items_demandes > ingest.fn_h21_exemplaires_par_appel() then
    raise exception 'No maximo % exemplares do arquivo por chamada (%).', ingest.fn_h21_exemplaires_par_appel(), v_items_demandes
      using hint = 'error.import.update_page_too_many_items';
  end if;
$a$,
$b$  -- H33 (12/10/2026), puis 14/10 : une page d'appel de PROMOTION porte au
  -- plus 100 lignes et 2 500 exemplaires du fichier ; l'écran et l'assistant
  -- découpent la sélection (pagesDePromotion). Au-delà, le plafond de 8 s des
  -- appels de l'API ne tient plus : 200 lignes x 25 exemplaires = 3,0 s au
  -- calme, mais 8,1 à 9,1 s sous la charge d'un second job (sql-tests du
  -- 13/10) — la page se réduit, jamais le seuil (note de H33). « Rapprocher »
  -- et « Préparer » gardent 200 lignes et 5 000 exemplaires.
  if v_requested_count > 100 then
    raise exception 'No maximo 100 linhas por chamada de promocao (%).', v_requested_count
      using hint = 'error.import.promotion_page_too_large';
  end if;
  if v_items_demandes > 2500 then
    raise exception 'No maximo 2500 exemplares do arquivo por chamada de promocao (%).', v_items_demandes
      using hint = 'error.import.promotion_page_too_many_items';
  end if;
$b$);
  EXECUTE v_def;
END
$h33_promotion_page$;

-- ─── Vérification ─────────────────────────────────────────────────────────────
DO $h33_promotion_verif$
DECLARE
  v_f constant text := 'ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid)';
  v_def text := pg_get_functiondef(v_f::regprocedure);
  v_e text := '';
BEGIN
  IF position('if v_requested_count > 100 then' IN v_def) = 0
     OR position('if v_items_demandes > 2500 then' IN v_def) = 0
     OR position('error.import.promotion_page_too_large' IN v_def) = 0
     OR position('error.import.promotion_page_too_many_items' IN v_def) = 0 THEN
    v_e := v_e || ' page';
  END IF;
  IF position('error.import.page_too_large' IN v_def) > 0
     OR position('error.import.update_page_too_many_items' IN v_def) > 0
     OR position('> 200' IN v_def) > 0 THEN
    v_e := v_e || ' ancienne-page';
  END IF;
  -- « Rapprocher » garde sa page de 200 lignes / 5 000 exemplaires
  IF ingest.fn_h21_exemplaires_par_appel() <> 5000
     OR position('error.import.page_too_large' IN pg_get_functiondef('ingest.fn_create_exemplar_drafts_from_import_rows(bigint, bigint[], text, text, uuid)'::regprocedure)) = 0 THEN
    v_e := v_e || ' rapprocher';
  END IF;
  IF has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
     OR NOT has_function_privilege('service_role', v_f, 'EXECUTE')
     OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
    v_e := v_e || ' droits';
  END IF;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'H33 promotion : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'H33 promotion : page de 100 lignes / 2 500 exemplaires, vérifications OK';
END
$h33_promotion_verif$;
