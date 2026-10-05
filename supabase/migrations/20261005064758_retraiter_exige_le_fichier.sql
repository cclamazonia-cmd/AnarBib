-- =====================================================================
-- H30 — « Retraiter » exige le fichier (04/10/2026)
--
-- Constat (revue du lot 0 de H21, prouvé au banc le 01/10) : « Retraiter »
-- (fn_import_dispatch, force_reparse) était accepté pour un run dont le
-- fichier n'est pas dans le stockage — moisson OAI (oai/…), candidat
-- institutionnel (lookup/…), dépôt direct de fonds (direct/…), dont le
-- chemin est une convention que rien ne lit (migration 20260828190000), ou
-- fichier disparu du seau. L'edge function effaçait alors toutes les lignes
-- du run, puis échouait au téléchargement : run « échoué », 0 ligne, fichiers
-- reçus d'un dépôt direct sans leur ligne. Mesuré en production le 04/10 :
-- 4 runs sur 8 sans fichier (des essais, déjà promus, donc déjà refusés).
--
-- Correctif : refus TOUT DE SUITE, à l'écran (HINT traduite
-- error.import.reparse_no_file), quand l'objet du run n'est pas dans
-- storage.objects (seau du run, sinon celui que les deux edge functions
-- prennent par défaut). Les edge functions, elles, lisent désormais le
-- fichier AVANT d'effacer quoi que ce soit (même commit).
--
-- Méthode : substitution comptée sur la définition vivante (lot 0 de H21,
-- 20261001200931, relue en production le 04/10).
-- =====================================================================

CREATE FUNCTION pg_temp.h30_remplacer(p_quoi text, p_def text, p_old text, p_new text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_n int;
BEGIN
  v_n := (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'H30 — % : ancre trouvée % fois (attendu 1) — relire la définition réelle', p_quoi, v_n;
  END IF;
  RETURN replace(p_def, p_old, p_new);
END
$f$;

DO $h30_dispatch$
DECLARE v_def text;
BEGIN
  v_def := pg_get_functiondef('public.fn_import_dispatch(bigint, boolean)'::regprocedure);
  v_def := pg_temp.h30_remplacer('fn_import_dispatch (fichier)', v_def,
$a$  -- H19 (27/09) : le profil posé sur le run a été supprimé depuis$a$,
$b$  -- H30 (04/10/2026) : retraiter, c'est relire le FICHIER. Sans lui (moisson
  -- OAI, candidat, dépôt direct : chemin de convention ; ou fichier disparu
  -- du seau), l'edge function effacerait les lignes puis échouerait.
  IF coalesce(p_force_reparse, false)
     AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs r
                       JOIN storage.objects o
                         ON o.bucket_id = coalesce(nullif(btrim(r.bucket_id), ''), 'catalogos_parceiros_raw')
                        AND o.name = btrim(r.storage_path)
                      WHERE r.id = p_run_id) THEN
    RAISE EXCEPTION 'Run % sem arquivo a reler.', p_run_id
      USING HINT = 'error.import.reparse_no_file';
  END IF;

  -- H19 (27/09) : le profil posé sur le run a été supprimé depuis$b$);
  EXECUTE v_def;
END
$h30_dispatch$;

DO $h30_verif$
DECLARE v_def text := pg_get_functiondef('public.fn_import_dispatch(bigint, boolean)'::regprocedure);
BEGIN
  IF position('error.import.reparse_no_file' IN v_def) = 0
     OR position('error.import.reparse_after_promotion' IN v_def) = 0
     OR position('e.discarded_draft_id IS NOT NULL' IN v_def) = 0
     OR position('error.import.profile_missing' IN v_def) = 0
     OR NOT has_function_privilege('authenticated', 'public.fn_import_dispatch(bigint, boolean)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.fn_import_dispatch(bigint, boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'H30 : vérification en échec';
  END IF;
  RAISE NOTICE 'H30 : vérifications OK';
END
$h30_verif$;

NOTIFY pgrst, 'reload schema';
