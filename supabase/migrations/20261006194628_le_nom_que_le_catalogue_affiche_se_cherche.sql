-- =========================================================================
-- Le nom que le catalogue affiche est un nom qu'on peut chercher
-- =========================================================================
-- Date     : 2026-10-06
-- Chantier : recherche du catalogue (signalement de Xavier du 06/10 au soir)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Catalogue — disponibilité d'ailleurs et nom d'autorité cherchable
--
-- LE CONSTAT (06/10/2026, app.anarbib.org, lecteur rattaché à BLMF).
--   La notice 1432 « A Guerra civil espanhola nos documentos libertários »
--   porte dans `books.autor` la saisie libre « C.N.T. », liée (book_contributors)
--   à l'autorité 10115 « Confederación Nacional del Trabajo ». Le catalogue
--   AFFICHE le nom de l'autorité (author_display de la vue matérialisée).
--   Champ « Auteur·rice » = « C.N.T. » → la notice sort, sous le nom
--   « Confederación Nacional del Trabajo » ; champ = « Confederación » → neuf
--   œuvres, pas celle-là. Le filtre de api.catalog_works_v1 et la meule de
--   api.catalog_search_ids_v1 ne lisaient que `autor` : le nom que la ligne
--   montre n'était pas cherchable. 327 notices du catalogue réseau ont un
--   author_display qui n'est pas leur `autor` (06/10).
--
-- LES GESTES — réécriture chirurgicale de la définition RÉELLE (replace, un
-- nombre d'occurrences exact, sinon la migration s'arrête) :
--   (1) api.catalog_works_v1 : la CTE `src` lit aussi c.author_display, et le
--       filtre texte par auteur·rice exige chaque mot dans `autor` OU dans
--       author_display (même meule), sans accents ni casse, sigles pliés par
--       public.fn_sigle_sans_points comme la recherche libre (« CNT » trouve
--       « C.N.T. »). Le parcours A–Z (alpha) et le filtre par lien d'autorité
--       (author_id) ne bougent pas.
--   (2) api.catalog_search_ids_v1 : la meule des deux branches (anon, session)
--       reçoit author_display à côté de `autor`. Le rang ne change pas.
--
-- Facettes (api.catalog_facets_v1) : n'appliquent pas le filtre texte par
-- auteur·rice — rien à changer.
-- Repli liste plate du front (src/lib/catalogFilters.js) : chaque mot est
-- cherché dans `autor` OU `author_display`, même commit.
-- Tests : tests/sql/nom_affiche_cherchable_tests.sql.
-- =========================================================================

BEGIN;

-- ── (1) Le filtre par auteur·rice lit aussi le nom affiché ─────────────────
DO $auteur$
DECLARE
  v_old_src text := $o$c.titulo, c.autor, c.author_id, c.ano$o$;
  v_new_src text := $n$c.titulo, c.autor, c.author_display, c.author_id, c.ano$n$;
  v_old     text := $o$extensions.unaccent(lower(coalesce(s.autor, ''))) NOT LIKE '%' || extensions.unaccent(lower(mot)) || '%'$o$;
  v_new     text := $n$public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(s.autor, '') || ' ' || coalesce(s.author_display, ''))))
                    NOT LIKE '%' || public.fn_sigle_sans_points(extensions.unaccent(lower(mot))) || '%'$n$;
  v_def text;
  v_n   int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1';
  v_n := (length(v_def) - length(replace(v_def, v_old_src, ''))) / length(v_old_src);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'nom affiché : colonnes de src attendues une fois dans api.catalog_works_v1, trouvées % fois', v_n;
  END IF;
  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'nom affiché : clause auteur·rice attendue une fois dans api.catalog_works_v1, trouvée % fois', v_n;
  END IF;
  EXECUTE replace(replace(v_def, v_old_src, v_new_src), v_old, v_new);
END
$auteur$;

-- ── (2) La recherche libre lit aussi le nom affiché ───────────────────────
DO $meule$
DECLARE
  v_old text := $o$coalesce(c.autor, '')    || ' ' || coalesce(c.editora, '')$o$;
  v_new text := $n$coalesce(c.autor, '')    || ' ' || coalesce(c.author_display, '') || ' ' || coalesce(c.editora, '')$n$;
  v_def text;
  v_n   int;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  v_n := (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old);
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'nom affiché : meule attendue deux fois (anon, session) dans api.catalog_search_ids_v1, trouvée % fois', v_n;
  END IF;
  EXECUTE replace(v_def, v_old, v_new);
END
$meule$;

-- ── Garde de sortie ───────────────────────────────────────────────────────
DO $sortie$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                  WHERE n.nspname = 'api' AND p.proname = 'catalog_works_v1'
                    AND p.prosrc LIKE '%coalesce(s.author_display, '''')%'
                    AND p.prosrc LIKE '%c.author_display, c.author_id%') THEN
    RAISE EXCEPTION 'nom affiché : api.catalog_works_v1 non réécrite';
  END IF;
  IF (SELECT (length(p.prosrc) - length(replace(p.prosrc, 'coalesce(c.author_display, '''')', ''))) / length('coalesce(c.author_display, '''')')
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1') <> 2 THEN
    RAISE EXCEPTION 'nom affiché : api.catalog_search_ids_v1 non réécrite dans ses deux branches';
  END IF;
END
$sortie$;

COMMIT;
