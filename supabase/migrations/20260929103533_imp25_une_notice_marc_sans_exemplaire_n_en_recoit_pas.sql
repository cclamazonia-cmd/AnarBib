-- =====================================================================
-- 20260929103533_imp25_une_notice_marc_sans_exemplaire_n_en_recoit_pas
-- IMP-25 (décision de Xavier, 28/09/2026) — une notice importée sans
-- exemplaire n'en reçoit pas d'automatique, quand le fichier sait en décrire.
--
-- Trouvé par H27 (réimport dans PMB de l'export tiré de la base) : à la
-- publication, toute notice sans brouillon d'exemplaire recevait un exemplaire
-- automatique ; les 22 notices des fixtures PMB qui n'en ont pas (15 articles,
-- 3 périodiques, 4 monographies) en recevaient un, que l'export rendait à PMB
-- (qui en refusait 15, posés sur des articles).
-- La règle ne vaut que pour un fichier MARC lu avec sa zone d'exemplaire
-- (marc_json.ingest.raw_payload.item_tag, posé par l'edge function d'import) :
-- là, « aucun exemplaire » est une information du fichier. Un CSV ou un RIS ne
-- décrit jamais d'exemplaire — l'exemplaire automatique reste le seul chemin
-- (lu le 28/09 : les 1 673 brouillons du lot 63, un CSV, n'en ont pas d'autre).
-- La notice reste détenue par la bibliothèque (book_holdings) ; un exemplaire
-- s'ajoute après la publication s'il en faut un.
-- Aucun rattrapage : 0 brouillon MARC ouvert en production (lu le 28/09).
-- publish_book_draft recréée depuis sa définition réelle (md5 c1ad0b79…),
-- une expression changée.
-- =====================================================================

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
  v_linked int := 0;                         -- H19 : exemplaires importés rattachés
  v_x record;
  v_valid_types text[] := ARRAY[
    'livro','periodico','tract','cartaz','audio','audiovisual',
    'recurso_digital','dossie','tese','artigo','relatorio','zine'
  ];
begin
  -- B30 : le staff de catalogage ACTIF, ou l'administration du réseau — les
  -- lots sans bibliothèque ne sont qu'à elle ; la garde #79 ne demandait pas
  -- d'adhésion active et fermait la porte à l'administration sans adhésion.
  IF NOT (public.fn_caller_is_network_admin()
          OR EXISTS (SELECT 1 FROM public.user_library_memberships m
                      WHERE m.user_id = auth.uid() AND m.status = 'active'
                        AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text]))) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.' USING HINT = 'error.catalog.staff_only';
  END IF;
  select * into v_draft from public.book_drafts where id = p_draft_id;
  if not found then
    raise exception 'rascunho_nao_encontrado' using hint = 'error.publish.draft_not_found';
  end if;
  -- B29 (CAT-E18) : on ne publie que les brouillons de ses bibliothèques
  -- (celle du brouillon, sinon celle de son créateur), ou comme administration.
  -- Avant tout autre contrôle : aucun ne renseigne sur le brouillon d'autrui.
  if not coalesce(public.fn_caller_can_edit_book_draft(p_draft_id), false) then
    raise exception 'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre.' using hint = 'error.publish.other_library';
  end if;
  if v_draft.status = 'cancelled' then
    raise exception 'rascunho_descartado' using hint = 'error.publish.draft_cancelled';
  end if;

  -- 05/09/2026 : un lot ne d'un import ne se publie qu'apres une revision
  -- approuvee par l'administration du reseau (catalog_batch_reviews).
  -- publish_catalog_batch passe ici pour chaque brouillon : la garde le couvre.
  if v_draft.batch_id is not null
     and public.fn_batch_is_imported(v_draft.batch_id)
     and public.fn_batch_review_status(v_draft.batch_id) is distinct from 'approved' then
    raise exception 'lote_importado_sem_revisao' using hint = 'error.publish.review_required';
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
         -- Volumes (27/09/2026) : l'ISBN d'un ensemble est porté par chacun de
         -- ses volumes (BTL-TL-000447 et BTL-TL-000448 : volumes 2 et 3 de « La
         -- C.N.T. y la Revolución Española », même ISBN). Deux notices qui portent
         -- des numéros de volume DIFFÉRENTS ne sont pas des doublons : refuser la
         -- seconde poussait, par le message ci-dessous, à enregistrer le volume 4
         -- comme un exemplaire du volume 2. Même volume, ou volume absent d'un
         -- côté : doublon, comme avant.
         and not (nullif(btrim(coalesce(v_draft.volume, '')), '') is not null
                  and nullif(btrim(coalesce(b.volume, '')), '') is not null
                  and lower(btrim(b.volume)) <> lower(btrim(v_draft.volume)))
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
      notas, tipo_material, cover_object_path, cover_source, cover_license, marc_json, catalog_source,
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
      v_draft.cover_source, v_draft.cover_license,  -- capas (27/09) : provenance et licence de l'image
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

    -- #biblio-choisie (17/08, elargi le 29/08/2026). La regle voulue : choisir
    -- explicitement la bibliotheque de destination est reserve a l'admin reseau.
    -- Elle etait posee sur initial_copies_library_id SEULEMENT, alors que
    -- owner_library_id est lu AVANT lui, decide donc en premier, et se modifie
    -- librement par toute personne qui catalogue (policy ALL sans portee de
    -- bibliotheque, UPDATE sur les 103 colonnes). La regle etait donc appliquee
    -- sur un champ et ouverte sur celui qui a la priorite.
    v_library_id := v_draft.owner_library_id;

    -- Publier dans le catalogue d'une bibliotheque, c'est y creer un holding et
    -- un exemplaire avec un tombo pris dans SA serie : on ne le fait pas au nom
    -- d'un collectif dont on n'est pas membre.
    if v_library_id is not null
       and not public.fn_caller_is_network_admin()
       and not exists (
         select 1 from public.user_library_memberships ulm
          where ulm.user_id = auth.uid()
            and ulm.status = 'active'
            and ulm.role = any (array['librarian'::text, 'coordenador'::text])
            and ulm.library_id = v_library_id
       ) then
      raise exception
        'Ce rascunho est rattache a une bibliotheque dont vous n''etes pas membre (%).', v_library_id
        using hint = 'error.publish.other_library';
    end if;

    -- La regle de resolution vit desormais dans UNE fonction, appelee ici et
    -- par la vue qui l'affiche a l'ecran. Deux copies d'une meme regle
    -- derivent : ce depot en a paye assez pour ne pas recommencer.
    -- B30 (revue) : une notice IMPORTÉE sans bibliothèque (dépôt d'une compagne
    -- non admise, destination inconnue) ne se publie pas : le repli ci-dessous
    -- la mettrait dans la bibliothèque de qui publie — ou nulle part, pour une
    -- administration sans adhésion. Sa bibliothèque vient du lot (« Changer la
    -- bibliothèque du lot »), ou d'un choix explicite de l'administration.
    if v_library_id is null
       and not (v_draft.initial_copies_library_id is not null and public.fn_caller_is_network_admin())
       -- importée : le lien d'import, ou la trace que la promotion laisse dans
       -- marc_json (le lien part avec une suppression définitive ou avec le run ;
       -- le rejeu du journal ne le recrée pas, la trace reste)
       and (exists (select 1 from ingest.partner_catalog_row_to_draft m where m.draft_id = p_draft_id)
            or coalesce(v_draft.marc_json, '{}'::jsonb) ? 'ingest')
       -- avec des exemplaires importés, le refus H19 ci-dessous dit mieux ce qui manque
       and not exists (select 1 from public.exemplar_drafts x
                        where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      raise exception 'noticia_importada_sem_biblioteca' using hint = 'error.publish.record_without_library';
    end if;
    if v_library_id is null then
      v_library_id := public.fn_book_draft_destination_library(p_draft_id);
    end if;

    -- L'override admin reste le seul chemin pour cibler une autre bibliotheque.
    -- H19 (27/09/2026, revue) : une notice qui porte des exemplaires importés
    -- les publie là où ils ont été attribués (tampon, réattribution du lot) ;
    -- le choix « exemplaires initiaux » de l'écran ne les sépare pas d'elle.
    if v_draft.initial_copies_library_id is not null and public.fn_caller_is_network_admin()
       and not exists (select 1 from public.exemplar_drafts x
                        where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      v_library_id := v_draft.initial_copies_library_id;
    end if;

    -- H19 : les exemplaires importés vont dans la bibliothèque qui leur a été
    -- DONNÉE (tampon à la promotion, ou réattribution par l'administration),
    -- jamais dans celle que le repli ci-dessus déduit de qui publie : c'est
    -- ainsi que le fonds d'une compagne non admise partirait chez qui clique
    -- (vu au banc le 26/09, suite import_exemplaires T6). Sans bibliothèque :
    -- refus ; bibliothèque différente de celle de la notice : refus.
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
                  and x.target_library_id is null) then
      raise exception 'exemplares_importados_sem_biblioteca'
        using hint = 'error.publish.items_without_library';
    end if;
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
                  and x.target_library_id is distinct from v_library_id) then
      raise exception 'exemplares_importados_de_outra_biblioteca'
        using hint = 'error.publish.items_library_mismatch';
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
      -- H19 : les exemplaires du fichier importé REMPLACENT l'exemplaire
      -- automatique (sinon N importés + 1 automatique). Ils sont publiés plus
      -- bas, une fois la notice marquée publiée.
      select count(*) into v_linked
        from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready');
      -- IMP-25 (28/09) : un fichier MARC lu avec sa zone d'exemplaire (995 / 852)
      -- qui n'en décrit aucun pour cette notice n'en fait pas créer : « aucun
      -- exemplaire » est alors une information du fichier (un article, un
      -- périodique, un livre que la bibliothèque n'a pas exemplarisé).
      -- Un CSV ou un RIS ne décrit jamais d'exemplaire : l'automatique reste.
      v_copies := case when v_linked > 0 then 0
                       when v_draft.marc_json->'ingest'->'raw_payload' ? 'item_tag' then 0
                       else greatest(1, least(coalesce(v_draft.initial_copies, 1), 50)) end;
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
    -- H19 : les exemplaires importés ne se rattachent qu'à une notice CRÉÉE
    -- par la publication (l'import ne produit que des brouillons 'create').
    if exists (select 1 from public.exemplar_drafts x
                where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')) then
      raise exception 'exemplares_importados_em_atualizacao'
        using hint = 'error.publish.items_on_update';
    end if;
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
      -- Capas (27/09/2026) : provenance et licence vont PAR PAIRE et suivent
      -- l'IMAGE. Un brouillon qui porte une provenance impose la sienne,
      -- licence comprise même nulle (Open Library et Inventaire écrivent au
      -- MÊME chemin books/<clé>/front.jpg : re-choisir une candidate ne doit
      -- pas garder la licence de l'autre). Un brouillon qui n'en porte pas
      -- (reprise d'avant cette migration) garde celles de la notice si l'image
      -- est la même — les écrire à NULL effacerait une attribution connue,
      -- comme serial_id le 27/08 — et n'hérite de rien pour une autre image.
      -- Dans un SET, la colonne nue désigne l'ANCIENNE valeur de la ligne.
      cover_source = case when v_draft.cover_source is not null then v_draft.cover_source
                          when v_draft.cover_object_path is not distinct from cover_object_path then cover_source
                          end,
      cover_license = case when v_draft.cover_source is not null then v_draft.cover_license
                           when v_draft.cover_object_path is not distinct from cover_object_path then cover_license
                           end,
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

  -- H19 : publier les exemplaires importés rattachés, dans la détention qui
  -- vient d'être posée ; chacun reçoit un tombo du schéma de SA bibliothèque
  -- (IMP-21 a) et garde son code d'origine.
  if v_linked > 0 then
    update public.exemplar_drafts x
       set target_library_id = v_library_id,
           target_holding_id = v_holding_id,
           target_bib_ref    = v_draft.bib_ref,
           updated_at        = now()
     where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready');
    for v_x in
      select x.id from public.exemplar_drafts x
       where x.book_draft_id = p_draft_id and x.status in ('draft', 'ready')
       order by x.id
    loop
      perform public.publish_exemplar_draft(v_x.id);
    end loop;
    perform public.fn_v2_recompute_holdings_availability(p_holding_ids := ARRAY[v_holding_id]);
  end if;

  -- H20 (27/09/2026) : une notice importée garde, À LA BIBLIOTHÈQUE où elle
  -- vient d'être publiée, le numéro que lui donnait sa source (001 de PMB) —
  -- books.source_record_id ne dit que l'origine de la notice partagée.
  -- Revue du 28/09 : ce qu'est un identifiant d'origine se juge en un seul
  -- lieu (ingest.fn_h20_identifiant_d_origine) ; les brouillons importés que
  -- celui-ci a absorbés (fusion de brouillons, en chaîne) gardent aussi le leur.
  if v_library_id is not null then
    if v_draft.marc_json ? 'ingest' then
      perform ingest.fn_record_book_external_id(
        v_book_id, v_library_id, coalesce((v_draft.marc_json->'ingest'->>'source_id')::bigint,
               (select r.source_id from ingest.partner_catalog_import_runs r
                 where r.id = (v_draft.marc_json->'ingest'->>'run_id')::bigint)),
        ingest.fn_h20_identifiant_d_origine(p_draft_id));
    end if;
    perform ingest.fn_record_book_external_id(
              v_book_id, v_library_id, coalesce((l.marc_json->'ingest'->>'source_id')::bigint,
               (select r.source_id from ingest.partner_catalog_import_runs r
                 where r.id = (l.marc_json->'ingest'->>'run_id')::bigint)),
              ingest.fn_h20_identifiant_d_origine(l.id))
       from public.book_drafts l
      where l.id in (with recursive absorbes(id) as (
                        select ml.duplicate_id from public.merge_log ml
                         where ml.entity_type = 'book_draft' and ml.details->>'scenario' = 'draft_into_draft'
                           and ml.canonical_id = p_draft_id
                        union
                        select ml.duplicate_id from public.merge_log ml
                          join absorbes a on ml.canonical_id = a.id
                         where ml.entity_type = 'book_draft' and ml.details->>'scenario' = 'draft_into_draft')
                      select id from absorbes)
        and l.status = 'cancelled' and l.marc_json ? 'ingest';
  end if;

  perform public.publish_book_draft_digital_resources(p_draft_id, v_book_id);

  return v_book_id;
end;
$function$
;

DO $$
BEGIN
  IF position('marc_json->''ingest''->''raw_payload'' ? ''item_tag''' IN pg_get_functiondef('public.publish_book_draft(bigint)'::regprocedure)) = 0 THEN
    RAISE EXCEPTION 'IMP-25 : publish_book_draft n''a pas sa règle';
  END IF;
END $$;
