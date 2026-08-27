-- =========================================================================
-- Paquet PÉRIODIQUES P7b — Reprendre une notice ne doit plus perdre sa revue
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques — correctif du paquet P7a du même jour
-- Auteur   : Xavier (constat sur données réelles) + Claude (rédaction)
--
-- ⚠️ DÉFAUT CONSTATÉ EN PRODUCTION, LE JOUR MÊME DE LA LIVRAISON. Les quatre
-- notices « Encontros com a Civilização brasileira » avaient été rattachées à
-- leur titre par le paquet P6. Une heure plus tard elles étaient TOUTES
-- détachées (books.serial_id = NULL), sans que personne ait rien demandé de
-- tel, et sans la moindre erreur.
--
-- LA CHAÎNE EXACTE, reconstituée sur les horodatages (07:53, 07:55, 08:18,
-- 08:19 UTC — identiques à la microseconde entre book_drafts.updated_at et
-- books.updated_at) :
--   1. le staff reprend une notice publiée pour la corriger. La reprise passe
--      par create_book_draft_from_book, qui recopie le livre dans un brouillon
--      neuf — isbn, issn, titulo_periodico, volume, numero, fasciculo… mais
--      PAS serial_id, puisque cette fonction est antérieure à la colonne ;
--   2. le brouillon naît donc avec serial_id = NULL ;
--   3. à la republication, la branche UPDATE de publish_book_draft écrit
--      `serial_id = v_draft.serial_id` — c'est-à-dire NULL.
-- Le rattachement est effacé. Silencieusement, et à chaque reprise.
--
-- CE QUE J'AVAIS MAL VU EN P7a. J'avais identifié le risque « republier fait
-- perdre le titre » et je l'ai traité dans le mauvais sens : j'ai fait recopier
-- la valeur du brouillon dans les DEUX branches, ce qui protège le cas « le
-- brouillon porte un titre » et aggrave le cas « le brouillon n'en porte
-- pas ». Le test T29 de la suite le vérifiait — mais avec un brouillon créé
-- AVEC un serial_id. Il ne pouvait pas voir le défaut : le seul cas testé
-- était celui qui marchait.
--
-- TROIS CORRECTIONS, ET IL FAUT LES TROIS :
--   1. create_book_draft_from_book recopie serial_id — la CAUSE. Sans elle,
--      chaque nouvelle reprise recrée le problème.
--   2. publish_book_draft passe à `coalesce(v_draft.serial_id, serial_id)`,
--      exactement comme work_id à la ligne du dessus. C'est le filet : un
--      brouillon sans titre ne peut plus en effacer un. Conséquence assumée —
--      détacher ne se fait plus en republiant, mais par le geste explicite
--      api.fn_serial_detach_issue, qui existe pour ça (même partage que
--      work_id / detach_book_from_work).
--   3. Réparation des données : les brouillons déjà publiés récupèrent le
--      serial_id de leur notice, et les fascicules détachés à tort sont
--      rerattachés par le titre — sur l'égalité STRICTE de la chaîne, comme
--      P6, sans aucun rapprochement approximatif.
--
-- CHECKLIST DOCTRINE
--   [x] CREATE OR REPLACE : signatures et types de retour INCHANGÉS
--   [x] SECURITY DEFINER + search_path conservés à l'identique
--   [x] Réparation de données bornée et idempotente
--   [x] DO block de vérification structurelle
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. La CAUSE : la reprise emporte le titre de revue
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_book_draft_from_book(p_book_id bigint, p_batch_id bigint DEFAULT NULL::bigint)
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
    isbn, issn, serial_id, titulo_periodico, volume, numero, fasciculo, data_edicao, periodicidade,
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
    b.isbn, b.issn, b.serial_id, b.titulo_periodico, b.volume, b.numero, b.fasciculo, b.data_edicao, b.periodicidade,
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

-- -------------------------------------------------------------------------
-- 2. Le FILET : la republication ne peut plus effacer
-- -------------------------------------------------------------------------
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
  v_holding_id bigint;
  v_library_id uuid;
  v_circ_policy text;
  v_auto_tombo text;                         -- #tombo-serie (17/06)
  v_copies int;                              -- #copies (17/08) : nb d'exemplaires initiaux
  v_i int;
  v_valid_types text[] := ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ];
begin
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid()
                   AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft from public.book_drafts where id = p_draft_id;
  if not found then
    raise exception 'rascunho_nao_encontrado' using hint = 'error.publish.draft_not_found';
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'rascunho_descartado' using hint = 'error.publish.draft_cancelled';
  end if;

  if v_draft.titulo is null or btrim(v_draft.titulo) = '' then
    raise exception 'titulo_obrigatorio' using hint = 'error.publish.titulo_required';
  end if;
  if v_draft.bib_ref is null or btrim(v_draft.bib_ref) = '' then
    raise exception 'bib_ref_obrigatoria' using hint = 'error.publish.bib_ref_required';
  end if;
  if v_draft.tipo_material is null or btrim(v_draft.tipo_material) = '' then
    raise exception 'tipo_material_obrigatorio' using hint = 'error.publish.tipo_material_required';
  end if;
  if lower(v_draft.tipo_material) <> ALL(v_valid_types) then
    raise exception 'tipo_material_invalido' using hint = 'error.publish.tipo_material_invalid';
  end if;

  select b.id into v_existing_book_id
    from public.books b
   where b.bib_ref = v_draft.bib_ref
     and (v_draft.published_book_id is null or b.id <> v_draft.published_book_id)
   limit 1;
  if v_existing_book_id is not null then
    raise exception 'bib_ref_duplicado: %', v_existing_book_id
      using errcode = 'P0001',
            hint = format('Ja existe uma ficha publicada com a mesma referencia bibliografica %s (ficha %s). Altere a bib_ref ou verifique a ficha existente.', v_draft.bib_ref, v_existing_book_id);
  end if;
  v_existing_book_id := null;

  if v_draft.published_book_id is null then
    v_isbn_norm := regexp_replace(upper(coalesce(v_draft.isbn, '')), '[^0-9X]', '', 'g');
    if v_isbn_norm <> '' then
      select b.id into v_existing_book_id
        from public.books b
       where regexp_replace(upper(coalesce(b.isbn, '')), '[^0-9X]', '', 'g') = v_isbn_norm
       limit 1;
      if v_existing_book_id is not null then
        raise exception 'isbn_duplicado: %', v_existing_book_id
          using errcode = 'P0001',
                hint = format('Ja existe uma ficha publicada com o mesmo ISBN (ficha %s). Revise o ISBN ou adicione um exemplar a ficha existente.', v_existing_book_id);
      end if;
    end if;

    insert into public.books (
      work_id,
      cdd, autor, titulo, ano, editora, bib_ref, loanable,
      subtitulo, edicao, local_publicacao, isbn, issn, idioma, paginas,
      notas, tipo_material, cover_object_path, marc_json, catalog_source,
      created_by, updated_by, updated_at, last_cataloged_at,
      serial_id,                             -- #périodiques P7 (27/08)
      titulo_periodico, volume, numero, fasciculo, data_edicao,
      periodicidade, colecao, acquisition_mode, acquisition_date,
      owner_library, holder_library, partner_source, source_record_id,
      source_record_url, import_format, import_method, provenance_note,
      mutualization_status, source_label,
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
      distribuidora, gravadora, tese_university, tese_advisor,
      artigo_source, artigo_volume, artigo_issue, artigo_pages,
      relatorio_org, relatorio_recipient, relatorio_internal_notes,
      zine_print_run, zine_technique, zine_format,
      subjects
    )
    values (
      v_draft.work_id,                       -- #œuvre (17/08) : NULL -> fn_books_ensure_work crée une œuvre neuve
      v_draft.cdd, v_draft.autor, v_draft.titulo, v_draft.ano,
      v_draft.editora, v_draft.bib_ref, coalesce(v_draft.loanable, true),
      v_draft.subtitulo, v_draft.edicao, v_draft.local_publicacao,
      v_draft.isbn, v_draft.issn, v_draft.idioma, v_draft.paginas,
      v_draft.notas, v_draft.tipo_material, v_draft.cover_object_path,
      coalesce(v_draft.marc_json, '{}'::jsonb), 'catalogacao',
      coalesce(v_draft.created_by, auth.uid()),
      coalesce(v_draft.updated_by, auth.uid()), now(), now(),
      v_draft.serial_id,                     -- #périodiques P7 (27/08)
      v_draft.titulo_periodico, v_draft.volume, v_draft.numero,
      v_draft.fasciculo, v_draft.data_edicao, v_draft.periodicidade,
      v_draft.colecao, v_draft.acquisition_mode, v_draft.acquisition_date,
      v_draft.owner_library, v_draft.holder_library, v_draft.partner_source,
      v_draft.source_record_id, v_draft.source_record_url,
      v_draft.import_format, v_draft.import_method, v_draft.provenance_note,
      v_draft.mutualization_status, v_draft.source_label,
      v_draft.tract_campaign, v_draft.emitter_org, v_draft.approximate_date,
      v_draft.diffusion_place, v_draft.recto_verso, v_draft.physical_format,
      v_draft.print_technique, v_draft.physical_state,
      v_draft.audio_duration, v_draft.audio_support, v_draft.audio_format,
      v_draft.audio_language, v_draft.audio_participants,
      v_draft.audio_recording_type,
      v_draft.audiovisual_duration, v_draft.audiovisual_support,
      v_draft.audiovisual_language, v_draft.audiovisual_director,
      v_draft.audiovisual_participants, v_draft.audiovisual_subtitles,
      v_draft.audiovisual_access_note,
      v_draft.digital_native_url, v_draft.digital_native_access,
      v_draft.digital_native_restriction, v_draft.digital_native_usage,
      v_draft.digital_native_file_note,
      v_draft.dossier_scope, v_draft.dossier_period,
      v_draft.dossier_organizations, v_draft.dossier_context,
      v_draft.distribuidora, v_draft.gravadora, v_draft.tese_university, v_draft.tese_advisor,
      v_draft.artigo_source, v_draft.artigo_volume, v_draft.artigo_issue,
      v_draft.artigo_pages, v_draft.relatorio_org, v_draft.relatorio_recipient,
      v_draft.relatorio_internal_notes,
      v_draft.zine_print_run, v_draft.zine_technique, v_draft.zine_format,
      v_draft.subjects
    )
    returning id into v_book_id;

    v_library_id := v_draft.owner_library_id;
    if v_library_id is null then
      select ulm.library_id into v_library_id
        from public.user_library_memberships ulm
       where ulm.user_id = coalesce(v_draft.created_by, auth.uid())
       order by ulm.role desc
       limit 1;
    end if;

    -- #biblio-choisie (17/08) : un·e admin réseau peut cibler explicitement la
    -- biblio des exemplaires initiaux. Pour le reste du staff, le champ est ignoré
    -- (garde-fou serveur, indépendant de l'UI).
    if v_draft.initial_copies_library_id is not null and public.fn_caller_is_network_admin() then
      v_library_id := v_draft.initial_copies_library_id;
    end if;

    if v_library_id is not null then
      v_circ_policy := case when coalesce(v_draft.loanable, true) then 'emprestavel' else 'consulta' end;
      insert into public.book_holdings (book_id, library_id)
      values (v_book_id, v_library_id)
      on conflict (book_id, library_id) do update set updated_at = now()
      returning id into v_holding_id;

      -- #copies (17/08) : N exemplaires (défaut 1, borné 1..50). fn_next_tombo,
      -- appelée en boucle dans la même transaction, voit ses propres INSERT et
      -- renvoie des tombos séquentiels distincts (+ verrou d'avis par préfixe).
      v_copies := greatest(1, least(coalesce(v_draft.initial_copies, 1), 50));
      for v_i in 1..v_copies loop
        begin
          v_auto_tombo := public.fn_next_tombo(v_library_id);
        exception when others then
          -- Pas de tombo_pattern : repli sur bib_ref, suffixé pour éviter la
          -- collision d'unicité globale au-delà du 1er exemplaire.
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end;
        if v_auto_tombo is null or btrim(v_auto_tombo) = '' then
          v_auto_tombo := case when v_i = 1 then v_draft.bib_ref
                               else v_draft.bib_ref || '-' || v_i::text end;
        end if;
        insert into public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
        values (v_draft.bib_ref, v_auto_tombo, v_library_id, v_holding_id, v_circ_policy, 'public');
      end loop;

      perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
    end if;

  else
    update public.books
    set
      work_id = coalesce(v_draft.work_id, work_id),
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
      -- #périodiques P7b (27/08) : coalesce, comme work_id juste au-dessus.
      -- Un brouillon antérieur à la colonne porte NULL ; l'écrire tel quel
      -- EFFAÇAIT le rattachement à chaque republication, en silence.
      serial_id = coalesce(v_draft.serial_id, serial_id),
      titulo_periodico = v_draft.titulo_periodico,
      volume = v_draft.volume, numero = v_draft.numero,
      fasciculo = v_draft.fasciculo, data_edicao = v_draft.data_edicao,
      periodicidade = v_draft.periodicidade, colecao = v_draft.colecao,
      acquisition_mode = v_draft.acquisition_mode,
      acquisition_date = v_draft.acquisition_date,
      owner_library = v_draft.owner_library, holder_library = v_draft.holder_library,
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
      print_technique = v_draft.print_technique,
      physical_state = v_draft.physical_state,
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
      distribuidora = v_draft.distribuidora, gravadora = v_draft.gravadora,
      tese_university = v_draft.tese_university, tese_advisor = v_draft.tese_advisor,
      artigo_source = v_draft.artigo_source, artigo_volume = v_draft.artigo_volume,
      artigo_issue = v_draft.artigo_issue, artigo_pages = v_draft.artigo_pages,
      relatorio_org = v_draft.relatorio_org,
      relatorio_recipient = v_draft.relatorio_recipient,
      relatorio_internal_notes = v_draft.relatorio_internal_notes,
      zine_print_run = v_draft.zine_print_run,
      zine_technique = v_draft.zine_technique, zine_format = v_draft.zine_format,
      subjects = v_draft.subjects
    where id = v_draft.published_book_id
    returning id into v_book_id;
  end if;

  update public.book_drafts
  set published_book_id = v_book_id, status = 'published',
      updated_by = coalesce(v_draft.updated_by, auth.uid()), updated_at = now()
  where id = p_draft_id;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);

  return v_book_id;
end;
$function$;

COMMENT ON FUNCTION public.create_book_draft_from_book(bigint, bigint) IS
  'Crée un brouillon de reprise à partir d''une notice publiée. Recopie '
  'serial_id depuis le paquet PÉRIODIQUES P7b du 27/08/2026 : sans cela, la '
  'reprise d''un fascicule produisait un brouillon sans titre de revue, et la '
  'republication effaçait le rattachement en silence.';

COMMENT ON FUNCTION public.publish_book_draft(bigint) IS
  'Publie un brouillon de catalogage en notice books (ou met à jour la notice '
  'déjà publiée). serial_id : recopié à l''INSERT, et en coalesce à l''UPDATE '
  'depuis le paquet PÉRIODIQUES P7b — un brouillon sans titre ne doit pas '
  'pouvoir en effacer un. Détacher se fait par api.fn_serial_detach_issue.';

-- -------------------------------------------------------------------------
-- 3. Réparation des données
-- -------------------------------------------------------------------------
DO $repare$
DECLARE
  v_brouillons int;
  v_rerattaches int;
  v_n int;
  v_couple record;
  v_etats int := 0;
BEGIN
  -- 3.1 Les brouillons déjà publiés récupèrent le titre de LEUR notice.
  -- Idempotent : ne touche que ceux qui n'en ont pas.
  UPDATE public.book_drafts d
     SET serial_id = b.serial_id
    FROM public.books b
   WHERE d.published_book_id = b.id
     AND d.serial_id IS NULL
     AND b.serial_id IS NOT NULL;
  GET DIAGNOSTICS v_brouillons = ROW_COUNT;

  -- 3.2 Les fascicules détachés à tort retrouvent leur titre. Même règle que
  -- P6 : égalité STRICTE de la chaîne, aucun rapprochement approximatif. Un
  -- fascicule dont le titre ne correspond à aucune autorité reste détaché —
  -- c'est au catalogage de trancher, pas à une migration.
  UPDATE public.books b
     SET serial_id = s.id
    FROM public.serials s
   WHERE b.serial_id IS NULL
     AND b.tipo_material = 'periodico'
     AND btrim(coalesce(b.titulo_periodico, '')) = ''
     AND btrim(coalesce(b.titulo, '')) = s.uniform_title;
  GET DIAGNOSTICS v_rerattaches = ROW_COUNT;

  -- Et le cas symétrique (titre transcrit rempli), pour être complet.
  UPDATE public.books b
     SET serial_id = s.id
    FROM public.serials s
   WHERE b.serial_id IS NULL
     AND b.tipo_material = 'periodico'
     AND btrim(coalesce(b.titulo_periodico, '')) = s.uniform_title;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_rerattaches := v_rerattaches + v_n;

  -- 3.3 Recalculer l'état de collection de tout couple concerné.
  FOR v_couple IN
    SELECT DISTINCT b.serial_id, h.library_id
    FROM public.books b
    JOIN public.book_holdings h ON h.book_id = b.id
    WHERE b.serial_id IS NOT NULL
  LOOP
    PERFORM public.fn_recompute_serial_holdings(v_couple.serial_id, v_couple.library_id);
    v_etats := v_etats + 1;
  END LOOP;

  RAISE NOTICE 'Paquet PÉRIODIQUES P7b : % brouillon(s) réparé(s), % fascicule(s) rerattaché(s), % état(s) recalculé(s).',
    v_brouillons, v_rerattaches, v_etats;
END $repare$;

-- -------------------------------------------------------------------------
-- 4. Vérification structurelle
-- -------------------------------------------------------------------------
DO $verif$
DECLARE v_pbd text; v_cbd text;
BEGIN
  v_pbd := pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure);
  v_cbd := pg_get_functiondef('public.create_book_draft_from_book(bigint,bigint)'::regprocedure);

  -- La reprise emporte le titre (la CAUSE).
  IF v_cbd NOT LIKE '%b.serial_id%' THEN
    RAISE EXCEPTION 'P7b : create_book_draft_from_book ne recopie toujours pas serial_id — chaque reprise reperdra le titre.';
  END IF;

  -- La republication ne peut plus effacer (le FILET).
  IF v_pbd NOT LIKE '%coalesce(v_draft.serial_id, serial_id)%' THEN
    RAISE EXCEPTION 'P7b : la branche UPDATE de publish_book_draft peut encore effacer serial_id.';
  END IF;

  -- L'INSERT, lui, doit rester une recopie franche : un brouillon neuf sans
  -- titre ne doit pas hériter d'on ne sait quoi.
  IF v_pbd NOT LIKE '%v_draft.serial_id,%' THEN
    RAISE EXCEPTION 'P7b : la branche INSERT de publish_book_draft ne recopie plus serial_id.';
  END IF;

  -- Les gardes préexistantes n'ont pas été perdues au patch.
  IF v_pbd NOT LIKE '%Acesso restrito ao staff de catalogacao%'
     OR v_pbd NOT LIKE '%bib_ref_duplicado%'
     OR v_pbd NOT LIKE '%isbn_duplicado%' THEN
    RAISE EXCEPTION 'P7b : une garde de publish_book_draft a disparu au patch.';
  END IF;

  RAISE NOTICE 'Paquet PÉRIODIQUES P7b : vérifications structurelles OK (cause, filet, INSERT intact, gardes intactes).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé : réappliquer les définitions du 27/08 (paquet P7a) de
-- publish_book_draft et create_book_draft_from_book. La réparation de données,
-- elle, ne se défait pas — et n'a pas à l'être : elle rétablit un état que le
-- staff avait demandé.
-- =========================================================================
