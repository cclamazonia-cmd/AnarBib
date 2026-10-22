-- =====================================================================
-- 20261022204656_une_bibliotheque_de_formation_sort_du_filtre_du_catalogue
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Identité Anarchief et filtre du catalogue
--
-- CONSTAT (prod, 21/10). Le filtre « Bibliothèques AnarBib » du catalogue
-- propose « Biblioteca de Teste — Formação BLMF », la bibliothèque de
-- formation (libraries.is_training = true, bac à sable de la formation de
-- coordination du 26/08). Elle y entre par fn_library_visible_to_caller :
-- une bibliothèque privée est visible de son équipe, et l'administration du
-- réseau est membre de la bibliothèque de formation. Anarchief.Org, privée
-- elle aussi, y figure par l'autre branche : c'est une source
-- (catalog_public), proposée à tout le monde.
--
-- DÉCISION (Xavier, 22/10/2026) : une bibliothèque de formation sort du
-- filtre, POUR TOUT LE MONDE, son équipe comprise. Anarchief, qui n'est pas
-- une bibliothèque de formation, reste.
--
-- CE QUE FAIT LE PAQUET. Une condition de plus dans api.catalog_filter_libraries_v1
-- (20261019195143) : NOT l.is_training, posée devant les deux branches
-- (visible, ou source active). Mêmes colonnes, même security_invoker, mêmes
-- privilèges.
--
-- CE QUE LE PAQUET NE FAIT PAS. La bibliothèque de formation n'est pas
-- désactivée ; ses notices, sa page, son tableau de bord restent ouverts à son
-- équipe. api.libraries_public_v1 (repli du filtre si la vue manque, flux RSS)
-- ne bouge pas.
--
-- Garde : tests/sql/source_catalogue_public_tests.sql T13.
-- =====================================================================

BEGIN;

CREATE OR REPLACE VIEW api.catalog_filter_libraries_v1 WITH (security_invoker = true) AS
 SELECT l.id,
    l.slug,
    l.name,
    l.short_name,
    l.city,
    l.state
   FROM public.libraries l
  WHERE NOT l.is_training
    AND (public.fn_library_visible_to_caller(l.id)
         OR ((l.is_active = true) AND (l.catalog_public = true)))
  ORDER BY l.name;

COMMENT ON VIEW api.catalog_filter_libraries_v1 IS
  'Filtre « Bibliothèques AnarBib » du catalogue (19/10/2026) : bibliothèques visibles, et sources actives (catalog_public). '
  'Sans les bibliothèques de formation (is_training, 22/10/2026). '
  'Pas un annuaire : l''annuaire est api.public_libraries.';

REVOKE ALL ON api.catalog_filter_libraries_v1 FROM PUBLIC, anon, authenticated;
GRANT SELECT ON api.catalog_filter_libraries_v1 TO anon, authenticated, service_role;

DO $$ BEGIN
  IF coalesce((SELECT option_value FROM pg_options_to_table((SELECT reloptions FROM pg_class
                 WHERE oid = 'api.catalog_filter_libraries_v1'::regclass)) WHERE option_name = 'security_invoker'), 'false') <> 'true' THEN
    RAISE EXCEPTION 'catalog_filter_libraries_v1 doit être security_invoker';
  END IF;
  IF NOT has_table_privilege('anon', 'api.catalog_filter_libraries_v1', 'SELECT')
     OR has_table_privilege('anon', 'api.catalog_filter_libraries_v1', 'INSERT') THEN
    RAISE EXCEPTION 'catalog_filter_libraries_v1 : privilèges inattendus';
  END IF;
  IF EXISTS (SELECT 1 FROM api.catalog_filter_libraries_v1 f
               JOIN public.libraries l ON l.id = f.id WHERE l.is_training) THEN
    RAISE EXCEPTION 'catalog_filter_libraries_v1 rend encore une bibliothèque de formation';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;
