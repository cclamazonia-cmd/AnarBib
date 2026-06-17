-- 20260617023031_opac_catalog_search_ids_v1.sql
-- OPAC / recherche (1b) — RPC de recherche INSENSIBLE AUX ACCENTS, multi-mots,
-- classée par PERTINENCE (similarité trigramme). Renvoie des book_id ordonnés.
--
-- Visibilité (point sensible) : branche selon auth.uid() —
--   anon         → api.catalog_list_anon_v1     (public uniquement)
--   connecté·e   → api.catalog_list_session_v1  (réseau-aware, RLS de l'appelant·e)
-- SECURITY INVOKER : la fonction s'exécute avec les droits de l'appelant·e, donc
--   exactement la même visibilité que les vues déjà servies au frontend →
--   AUCUNE fuite réseau/BTL. search_path vidé + tout est schéma-qualifié.
--
-- Multi-mots ET insensible aux accents : chaque mot (désaccentué) doit
--   apparaître dans le texte concaténé désaccentué (titre+sous-titre+auteur+
--   éditeur+sujets+réf+isbn). Rang = similarité trigramme titre+auteur.
--
-- Câblage frontend : à la recherche, le front appelle ce RPC ; en cas d'erreur
--   ou de RPC absent, il RETOMBE sur la recherche multi-mots ilike
--   (src/lib/catalogFilters.js) → déploiement sans risque (dégradation
--   gracieuse, jamais pire que l'existant). L'ordre app→backend du CI (frontend
--   déployé avant la migration) est donc sûr grâce à ce repli.
--
-- Cœur de requête validé en lecture seule sur la prod (16/06 : « revolucao
--   espanhola » sans accents retrouve « …Revolução Espanhola » ;
--   unaccent(titulo) ilike '%educacao%' = 14 vs ilike '%educacao%' = 0).
--
-- Session : Catalogue longue traîne (recherche + fiche auteur)

create or replace function api.catalog_search_ids_v1(p_q text)
returns table(book_id bigint, rank real)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  -- Garde : requête vide → rien (évite de tout renvoyer).
  if coalesce(btrim(p_q), '') = '' then
    return;
  end if;

  if auth.uid() is null then
    return query
      select s.book_id, s.rank
      from (
        select c.book_id,
          extensions.similarity(
            extensions.unaccent(lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, ''))),
            extensions.unaccent(lower(p_q))
          )::real as rank,
          extensions.unaccent(lower(
            coalesce(c.titulo, '')   || ' ' || coalesce(c.subtitulo, '') || ' ' ||
            coalesce(c.autor, '')    || ' ' || coalesce(c.editora, '')   || ' ' ||
            coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '')   || ' ' ||
            coalesce(c.isbn, '')
          )) as hay
        from api.catalog_list_anon_v1 c
      ) s
      where not exists (
        select 1
        from pg_catalog.regexp_split_to_table(p_q, '\s+') as term
        where length(term) > 0
          and s.hay not like '%' || extensions.unaccent(lower(term)) || '%'
      )
      order by s.rank desc nulls last
      limit 500;
  else
    return query
      select s.book_id, s.rank
      from (
        select c.book_id,
          extensions.similarity(
            extensions.unaccent(lower(coalesce(c.titulo, '') || ' ' || coalesce(c.autor, ''))),
            extensions.unaccent(lower(p_q))
          )::real as rank,
          extensions.unaccent(lower(
            coalesce(c.titulo, '')   || ' ' || coalesce(c.subtitulo, '') || ' ' ||
            coalesce(c.autor, '')    || ' ' || coalesce(c.editora, '')   || ' ' ||
            coalesce(c.assuntos, '') || ' ' || coalesce(c.bib_ref, '')   || ' ' ||
            coalesce(c.isbn, '')
          )) as hay
        from api.catalog_list_session_v1 c
      ) s
      where not exists (
        select 1
        from pg_catalog.regexp_split_to_table(p_q, '\s+') as term
        where length(term) > 0
          and s.hay not like '%' || extensions.unaccent(lower(term)) || '%'
      )
      order by s.rank desc nulls last
      limit 500;
  end if;
end
$$;

revoke all on function api.catalog_search_ids_v1(text) from public;
grant execute on function api.catalog_search_ids_v1(text) to anon, authenticated;
