-- =========================================================================
-- Catalogue — auteur affiché : repli sur le rôle créateur principal du média
-- (audiovisuel → réalisateur·rice, audio → compositeur·rice)
-- =========================================================================
-- Date     : 2026-06-17
-- Chantier : Catalogação / cohérence supports non écrits (#CAT-AUTEUR-AV-AUDIO)
-- Auteur   : Xavier + Claude
-- Session  : File éditoriale — tri & supports AV
--
-- OBJET
-- -----
-- v_book_authors_canonical alimente la colonne « auteur » du catalogue (MV
-- mv_books_catalog_list_network_v1 ET mv_books_catalog_list_v1). Elle ne
-- retenait que les contributeur·rices role='autor'. Conséquence : un film ou
-- un enregistrement catalogué avec les rôles dédiés (réalisateur·rice,
-- compositeur·rice…) mais SANS 'autor' affichait un auteur VIDE.
--
-- CORRECTIF (cadré)
-- -----------------
-- Auteur catalogue = role='autor' SI la notice en a au moins un ; SINON repli
-- sur le rôle créateur principal du média :
--   * tipo_material = 'audiovisual' → role 'realizador'
--   * tipo_material = 'audio'       → role 'compositor'
-- Les écrits restent STRICTEMENT inchangés (ils ont 'autor' → la branche
-- historique s'applique, le repli ne se déclenche jamais). Pas de flood :
-- acteur·rices / interprètes / rôles secondaires ne sont jamais promus.
--
-- Contrat PRÉSERVÉ : security_invoker=true, mêmes 3 colonnes en sortie, même
-- canonicalisation du nom. Seuls changent : un CTE per_book + l'extension du
-- WHERE (join books pour tipo_material). Réversible (rollback en pied).
-- =========================================================================

begin;

create or replace view public.v_book_authors_canonical
with (security_invoker = true)
as
 with per_book as (
         select bc.book_id,
                bool_or(bc.role = 'autor'::text) as has_autor
           from book_contributors bc
          group by bc.book_id
        ), canon_source as (
         select bc.book_id,
            bc.author_id,
            bc.position as ord,
            COALESCE(
              NULLIF(btrim(a.sort_name), ''),
              NULLIF(btrim(a.preferred_name), ''),
              NULLIF(btrim(bc.name), '')
            ) as base_name
           from book_contributors bc
             left join authors a ON a.id = bc.author_id
             left join books b ON b.id = bc.book_id
             left join per_book pb ON pb.book_id = bc.book_id
          where bc.role = 'autor'::text
             or (
                  pb.has_autor = false
                  and (
                       (b.tipo_material = 'audiovisual'::text and bc.role = 'realizador'::text)
                    or (b.tipo_material = 'audio'::text       and bc.role = 'compositor'::text)
                  )
                )
        ), canon as (
         select canon_source.book_id,
            canon_source.author_id,
            canon_source.ord,
                CASE
                    WHEN canon_source.base_name IS NULL THEN NULL::text
                    WHEN POSITION((','::text) IN (canon_source.base_name)) > 0 THEN upper(TRIM(BOTH FROM split_part(canon_source.base_name, ','::text, 1))) ||
                    CASE
                        WHEN NULLIF(TRIM(BOTH FROM SUBSTRING(canon_source.base_name FROM POSITION((','::text) IN (canon_source.base_name)) + 1)), ''::text) IS NOT NULL THEN ', '::text || TRIM(BOTH FROM SUBSTRING(canon_source.base_name FROM POSITION((','::text) IN (canon_source.base_name)) + 1))
                        ELSE ''::text
                    END
                    ELSE canon_source.base_name
                END as display_name
           from canon_source
        )
 select book_id,
    string_agg(display_name, ' ; '::text ORDER BY ord, display_name) as author_display,
    jsonb_agg(jsonb_build_object('author_id', author_id, 'label', display_name, 'ord', ord) ORDER BY ord, display_name) as author_chips
   from canon
  group by book_id;

-- ---------------------------------------------------------------------------
-- Vérification fail-fast
-- ---------------------------------------------------------------------------
do $verif$
declare
  v_count int;
begin
  -- a. la vue référence books (join tipo_material ajouté)
  select count(*) into v_count
    from information_schema.view_column_usage
   where view_schema = 'public' and view_name = 'v_book_authors_canonical'
     and table_name = 'books';
  if v_count < 1 then
    raise exception 'VERIF_FAIL_a : v_book_authors_canonical ne référence pas books';
  end if;

  -- b. mêmes 3 colonnes en sortie (contrat MV inchangé)
  select count(*) into v_count
    from information_schema.columns
   where table_schema = 'public' and table_name = 'v_book_authors_canonical'
     and column_name in ('book_id', 'author_display', 'author_chips');
  if v_count <> 3 then
    raise exception 'VERIF_FAIL_b : colonnes de v_book_authors_canonical altérées (%/3)', v_count;
  end if;

  -- c. security_invoker = true préservé (doctrine vues)
  select count(*) into v_count
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relname = 'v_book_authors_canonical'
     and c.reloptions @> ARRAY['security_invoker=true'];
  if v_count <> 1 then
    raise exception 'VERIF_FAIL_c : v_book_authors_canonical n''est pas security_invoker=true';
  end if;

  raise notice 'catalog_author_principal_av_audio — v_book_authors_canonical étendue OK';
end
$verif$;

notify pgrst, 'reload schema';

commit;

-- =========================================================================
-- Après COMMIT : REFRESH des MV consommatrices (réseau puis publique).
-- Non concurrent (aligné sur 20260605310000) : REFRESH CONCURRENTLY interdit
-- en bloc transactionnel.
-- =========================================================================
refresh materialized view public.mv_books_catalog_list_network_v1;
refresh materialized view public.mv_books_catalog_list_v1;

-- =========================================================================
-- Rollback : restaurer la définition role='autor' seul (cf. 20260605310000).
-- =========================================================================
