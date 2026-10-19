-- =====================================================================
-- 20261019195143_une_source_se_choisit_dans_le_filtre_du_catalogue
-- Le filtre « Bibliothèques AnarBib » du catalogue propose aussi les
-- bibliothèques sources (décision de Xavier, 19/10/2026, ~21 h 50 :
-- « les bibliothèques sources doivent apparaître dans le filtre
-- « Bibliothèques AnarBib » du catalogue, mais rester hors de l'annuaire, de
-- la carte et de l'OAI »).
--
-- POURQUOI. Le filtre lisait api.libraries_public_v1, qui ne rend que les
-- bibliothèques que l'on VOIT (fn_library_visible_to_caller). Une source
-- (libraries.catalog_public, 20261019122125) montre ses notices sans être
-- visible elle-même : ses 1 002 notices se filtraient déjà par son nom
-- (holding_library_names_json, liste plate comme RPC des œuvres), mais on ne
-- pouvait pas la choisir dans la liste.
--
-- CE QUE FAIT LE PAQUET. Une vue dédiée au filtre, api.catalog_filter_libraries_v1
-- (security_invoker) : les bibliothèques dont le CATALOGUE se lit —
-- visibles, ou sources actives. Mêmes colonnes que libraries_public_v1.
-- Sous la RLS de la personne qui lit : la ligne d'une source est lisible
-- depuis 20261019122125 (branche catalog_public de libraries_read).
--
-- CE QUE LE PAQUET NE FAIT PAS. api.libraries_public_v1 reste telle quelle :
-- elle sert aussi l'EF rss-novidades (un flux seulement pour une bibliothèque
-- publique). L'annuaire (api.public_libraries), la carte et l'OAI ne bougent pas.
--
-- Garde : tests/sql/source_catalogue_public_tests.sql T12.
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
  WHERE public.fn_library_visible_to_caller(l.id)
     OR ((l.is_active = true) AND (l.catalog_public = true))
  ORDER BY l.name;

COMMENT ON VIEW api.catalog_filter_libraries_v1 IS
  'Filtre « Bibliothèques AnarBib » du catalogue (19/10/2026) : bibliothèques visibles, et sources actives (catalog_public). '
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
END $$;

COMMIT;
