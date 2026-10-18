-- =====================================================================
-- Les livres d'une autorité : tous ses contributeurs liés, pas seulement le
-- premier (18/10/2026, signalé par Xavier).
--
-- Xavier a remis Élisée Reclus (autorité 1) parmi les contributeurs d'« Élisée
-- Reclus: Geografia » (MLEG-0106), en troisième position, après la
-- coordination (Florestan Fernandes) et l'organisation (Manuel Correia de
-- Andrade) ; la notice ne revenait pas dans la liste des livres de Reclus.
-- Cause : le filtre par autorité (`author_id`) de api.catalog_works_v1 et
-- api.catalog_facets_v1 comparait la seule colonne `author_id` de la vue du
-- catalogue — le PREMIER contributeur lié dans l'ordre, quel que soit son
-- rôle (Fernandes ici). Le filtre par nom, lui, regardait déjà toutes les
-- autorités liées (`author_chips`, 11/10/2026).
--
-- Le filtre par autorité trouve désormais une notice si l'autorité est la
-- première OU l'une de ses autorités liées. La correction se pose sur la
-- définition RÉELLE des deux fonctions (pg_get_functiondef) en remplaçant la
-- seule ligne du filtre ; elle échoue si la ligne n'est pas trouvée une fois
-- et une seule (une définition qui aurait bougé ne doit pas être réécrite à
-- l'aveugle).
-- =====================================================================
DO $$
DECLARE
  v_oid   oid;
  v_def   text;
  v_avant text;
  v_apres text;
  v_n     int;
BEGIN
  -- ── 1. La liste (une ligne par œuvre) ──
  SELECT p.oid INTO STRICT v_oid FROM pg_proc p
   WHERE p.pronamespace = 'api'::regnamespace AND p.proname = 'catalog_works_v1';
  v_def   := pg_get_functiondef(v_oid);
  v_avant := $a$' AND s.author_id::text = p.author_id'$a$;
  v_apres := $a$' AND (s.author_id::text = p.author_id OR EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(s.author_chips) = ''array'' THEN s.author_chips ELSE ''[]''::jsonb END) ch WHERE ch->>''author_id'' = p.author_id))'$a$;
  v_n := (length(v_def) - length(replace(v_def, v_avant, ''))) / length(v_avant);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'api.catalog_works_v1 : le filtre par autorité attendu apparaît % fois (1 attendue)', v_n;
  END IF;
  EXECUTE replace(v_def, v_avant, v_apres);

  -- ── 2. Les facettes (mêmes notices que la liste) ──
  SELECT p.oid INTO STRICT v_oid FROM pg_proc p
   WHERE p.pronamespace = 'api'::regnamespace AND p.proname = 'catalog_facets_v1';
  v_def   := pg_get_functiondef(v_oid);
  v_avant := $a$' AND c.author_id::text = p.author_id'$a$;
  v_apres := $a$' AND (c.author_id::text = p.author_id OR EXISTS (SELECT 1 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.author_chips) = ''array'' THEN c.author_chips ELSE ''[]''::jsonb END) ch WHERE ch->>''author_id'' = p.author_id))'$a$;
  v_n := (length(v_def) - length(replace(v_def, v_avant, ''))) / length(v_avant);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'api.catalog_facets_v1 : le filtre par autorité attendu apparaît % fois (1 attendue)', v_n;
  END IF;
  EXECUTE replace(v_def, v_avant, v_apres);
END $$;
