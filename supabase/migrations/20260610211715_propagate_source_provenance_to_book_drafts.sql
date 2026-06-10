-- Migration : propager la provenance STRUCTURÉE sur les book_drafts importés
-- Auteur  : Claude Opus 4.8
-- Session : Rigueur de source à l'import (inc. A — propagation)
-- Date    : 2026-06-10 (UTC)
--
-- CONSTAT. La chaîne d'import capture une provenance riche (source, run,
-- empreinte fichier, format, opérateur·rice) mais ingest.fn_create_book_drafts_
-- from_import_rows (appelée par fn_bulk_create_book_drafts_from_run, donc par le
-- wizard) ne la déversait QUE dans le texte libre provenance_note + le blob
-- marc_json.ingest. Les COLONNES STRUCTURÉES partner_source / import_format /
-- import_method restaient à NULL — alors que la donnée est déjà dans le curseur.
-- Conséquence : provenance non requêtable, non affichable proprement.
--
-- CORRECTION (extension de la rigueur catalographique à l'import) : on renseigne
-- ces 3 colonnes depuis la source/run déjà jointes. Trois changements seulement :
--   1. le curseur sélectionne aussi s.source_kind ;
--   2. partner_source := rec.partner_name (au lieu de null) ;
--   3. import_format := rec.detected_format (au lieu de null) ;
--   4. import_method := coalesce(rec.source_kind, 'partner_catalog') (au lieu de null).
-- Le reste de la fonction est reproduit À L'IDENTIQUE (CREATE OR REPLACE conserve
-- les GRANT existants ; search_path et SECURITY DEFINER préservés).

CREATE OR REPLACE FUNCTION ingest.fn_create_book_drafts_from_import_rows(
  p_run_id bigint,
  p_row_ids bigint[] DEFAULT NULL::bigint[],
  p_batch_name text DEFAULT NULL::text,
  p_batch_notes text DEFAULT NULL::text,
  p_created_by uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'ingest', 'public', 'auth'
AS $function$
declare
  v_actor uuid;
  v_partner_name text;
  v_relation_status text;
  v_original_filename text;
  v_detected_format text;
  v_batch_id bigint;
  v_batch_name text;
  v_batch_notes text;
  v_created_count integer := 0;
  v_requested_count integer := 0;
  v_draft_id bigint;
  v_refresh jsonb;
  v_collection_hint text;
  v_local_classification_hint text;
  v_provenance_note text;
  rec record;
begin
  v_actor := coalesce(p_created_by, auth.uid());

  select s.partner_name, s.relation_status, r.original_filename, r.detected_format
    into v_partner_name, v_relation_status, v_original_filename, v_detected_format
  from ingest.partner_catalog_import_runs r
  join ingest.partner_catalog_sources s on s.id = r.source_id
  where r.id = p_run_id;

  if not found then
    raise exception 'import_run % introuvable', p_run_id;
  end if;

  if coalesce(array_length(p_row_ids, 1), 0) > 0 then
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.id = any(p_row_ids)
      and sr.created_book_draft_id is null
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  else
    select count(*)::integer
      into v_requested_count
    from ingest.partner_catalog_staging_rows sr
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and sr.selected_for_draft = true
      and sr.review_status = 'approved'
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      );
  end if;

  if v_requested_count = 0 then
    raise exception 'Aucune ligne autorisée à convertir pour le run %', p_run_id;
  end if;

  v_batch_name := coalesce(
    nullif(trim(p_batch_name), ''),
    format(
      'Import parceiro #%s — %s — %s',
      p_run_id,
      left(coalesce(v_partner_name, 'parceiro sem nome'), 80),
      to_char(now() at time zone 'UTC', 'YYYY-MM-DD HH24:MI UTC')
    )
  );

  v_batch_notes := coalesce(
    nullif(trim(p_batch_notes), ''),
    format(
      'Lote criado a partir do import run %s (%s, formato %s).',
      p_run_id,
      coalesce(v_original_filename, 'arquivo sem nome'),
      coalesce(v_detected_format, 'unknown')
    )
  );

  insert into public.catalog_batches (name, notes, created_by)
  values (v_batch_name, v_batch_notes, v_actor)
  returning id into v_batch_id;

  for rec in
    select sr.*, r.original_filename, r.detected_format, s.partner_name, s.relation_status, s.source_kind
    from ingest.partner_catalog_staging_rows sr
    join ingest.partner_catalog_import_runs r on r.id = sr.run_id
    join ingest.partner_catalog_sources s on s.id = r.source_id
    where sr.run_id = p_run_id
      and sr.created_book_draft_id is null
      and not exists (
        select 1 from ingest.partner_catalog_row_to_draft rd where rd.staging_row_id = sr.id
      )
      and (
        (coalesce(array_length(p_row_ids, 1), 0) > 0 and sr.id = any(p_row_ids))
        or
        (coalesce(array_length(p_row_ids, 1), 0) = 0 and sr.selected_for_draft = true and sr.review_status = 'approved')
      )
      and (
        (sr.match_status = 'new_record' and sr.editorial_decision = 'accept_new')
        or
        (sr.match_status in ('matched_book', 'matched_draft', 'possible_duplicate', 'manual_decision')
         and sr.editorial_decision = 'accept_duplicate')
      )
    order by sr.row_no, sr.id
  loop
    v_collection_hint := ingest.fn_partner_catalog_extract_collection_hint(rec.normalized_payload, rec.raw_payload);
    v_local_classification_hint := ingest.fn_partner_catalog_extract_local_classification_hint(rec.normalized_payload, rec.raw_payload);

    v_provenance_note := format(
      'Importado de catálogo parceiro "%s" (%s, run %s, linha %s, formato bruto %s, relação %s, decisão %s).',
      rec.partner_name,
      coalesce(rec.original_filename, 'arquivo sem nome'),
      rec.run_id,
      rec.row_no,
      coalesce(rec.detected_format, 'unknown'),
      coalesce(rec.relation_status, 'sem_status'),
      coalesce(rec.editorial_decision, 'pending')
    );

    if v_local_classification_hint is not null then
      v_provenance_note := v_provenance_note || format(' Sinal local da parceira preservado: %s.', v_local_classification_hint);
    end if;

    insert into public.book_drafts (
      batch_id,
      action,
      status,
      titulo,
      subtitulo,
      autor,
      edicao,
      local_publicacao,
      editora,
      ano,
      isbn,
      issn,
      idioma,
      tipo_material,
      cdd,
      colecao,
      marc_json,
      created_by,
      updated_by,
      acquisition_mode,
      partner_source,
      source_record_id,
      import_format,
      import_method,
      provenance_note,
      mutualization_status,
      source_label,
      notas
    ) values (
      v_batch_id,
      'create',
      'draft',
      nullif(trim(rec.title), ''),
      nullif(trim(rec.subtitle), ''),
      coalesce(nullif(trim(rec.responsibility_statement), ''), ingest.fn_format_partner_authors(rec.authors)),
      nullif(trim(rec.edition_statement), ''),
      nullif(trim(rec.place_of_publication), ''),
      nullif(trim(rec.publisher), ''),
      nullif(trim(rec.publication_year), ''),
      nullif(trim(rec.isbn), ''),
      nullif(trim(rec.issn), ''),
      nullif(trim(rec.language), ''),
      coalesce(nullif(trim(rec.item_type), ''), 'Livro'),
      null,
      case
        when v_collection_hint is null then null
        when lower(coalesce(rec.item_type, '')) ~ '(periodic|journal|article|boletim|periodico|periódico)' then null
        when lower(regexp_replace(coalesce(v_collection_hint, ''), '\s+', ' ', 'g')) = lower(regexp_replace(coalesce(rec.title, ''), '\s+', ' ', 'g')) then null
        else v_collection_hint
      end,
      coalesce(rec.normalized_payload, '{}'::jsonb)
        || jsonb_build_object(
             'ingest',
             jsonb_build_object(
               'run_id', rec.run_id,
               'staging_row_id', rec.id,
               'row_no', rec.row_no,
               'source_file_id', rec.source_file_id,
               'partner_name', rec.partner_name,
               'relation_status', rec.relation_status,
               'original_filename', rec.original_filename,
               'detected_format', rec.detected_format,
               'raw_payload', coalesce(rec.raw_payload, '{}'::jsonb),
               'authors', coalesce(rec.authors, '[]'::jsonb),
               'subjects', coalesce(rec.subjects, '[]'::jsonb),
               'editorial_decision', rec.editorial_decision,
               'editorial_note', rec.editorial_note,
               'derived_collection_hint', v_collection_hint,
               'derived_local_classification_hint', v_local_classification_hint
             )
           ),
      v_actor,
      v_actor,
      null,
      rec.partner_name,                              -- partner_source (rigueur source)
      coalesce(nullif(trim(rec.external_key), ''), rec.id::text),
      rec.detected_format,                           -- import_format (rigueur source)
      coalesce(rec.source_kind, 'partner_catalog'),  -- import_method (rigueur source)
      v_provenance_note,
      null,
      coalesce(rec.original_filename, rec.partner_name),
      concat_ws(
        ' ',
        case
          when rec.subjects is not null
           and jsonb_typeof(rec.subjects) = 'array'
           and jsonb_array_length(rec.subjects) > 0
          then 'Assuntos importados: '
               || array_to_string(array(select jsonb_array_elements_text(rec.subjects)), '; ')
          else null
        end,
        case
          when v_local_classification_hint is not null
          then format('Classificação / cote local preservada da parceira: %s.', v_local_classification_hint)
          else null
        end
      )
    ) returning id into v_draft_id;

    insert into ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id, created_by)
    values (rec.id, rec.run_id, v_draft_id, v_batch_id, v_actor);

    update ingest.partner_catalog_staging_rows
       set created_book_draft_id = v_draft_id,
           review_status = 'draft_created',
           selected_for_draft = false
     where id = rec.id;

    v_created_count := v_created_count + 1;
  end loop;

  if v_created_count = 0 then
    delete from public.catalog_batches where id = v_batch_id;
    raise exception 'Aucun rascunho créé pour le run %', p_run_id;
  end if;

  v_refresh := ingest.fn_refresh_partner_catalog_run_counters(p_run_id);

  return jsonb_build_object(
    'run_id', p_run_id,
    'batch_id', v_batch_id,
    'batch_name', v_batch_name,
    'requested_rows', v_requested_count,
    'created_drafts', v_created_count,
    'run', v_refresh
  );
end;
$function$;

-- Doctrine SECURITY DEFINER : verrou d'exécution PUBLIC (idempotent). La fonction
-- vit dans le schéma ingest (aucun USAGE pour authenticated/anon) et n'est appelée
-- qu'en contexte définisseur par fn_bulk_create_book_drafts_from_run ; ce REVOKE
-- ré-affirme la doctrine sans modifier les GRANT applicatifs préservés par REPLACE.
REVOKE EXECUTE ON FUNCTION ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid) FROM PUBLIC;

-- Vérification : les 3 colonnes structurées sont désormais renseignées.
DO $verif$
DECLARE
  v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='ingest' AND p.proname='fn_create_book_drafts_from_import_rows';
  IF v_src NOT LIKE '%-- partner_source (rigueur source)%'
     OR v_src NOT LIKE '%-- import_format (rigueur source)%'
     OR v_src NOT LIKE '%-- import_method (rigueur source)%' THEN
    RAISE EXCEPTION 'Propagation provenance : la fonction ne renseigne pas les 3 colonnes structurées.';
  END IF;
  RAISE NOTICE 'Propagation provenance OK : partner_source / import_format / import_method renseignés.';
END
$verif$;
