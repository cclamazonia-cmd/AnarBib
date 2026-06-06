-- =========================================================================
-- Ajout de owner_library_id / holder_library_id (uuid FK) sur books et
-- book_drafts — normalisation progressive (strategie additive)
-- =========================================================================
-- Date     : 2026-06-06 23:41 UTC (horodatage reel)
-- Session  : Catalogacao work completion
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- owner_library et holder_library sont des colonnes TEXT sans contrat :
-- certaines lignes contiennent des UUIDs, d'autres des noms de
-- bibliotheque. Aucune FK, aucune validation.
--
-- Cette migration ajoute des colonnes uuid typees avec FK vers
-- libraries(id), peuple les valeurs existantes, normalise les textes
-- incoherents, et met a jour les RPCs pour ecrire dans les deux
-- colonnes (uuid + label) pendant la transition.
--
-- Les colonnes text NE SONT PAS supprimees : elles restent en place
-- pour la retro-compatibilite jusqu'a la prochaine phase de nettoyage.
-- =========================================================================

-- ─── 1. DDL : ajout colonnes ─────────────────────────────────────────────

ALTER TABLE public.books
  ADD COLUMN IF NOT EXISTS owner_library_id uuid REFERENCES public.libraries(id),
  ADD COLUMN IF NOT EXISTS holder_library_id uuid REFERENCES public.libraries(id);

ALTER TABLE public.book_drafts
  ADD COLUMN IF NOT EXISTS owner_library_id uuid REFERENCES public.libraries(id),
  ADD COLUMN IF NOT EXISTS holder_library_id uuid REFERENCES public.libraries(id);

-- ─── 2. Peuplement : mapper les donnees existantes ───────────────────────

-- 2a. books : les valeurs sont des noms de bibliotheque
UPDATE public.books SET
  owner_library_id = (SELECT id FROM public.libraries WHERE name = books.owner_library)
WHERE owner_library IS NOT NULL AND owner_library_id IS NULL;

UPDATE public.books SET
  holder_library_id = (SELECT id FROM public.libraries WHERE name = books.holder_library)
WHERE holder_library IS NOT NULL AND holder_library_id IS NULL;

-- 2b. book_drafts : valeurs mixtes (UUID ou nom)
-- Cas UUID (regex match)
UPDATE public.book_drafts SET
  owner_library_id = owner_library::uuid
WHERE owner_library ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND owner_library_id IS NULL;

UPDATE public.book_drafts SET
  holder_library_id = holder_library::uuid
WHERE holder_library ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  AND holder_library_id IS NULL;

-- Cas nom de bibliotheque
UPDATE public.book_drafts SET
  owner_library_id = (SELECT id FROM public.libraries WHERE name = book_drafts.owner_library)
WHERE owner_library IS NOT NULL
  AND owner_library !~ '^[0-9a-f]{8}-'
  AND owner_library_id IS NULL;

UPDATE public.book_drafts SET
  holder_library_id = (SELECT id FROM public.libraries WHERE name = book_drafts.holder_library)
WHERE holder_library IS NOT NULL
  AND holder_library !~ '^[0-9a-f]{8}-'
  AND holder_library_id IS NULL;

-- ─── 3. Normalisation : remplacer les UUIDs dans les colonnes text ───────
-- par le nom de la bibliotheque (coherence : le champ text = label lisible)

UPDATE public.book_drafts SET
  owner_library = (SELECT name FROM public.libraries WHERE id = owner_library_id)
WHERE owner_library ~ '^[0-9a-f]{8}-'
  AND owner_library_id IS NOT NULL;

UPDATE public.book_drafts SET
  holder_library = (SELECT name FROM public.libraries WHERE id = holder_library_id)
WHERE holder_library ~ '^[0-9a-f]{8}-'
  AND holder_library_id IS NOT NULL;

-- ─── 4. RPCs : dual-write (uuid + label) ─────────────────────────────────

-- 4a. publish_book_draft — ajoute owner_library_id / holder_library_id

CREATE OR REPLACE FUNCTION public.publish_book_draft(p_draft_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_draft public.book_drafts%rowtype;
  v_book_id bigint;
  v_isbn_norm text;
  v_existing_book_id bigint;
begin
  select * into v_draft
  from public.book_drafts
  where id = p_draft_id;

  if not found then
    raise exception 'Rascunho de livro nao encontrado: %', p_draft_id;
  end if;

  if v_draft.status = 'cancelled' then
    raise exception 'Este rascunho de livro foi descartado.';
  end if;

  -- Garde doublon bib_ref (couvre INSERT et UPDATE)
  if v_draft.bib_ref is not null and v_draft.bib_ref <> '' then
    select b.id
      into v_existing_book_id
      from public.books b
     where b.bib_ref = v_draft.bib_ref
       and (v_draft.published_book_id is null or b.id <> v_draft.published_book_id)
     limit 1;
    if v_existing_book_id is not null then
      raise exception 'bib_ref_duplicado: %', v_existing_book_id
        using errcode = 'P0001',
              hint = format(
                'Ja existe uma ficha publicada com a mesma referencia bibliografica %s (ficha %s). Altere a bib_ref ou verifique a ficha existente.',
                v_draft.bib_ref, v_existing_book_id
              );
    end if;
    v_existing_book_id := null;
  end if;

  if v_draft.published_book_id is null then
    -- Garde doublon ISBN (P1.3a)
    v_isbn_norm := regexp_replace(upper(coalesce(v_draft.isbn, '')), '[^0-9X]', '', 'g');
    if v_isbn_norm <> '' then
      select b.id
        into v_existing_book_id
        from public.books b
       where regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') = v_isbn_norm
       limit 1;
      if v_existing_book_id is not null then
        raise exception 'isbn_duplicado: %', v_existing_book_id
          using errcode = 'P0001',
                hint = format(
                  'Ja existe uma ficha publicada com o mesmo ISBN (ficha %s). Revise o ISBN ou adicione um exemplar a ficha existente.',
                  v_existing_book_id
                );
      end if;
    end if;

    insert into public.books (
      cdd, autor, titulo, ano, editora, bib_ref, loanable,
      subtitulo, edicao, local_publicacao, isbn, issn, idioma, paginas, notas,
      tipo_material, cover_object_path, marc_json, catalog_source,
      created_by, updated_by, updated_at, last_cataloged_at,
      titulo_periodico, volume, numero, fasciculo, data_edicao, periodicidade,
      colecao, acquisition_mode, acquisition_date,
      owner_library, holder_library,
      owner_library_id, holder_library_id,
      partner_source, source_record_id, source_record_url,
      import_format, import_method, provenance_note, mutualization_status, source_label,
      tract_campaign, emitter_org, approximate_date, diffusion_place,
      recto_verso, physical_format, print_technique, physical_state,
      audio_duration, audio_support, audio_format, audio_language,
      audio_participants, audio_recording_type,
      audiovisual_duration, audiovisual_support, audiovisual_language,
      audiovisual_director, audiovisual_participants, audiovisual_subtitles,
      audiovisual_access_note,
      digital_native_url, digital_native_access, digital_native_restriction,
      digital_native_usage, digital_native_file_note,
      dossier_scope, dossier_period, dossier_organizations, dossier_context,
      distribuidora, tese_university, tese_advisor,
      artigo_source, artigo_volume, artigo_issue, artigo_pages,
      relatorio_org, relatorio_recipient, relatorio_internal_notes,
      zine_print_run, zine_technique, zine_format,
      subjects, viaf, isni, wikidata
    )
    values (
      v_draft.cdd, v_draft.autor, v_draft.titulo, v_draft.ano, v_draft.editora,
      v_draft.bib_ref, coalesce(v_draft.loanable, true),
      v_draft.subtitulo, v_draft.edicao, v_draft.local_publicacao,
      v_draft.isbn, v_draft.issn, v_draft.idioma, v_draft.paginas, v_draft.notas,
      v_draft.tipo_material, v_draft.cover_object_path,
      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',
      coalesce(v_draft.created_by, auth.uid()), coalesce(v_draft.updated_by, auth.uid()),
      now(), now(),
      v_draft.titulo_periodico, v_draft.volume, v_draft.numero, v_draft.fasciculo,
      v_draft.data_edicao, v_draft.periodicidade,
      v_draft.colecao, v_draft.acquisition_mode, v_draft.acquisition_date,
      v_draft.owner_library, v_draft.holder_library,
      v_draft.owner_library_id, v_draft.holder_library_id,
      v_draft.partner_source, v_draft.source_record_id, v_draft.source_record_url,
      v_draft.import_format, v_draft.import_method, v_draft.provenance_note,
      v_draft.mutualization_status, v_draft.source_label,
      v_draft.tract_campaign, v_draft.emitter_org, v_draft.approximate_date,
      v_draft.diffusion_place, v_draft.recto_verso, v_draft.physical_format,
      v_draft.print_technique, v_draft.physical_state,
      v_draft.audio_duration, v_draft.audio_support, v_draft.audio_format,
      v_draft.audio_language, v_draft.audio_participants, v_draft.audio_recording_type,
      v_draft.audiovisual_duration, v_draft.audiovisual_support, v_draft.audiovisual_language,
      v_draft.audiovisual_director, v_draft.audiovisual_participants,
      v_draft.audiovisual_subtitles, v_draft.audiovisual_access_note,
      v_draft.digital_native_url, v_draft.digital_native_access,
      v_draft.digital_native_restriction, v_draft.digital_native_usage,
      v_draft.digital_native_file_note,
      v_draft.dossier_scope, v_draft.dossier_period, v_draft.dossier_organizations,
      v_draft.dossier_context,
      v_draft.distribuidora, v_draft.tese_university, v_draft.tese_advisor,
      v_draft.artigo_source, v_draft.artigo_volume, v_draft.artigo_issue, v_draft.artigo_pages,
      v_draft.relatorio_org, v_draft.relatorio_recipient, v_draft.relatorio_internal_notes,
      v_draft.zine_print_run, v_draft.zine_technique, v_draft.zine_format,
      v_draft.subjects, v_draft.viaf, v_draft.isni, v_draft.wikidata
    )
    returning id into v_book_id;
  else
    update public.books
    set
      cdd = v_draft.cdd, autor = v_draft.autor, titulo = v_draft.titulo,
      ano = v_draft.ano, editora = v_draft.editora, bib_ref = v_draft.bib_ref,
      loanable = coalesce(v_draft.loanable, true),
      subtitulo = v_draft.subtitulo, edicao = v_draft.edicao,
      local_publicacao = v_draft.local_publicacao,
      isbn = v_draft.isbn, issn = v_draft.issn, idioma = v_draft.idioma,
      paginas = v_draft.paginas, notas = v_draft.notas,
      tipo_material = v_draft.tipo_material,
      cover_object_path = v_draft.cover_object_path,
      marc_json = coalesce(v_draft.marc_json, '{}'::jsonb),
      updated_by = coalesce(v_draft.updated_by, auth.uid()),
      updated_at = now(), last_cataloged_at = now(),
      titulo_periodico = v_draft.titulo_periodico, volume = v_draft.volume,
      numero = v_draft.numero, fasciculo = v_draft.fasciculo,
      data_edicao = v_draft.data_edicao, periodicidade = v_draft.periodicidade,
      colecao = v_draft.colecao, acquisition_mode = v_draft.acquisition_mode,
      acquisition_date = v_draft.acquisition_date,
      owner_library = v_draft.owner_library, holder_library = v_draft.holder_library,
      owner_library_id = v_draft.owner_library_id,
      holder_library_id = v_draft.holder_library_id,
      partner_source = v_draft.partner_source,
      source_record_id = v_draft.source_record_id,
      source_record_url = v_draft.source_record_url,
      import_format = v_draft.import_format, import_method = v_draft.import_method,
      provenance_note = v_draft.provenance_note,
      mutualization_status = v_draft.mutualization_status,
      source_label = v_draft.source_label,
      tract_campaign = v_draft.tract_campaign, emitter_org = v_draft.emitter_org,
      approximate_date = v_draft.approximate_date,
      diffusion_place = v_draft.diffusion_place, recto_verso = v_draft.recto_verso,
      physical_format = v_draft.physical_format,
      print_technique = v_draft.print_technique, physical_state = v_draft.physical_state,
      audio_duration = v_draft.audio_duration, audio_support = v_draft.audio_support,
      audio_format = v_draft.audio_format, audio_language = v_draft.audio_language,
      audio_participants = v_draft.audio_participants,
      audio_recording_type = v_draft.audio_recording_type,
      audiovisual_duration = v_draft.audiovisual_duration,
      audiovisual_support = v_draft.audiovisual_support,
      audiovisual_language = v_draft.audiovisual_language,
      audiovisual_director = v_draft.audiovisual_director,
      audiovisual_participants = v_draft.audiovisual_participants,
      audiovisual_subtitles = v_draft.audiovisual_subtitles,
      audiovisual_access_note = v_draft.audiovisual_access_note,
      digital_native_url = v_draft.digital_native_url,
      digital_native_access = v_draft.digital_native_access,
      digital_native_restriction = v_draft.digital_native_restriction,
      digital_native_usage = v_draft.digital_native_usage,
      digital_native_file_note = v_draft.digital_native_file_note,
      dossier_scope = v_draft.dossier_scope, dossier_period = v_draft.dossier_period,
      dossier_organizations = v_draft.dossier_organizations,
      dossier_context = v_draft.dossier_context,
      distribuidora = v_draft.distribuidora,
      tese_university = v_draft.tese_university, tese_advisor = v_draft.tese_advisor,
      artigo_source = v_draft.artigo_source, artigo_volume = v_draft.artigo_volume,
      artigo_issue = v_draft.artigo_issue, artigo_pages = v_draft.artigo_pages,
      relatorio_org = v_draft.relatorio_org,
      relatorio_recipient = v_draft.relatorio_recipient,
      relatorio_internal_notes = v_draft.relatorio_internal_notes,
      zine_print_run = v_draft.zine_print_run, zine_technique = v_draft.zine_technique,
      zine_format = v_draft.zine_format,
      subjects = v_draft.subjects, viaf = v_draft.viaf, isni = v_draft.isni,
      wikidata = v_draft.wikidata
    where id = v_draft.published_book_id
    returning id into v_book_id;
  end if;

  update public.book_drafts
  set
    published_book_id = v_book_id,
    status = 'published',
    updated_by = coalesce(v_draft.updated_by, auth.uid()),
    updated_at = now()
  where id = p_draft_id;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);

  return v_book_id;
end;
$function$;

-- 4b. create_book_draft_from_book — copie aussi les colonnes _id

CREATE OR REPLACE FUNCTION public.create_book_draft_from_book(p_book_id bigint, p_batch_id bigint DEFAULT NULL)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id bigint;
begin
  insert into public.book_drafts (
    published_book_id, batch_id, action, status,
    bib_ref, titulo, subtitulo, autor, edicao, local_publicacao, editora, ano,
    isbn, issn, titulo_periodico, volume, numero, fasciculo, data_edicao, periodicidade,
    cdd, idioma, paginas, notas, tipo_material, loanable, colecao,
    cover_object_path, marc_json,
    acquisition_mode, acquisition_date,
    owner_library, holder_library,
    owner_library_id, holder_library_id,
    partner_source, source_record_id, source_record_url,
    import_format, import_method, provenance_note, mutualization_status, source_label,
    tract_campaign, emitter_org, approximate_date, diffusion_place,
    recto_verso, physical_format, print_technique, physical_state,
    audio_duration, audio_support, audio_format, audio_language,
    audio_participants, audio_recording_type,
    audiovisual_duration, audiovisual_support, audiovisual_language,
    audiovisual_director, audiovisual_participants, audiovisual_subtitles,
    audiovisual_access_note,
    digital_native_url, digital_native_access, digital_native_restriction,
    digital_native_usage, digital_native_file_note,
    dossier_scope, dossier_period, dossier_organizations, dossier_context,
    created_by, updated_by
  )
  select
    b.id, p_batch_id, 'update', 'draft',
    b.bib_ref, b.titulo, b.subtitulo, b.autor, b.edicao, b.local_publicacao, b.editora, b.ano,
    b.isbn, b.issn, b.titulo_periodico, b.volume, b.numero, b.fasciculo, b.data_edicao, b.periodicidade,
    b.cdd, b.idioma, b.paginas, b.notas, b.tipo_material, b.loanable, b.colecao,
    b.cover_object_path, coalesce(b.marc_json, '{}'::jsonb),
    b.acquisition_mode, b.acquisition_date,
    b.owner_library, b.holder_library,
    b.owner_library_id, b.holder_library_id,
    b.partner_source, b.source_record_id, b.source_record_url,
    b.import_format, b.import_method, b.provenance_note, b.mutualization_status, b.source_label,
    b.tract_campaign, b.emitter_org, b.approximate_date, b.diffusion_place,
    b.recto_verso, b.physical_format, b.print_technique, b.physical_state,
    b.audio_duration, b.audio_support, b.audio_format, b.audio_language,
    b.audio_participants, b.audio_recording_type,
    b.audiovisual_duration, b.audiovisual_support, b.audiovisual_language,
    b.audiovisual_director, b.audiovisual_participants, b.audiovisual_subtitles,
    b.audiovisual_access_note,
    b.digital_native_url, b.digital_native_access, b.digital_native_restriction,
    b.digital_native_usage, b.digital_native_file_note,
    b.dossier_scope, b.dossier_period, b.dossier_organizations, b.dossier_context,
    auth.uid(), auth.uid()
  from public.books b
  where b.id = p_book_id
  returning id into v_id;

  if v_id is null then
    raise exception 'Livro nao encontrado: %', p_book_id;
  end if;

  perform public.copy_book_digital_resources_to_draft(p_book_id, v_id);

  return v_id;
end;
$function$;

-- 4c. network_admin_reassign_book_to_library — ecrit uuid + nom

CREATE OR REPLACE FUNCTION public.network_admin_reassign_book_to_library(p_book_id bigint, p_target_library_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_lib_name       text;
  v_lib_mode       text;
  v_book_loanable  boolean;
  v_target_holding bigint;
  v_old_holdings   bigint[];
  v_moved          integer := 0;
  v_affected       bigint[];
  v_distinct_libs  integer;
BEGIN
  IF NOT public.fn_caller_is_network_admin() THEN
    RAISE EXCEPTION 'Acesso restrito ao administrador de rede.';
  END IF;

  SELECT name, catalog_mode INTO v_lib_name, v_lib_mode
  FROM public.libraries WHERE id = p_target_library_id;
  IF v_lib_name IS NULL THEN
    RAISE EXCEPTION 'Biblioteca alvo inexistente: %', p_target_library_id;
  END IF;
  IF v_lib_mode IS DISTINCT FROM 'network_published' THEN
    RAISE EXCEPTION 'A biblioteca alvo nao tem catalogo presente na rede.';
  END IF;

  SELECT loanable INTO v_book_loanable FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Noticia inexistente: %', p_book_id;
  END IF;

  -- GARDE-FOU : ne pas rapatrier en masse une notice partagee.
  SELECT count(DISTINCT e.library_id) INTO v_distinct_libs
  FROM public.exemplares e
  JOIN public.book_holdings h ON h.id = e.holding_id
  WHERE h.book_id = p_book_id;
  IF COALESCE(v_distinct_libs, 0) > 1 THEN
    RAISE EXCEPTION 'Esta noticia tem exemplares em % bibliotecas. Reatribuicao global bloqueada: use network_admin_reassign_book_from_to_library.', v_distinct_libs;
  END IF;

  SELECT array_agg(id) INTO v_old_holdings
  FROM public.book_holdings WHERE book_id = p_book_id;

  SELECT id INTO v_target_holding
  FROM public.book_holdings
  WHERE book_id = p_book_id AND library_id = p_target_library_id
  LIMIT 1;
  IF v_target_holding IS NULL THEN
    INSERT INTO public.book_holdings (book_id, library_id, loanable, exemplares_total, available_count)
    VALUES (p_book_id, p_target_library_id, COALESCE(v_book_loanable, true), 0, 0)
    RETURNING id INTO v_target_holding;
  END IF;

  UPDATE public.exemplares e
  SET holding_id = v_target_holding,
      library_id = p_target_library_id,
      updated_at = now()
  WHERE e.holding_id IN (SELECT id FROM public.book_holdings WHERE book_id = p_book_id)
    AND e.holding_id IS DISTINCT FROM v_target_holding;
  GET DIAGNOSTICS v_moved = ROW_COUNT;

  UPDATE public.books
  SET owner_library = v_lib_name,
      holder_library = v_lib_name,
      owner_library_id = p_target_library_id,
      holder_library_id = p_target_library_id,
      updated_at = now()
  WHERE id = p_book_id;

  v_affected := COALESCE(v_old_holdings, ARRAY[]::bigint[]) || v_target_holding;
  PERFORM public.fn_v2_recompute_holdings_availability(v_affected, ARRAY[p_book_id]);

  PERFORM public.fn_log_cross_library_action(
    p_target_library_id, 'reassign_book_to_library', true, 'book', NULL,
    jsonb_build_object('book_id', p_book_id, 'target_library', v_lib_name, 'exemplares_moved', v_moved)
  );

  RETURN jsonb_build_object(
    'ok', true,
    'target_library', v_lib_name,
    'exemplares_moved', v_moved,
    'target_holding', v_target_holding
  );
END;
$function$;

-- ─── 5. Vue : ajouter les colonnes _id ───────────────────────────────────

DROP VIEW IF EXISTS public.v_catalog_books_editable;
CREATE VIEW public.v_catalog_books_editable
  WITH (security_invoker = true)
AS
WITH holdings_source AS (
  SELECT h.id AS holding_id, h.book_id,
    b.bib_ref AS book_bib_ref,
    COALESCE(NULLIF(TRIM(BOTH FROM h.local_bib_ref), ''), b.bib_ref) AS local_bib_ref,
    h.library_id, l.slug AS library_slug, l.name AS library_name,
    l.short_name, l.city, l.state,
    COALESCE(h.loanable, b.loanable, true) AS holding_loanable,
    COALESCE(h.exemplares_total, 0) AS holding_exemplares_total,
    COALESCE(h.available_count, 0) AS holding_available_count
  FROM book_holdings h
  JOIN books b ON b.id = h.book_id
  JOIN libraries l ON l.id = h.library_id
), exemplares_by_holding AS (
  SELECT e.holding_id,
    count(*)::integer AS exemplares_total_real,
    jsonb_agg(e.tombo ORDER BY e.tombo)
      FILTER (WHERE NULLIF(TRIM(BOTH FROM COALESCE(e.tombo, '')), '') IS NOT NULL) AS tombos_json
  FROM exemplares e WHERE e.holding_id IS NOT NULL
  GROUP BY e.holding_id
), holdings_enriched AS (
  SELECT hs.*, COALESCE(hs.holding_exemplares_total, exh.exemplares_total_real, 0) AS holding_exemplares_total_final,
    COALESCE(exh.tombos_json, '[]'::jsonb) AS tombos_json
  FROM holdings_source hs
  LEFT JOIN exemplares_by_holding exh ON exh.holding_id = hs.holding_id
), holdings_rollup_by_book AS (
  SELECT he.book_id,
    COALESCE(sum(he.holding_exemplares_total_final), 0)::integer AS total_exemplares,
    count(*)::integer AS bibliotecas_count,
    COALESCE(sum(he.holding_available_count), 0)::integer AS total_available_count_local,
    jsonb_agg(jsonb_build_object(
      'holding_id', he.holding_id, 'library_id', he.library_id,
      'library_slug', he.library_slug, 'library_name', he.library_name,
      'short_name', he.short_name, 'city', he.city, 'state', he.state,
      'local_bib_ref', he.local_bib_ref, 'loanable', he.holding_loanable,
      'available_count', he.holding_available_count,
      'exemplares_total', he.holding_exemplares_total_final,
      'tombos_json', he.tombos_json
    ) ORDER BY he.library_name, he.library_slug, he.holding_id) AS holding_libraries_json,
    jsonb_agg(
      COALESCE(NULLIF(TRIM(he.library_name), ''), NULLIF(TRIM(he.short_name), ''), upper(he.library_slug))
      ORDER BY he.library_name, he.library_slug, he.holding_id
    ) FILTER (WHERE COALESCE(NULLIF(TRIM(he.library_name), ''), NULLIF(TRIM(he.short_name), ''), NULLIF(TRIM(he.library_slug), '')) IS NOT NULL) AS holding_library_names_json
  FROM holdings_enriched he
  GROUP BY he.book_id
)
SELECT b.id, b.cdd, b.autor, b.titulo, b.ano, b.editora,
  b.available_count, b.created_at, b.bib_ref, b.loanable,
  b.subtitulo, b.edicao, b.local_publicacao,
  b.isbn, b.issn, b.idioma, b.paginas, b.notas,
  b.tipo_material, b.cover_object_path, b.marc_json,
  b.catalog_source, b.created_by, b.updated_by, b.updated_at, b.last_cataloged_at,
  b.titulo_periodico, b.volume, b.numero, b.fasciculo, b.data_edicao, b.periodicidade,
  b.autores_secundarios, b.colecao, b.assuntos, b.tradutor, b.organizador,
  COALESCE(hr.total_exemplares, 0) AS total_exemplares,
  b.acquisition_mode, b.acquisition_date,
  b.owner_library, b.holder_library,
  b.owner_library_id, b.holder_library_id,
  b.partner_source, b.source_record_id, b.source_record_url,
  b.import_format, b.import_method, b.provenance_note,
  b.mutualization_status, b.source_label,
  b.tract_campaign, b.emitter_org, b.approximate_date, b.diffusion_place,
  b.recto_verso, b.physical_format, b.print_technique, b.physical_state,
  b.audio_duration, b.audio_support, b.audio_format, b.audio_language,
  b.audio_participants, b.audio_recording_type,
  b.audiovisual_duration, b.audiovisual_support, b.audiovisual_language,
  b.audiovisual_director, b.audiovisual_participants, b.audiovisual_subtitles,
  b.audiovisual_access_note,
  b.digital_native_url, b.digital_native_access, b.digital_native_restriction,
  b.digital_native_usage, b.digital_native_file_note,
  b.dossier_scope, b.dossier_period, b.dossier_organizations, b.dossier_context,
  COALESCE(hr.bibliotecas_count, 0) AS bibliotecas_count,
  COALESCE(hr.holding_libraries_json, '[]'::jsonb) AS holding_libraries_json,
  COALESCE(hr.holding_library_names_json, '[]'::jsonb) AS holding_library_names_json,
  COALESCE(hr.total_available_count_local, 0) AS total_available_count_local
FROM books b
LEFT JOIN holdings_rollup_by_book hr ON hr.book_id = b.id;

-- ─── 6. Verification ─────────────────────────────────────────────────────

DO $verif$
DECLARE
  v_orphan_books integer;
  v_orphan_drafts integer;
BEGIN
  -- Verifier que toutes les valeurs non-null ont ete mappees
  SELECT count(*) INTO v_orphan_books
  FROM public.books
  WHERE owner_library IS NOT NULL AND owner_library_id IS NULL;
  IF v_orphan_books > 0 THEN
    RAISE WARNING 'books: % lignes avec owner_library non-null mais owner_library_id null', v_orphan_books;
  END IF;

  SELECT count(*) INTO v_orphan_drafts
  FROM public.book_drafts
  WHERE owner_library IS NOT NULL AND owner_library_id IS NULL;
  IF v_orphan_drafts > 0 THEN
    RAISE WARNING 'book_drafts: % lignes avec owner_library non-null mais owner_library_id null', v_orphan_drafts;
  END IF;

  -- Verifier que les RPCs ont les nouvelles colonnes
  IF position('owner_library_id' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: owner_library_id absent de publish_book_draft';
  END IF;
  IF position('owner_library_id' IN
       pg_get_functiondef('public.create_book_draft_from_book(bigint,bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: owner_library_id absent de create_book_draft_from_book';
  END IF;
  IF position('owner_library_id' IN
       pg_get_functiondef('public.network_admin_reassign_book_to_library(bigint,uuid)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: owner_library_id absent de network_admin_reassign_book_to_library';
  END IF;
  -- Gardes precedentes toujours presentes
  IF position('bib_ref_duplicado' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde bib_ref_duplicado absente (regression)';
  END IF;
  IF position('isbn_duplicado' IN
       pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'VERIF: garde isbn_duplicado absente (regression)';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';
