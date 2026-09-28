-- =========================================================================
-- La recherche du catalogue lit les sigles sans leurs points :
-- « C.N.T. », « CNT » et « C.N.T » se trouvent l'un l'autre
-- =========================================================================
-- Date     : 2026-09-28
-- Chantier : suite de la réunion des œuvres 93 et 2037 (Peirats, La CNT en la
--            revolución española) ; décision de Xavier du 28/09 au soir.
--
-- LE CONSTAT. Les deux éditions d'une même œuvre — La Cuchilla 1988 à la BTL,
-- titres écrits « La C.N.T. y la revolución española » ; Ruedo Ibérico 1978 à
-- la MLEG, « La CNT en la revolución española » — restaient deux lignes au
-- catalogue par œuvre selon la graphie cherchée : « La C.N.T. » ne rendait
-- que les tomes BTL, « La CNT » que les tomes MLEG. Le filtre par auteur·rice,
-- lui, les repliait sous une seule ligne à six éditions. Ce n'est pas l'œuvre
-- qui était scindée : api.catalog_search_ids_v1 exige chaque terme de la
-- requête, tel quel, comme sous-chaîne d'une meule (titre, sous-titre,
-- auteur·rice, éditeur, sujets, cote, ISBN — sans accents ni casse), et
-- « c.n.t. » n'est pas une sous-chaîne de « cnt », ni l'inverse. Le catalogue
-- par œuvre regroupe ensuite ce qui a passé le filtre : chaque graphie ne
-- ramenait que ses tomes.
--
-- LE GESTE. public.fn_sigle_sans_points(text) plie un sigle écrit avec des
-- points sur ses seules lettres : « c.n.t. » → « cnt », « u.g.t.-c.n.t. » →
-- « ugt-cnt », « la f.a.i. » → « la fai ». Un sigle est une suite de lettres
-- SEULES séparées par des points, en début de mot, avec ou sans point final ;
-- une abréviation ordinaire n'est pas touchée (« ed. », « etc. », « J. Peirats »
-- gardent leur point). La meule et chaque terme de la requête passent par elle,
-- ainsi que les deux côtés de la similarité qui classe les résultats : les
-- trois graphies se cherchent l'une l'autre, et se classent pareil. Rien d'autre
-- ne change dans api.catalog_search_ids_v1 : mêmes colonnes, mêmes deux
-- branches (anonyme, session), même plafond de 500, même ordre — garde
-- d'entrée sur le md5 de la définition réelle (celle du 28/09 au soir). Les
-- facettes (api.catalog_facets_v1) passent déjà par cette fonction pour leur
-- « q » : elles suivent sans rien recopier.
--
-- Coût : deux expressions régulières par ligne de la vue, seulement quand la
-- meule contient un point (strpos(…, '.') = 0 court-circuite) ; la meule est
-- déjà calculée par ligne (unaccent + lower), la recherche parcourt déjà toute
-- la vue. Aucun index en jeu : ni f_normalize_search ni les index trigramme ne
-- bougent — la recherche unifiée (api.search_catalog_v1) et les autorités
-- gardent leur normalisation, à traiter à part si le besoin se présente.
-- Garde : tests/sql/recherche_sigles_tests.sql.
-- =========================================================================

BEGIN;

DO $entree$
DECLARE v_md5 text;
BEGIN
  SELECT md5(p.prosrc) INTO v_md5 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF v_md5 IS DISTINCT FROM '9e3c48adbbbd547f9faf564bbac8af6c' THEN
    RAISE EXCEPTION 'sigles : api.catalog_search_ids_v1 n''est pas la version du 28/09 (md5 %) — relire sa définition réelle avant de la réécrire', v_md5;
  END IF;
END
$entree$;

-- ── Le pli d'un sigle ──────────────────────────────────────────────────────
-- Deux passes sur la chaîne d'origine : (1) le point FINAL d'un sigle (précédé
-- de « lettre.lettre », suivi d'autre chose qu'une lettre) ; (2) chaque point
-- INTÉRIEUR (précédé d'une lettre seule en début de mot, suivi d'une lettre
-- seule qui finit le mot ou précède un point). « c.n.trabajo » garde son
-- second point : « n » y est suivi d'un mot, pas d'une lettre seule.
CREATE OR REPLACE FUNCTION public.fn_sigle_sans_points(p_texte text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE STRICT
 SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN pg_catalog.strpos(p_texte, '.') = 0 THEN p_texte
    ELSE pg_catalog.regexp_replace(
           pg_catalog.regexp_replace(p_texte, '(?<=[[:alpha:]]\.[[:alpha:]])\.(?![[:alpha:]])', '', 'g'),
           '(?<=\m[[:alpha:]])\.(?=[[:alpha:]](?:\.|\M))', '', 'g')
  END
$function$;

COMMENT ON FUNCTION public.fn_sigle_sans_points(text) IS
  'Plie un sigle écrit avec des points sur ses lettres (« c.n.t. » → « cnt ») ; une abréviation ordinaire (« ed. », « etc. ») garde son point. Sert à la recherche du catalogue (api.catalog_search_ids_v1), sur la meule et sur chaque terme. Migration 20260928174350.';

REVOKE ALL ON FUNCTION public.fn_sigle_sans_points(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_sigle_sans_points(text) TO anon, authenticated, service_role;

-- ── La recherche du catalogue, meule et termes pliés ──────────────────────
CREATE OR REPLACE FUNCTION api.catalog_search_ids_v1(p_q text)
 RETURNS TABLE(book_id bigint, rank real)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
begin
  -- Garde : requête vide → rien (évite de tout renvoyer).
  if coalesce(btrim(p_q), '') = '' then
    return;
  end if;

  -- Sigles (28/09/2026) : la meule et chaque terme passent par
  -- public.fn_sigle_sans_points — « c.n.t. », « cnt » et « c.n.t » se
  -- cherchent l'un l'autre. La similarité qui classe lit les mêmes formes.
  if auth.uid() is null then
    return query
      select s.book_id, s.rank
      from (
        select c.book_id,
          extensions.similarity(
            public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, '')))),
            public.fn_sigle_sans_points(extensions.unaccent(lower(p_q)))
          )::real as rank,
          public.fn_sigle_sans_points(extensions.unaccent(lower(
            coalesce(c.titulo, '')   || ' ' || coalesce(c.subtitulo, '') || ' ' ||
            coalesce(c.autor, '')    || ' ' || coalesce(c.editora, '')   || ' ' ||
            coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '')   || ' ' ||
            coalesce(c.isbn, '')
          ))) as hay
        from api.catalog_list_anon_v1 c
      ) s
      where not exists (
        select 1
        from pg_catalog.regexp_split_to_table(p_q, '\s+') as term
        where length(term) > 0
          and s.hay not like '%' || public.fn_sigle_sans_points(extensions.unaccent(lower(term))) || '%'
      )
      order by s.rank desc nulls last, s.book_id
      limit 500;
  else
    return query
      select s.book_id, s.rank
      from (
        select c.book_id,
          extensions.similarity(
            public.fn_sigle_sans_points(extensions.unaccent(lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, '')))),
            public.fn_sigle_sans_points(extensions.unaccent(lower(p_q)))
          )::real as rank,
          public.fn_sigle_sans_points(extensions.unaccent(lower(
            coalesce(c.titulo, '')   || ' ' || coalesce(c.subtitulo, '') || ' ' ||
            coalesce(c.autor, '')    || ' ' || coalesce(c.editora, '')   || ' ' ||
            coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '')   || ' ' ||
            coalesce(c.isbn, '')
          ))) as hay
        from api.catalog_list_session_v1 c
      ) s
      where not exists (
        select 1
        from pg_catalog.regexp_split_to_table(p_q, '\s+') as term
        where length(term) > 0
          and s.hay not like '%' || public.fn_sigle_sans_points(extensions.unaccent(lower(term))) || '%'
      )
      order by s.rank desc nulls last, s.book_id
      limit 500;
  end if;
end
$function$;

-- ── Vérification : ce que la migration fait, et rien de plus ───────────────
DO $verif$
DECLARE v_src text; r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('la c.n.t. y la revolucion espanola', 'la cnt y la revolucion espanola'),
      ('la cnt en la revolucion espanola',   'la cnt en la revolucion espanola'),
      ('c.n.t',                              'cnt'),
      ('u.g.t.-c.n.t.',                      'ugt-cnt'),
      ('la f.a.i.',                          'la fai'),
      ('j. peirats, ed. 2a ed.',             'j. peirats, ed. 2a ed.'),
      ('etc. p.m.',                          'etc. pm'),
      ('sans point',                         'sans point')
    ) AS t(entree, attendu)
  LOOP
    IF public.fn_sigle_sans_points(r.entree) IS DISTINCT FROM r.attendu THEN
      RAISE EXCEPTION 'sigles : « % » plié en « % », attendu « % »', r.entree, public.fn_sigle_sans_points(r.entree), r.attendu;
    END IF;
  END LOOP;
  IF public.fn_sigle_sans_points(NULL) IS NOT NULL THEN RAISE EXCEPTION 'sigles : NULL doit rester NULL'; END IF;

  SELECT p.prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'api' AND p.proname = 'catalog_search_ids_v1';
  IF v_src NOT LIKE '%public.fn_sigle_sans_points(extensions.unaccent(lower(term)))%'
     OR v_src NOT LIKE '%from api.catalog_list_anon_v1 c%'
     OR v_src NOT LIKE '%from api.catalog_list_session_v1 c%'
     OR v_src NOT LIKE '%limit 500%' THEN
    RAISE EXCEPTION 'sigles : api.catalog_search_ids_v1 n''a pas la forme attendue';
  END IF;
  IF NOT has_function_privilege('anon', 'public.fn_sigle_sans_points(text)', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_sigle_sans_points(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'sigles : anon et authenticated doivent pouvoir plier (la recherche est en droits de l''appelant·e)';
  END IF;
END
$verif$;

COMMIT;
