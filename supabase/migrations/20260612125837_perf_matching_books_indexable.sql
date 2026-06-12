-- Migration : perf matching — requetes books indexables + index d'expression (B+C)
-- Auteur  : Claude (Opus 4.8)
-- Session : Import/Export — fiabilisation matching & rapprochement
-- Date    : 2026-06-12 (UTC)
--
-- Volet B : fn_match_partner_catalog_row compare fn_norm(b.col) DIRECTEMENT
-- (suppression du detour to_jsonb(b)->>'col' qui interdisait l'indexation, car
-- to_jsonb n'est pas IMMUTABLE). Reecriture SEMANTIQUEMENT NEUTRE. Band-aid
-- statement_timeout=0 conserve (dans la def). Volet A deja fait (fonctions
-- IMMUTABLE). Volet C : index d'expression concordants au mot pres.

CREATE OR REPLACE FUNCTION ingest.fn_match_partner_catalog_row(p_staging_row_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
 SET statement_timeout TO '0'
AS $function$
declare
  rec ingest.partner_catalog_staging_rows%rowtype;
  v_author_label text;
  v_title_norm text;
  v_author_norm text;
  v_year_norm text;
  v_isbn_norm text;
  v_issn_norm text;
  v_publisher_norm text;
  v_place_norm text;

  v_top_candidate_type text;
  v_top_candidate_id bigint;
  v_top_match_method text;
  v_top_match_score numeric(5,2);

  v_match_status text := 'new_record';
  v_proposed_book_id bigint := null;
  v_proposed_book_draft_id bigint := null;
begin
  select *
    into rec
  from ingest.partner_catalog_staging_rows
  where id = p_staging_row_id;

  if not found then
    raise exception 'staging_row % introuvable', p_staging_row_id;
  end if;

  v_author_label := coalesce(
    nullif(trim(rec.responsibility_statement), ''),
    ingest.fn_format_partner_authors(rec.authors)
  );

  v_title_norm     := ingest.fn_match_normalize_text(rec.title);
  v_author_norm    := ingest.fn_match_normalize_text(v_author_label);
  v_year_norm      := ingest.fn_extract_year4(rec.publication_year);
  v_isbn_norm      := ingest.fn_normalize_isxn(rec.isbn);
  v_issn_norm      := ingest.fn_normalize_isxn(rec.issn);
  v_publisher_norm := ingest.fn_match_normalize_publisher(rec.publisher);
  v_place_norm     := ingest.fn_match_normalize_text(rec.place_of_publication);

  delete from ingest.partner_catalog_match_candidates
  where staging_row_id = p_staging_row_id;

  update ingest.partner_catalog_staging_rows
     set proposed_book_id = null,
         proposed_book_draft_id = null
   where id = p_staging_row_id;

  -- -------------------------------------------------------
  -- 1) ISBN EXACT -> BOOKS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book',
    b.id,
    'isbn_exact',
    100.00,
    jsonb_build_object(
      'source_table', 'books',
      'title', b.titulo,
      'author', b.autor,
      'year', b.ano,
      'publisher', b.editora,
      'place', b.local_publicacao,
      'isbn', b.isbn,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'isbn_exact',
          null,
          null,
          null,
          null
        )
    )
  from public.books b
  where v_isbn_norm is not null
    and ingest.fn_normalize_isxn(b.isbn) = v_isbn_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 2) ISBN EXACT -> BOOK_DRAFTS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book_draft',
    d.id,
    'isbn_exact',
    98.00,
    jsonb_build_object(
      'source_table', 'book_drafts',
      'title', d.titulo,
      'author', d.autor,
      'year', d.ano,
      'publisher', d.editora,
      'place', d.local_publicacao,
      'isbn', d.isbn,
      'status', d.status,
      'batch_id', d.batch_id,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'isbn_exact',
          null,
          null,
          null,
          null
        )
    )
  from public.book_drafts d
  where v_isbn_norm is not null
    and ingest.fn_normalize_isxn(d.isbn) = v_isbn_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 3) ISSN EXACT -> BOOKS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book',
    b.id,
    'issn_exact',
    97.00,
    jsonb_build_object(
      'source_table', 'books',
      'title', b.titulo,
      'author', b.autor,
      'year', b.ano,
      'publisher', b.editora,
      'place', b.local_publicacao,
      'issn', b.issn,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'issn_exact',
          null,
          null,
          null,
          null
        )
    )
  from public.books b
  where v_issn_norm is not null
    and ingest.fn_normalize_isxn(b.issn) = v_issn_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 4) ISSN EXACT -> BOOK_DRAFTS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book_draft',
    d.id,
    'issn_exact',
    95.00,
    jsonb_build_object(
      'source_table', 'book_drafts',
      'title', d.titulo,
      'author', d.autor,
      'year', d.ano,
      'publisher', d.editora,
      'place', d.local_publicacao,
      'issn', d.issn,
      'status', d.status,
      'batch_id', d.batch_id,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'issn_exact',
          null,
          null,
          null,
          null
        )
    )
  from public.book_drafts d
  where v_issn_norm is not null
    and ingest.fn_normalize_isxn(d.issn) = v_issn_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 5) TITLE + AUTHOR + YEAR + PUBLISHER -> BOOKS
  -- match_method conservé = title_author_year
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book',
    b.id,
    'title_author_year',
    92.00,
    jsonb_build_object(
      'source_table', 'books',
      'title', b.titulo,
      'author', b.autor,
      'year', b.ano,
      'publisher', b.editora,
      'place', b.local_publicacao,
      'year_equal', true,
      'year_conflict', false,
      'publisher_match', true,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author_year',
          true,
          false,
          true,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.books b
  where v_title_norm is not null
    and v_author_norm is not null
    and v_year_norm is not null
    and v_publisher_norm is not null
    and ingest.fn_match_normalize_text(b.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(b.autor) = v_author_norm
    and ingest.fn_extract_year4(b.ano) = v_year_norm
    and ingest.fn_match_normalize_publisher(b.editora) = v_publisher_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 6) TITLE + AUTHOR + YEAR + PUBLISHER -> BOOK_DRAFTS
  -- match_method conservé = title_author_year
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book_draft',
    d.id,
    'title_author_year',
    90.00,
    jsonb_build_object(
      'source_table', 'book_drafts',
      'title', d.titulo,
      'author', d.autor,
      'year', d.ano,
      'publisher', d.editora,
      'place', d.local_publicacao,
      'year_equal', true,
      'year_conflict', false,
      'publisher_match', true,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'status', d.status,
      'batch_id', d.batch_id,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author_year',
          true,
          false,
          true,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.book_drafts d
  where v_title_norm is not null
    and v_author_norm is not null
    and v_year_norm is not null
    and v_publisher_norm is not null
    and ingest.fn_match_normalize_text(d.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(d.autor) = v_author_norm
    and ingest.fn_extract_year4(d.ano) = v_year_norm
    and ingest.fn_match_normalize_publisher(d.editora) = v_publisher_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 7) TITLE + AUTHOR + YEAR -> BOOKS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book',
    b.id,
    'title_author_year',
    90.00,
    jsonb_build_object(
      'source_table', 'books',
      'title', b.titulo,
      'author', b.autor,
      'year', b.ano,
      'publisher', b.editora,
      'place', b.local_publicacao,
      'year_equal', true,
      'year_conflict', false,
      'publisher_match',
        case
          when v_publisher_norm is not null
           and ingest.fn_match_normalize_publisher(b.editora) = v_publisher_norm
          then true
          else false
        end,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author_year',
          true,
          false,
          case
            when v_publisher_norm is not null
             and ingest.fn_match_normalize_publisher(b.editora) = v_publisher_norm
            then true
            else false
          end,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.books b
  where v_title_norm is not null
    and v_author_norm is not null
    and v_year_norm is not null
    and ingest.fn_match_normalize_text(b.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(b.autor) = v_author_norm
    and ingest.fn_extract_year4(b.ano) = v_year_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 8) TITLE + AUTHOR + YEAR -> BOOK_DRAFTS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book_draft',
    d.id,
    'title_author_year',
    88.00,
    jsonb_build_object(
      'source_table', 'book_drafts',
      'title', d.titulo,
      'author', d.autor,
      'year', d.ano,
      'publisher', d.editora,
      'place', d.local_publicacao,
      'year_equal', true,
      'year_conflict', false,
      'publisher_match',
        case
          when v_publisher_norm is not null
           and ingest.fn_match_normalize_publisher(d.editora) = v_publisher_norm
          then true
          else false
        end,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'status', d.status,
      'batch_id', d.batch_id,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author_year',
          true,
          false,
          case
            when v_publisher_norm is not null
             and ingest.fn_match_normalize_publisher(d.editora) = v_publisher_norm
            then true
            else false
          end,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.book_drafts d
  where v_title_norm is not null
    and v_author_norm is not null
    and v_year_norm is not null
    and ingest.fn_match_normalize_text(d.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(d.autor) = v_author_norm
    and ingest.fn_extract_year4(d.ano) = v_year_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 9) TITLE + AUTHOR + PUBLISHER -> BOOKS
  -- match_method conservé = title_author
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book',
    b.id,
    'title_author',
    86.00,
    jsonb_build_object(
      'source_table', 'books',
      'title', b.titulo,
      'author', b.autor,
      'year', b.ano,
      'publisher', b.editora,
      'place', b.local_publicacao,
      'year_equal',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(b.ano) = v_year_norm
          then true
          else false
        end,
      'year_conflict',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(b.ano) is not null
           and ingest.fn_extract_year4(b.ano) <> v_year_norm
          then true
          else false
        end,
      'publisher_match', true,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author',
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(b.ano) = v_year_norm
            then true
            else false
          end,
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(b.ano) is not null
             and ingest.fn_extract_year4(b.ano) <> v_year_norm
            then true
            else false
          end,
          true,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.books b
  where v_title_norm is not null
    and v_author_norm is not null
    and v_publisher_norm is not null
    and ingest.fn_match_normalize_text(b.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(b.autor) = v_author_norm
    and ingest.fn_match_normalize_publisher(b.editora) = v_publisher_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 10) TITLE + AUTHOR + PUBLISHER -> BOOK_DRAFTS
  -- match_method conservé = title_author
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book_draft',
    d.id,
    'title_author',
    84.00,
    jsonb_build_object(
      'source_table', 'book_drafts',
      'title', d.titulo,
      'author', d.autor,
      'year', d.ano,
      'publisher', d.editora,
      'place', d.local_publicacao,
      'year_equal',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(d.ano) = v_year_norm
          then true
          else false
        end,
      'year_conflict',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(d.ano) is not null
           and ingest.fn_extract_year4(d.ano) <> v_year_norm
          then true
          else false
        end,
      'publisher_match', true,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'status', d.status,
      'batch_id', d.batch_id,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author',
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(d.ano) = v_year_norm
            then true
            else false
          end,
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(d.ano) is not null
             and ingest.fn_extract_year4(d.ano) <> v_year_norm
            then true
            else false
          end,
          true,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.book_drafts d
  where v_title_norm is not null
    and v_author_norm is not null
    and v_publisher_norm is not null
    and ingest.fn_match_normalize_text(d.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(d.autor) = v_author_norm
    and ingest.fn_match_normalize_publisher(d.editora) = v_publisher_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 11) TITLE + AUTHOR -> BOOKS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book',
    b.id,
    'title_author',
    82.00,
    jsonb_build_object(
      'source_table', 'books',
      'title', b.titulo,
      'author', b.autor,
      'year', b.ano,
      'publisher', b.editora,
      'place', b.local_publicacao,
      'year_equal',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(b.ano) = v_year_norm
          then true
          else false
        end,
      'year_conflict',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(b.ano) is not null
           and ingest.fn_extract_year4(b.ano) <> v_year_norm
          then true
          else false
        end,
      'publisher_match',
        case
          when v_publisher_norm is not null
           and ingest.fn_match_normalize_publisher(b.editora) = v_publisher_norm
          then true
          else false
        end,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author',
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(b.ano) = v_year_norm
            then true
            else false
          end,
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(b.ano) is not null
             and ingest.fn_extract_year4(b.ano) <> v_year_norm
            then true
            else false
          end,
          case
            when v_publisher_norm is not null
             and ingest.fn_match_normalize_publisher(b.editora) = v_publisher_norm
            then true
            else false
          end,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(b.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.books b
  where v_title_norm is not null
    and v_author_norm is not null
    and ingest.fn_match_normalize_text(b.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(b.autor) = v_author_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- 12) TITLE + AUTHOR -> BOOK_DRAFTS
  -- -------------------------------------------------------
  insert into ingest.partner_catalog_match_candidates (
    staging_row_id,
    candidate_type,
    candidate_id,
    match_method,
    match_score,
    details
  )
  select
    p_staging_row_id,
    'book_draft',
    d.id,
    'title_author',
    80.00,
    jsonb_build_object(
      'source_table', 'book_drafts',
      'title', d.titulo,
      'author', d.autor,
      'year', d.ano,
      'publisher', d.editora,
      'place', d.local_publicacao,
      'year_equal',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(d.ano) = v_year_norm
          then true
          else false
        end,
      'year_conflict',
        case
          when v_year_norm is not null
           and ingest.fn_extract_year4(d.ano) is not null
           and ingest.fn_extract_year4(d.ano) <> v_year_norm
          then true
          else false
        end,
      'publisher_match',
        case
          when v_publisher_norm is not null
           and ingest.fn_match_normalize_publisher(d.editora) = v_publisher_norm
          then true
          else false
        end,
      'place_match',
        case
          when v_place_norm is not null
           and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
          then true
          else false
        end,
      'status', d.status,
      'batch_id', d.batch_id,
      'duplicate_signal',
        ingest.fn_classify_duplicate_signal(
          'title_author',
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(d.ano) = v_year_norm
            then true
            else false
          end,
          case
            when v_year_norm is not null
             and ingest.fn_extract_year4(d.ano) is not null
             and ingest.fn_extract_year4(d.ano) <> v_year_norm
            then true
            else false
          end,
          case
            when v_publisher_norm is not null
             and ingest.fn_match_normalize_publisher(d.editora) = v_publisher_norm
            then true
            else false
          end,
          case
            when v_place_norm is not null
             and ingest.fn_match_normalize_text(d.local_publicacao) = v_place_norm
            then true
            else false
          end
        )
    )
  from public.book_drafts d
  where v_title_norm is not null
    and v_author_norm is not null
    and ingest.fn_match_normalize_text(d.titulo) = v_title_norm
    and ingest.fn_match_normalize_text(d.autor) = v_author_norm
  on conflict do nothing;

  -- -------------------------------------------------------
  -- CHOIX DU MEILLEUR CANDIDAT
  -- -------------------------------------------------------
  select
    mc.candidate_type,
    mc.candidate_id,
    mc.match_method,
    mc.match_score
  into
    v_top_candidate_type,
    v_top_candidate_id,
    v_top_match_method,
    v_top_match_score
  from ingest.partner_catalog_match_candidates mc
  where mc.staging_row_id = p_staging_row_id
  order by
    mc.match_score desc,
    case mc.candidate_type
      when 'book' then 0
      when 'book_draft' then 1
      else 9
    end,
    mc.id
  limit 1;

  if v_top_candidate_id is null then
    v_match_status := 'new_record';
  elsif v_top_match_method in ('isbn_exact', 'issn_exact') and v_top_candidate_type = 'book' then
    v_match_status := 'matched_book';
    v_proposed_book_id := v_top_candidate_id;
  elsif v_top_match_method in ('isbn_exact', 'issn_exact') and v_top_candidate_type = 'book_draft' then
    v_match_status := 'matched_draft';
    v_proposed_book_draft_id := v_top_candidate_id;
  elsif v_top_candidate_type = 'book' then
    v_match_status := 'possible_duplicate';
    v_proposed_book_id := v_top_candidate_id;
  elsif v_top_candidate_type = 'book_draft' then
    v_match_status := 'possible_duplicate';
    v_proposed_book_draft_id := v_top_candidate_id;
  else
    v_match_status := 'manual_decision';
  end if;

  update ingest.partner_catalog_staging_rows
     set match_status = v_match_status,
         proposed_book_id = v_proposed_book_id,
         proposed_book_draft_id = v_proposed_book_draft_id
   where id = p_staging_row_id;

  return jsonb_build_object(
    'staging_row_id', p_staging_row_id,
    'match_status', v_match_status,
    'top_candidate_type', v_top_candidate_type,
    'top_candidate_id', v_top_candidate_id,
    'top_match_method', v_top_match_method,
    'top_match_score', v_top_match_score
  );
end;
$function$
;

REVOKE EXECUTE ON FUNCTION ingest.fn_match_partner_catalog_row(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION ingest.fn_match_partner_catalog_row(bigint) TO service_role;

CREATE INDEX IF NOT EXISTS idx_books_isbn_norm    ON public.books (ingest.fn_normalize_isxn(isbn));
CREATE INDEX IF NOT EXISTS idx_books_issn_norm    ON public.books (ingest.fn_normalize_isxn(issn));
CREATE INDEX IF NOT EXISTS idx_books_tit_aut_norm ON public.books (ingest.fn_match_normalize_text(titulo), ingest.fn_match_normalize_text(autor));
CREATE INDEX IF NOT EXISTS idx_bd_isbn_norm    ON public.book_drafts (ingest.fn_normalize_isxn(isbn));
CREATE INDEX IF NOT EXISTS idx_bd_issn_norm    ON public.book_drafts (ingest.fn_normalize_isxn(issn));
CREATE INDEX IF NOT EXISTS idx_bd_tit_aut_norm ON public.book_drafts (ingest.fn_match_normalize_text(titulo), ingest.fn_match_normalize_text(autor));
