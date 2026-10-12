-- =========================================================================
-- La liste plate s'approche aussi des notices sans autorité liée
-- =========================================================================
-- Date     : 2026-10-12
-- Chantier : recherche du catalogue (E38, suite ; demande de Xavier du 12/10 :
--            « ajoute l'approché pour les notices sans lien »)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
--
-- LE CONSTAT. En « Liste plate », E38 (20261012074224) résout le nom saisi en
--   autorités (api.catalog_author_ids_v1), puis à une ou deux lettres près si
--   rien. Mais une notice SANS autorité liée — `autor` en saisie libre — ne
--   sort que par l'ILIKE mot à mot de PostgREST : « Bakunim » trouve les
--   notices liées à Bakunin, jamais celles où « BAKUNIN, Mikhail » est seulement
--   écrit. Le catalogue par œuvre (api.catalog_works_v1), lui, s'approche du
--   texte de toutes les notices.
--
-- LE GESTE. api.catalog_author_book_ids_v1(p_name) rend les NOTICES que le
--   filtre auteur·rice du catalogue par œuvre retient, avec sa règle exacte :
--     chaque mot dans `autor` ou `author_display` (sans accents ni casse, sigles
--     pliés) OU notice liée (author_id, author_chips) à une autorité que
--     private.fn_auteurs_par_nom trouve sous l'un de ses noms ;
--     si rien ne sort dans tout le catalogue, même recherche à une ou deux
--     lettres près (private.fn_mots_proches) — sur le texte de TOUTES les
--     notices, liées ou non — et `approx` vaut vrai.
--   Plafond 501 lignes : la liste plate se contraint par `book_id=in.(…)`
--   jusqu'à 500 notices ; au-delà (un filtre d'une lettre) ou en cas d'erreur,
--   le front garde le chemin d'E38 (autorités + ILIKE paginé) — jamais de liste
--   tronquée. Mesuré en prod (transaction annulée, 11/10) : mêmes notices que
--   catalog_works_v1 sur 13 noms, 80 à 120 ms en exact, ~330 ms en approché.
--   INVOKER : la vue (anon ou session) décide de la visibilité ; ouverte à anon
--   comme les autres lectures du catalogue (liste T12 de grants_herites_tests).
-- Tests : tests/sql/recherche_variantes_approchee_tests.sql (T12-T14).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.catalog_author_book_ids_v1(p_name text)
 RETURNS TABLE(book_id bigint, approx boolean)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
declare
  v_view text := case when auth.uid() is null then 'api.catalog_list_anon_v1' else 'api.catalog_list_session_v1' end;
  v_sql  text;
begin
  if coalesce(btrim(p_name), '') = '' then
    return;
  end if;

  -- La règle du filtre auteur·rice de api.catalog_works_v1 (20261011211012) :
  -- $1 la saisie, $2 les autorités qui portent ce nom, $3 passe approchée.
  v_sql := $q$
    select c.book_id, $3
      from __VIEW__ c
     where not exists (
             select 1
               from pg_catalog.regexp_split_to_table($1, '[[:space:],;]+') as mot
              where mot <> ''
                and not (case when $3
                  then private.fn_mots_proches(
                         public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(mot))),
                         public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(coalesce(c.autor, '') || ' ' || coalesce(c.author_display, '')))))
                  else public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(coalesce(c.autor, '') || ' ' || coalesce(c.author_display, ''))))
                       like '%' || public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(mot))) || '%'
                  end))
        or c.author_id = any ($2)
        or exists (select 1
                     from pg_catalog.jsonb_array_elements(case when pg_catalog.jsonb_typeof(c.author_chips) = 'array'
                                                               then c.author_chips else '[]'::jsonb end) ch
                    where (ch->>'author_id')::bigint = any ($2))
     order by c.book_id
     limit 501
  $q$;
  v_sql := replace(v_sql, '__VIEW__', v_view);

  return query execute v_sql using btrim(p_name), private.fn_auteurs_par_nom(p_name, false), false;
  if not found then
    return query execute v_sql using btrim(p_name), private.fn_auteurs_par_nom(p_name, true), true;
  end if;
end
$function$;

REVOKE ALL ON FUNCTION api.catalog_author_book_ids_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.catalog_author_book_ids_v1(text) TO anon, authenticated, service_role;

-- ── Garde de sortie ───────────────────────────────────────────────────────
DO $sortie$
DECLARE v_n int; v_m int;
BEGIN
  IF has_function_privilege('anon', 'api.catalog_author_book_ids_v1(text)', 'EXECUTE') IS NOT TRUE
     OR EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                 WHERE p.oid = 'api.catalog_author_book_ids_v1(text)'::regprocedure AND a.grantee = 0) THEN
    RAISE EXCEPTION 'liste plate : api.catalog_author_book_ids_v1 doit être ouverte à anon, fermée à PUBLIC';
  END IF;
  -- Sur les données réelles quand elles sont là : la liste plate retient les
  -- mêmes notices que le catalogue par œuvre, en exact comme en approché.
  IF EXISTS (SELECT 1 FROM public.author_name_aliases WHERE author_id = 5 AND alias_text = 'Kropotkine' AND is_active)
     AND EXISTS (SELECT 1 FROM api.catalog_list_anon_v1 WHERE author_id = 5) THEN
    SELECT count(*) INTO v_n FROM api.catalog_author_book_ids_v1('kropotkine');
    SELECT count(*) INTO v_m
      FROM jsonb_array_elements(api.catalog_works_v1('{"author":"kropotkine"}'::jsonb, 'relevance', 0, 200, 'fr')->'works') g,
           jsonb_array_elements(g->'editions') e;
    IF v_n = 0 OR v_n <> v_m THEN
      RAISE EXCEPTION 'liste plate : « kropotkine » rend % notice(s), le catalogue par œuvre %', v_n, v_m;
    END IF;
    SELECT count(*) INTO v_n FROM api.catalog_author_book_ids_v1('kropotkn') WHERE approx;
    IF v_n = 0 THEN
      RAISE EXCEPTION 'liste plate : « kropotkn » ne trouve rien en approché';
    END IF;
  END IF;
END
$sortie$;

NOTIFY pgrst, 'reload schema';

COMMIT;
