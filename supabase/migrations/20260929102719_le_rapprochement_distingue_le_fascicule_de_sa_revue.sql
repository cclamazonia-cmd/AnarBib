-- =====================================================================
-- 20260929102719_le_rapprochement_distingue_le_fascicule_de_sa_revue
-- Revue contradictoire de la fin de H27 (29/09/2026) : ce que la preuve de
-- l'aller-retour ne voyait pas, parce qu'elle posait le statut des lignes à la
-- main au lieu de passer par le rapprochement.
--
-- 1. ingest.fn_flag_intra_run_duplicates — la détection des doublons internes
--    à un lot (28/08) groupait par titre + responsabilité. Un export PMB porte
--    des notices de même titre qui ne sont pas la même notice : une revue et
--    ses fascicules (les « notices de bulletin », qui portent les exemplaires),
--    un ensemble et ses tomes. Sur les fixtures PMB : « Géo » ×3,
--    « Chroniques de l'entraide ouvrière » ×3, signalés « doublon possible »
--    — et une ligne signalée par le lot n'a aucun geste à l'écran pour entrer
--    (« Créer » veut new_record, « Rapprocher » veut une notice proposée) : il
--    ne restait que « Rejeter ». La clé prend aussi le numéro (fascicule ou
--    tome) et la date du fascicule. Un CSV ou un RIS ne les décrit pas : leur
--    clé ne change pas (le lot Solidaires se signale comme avant).
-- 2. ingest.fn_match_partner_catalog_row — le rapprochement par ISSN prenait
--    pour candidate toute notice de même ISSN. Or un article porte l'ISSN de
--    sa revue (H17) : la ligne d'une revue pouvait sortir « déjà au
--    catalogue » sur l'un de ses articles. Un article n'est plus candidat, et
--    la ligne d'un article n'est plus rapprochée par ISSN.
--
-- Les deux fonctions sont recréées depuis leur définition réelle, la même au
-- banc et en production (md5 ff74bf9b… et bc3077b9…, lus le 29/09/2026) ;
-- propriétaire, SECURITY DEFINER, search_path et statement_timeout inchangés.
-- =====================================================================

CREATE OR REPLACE FUNCTION ingest.fn_flag_intra_run_duplicates(p_run_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'pg_temp'
AS $function$
declare
  v_lignes  int := 0;
  v_groupes int := 0;
begin
  if not exists (select 1 from ingest.partner_catalog_import_runs where id = p_run_id) then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  -- 1a. Effacer nos propres traces, et seulement les notres. On ne rend son
  --     statut qu'a une ligne que NOUS avions signalee : le warning fait foi.
  update ingest.partner_catalog_staging_rows sr
     set match_status = 'new_record',
         warnings = coalesce((
           select jsonb_agg(w)
             from jsonb_array_elements(coalesce(sr.warnings, '[]'::jsonb)) w
            where w->>'kind' is distinct from 'intra_run_duplicate'
         ), '[]'::jsonb)
   where sr.run_id = p_run_id
     and sr.match_status = 'possible_duplicate'
     and exists (
       select 1 from jsonb_array_elements(coalesce(sr.warnings, '[]'::jsonb)) w
        where w->>'kind' = 'intra_run_duplicate'
     );

  -- 1b. Re-signaler.
  with norme as (
    select sr.id,
           coalesce(sr.external_key, sr.id::text) as cle,
           btrim(regexp_replace(lower(coalesce(sr.title, '')),
                                '[^[:alnum:]]+', ' ', 'g')) as t,
           btrim(regexp_replace(lower(coalesce(sr.responsibility_statement, '')),
                                '[^[:alnum:]]+', ' ', 'g')) as a,
           -- (29/09/2026) Le numero du fascicule ou du tome, et la date du
           -- fascicule : une revue et ses fascicules, deux fascicules, un
           -- ensemble et ses tomes portent le meme titre et la meme
           -- responsabilite sans etre la meme notice. Seul un fichier MARC
           -- les decrit ; un CSV ou un RIS garde la cle d'avant.
           btrim(regexp_replace(lower(coalesce(sr.normalized_payload->'issue'->>'number',
                                               sr.normalized_payload->>'volume', '')),
                                '[^[:alnum:]]+', ' ', 'g'))
             || '/' || btrim(coalesce(sr.normalized_payload->'issue'->>'date', '')) as n
      from ingest.partner_catalog_staging_rows sr
     where sr.run_id = p_run_id
       and sr.match_status in ('unreviewed', 'new_record')
  ),
  groupes as (
    select t, a, n,
           array_agg(id order by id) as ids,
           array_agg(cle order by id) as cles
      from norme
     where t <> ''
     group by t, a, n
    having count(*) > 1
  ),
  aplati as (
    select g.t, g.a, g.n, g.cles, u.id
      from groupes g cross join lateral unnest(g.ids) as u(id)
  ),
  maj as (
    update ingest.partner_catalog_staging_rows sr
       set match_status = 'possible_duplicate',
           warnings = coalesce((
               select jsonb_agg(w)
                 from jsonb_array_elements(coalesce(sr.warnings, '[]'::jsonb)) w
                where w->>'kind' is distinct from 'intra_run_duplicate'
             ), '[]'::jsonb)
             || jsonb_build_array(jsonb_build_object(
                  'kind', 'intra_run_duplicate',
                  'jumelles', to_jsonb(array_remove(
                                f.cles, coalesce(sr.external_key, sr.id::text))),
                  'cle', 'titre+responsabilite+numero'
                ))
      from aplati f
     where sr.id = f.id
    returning sr.id, f.t || '|' || f.a || '|' || f.n as groupe
  )
  select count(*), count(distinct groupe) into v_lignes, v_groupes from maj;

  return jsonb_build_object(
    'run_id',           p_run_id,
    'groupes',          coalesce(v_groupes, 0),
    'lignes_signalees', coalesce(v_lignes, 0)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION ingest.fn_match_partner_catalog_row(p_staging_row_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
 SET statement_timeout TO '120s'
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
    -- (29/09/2026) L'ISSN d'un article est celui de sa revue (H17) : un
    -- article n'est pas la revue, et une ligne d'article n'est pas sa revue.
    and lower(coalesce(b.tipo_material, '')) <> 'artigo'
    and coalesce(rec.normalized_payload->>'material_type', '') <> 'artigo'
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
    and lower(coalesce(d.tipo_material, '')) <> 'artigo'
    and coalesce(rec.normalized_payload->>'material_type', '') <> 'artigo'
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

REVOKE ALL ON FUNCTION ingest.fn_flag_intra_run_duplicates(bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION ingest.fn_match_partner_catalog_row(bigint) FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_flag text := pg_get_functiondef('ingest.fn_flag_intra_run_duplicates(bigint)'::regprocedure);
  v_match text := pg_get_functiondef('ingest.fn_match_partner_catalog_row(bigint)'::regprocedure);
BEGIN
  IF position('group by t, a, n' IN v_flag) = 0 OR position('titre+responsabilite+numero' IN v_flag) = 0 THEN
    RAISE EXCEPTION 'revue H27 : fn_flag_intra_run_duplicates n''a pas sa clé';
  END IF;
  IF (length(v_match) - length(replace(v_match, '<> ''artigo''', ''))) / length('<> ''artigo''') <> 4
     OR position('statement_timeout TO ''120s''' IN v_match) = 0 THEN
    RAISE EXCEPTION 'revue H27 : fn_match_partner_catalog_row n''a pas ses gardes, ou a perdu son délai';
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.routine_privileges
              WHERE routine_schema = 'ingest' AND routine_name IN ('fn_flag_intra_run_duplicates', 'fn_match_partner_catalog_row')
                AND grantee IN ('PUBLIC', 'anon', 'authenticated')) THEN
    RAISE EXCEPTION 'revue H27 : une fonction du rapprochement est ouverte à PUBLIC, anon ou authenticated';
  END IF;
END $$;
