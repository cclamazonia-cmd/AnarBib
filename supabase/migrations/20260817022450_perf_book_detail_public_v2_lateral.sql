-- Performance : v_book_detail_public_v2 — CTE agrégées globalement -> LATERAL corrélées.
--
-- Problème. La vue était bâtie sur huit CTE qui agrègent chacune la TOTALITÉ d'une
-- table (book_authors, author_books_public, book_digital_resources, book_subjects,
-- book_holdings, exemplares, emprestimo_itens_v2), puis joignent le résultat sur
-- `books` pour n'en garder qu'une ligne. Le prédicat `book_id = ?` ne peut pas
-- descendre à travers ces agrégats : afficher UNE fiche recalculait le rollup des
-- fonds de tout le catalogue. Le coût croissait donc avec la taille du réseau.
--
-- Mesuré le 2026-08-16 (2 677 livres, rôle `authenticated`, RLS active) :
--   avant : ~2 594 ms par fiche      (940 ms d'exécution serveur, 46 sous-plans,
--                                     84 boucles imbriquées ; la seule CTE
--                                     holdings_rollup_by_book en pesait 598 ms)
--   après : ~44,7 ms par fiche       (~58x)
--
-- Sous charge, l'ancienne version dépassait le statement_timeout du rôle
-- `authenticated` (8 s) et renvoyait des HTTP 500 : 37,5 % d'échecs dès 10 usagers
-- simultanés, 100 % à 30. Elle saturait le CPU de l'instance et dégradait toutes
-- les autres requêtes par ricochet (p95 global à ~10 s). Une fois écartée, la même
-- charge passe à 162 req/s sans une seule erreur à 120 usagers simultanés.
--
-- Le contrat de sortie (noms, ordre et types des colonnes) et la sémantique sont
-- STRICTEMENT identiques : comparaison ligne à ligne et colonne à colonne des deux
-- versions sur les 2 677 livres — zéro différence. Aucun changement côté front.

create or replace view public.v_book_detail_public_v2 with (security_invoker = true) as
select
  b.id,
  b.id as book_id,
  b.bib_ref,
  b.autor,
  b.titulo,
  b.ano,
  b.editora,
  b.cdd,
  coalesce(b.loanable, true) as loanable,
  coalesce(hold.global_available_count, 0) as available_count,
  b.created_at,
  b.cover_object_path,
  b.subtitulo,
  b.edicao,
  b.local_publicacao,
  b.isbn,
  b.issn,
  b.idioma,
  b.paginas,
  b.notas,
  b.tipo_material,
  b.autores_secundarios,
  b.colecao,
  b.volume,
  b.assuntos,
  b.tradutor,
  b.organizador,
  fa.author_id,
  b.catalog_source,
  case when hold.bibliotecas_count = 1 then hold.single_library_id else null::uuid end as library_id,
  case when hold.bibliotecas_count = 1 then hold.single_library_slug else null::text end as library_slug,
  case when hold.bibliotecas_count = 1 then hold.single_library_name else null::text end as library_name,
  case
    when hold.bibliotecas_count = 1 then hold.single_library_name
    when hold.bibliotecas_count > 1 then hold.bibliotecas_count::text || ' bibliotecas'::text
    else null::text
  end as biblioteca,
  coalesce(df.has_online_reading, false) as has_online_reading,
  coalesce(c.author_display, b.autor) as author_display,
  coalesce(c.author_chips, '[]'::jsonb) as author_chips,
  coalesce(aj.authors_json, '[]'::jsonb) as authors_json,
  coalesce(hold.exemplares_total, 0) as exemplares_total,
  coalesce(hold.bibliotecas_count, 0) as bibliotecas_count,
  coalesce(hold.holding_libraries_json, '[]'::jsonb) as holding_libraries_json,
  coalesce(hold.tombos_json, '[]'::jsonb) as tombos_json,
  coalesce(hold.global_available_count, 0) as global_available_count,
  coalesce(b.available_count, 0) as legacy_available_count_global,
  coalesce(hold.exemplares_total, 0) as global_exemplares_total,
  edb.earliest_due_back_at,
  b.distribuidora,
  b.gravadora,
  coalesce(bsa.subjects_json, '[]'::jsonb) as subjects_json
from books b

-- ex-CTE first_author (DISTINCT ON sur toute book_authors)
left join lateral (
  select ba.author_id
  from book_authors ba
  where ba.book_id = b.id
    and ba.author_id is not null
  order by ba.ord, ba.author_id
  limit 1
) fa on true

left join v_book_authors_canonical c on c.book_id = b.id

-- ex-CTE authors_json_by_book
left join lateral (
  select jsonb_agg(jsonb_build_object(
           'author_id', abp.author_id,
           'display_name', coalesce(abp.author_name, abp.sort_name, abp.preferred_name),
           'preferred_name', abp.preferred_name,
           'sort_name', abp.sort_name,
           'role', abp.role,
           'ord', abp.ord)
         order by abp.ord, abp.author_id) as authors_json
  from author_books_public abp
  where abp.book_id = b.id
) aj on true

-- ex-CTE digital_flags
left join lateral (
  select bool_or(r.resource_type = 'pdf_restrito'::text
             and r.usage_type = 'leitura_online'::text
             and r.access_scope = 'conta_ativa'::text
             and r.status = 'active'::text
             and coalesce(r.is_active, false) = true) as has_online_reading
  from book_digital_resources r
  where r.book_id = b.id
) df on true

-- ex-CTE book_subjects_agg
left join lateral (
  select jsonb_agg(jsonb_build_object('subject_id', s.id, 'slug', s.slug, 'label_i18n', s.label_i18n)
                   order by bs.ord, s.id) as subjects_json
  from book_subjects bs
  join subjects s on s.id = bs.subject_id
  where bs.book_id = b.id
    and s.status = 'ativo'::text
) bsa on true

-- ex-CTE earliest_due_by_book
left join lateral (
  select min(coalesce(ei.extended_until, ei.due_at)) as earliest_due_back_at
  from emprestimo_itens_v2 ei
  where ei.book_id = b.id
    and ei.item_status = 'aberto'::text
) edb on true

-- ex-CTE holdings_source + exemplares_by_holding + earliest_due_by_holding +
-- holdings_enriched + holdings_rollup_by_book + single_library + tombos_all,
-- regroupées en un seul LATERAL évalué par livre.
left join lateral (
  with he as (
    select h.id as holding_id,
           h.library_id,
           l.slug as library_slug,
           l.name as library_name,
           l.short_name,
           l.city,
           l.state,
           coalesce(nullif(btrim(h.local_bib_ref), ''::text), b.bib_ref) as local_bib_ref,
           coalesce(h.loanable, b.loanable, true) as holding_loanable,
           -- NB : l'original calculait COALESCE(COALESCE(h.exemplares_total,0),
           -- exh.exemplares_total_real, 0), dont le premier terme n'est jamais NULL.
           -- exemplares_total_real était donc déjà du code mort ; comportement
           -- conservé à l'identique ici (à traiter séparément si c'était un oubli).
           coalesce(h.exemplares_total, 0) as holding_exemplares_total,
           coalesce(h.available_count, 0) as holding_available_count,
           coalesce(exh.tombos_json, '[]'::jsonb) as tombos_json,
           edh.earliest_due_back_at as holding_earliest_due_back_at
    from book_holdings h
    join libraries l on l.id = h.library_id
    left join lateral (
      select jsonb_agg(e.tombo order by e.tombo)
               filter (where nullif(btrim(coalesce(e.tombo, ''::text)), ''::text) is not null) as tombos_json
      from exemplares e
      where e.holding_id = h.id
    ) exh on true
    left join lateral (
      select min(coalesce(ei.extended_until, ei.due_at)) as earliest_due_back_at
      from emprestimo_itens_v2 ei
      join exemplares e2 on e2.id = ei.item_id
      where e2.holding_id = h.id
        and ei.item_status = 'aberto'::text
    ) edh on true
    where h.book_id = b.id
  )
  select
    coalesce(sum(he.holding_exemplares_total), 0::bigint)::integer as exemplares_total,
    count(*)::integer as bibliotecas_count,
    coalesce(sum(he.holding_available_count), 0::bigint)::integer as global_available_count,
    jsonb_agg(jsonb_build_object(
        'holding_id', he.holding_id,
        'library_id', he.library_id,
        'library_slug', he.library_slug,
        'library_name', he.library_name,
        'short_name', he.short_name,
        'city', he.city,
        'state', he.state,
        'local_bib_ref', he.local_bib_ref,
        'loanable', he.holding_loanable,
        'available_count', he.holding_available_count,
        'exemplares_total', he.holding_exemplares_total,
        'tombos_json', he.tombos_json,
        'earliest_due_back_at', he.holding_earliest_due_back_at)
      order by he.library_name, he.library_slug, he.holding_id) as holding_libraries_json,
    (array_agg(he.library_id order by he.holding_id))[1] as single_library_id,
    (array_agg(he.library_slug order by he.holding_id))[1] as single_library_slug,
    (array_agg(he.library_name order by he.holding_id))[1] as single_library_name,
    (select jsonb_agg(x.tombo order by x.tombo)
       from (select jsonb_array_elements_text(he2.tombos_json) as tombo from he he2) x) as tombos_json
  from he
) hold on true;
