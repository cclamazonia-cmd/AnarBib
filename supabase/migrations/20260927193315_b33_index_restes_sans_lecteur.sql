-- =========================================================================
-- B33 — les index restés sans lecteur sont retirés, raison écrite
-- =========================================================================
-- Date     : 2026-09-27
-- Chantier : B33, après la migration précédente (les recherches empruntent
--            leurs index trigramme). B10 avait gardé ces index en attendant
--            qu'on sache si une requête corrigée les écrirait : aucune ne les
--            écrit, et trois ne pouvaient servir aucune requête possible.
--
-- La règle qui tranche les trois derniers : une table sous RLS ne promeut une
-- condition en condition d'index que si son opérateur est LEAKPROOF. LIKE,
-- ILIKE, `~` et `%` ne le sont pas (textlike, texticlike, textregexeq,
-- similarity_op : proleakproof = false). Un index trigramme ne sert donc que
-- les fonctions SECURITY DEFINER dont le propriétaire possède la table ; une
-- recherche faite par PostgREST ou par une fonction INVOKER ne l'emprunte
-- jamais, quelle que soit la forme de son OU.
--
-- Relevé du 27/09 en production : 0 parcours depuis le 02/09 pour chacun.
-- =========================================================================

BEGIN;

-- idx_publishers_name_trgm — GIN trigramme sur publishers.name BRUT. Ses deux
-- lecteurs possibles écrivent autre chose : search_publishers_by_name travaille
-- sur fn_normalize_name(name) (servie depuis la migration précédente par
-- publishers_fn_normalize_name_trgm_idx), fn_sync_publisher_id_on_publish sur
-- lower(name) (servie par publishers_lower_name_idx).
DROP INDEX IF EXISTS public.idx_publishers_name_trgm;

-- idx_authors_external_ids — GIN (jsonb_ops) posé en juin pour « chercher une
-- autorité par identifiant externe (ex. MBID) » : cette recherche n'a jamais été
-- câblée. GIN ne sert que @>, ?, ?| et ?& ; les usages réels sont l'extraction
-- ->> sur une ligne déjà trouvée (fn_oai_harvestable_records) et des NOT ? dans
-- les migrations d'enrichissement du 26-27/09. Il alourdissait chacune de ces
-- écritures. Un dédoublonnage par QID demanderait un index d'expression sur
-- external_ids->>'wikidata', pas celui-ci.
DROP INDEX IF EXISTS public.idx_authors_external_ids;

-- serials_issn_idx — btree sur l'ISSN brut. Toutes les comparaisons portent sur
-- sa forme réduite aux chiffres, regexp_replace(coalesce(issn,''), '\D', '', 'g')
-- (fn_serial_search, suggest_serial_duplicates) ; aucune n'écrit `issn =`.
DROP INDEX IF EXISTS public.serials_issn_idx;

-- serials_uniform_title_trgm — son seul `%` (suggest_serial_duplicates,
-- `b.uniform_title % a.uniform_title`) est OU-é avec l'égalité des ISSN
-- réduits, que rien n'indexe : pas de BitmapOr. fn_serial_search écrit une
-- autre expression (f_normalize_search(uniform_title)), dans une fonction
-- INVOKER, donc sous RLS. La table compte 4 périodiques : si elle grossit,
-- c'est la jointure du dédoublonnage qu'il faudra couper en deux (UNION), et
-- l'index se recréera avec elle.
DROP INDEX IF EXISTS public.serials_uniform_title_trgm;

-- idx_books_autor_trgm — ses deux lecteurs lisent books SOUS RLS : l'onglet
-- Catalogue (CatalogPanel, par PostgREST : titulo, autor, isbn, bib_ref en
-- ILIKE) et fn_peb_search_exemplares (INVOKER). ILIKE n'étant pas leakproof,
-- aucun des deux ne peut l'emprunter, même avec un OU tout indexé. Le seul
-- lecteur DEFINER (api.capas_photo_liste, 27/09) l'enferme dans un CASE. Le
-- coût de ces recherches à grande échelle est celui de la policy calculée
-- ligne à ligne : c'est B32.
DROP INDEX IF EXISTS public.idx_books_autor_trgm;

-- Garde de sortie : les cinq sont partis, les index qui les remplacent ou que
-- la recherche emprunte sont là.
DO $sortie$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class
              WHERE relnamespace = 'public'::regnamespace
                AND relname IN ('idx_publishers_name_trgm', 'idx_authors_external_ids',
                                'serials_issn_idx', 'serials_uniform_title_trgm',
                                'idx_books_autor_trgm')) THEN
    RAISE EXCEPTION 'B33 : un index sans lecteur est encore là';
  END IF;
  IF (SELECT count(*) FROM pg_class
       WHERE relnamespace = 'public'::regnamespace
         AND relname IN ('publishers_fn_normalize_name_trgm_idx', 'publishers_lower_name_idx',
                         'idx_books_titulo_trgm', 'authors_fn_normalize_name_trgm_idx',
                         'authors_sort_name_fn_normalize_name_trgm_idx')) <> 5 THEN
    RAISE EXCEPTION 'B33 : un index de recherche attendu manque';
  END IF;
END
$sortie$;

COMMIT;
