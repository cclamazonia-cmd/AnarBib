-- =====================================================================
-- « Préparer la mise à jour » va par pages plus petites (15/10/2026)
-- Session : D17 lien vers la page source (stabiliser le test de durée
--           h21_lot6b T18b)
--
-- Même cas que la promotion le 14/10 (20261013225550) : T18b de
-- tests/sql/h21_lot6b_exemplaires_maj_tests.sql — « Préparer » 200 lignes x 25
-- exemplaires (5 000 brouillons d'exemplaire) — a rougi quatre fois le 15/10
-- (8 011, 10 576, 13 043, 9 941 ms) sous la charge de la machine du runner ;
-- au banc, 4,8 à 6,6 s sous une charge modérée, 10 à 18 s sous une charge
-- soutenue : la marge sous les 8 s de la coupure des appels de l'API est
-- mince. Décision de Xavier (15/10) : comme la promotion, la page de
-- « Préparer » se réduit à 100 lignes et 2 500 exemplaires du fichier ; le
-- seuil, jamais. Le recalcul (fn_import_recomparer) et « Rapprocher » gardent
-- 200 lignes / 5 000 exemplaires.
--
-- Seule public.fn_import_preparer_mises_a_jour change :
--   * 100 lignes au plus (HINT inchangé, error.import.update_page_too_large :
--     il ne sert qu'à elle ; ses libellés disent désormais 100) ;
--   * 2 500 exemplaires du fichier au plus, compte fait ici, avec son HINT
--     error.import.preparation_page_too_many_items — elle n'appelle plus
--     ingest.fn_h21_garde_plafond_exemplaires, que garde le recalcul (5 000,
--     error.import.update_page_too_many_items, inchangés).
-- L'écran découpe par pagesDePreparation (src/lib/importItemUpdates.js).
--
-- Définitions de départ : production (uflwmikiyjfnikiphtcp, lues le
-- 15/10/2026 par pg_get_functiondef, \r ôtés) :
--   public.fn_import_preparer_mises_a_jour       2dc11ce41c62bb094977c22cd967ab47
--   lue, inchangée : ingest.fn_h21_garde_plafond_exemplaires 812bb371012e9466b16a9e028ba808f1
-- Méthode de H33 : chaque ancre doit figurer une fois et une seule, sinon la
-- migration s'arrête. CREATE OR REPLACE garde les droits (DEFINER,
-- search_path, ouverte à authenticated) ; vérifiés à la fin.
-- Garde CI : tests/sql/h21_lot6b_exemplaires_maj_tests.sql (T18, T18b, T18c),
-- tests/sql/h21_lot4_mise_a_jour_tests.sql (borne des lignes).
-- =====================================================================

CREATE OR REPLACE FUNCTION pg_temp.prep_remplacer(p_quoi text, p_def text, p_old text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  IF coalesce(p_old, '') = '' THEN
    RAISE EXCEPTION 'Préparer par pages — % : ancre vide', p_quoi;
  END IF;
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'Préparer par pages — % : ancre trouvée % fois (attendu 1) — relire la définition réelle', p_quoi, v_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

DO $preparer_page$
DECLARE v_def text;
BEGIN
  v_def := replace(pg_get_functiondef('public.fn_import_preparer_mises_a_jour(bigint, bigint[])'::regprocedure), E'\r', '');

  v_def := pg_temp.prep_remplacer('variable', v_def,
$a$  v_ex jsonb;   -- H21 lot 6b : la partie exemplaires
$a$,
$b$  v_ex jsonb;   -- H21 lot 6b : la partie exemplaires
  v_items_demandes bigint;   -- 15/10/2026 : exemplaires du fichier de la page
$b$);

  v_def := pg_temp.prep_remplacer('les lignes', v_def,
$a$  -- Une page : 200 lignes au plus (l'écran envoie des pages de 200 ; le
  -- plafond des appels de l'API est de 8 s).
  IF coalesce(cardinality(p_row_ids), 0) > 200 THEN
    RAISE EXCEPTION 'No maximo 200 linhas por chamada.' USING HINT = 'error.import.update_page_too_large';
  END IF;
$a$,
$b$  -- Une page : 100 lignes au plus depuis le 15/10/2026 (200 avant ; l'écran
  -- découpe par pagesDePreparation). Le plafond des appels de l'API est de
  -- 8 s : 200 lignes x 25 exemplaires prenaient 4,8 à 6,6 s au banc chargé et
  -- ont dépassé 8 s quatre fois sous la charge du runner — la page se réduit,
  -- jamais le seuil (comme la promotion, 14/10).
  IF coalesce(cardinality(p_row_ids), 0) > 100 THEN
    RAISE EXCEPTION 'No maximo 100 linhas por chamada.' USING HINT = 'error.import.update_page_too_large';
  END IF;
$b$);

  v_def := pg_temp.prep_remplacer('les exemplaires', v_def,
$a$  -- H21 lot 6b (revue sceptique du 08/10) : 5 000 exemplaires du fichier au
  -- plus par appel (l'écran découpe), refus dit, avant tout calcul.
  PERFORM ingest.fn_h21_garde_plafond_exemplaires(p_run_id, v_ids);
$a$,
$b$  -- H21 lot 6b (revue sceptique du 08/10), puis 15/10/2026 : 2 500
  -- exemplaires du fichier au plus par appel de PRÉPARATION (l'écran
  -- découpe), refus dit, avant tout calcul. Même compte que
  -- ingest.fn_h21_garde_plafond_exemplaires, qui garde le recalcul à 5 000.
  SELECT coalesce(sum(CASE WHEN jsonb_typeof(sr.normalized_payload->'items') = 'array'
                           THEN jsonb_array_length(sr.normalized_payload->'items') ELSE 0 END), 0)
    INTO v_items_demandes
    FROM ingest.partner_catalog_staging_rows sr
   WHERE sr.run_id = p_run_id
     AND sr.id = ANY (v_ids)
     AND sr.match_status = 'known_record';
  IF v_items_demandes > 2500 THEN
    RAISE EXCEPTION 'No maximo 2500 exemplares do arquivo por chamada de preparacao (%).', v_items_demandes
      USING HINT = 'error.import.preparation_page_too_many_items';
  END IF;
$b$);

  EXECUTE v_def;
END
$preparer_page$;

-- ─── Vérification ─────────────────────────────────────────────────────────────
DO $preparer_page_verif$
DECLARE
  v_f constant text := 'public.fn_import_preparer_mises_a_jour(bigint, bigint[])';
  v_def text := pg_get_functiondef(v_f::regprocedure);
  v_e text := '';
BEGIN
  IF position('> 100 THEN' IN v_def) = 0
     OR position('IF v_items_demandes > 2500 THEN' IN v_def) = 0
     OR position('error.import.preparation_page_too_many_items' IN v_def) = 0
     OR position('error.import.update_page_too_large' IN v_def) = 0 THEN
    v_e := v_e || ' page';
  END IF;
  IF position('> 200 THEN' IN v_def) > 0
     OR position('PERFORM ingest.fn_h21_garde_plafond_exemplaires' IN v_def) > 0 THEN
    v_e := v_e || ' ancienne-page';
  END IF;
  -- le recalcul garde sa page de 5 000 exemplaires
  IF ingest.fn_h21_exemplaires_par_appel() <> 5000
     OR position('PERFORM ingest.fn_h21_garde_plafond_exemplaires' IN pg_get_functiondef('public.fn_import_recomparer(bigint, bigint[])'::regprocedure)) = 0 THEN
    v_e := v_e || ' recalcul';
  END IF;
  IF NOT has_function_privilege('authenticated', v_f, 'EXECUTE') OR has_function_privilege('anon', v_f, 'EXECUTE')
     OR NOT (SELECT p.prosecdef AND coalesce(p.proconfig::text, '') LIKE '%search_path%' FROM pg_proc p WHERE p.oid = v_f::regprocedure) THEN
    v_e := v_e || ' droits';
  END IF;
  IF v_e <> '' THEN
    RAISE EXCEPTION 'Préparer par pages : vérification en échec :%', v_e;
  END IF;
  RAISE NOTICE 'Préparer par pages : 100 lignes / 2 500 exemplaires, vérifications OK';
END
$preparer_page_verif$;
