-- =========================================================================
-- Le catalogage cherche ses documents publiés comme l'OPAC
-- =========================================================================
-- Date     : 2026-10-13
-- Chantier : catalogage, onglet « Catalogue(s) publié(s) » (demande de Xavier)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Catalogage — recherche des documents publiés
--
-- LE CONSTAT (13/10/2026).
--   La barre de l'onglet « Catalogue(s) publié(s) › Documents » faisait un
--   ILIKE PostgREST de la saisie ENTIÈRE sur titulo, autor, isbn, bib_ref :
--   « kropotkin conquete » ne trouvait rien (deux mots), « kropotkine » non
--   plus (alias de l'autorité), ni une lettre de travers, ni un ISBN tapé
--   sans tirets (290 des 438 ISBN de la base en portent), ni un ISBN-10
--   d'une édition cataloguée en ISBN-13. L'OPAC fait mieux depuis le 11/10
--   (api.catalog_search_ids_v1).
--
-- POURQUOI PAS api.catalog_search_ids_v1 TELLE QUELLE.
--   Elle lit api.catalog_list_*_v1, donc la vue MATÉRIALISÉE du catalogue
--   (mv_books_catalog_list_network_v1), rafraîchie par cron : une notice que
--   le ou la bibliothécaire vient de publier n'y est pas encore — c'est
--   justement celle qu'on cherche dans cet onglet. Et la vue écarte les
--   bibliothèques de formation (en prod : 2 566 notices dans `books`, 2 561
--   dans la vue). L'onglet liste `public.books` ; sa recherche doit lire la
--   même table, sous la même RLS.
--
-- LE GESTE.
--   api.catalogacao_book_ids_v1(p_q) — INVOKER, lit public.books en direct
--   (books_select_authenticated s'applique : l'appelant·e ne retrouve que ce
--   que l'onglet lui montre déjà). Mêmes règles que l'OPAC :
--     - chaque mot de la saisie doit se trouver dans la notice (titre,
--       sous-titre, auteur·rices transcrit·es et contributions, éditeur,
--       collection, sujets, référence, ISBN, ISSN, CDD, année, titres de
--       l'œuvre dans toutes les langues), sans accents ni casse, sigles sans
--       leurs points (public.fn_sigle_sans_points) ;
--     - un mot de trois lettres et plus est aussi satisfait par une autorité
--       liée à la notice (book_contributors.author_id) qui porte ce nom sous
--       une autre forme (private.fn_auteurs_par_nom : variantes, alias) ;
--     - si RIEN ne sort, deuxième passe à une ou deux lettres près
--       (private.fn_mots_proches, jamais sous cinq lettres), rangs décalés
--       sous zéro : un rang négatif veut dire « approché » (même contrat que
--       catalog_search_ids_v1 ; l'écran le dit).
--   En plus de l'OPAC, l'ISBN :
--     - un mot fait de chiffres (et de tirets, X) se compare aussi aux seuls
--       chiffres de books.isbn — « 9789568134860 », « 978-956-8134-86-0 » et
--       « 978-956 » trouvent tous « 978-956-8134-86-0 » ;
--     - un ISBN complet se compare par son cœur (public.fn_isbn_coeur, la
--       règle de DEDUP « un même ISBN est une même édition ») : l'ISBN-10
--       trouve la notice cataloguée en ISBN-13 et inversement, au rang 1.
--   Classement : similarité trigramme de la saisie avec titre + auteur·rice
--   (ou le meilleur titre d'œuvre), puis la notice modifiée le plus
--   récemment ; 500 notices au plus (comme l'OPAC).
--
-- Droits : authenticated et service_role ; ni anon ni PUBLIC (l'onglet est
-- derrière une session de catalogage, la liste T12 de grants_herites ne
-- bouge pas).
-- Tests : tests/sql/catalogacao_recherche_documents_tests.sql.
-- =========================================================================

CREATE OR REPLACE FUNCTION api.catalogacao_book_ids_v1(p_q text)
 RETURNS TABLE(book_id bigint, rank real)
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
#variable_conflict use_column
declare
  v_approche boolean;
begin
  -- Garde : requête vide → rien (la liste sans recherche reste celle de l'onglet).
  if coalesce(btrim(p_q), '') = '' then
    return;
  end if;

  -- Passe exacte, puis — seulement si elle ne rend rien — passe approchée.
  foreach v_approche in array array[false, true] loop
    return query
      with saisie as (
        select public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(pg_catalog.btrim(p_q)))) as q
      ),
      termes as materialized (
        select public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(t.term))) as norme,
               -- un mot qui commence par un chiffre et n'a que chiffres, tirets
               -- et X : sa forme « chiffres seuls » se compare à l'ISBN compact
               case when t.term ~ '^[0-9][0-9Xx-]*$'
                    then pg_catalog.regexp_replace(pg_catalog.lower(t.term), '[^0-9x]', '', 'g')
                    else '' end as chiffres,
               public.fn_isbn_coeur(t.term) as coeur,
               case when pg_catalog.length(t.term) >= 3
                    then private.fn_auteurs_par_nom(t.term, v_approche) else '{}'::bigint[] end as auteurs
          from pg_catalog.regexp_split_to_table(pg_catalog.btrim(p_q), '\s+') as t(term)
         where pg_catalog.length(t.term) > 0
      ),
      notices as (
        select b.id as id_notice, b.work_id, b.updated_at,
          public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(
            coalesce(b.titulo, '') || ' ' || coalesce(b.autor, '')))) as titre_auteur,
          public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(pg_catalog.concat_ws(' ',
            b.titulo, b.subtitulo, b.autor, b.autores_secundarios, b.organizador, b.tradutor,
            b.editora, b.colecao, b.assuntos, b.subjects, b.bib_ref, b.isbn, b.issn, b.cdd, b.ano,
            (select pg_catalog.string_agg(wt.title, ' ') from public.work_titles wt where wt.work_id = b.work_id),
            (select pg_catalog.string_agg(bc.name, ' ') from public.book_contributors bc where bc.book_id = b.id)
          )))) as hay,
          pg_catalog.regexp_replace(pg_catalog.lower(coalesce(b.isbn, '')), '[^0-9x]', '', 'g') as isbn_chiffres,
          public.fn_isbn_coeur(b.isbn) as isbn_coeur,
          array(select bc.author_id from public.book_contributors bc
                 where bc.book_id = b.id and bc.author_id is not null) as auteurs
        from public.books b
      )
      select n.id_notice,
        (greatest(
           extensions.similarity(n.titre_auteur, (select s.q from saisie s)),
           coalesce((select max(extensions.similarity(
                       public.fn_sigle_sans_points(extensions.unaccent(pg_catalog.lower(wt.title))),
                       (select s.q from saisie s)))
                       from public.work_titles wt where wt.work_id = n.work_id), 0),
           case when n.isbn_coeur <> ''
                 and exists (select 1 from termes t where t.coeur = n.isbn_coeur) then 1 else 0 end
         ) - case when v_approche then 1 else 0 end)::real
      from notices n
      where not exists (
        select 1
          from termes t
         where n.hay not like '%' || t.norme || '%'
           and not (pg_catalog.length(t.chiffres) >= 4 and n.isbn_chiffres like '%' || t.chiffres || '%')
           and not (t.coeur <> '' and t.coeur = n.isbn_coeur)
           and not (n.auteurs && t.auteurs)
           and not (v_approche and private.fn_mots_proches(t.norme, n.hay))
      )
      order by 2 desc nulls last, n.updated_at desc nulls last, n.id_notice desc
      limit 500;

    exit when found;
  end loop;
end
$function$;

REVOKE ALL ON FUNCTION api.catalogacao_book_ids_v1(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION api.catalogacao_book_ids_v1(text) TO authenticated, service_role;

COMMENT ON FUNCTION api.catalogacao_book_ids_v1(text) IS
  'Catalogage, onglet « Catalogue(s) publié(s) › Documents » : notices de public.books (sous RLS, en direct, '
  'pas la vue matérialisée de l''OPAC) qui portent chaque mot de la saisie — variantes de l''autorité liée, '
  'ISBN avec ou sans tirets, ISBN-10 ↔ ISBN-13 ; si rien, une ou deux lettres près, rang < 0 = approché. '
  '500 au plus, classées par pertinence. 20261013062921.';
