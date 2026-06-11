-- Migration : fix promote (FK source_partner_code) + delete run (storage interdit)
-- Auteur  : Claude Opus 4.8
-- Session : Unification partenaire <-> source d'import (fix FK provenance + delete)
-- Date    : 2026-06-11 (UTC)
--
-- BUG A (promote, 3e couche) : a l'insert d'un book_draft, le pont de provenance
-- (trg_sync_book_draft_catalog_context_from_marc_json -> upsert_book_draft_catalog_
-- context_from_marc_json) recopie partner_source/import_format/import_method dans
-- book_draft_catalog_context.*_code, dont source_partner_code FK
-- catalog_ref_source_partners(code). Or 400af5d posait partner_source = nom
-- d'affichage ('CIRA Marseille') -> PAS un code valide -> FK violee -> INSERT en
-- echec -> 0 brouillon. Fix : partner_source = 'other_partner' (code valide),
-- import_format/import_method = NULL (la provenance detaillee reste dans
-- provenance_note + source_label + marc_json.ingest). La rigueur « colonnes
-- structurees » (400af5d) entre en conflit avec les codes FK du pont catalog_context
-- -> reconciliation propre (mapping vers codes ref) a faire a froid.
--
-- BUG B (delete run) : fn_import_delete_run faisait DELETE FROM storage.objects,
-- INTERDIT par Supabase ('Direct deletion from storage tables is not allowed')
-- -> la RPC plantait -> run non supprime. Fix : best-effort (EXCEPTION ignoree).

-- ═══════════════════════════════════════════════════════════════
-- 1. fn_create_book_drafts_from_import_rows — codes provenance compatibles FK
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
      batch_id, action, status, titulo, subtitulo, autor, edicao,
      local_publicacao, editora, ano, isbn, issn, idioma, tipo_material,
      cdd, colecao, marc_json, created_by, updated_by, acquisition_mode,
      partner_source, source_record_id, import_format, import_method,
      provenance_note, mutualization_status, source_label, notas
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
      -- tipo_material : MAP du type brut (RIS/BibTeX) vers le vocabulaire valide.
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
      'other_partner',                               -- partner_source : code valide (FK source_partner_code). Nom precis dans provenance_note/source_label.
      coalesce(nullif(trim(rec.external_key), ''), rec.id::text),
      null,                                          -- import_format : NULL (evite FK source_format_code)
      null,                                          -- import_method : NULL (evite FK import_method_code)
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
-- 2. fn_import_delete_run — suppression storage best-effort
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_import_delete_run(p_run_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, ingest, auth
AS $fn$
DECLARE
  v_actor public.my_access%rowtype;
  v_run   ingest.partner_catalog_import_runs%rowtype;
BEGIN
  SELECT * INTO v_actor FROM public.my_access LIMIT 1;
  IF v_actor.library_id IS NULL OR NOT coalesce(v_actor.can_access_painel, false) THEN
    RAISE EXCEPTION 'Acesso bibliotecario obrigatorio.';
  END IF;
  IF v_actor.role IS DISTINCT FROM 'coordenador' AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao coordenador da biblioteca.';
  END IF;

  SELECT * INTO v_run FROM ingest.partner_catalog_import_runs WHERE id = p_run_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Run % introuvable', p_run_id;
  END IF;
  IF v_run.library_id IS DISTINCT FROM v_actor.library_id
     AND NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Run % nao pertence a esta biblioteca', p_run_id;
  END IF;

  -- Objet storage : la suppression DIRECTE de storage.objects est interdite par
  -- Supabase ('Direct deletion from storage tables is not allowed') -> best-effort,
  -- on ignore l'echec (fichier eventuellement orphelin, non bloquant).
  IF v_run.bucket_id IS NOT NULL AND v_run.storage_path IS NOT NULL THEN
    BEGIN
      DELETE FROM storage.objects
       WHERE bucket_id = v_run.bucket_id AND name = v_run.storage_path;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  -- Le run -> CASCADE sur import_files / staging_rows / row_to_draft / dispatch_log
  DELETE FROM ingest.partner_catalog_import_runs WHERE id = p_run_id;

  RETURN jsonb_build_object('ok', true, 'deleted_run', p_run_id);
END;
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_import_delete_run(bigint) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.fn_import_delete_run(bigint) TO authenticated;

-- ═══════════════════════════════════════════════════════════════
-- 3. Vérification
-- ═══════════════════════════════════════════════════════════════

DO $verif$
DECLARE
  v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='ingest' AND p.proname='fn_create_book_drafts_from_import_rows';
  IF v_src NOT LIKE '%other_partner%' THEN
    RAISE EXCEPTION 'fn_create : partner_source non corrige.';
  END IF;
  SELECT prosrc INTO v_src FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='public' AND p.proname='fn_import_delete_run';
  IF v_src NOT LIKE '%best-effort%' THEN
    RAISE EXCEPTION 'fn_import_delete_run : storage non enrobe.';
  END IF;
  RAISE NOTICE 'Fix OK : provenance FK + delete storage best-effort.';
END
$verif$;
