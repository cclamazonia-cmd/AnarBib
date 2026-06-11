-- Migration : fix génération de brouillons (tipo_material) + OAI (to_jsonb)
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (fix promotion)
-- Date    : 2026-06-11 (UTC)
--
-- BUG 1 (bloquant promotion) : fn_create_book_drafts_from_import_rows posait
-- tipo_material = item_type BRUT du parser RIS ('BOOK', 'JOUR'), or la contrainte
-- book_drafts_tipo_material_check n'accepte que le vocabulaire pt minuscule
-- (livro, periodico, artigo, tese, relatorio, tract, zine, ...). -> CHECK violée,
-- INSERT en échec, 0 brouillon cree (les boutons « ne marchaient pas »). Le
-- fallback 'Livro' (majuscule) echouait aussi. On MAPPE vers une valeur valide.
--
-- BUG 2 (séparé) : fn_import_list_oai_sources appelait row_to_jsonb(sub) — fonction
-- INEXISTANTE (le bon nom est to_jsonb / row_to_json). -> loadOaiSources echouait
-- en silence au chargement de la page (et polluait les logs). Corrige en to_jsonb.

-- ═══════════════════════════════════════════════════════════════
-- 1. fn_create_book_drafts_from_import_rows — mapping tipo_material
-- ═══════════════════════════════════════════════════════════════

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
      -- tipo_material : MAP du type brut (RIS/BibTeX) vers le vocabulaire valide
      -- (book_drafts_tipo_material_check). Defaut : 'livro'.
      case lower(coalesce(nullif(trim(rec.item_type), ''), 'book'))
        when 'book' then 'livro'
        when 'livro' then 'livro'
        when 'jour' then 'periodico'
        when 'mgzn' then 'periodico'
        when 'news' then 'periodico'
        when 'newspaper' then 'periodico'
        when 'periodico' then 'periodico'
        when 'chap' then 'artigo'
        when 'inbook' then 'artigo'
        when 'article' then 'artigo'
        when 'artigo' then 'artigo'
        when 'thes' then 'tese'
        when 'tese' then 'tese'
        when 'rprt' then 'relatorio'
        when 'relatorio' then 'relatorio'
        when 'pamp' then 'tract'
        when 'tract' then 'tract'
        when 'zine' then 'zine'
        when 'elec' then 'recurso_digital'
        when 'sound' then 'audio'
        when 'audio' then 'audio'
        when 'video' then 'audiovisual'
        when 'mpct' then 'audiovisual'
        when 'audiovisual' then 'audiovisual'
        else 'livro'
      end,
      null,
      case
        when v_collection_hint is null then null
        when lower(coalesce(rec.item_type, '')) ~ '(periodic|journal|article|boletim|periodico|periódico|jour)' then null
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

REVOKE EXECUTE ON FUNCTION ingest.fn_create_book_drafts_from_import_rows(bigint, bigint[], text, text, uuid) FROM PUBLIC;

-- ═══════════════════════════════════════════════════════════════
-- 2. fn_import_list_oai_sources — row_to_jsonb -> to_jsonb
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_import_list_oai_sources()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'ingest', 'auth'
AS $function$
DECLARE
  v_actor   public.my_access%rowtype;
  v_is_admin boolean;
  v_result  jsonb;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL
     OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  v_is_admin := public.fn_caller_is_network_admin();

  SELECT coalesce(jsonb_agg(to_jsonb(sub) ORDER BY sub.partner_name), '[]'::jsonb)
    INTO v_result
    FROM (
      SELECT s.id, s.partner_name, s.library_id, s.oai_endpoint_url,
             s.oai_metadata_prefix, s.oai_set, s.import_enabled,
             s.relation_status, s.notes,
             h.harvest_status, h.last_harvest_at,
             h.pending_resumption_token IS NOT NULL AS has_pending_token,
             h.lots_per_cycle, h.lots_completed_this_cycle,
             h.total_records_harvested, h.last_error,
             h.updated_at AS harvest_updated_at
        FROM ingest.partner_catalog_sources s
        LEFT JOIN ingest.oai_harvest_state h ON h.source_id = s.id
       WHERE s.source_kind = 'oai_pmh'
         AND (v_is_admin OR s.library_id = v_actor.library_id)
    ) sub;

  RETURN v_result;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_import_list_oai_sources() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_list_oai_sources() TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 3. Vérification
-- ═══════════════════════════════════════════════════════════════

DO $verif$
DECLARE
  v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='ingest' AND p.proname='fn_create_book_drafts_from_import_rows';
  IF v_src NOT LIKE '%MAP du type brut%' THEN
    RAISE EXCEPTION 'fn_create : mapping tipo_material absent.';
  END IF;
  SELECT prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='fn_import_list_oai_sources';
  IF v_src LIKE '%row_to_jsonb%' THEN
    RAISE EXCEPTION 'fn_import_list_oai_sources : row_to_jsonb encore present.';
  END IF;
  RAISE NOTICE 'Fix OK : tipo_material mappe + OAI to_jsonb.';
END
$verif$;
