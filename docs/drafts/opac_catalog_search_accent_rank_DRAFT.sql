-- ============================================================================
-- ⛔ SUPERSEDED / PÉRIMÉ — 2026-07-03. NE PAS DÉPLOYER, NE PAS S'EN INSPIRER.
--   Ce brouillon (1b) est intégralement remplacé par la RPC EN PROD
--   `api.catalog_search_ids_v1(text)`, qui fait déjà tout ce qui suit :
--   insensibilité aux accents (extensions.unaccent), classement par PERTINENCE
--   (extensions.similarity + ORDER BY rank DESC), split multi-mots, ET les DEUX
--   chemins — anon (api.catalog_list_anon_v1) et connecté (api.catalog_list_session_v1).
--   Le « chemin session à écrire » que ce brouillon annonçait est donc FAIT.
--   Conservé pour trace historique uniquement. Cf. clôture #4, session 2026-07-03.
-- ============================================================================
--
-- 20260616212140_opac_catalog_search_accent_rank_DRAFT.sql
-- OPAC / recherche — classement par PERTINENCE + insensibilité aux ACCENTS (1b).
--
-- ⚠️⚠️ BROUILLON — NE PAS DÉPLOYER TEL QUEL. ⚠️⚠️
--   Cette migration touche la chaîne de VISIBILITÉ du catalogue. Avant tout
--   déploiement : (1) tester sur une BRANCHE Supabase (pas la prod) ; (2) passer
--   les security advisors ; (3) vérifier les GRANTs de la chaîne anon →
--   api.catalog_list_anon_v1 → private.fn_catalog_public_rows(). La logique de
--   classement ci-dessous a été VALIDÉE en lecture seule sur la prod le 16/06
--   (« revolucao espanhola » sans accents retrouve « …Revolução Espanhola »),
--   mais l'enrobage fonction + grants + perfs reste à éprouver sur branche.
--
-- Acquis livré en frontend (1a) : recherche MULTI-MOTS (src/lib/catalogFilters.js).
-- Ce que (1b) ajoute : insensibilité aux accents (prouvée : `ilike '%educacao%'`
--   = 0 résultat sur les titres « Educação… », vs `unaccent(titulo) ilike` = 14)
--   et un classement par pertinence (similarité trigramme) — l'« ordre pertinence »
--   du tri étant aujourd'hui factice (resolveOrder → titulo.asc).
--
-- PÉRIMÈTRE de ce brouillon : chemin ANON / public uniquement (lit la vue
--   api.catalog_list_anon_v1, donc même visibilité que l'OPAC public — pas de
--   fuite réseau/BTL). Le chemin CONNECTÉ (session/réseau) = MÊME patron sur
--   api.catalog_list_session_v1, à écrire ensuite ; tant qu'il n'existe pas, NE
--   PAS câbler ce RPC pour les connecté·es (sinon régression : ils perdraient
--   la recherche sur leur périmètre de session, que (1a) couvre déjà).
--
-- Câblage frontend prévu (après déploiement) : quand `search` est non vide,
--   appeler ce RPC → liste ordonnée de book_id → filtrer la grille par
--   book_id=in.(…) puis re-trier côté client selon le rang (PostgREST in.() ne
--   préserve pas l'ordre). Patron identique au filtre par sujet existant.
--
-- Perf : à l'échelle anon actuelle (~499 lignes) le balayage + unaccent est
--   trivial. Pour le chemin session (plus large), prévoir un index GIN trigramme
--   sur une expression unaccent IMMUTABLE (wrapper) — à dimensionner sur branche.
--
-- Session : Catalogue longue traîne (recherche + fiche auteur)

create or replace function api.catalog_search_ids_v1(p_q text)
returns table(book_id bigint, rank real)
language sql
stable
security invoker
set search_path = ''
as $$
  with terms as (
    select extensions.unaccent(lower(t)) as t
    from regexp_split_to_table(coalesce(p_q, ''), '\s+') as t
    where length(t) > 0
  ),
  src as (
    select c.book_id,
      extensions.unaccent(lower(
        coalesce(c.titulo, '') || ' ' || coalesce(c.subtitulo, '') || ' ' ||
        coalesce(c.autor, '')  || ' ' || coalesce(c.editora, '')   || ' ' ||
        coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '') || ' ' ||
        coalesce(c.isbn, '')
      )) as hay,
      extensions.unaccent(lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, ''))) as hay_short
    from api.catalog_list_anon_v1 c
  )
  select s.book_id,
    extensions.similarity(s.hay_short, extensions.unaccent(lower(coalesce(p_q, ''))))::real as rank
  from src s
  -- AND multi-mots : aucun terme ne doit manquer dans le texte désaccentué.
  where exists (select 1 from terms)
    and not exists (select 1 from terms x where s.hay not like '%' || x.t || '%')
  order by rank desc nulls last;
$$;

revoke all on function api.catalog_search_ids_v1(text) from public;
grant execute on function api.catalog_search_ids_v1(text) to anon, authenticated;
