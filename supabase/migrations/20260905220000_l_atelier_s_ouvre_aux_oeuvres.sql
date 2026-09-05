-- =========================================================================
-- Paquet l-atelier-s-ouvre-aux-oeuvres — le meme moteur de propositions, de
-- consentement et d'objection, pour la couche des oeuvres
-- =========================================================================
-- Date     : 2026-09-05
-- Chantier : atelier / oeuvres — decision Xavier du 05/09/2026 (« livrer les
--            cinq types d'un coup, reserver les objections a des
--            contributeurs rattaches a une bibliotheque »)
-- Auteur   : coordination AnarBib
--
-- POURQUOI
--   L'Atelier autorites porte un moteur generique : une proposition typee,
--   une cible, un delai d'objection, un consentement par silence, une
--   application par le staff. La couche des oeuvres (2449 oeuvres, 161 a
--   plusieurs editions, 1452 titres pre-traduits « corrige-moi » jamais
--   relus) n'avait que des gestes de staff, disperses. Ce paquet donne aux
--   oeuvres leur file dans le meme atelier, avec cinq types de proposition :
--
--     titre        corriger ou traduire le titre d'une oeuvre dans une langue
--     fusion       deux oeuvres sont la meme (target -> merge_into)
--     rattachement une edition appartient a une autre oeuvre
--     scission     une oeuvre melange des textes distincts
--     tomes        des oeuvres sont les tomes d'une serie (une seule oeuvre)
--
-- QUI PEUT QUOI
--   - proposer : contributeur·rice du reseau ou staff (inchange) ;
--   - objecter : le staff d'une bibliotheque concernee (inchange) ET,
--     desormais, un·e contributeur·rice du reseau RATTACHE·E a cette
--     bibliotheque (adhesion active, quel que soit le role). Une personne
--     sans bibliotheque propose, mais n'objecte pas : c'est la bibliotheque
--     qui detient les livres qui a voix. Vaut pour toutes les files.
--   - appliquer : le staff, apres consentement (inchange).
--
-- CE QUE FAIT LE PAQUET
--   1. Les CHECK de authority_proposals admettent target_kind 'work' et les
--      kinds titre / rattachement / tomes.
--   2. fn_authority_using_libraries et fn_library_uses_authority connaissent
--      les oeuvres (bibliotheques qui detiennent une edition).
--   3. api.fn_authority_propose / _object / _apply / _list : branche 'work',
--      validation et application deleguees a deux fonctions internes
--      (fn_work_proposal_check, fn_work_proposal_apply). Les corps repartent
--      des definitions REELLES (pg_get_functiondef en prod), pas du baseline.
--   4. api.fn_work_titles_review_list : la file « corrige-moi » par langue ;
--      api.fn_work_title_validate : le geste direct du staff (valider ou
--      corriger un titre) — les contributeur·rices passent par une
--      proposition 'titre'.
--
-- CE QUE LE PAQUET NE FAIT PAS
--   - Pas de nouvel evenement de notification : les evenements de l'atelier
--     sont reutilises (une notification morte est invisible ; cf. apply).
--     La fonction Edge apprend seulement a NOMMER une oeuvre.
--   - Pas de nouvelle table.
--
-- CHECKLIST DOCTRINE
--   [x] Fonctions DEFINER : search_path pose ; REVOKE FROM PUBLIC, anon ;
--       internes sans grant a authenticated
--   [x] CHECK elargies : anciens vocabulaires = sous-ensembles stricts
--   [x] DO block de verification STRUCTUREL ; le fonctionnel vit dans
--       tests/sql/atelier_oeuvres_tests.sql
-- =========================================================================

begin;

-- ── 1. Les vocabulaires s'ouvrent ────────────────────────────────────────
alter table public.authority_proposals drop constraint if exists authority_proposals_kind_check;
alter table public.authority_proposals add constraint authority_proposals_kind_check
  check (kind = any (array['creation','edition','fusion','traduction','scission','titre','rattachement','tomes']));

alter table public.authority_proposals drop constraint if exists authority_proposals_target_kind_check;
alter table public.authority_proposals add constraint authority_proposals_target_kind_check
  check (target_kind = any (array['author','subject','serial','work']));

-- ── 2. Les bibliotheques concernees par une oeuvre ───────────────────────
create or replace function public.fn_authority_using_libraries(p_target_kind text, p_target_id bigint)
returns table(library_id uuid)
language sql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
  SELECT DISTINCT bh.library_id
  FROM public.book_holdings bh
  WHERE p_target_id IS NOT NULL AND (
        (p_target_kind = 'author'  AND bh.book_id IN (SELECT book_id FROM public.book_authors  WHERE author_id  = p_target_id))
     OR (p_target_kind = 'subject' AND bh.book_id IN (SELECT book_id FROM public.book_subjects WHERE subject_id = p_target_id))
     OR (p_target_kind = 'work'    AND bh.book_id IN (SELECT id      FROM public.books         WHERE work_id    = p_target_id))
  );
$function$;

create or replace function public.fn_library_uses_authority(p_library_id uuid, p_target_kind text, p_target_id bigint)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
  SELECT CASE p_target_kind
    WHEN 'author' THEN EXISTS (
      SELECT 1 FROM public.book_authors ba
      JOIN public.book_holdings bh ON bh.book_id = ba.book_id
      WHERE ba.author_id = p_target_id AND bh.library_id = p_library_id)
    WHEN 'subject' THEN EXISTS (
      SELECT 1 FROM public.book_subjects bs
      JOIN public.book_holdings bh ON bh.book_id = bs.book_id
      WHERE bs.subject_id = p_target_id AND bh.library_id = p_library_id)
    WHEN 'work' THEN EXISTS (
      SELECT 1 FROM public.books b
      JOIN public.book_holdings bh ON bh.book_id = b.id
      WHERE b.work_id = p_target_id AND bh.library_id = p_library_id)
    ELSE false
  END;
$function$;

-- ── 3a. Valider une proposition sur une oeuvre (interne) ─────────────────
create or replace function public.fn_work_proposal_check(p_kind text, p_target_id bigint, p_merge_into_id bigint, p_payload jsonb)
returns void
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_part jsonb; v_n int; v_book bigint; v_w bigint; v_seen bigint[] := '{}';
begin
  if p_kind not in ('titre', 'fusion', 'rattachement', 'scission', 'tomes') then
    raise exception 'bad_kind_for_work' using hint = 'atelier.error.workKind';
  end if;
  if p_target_id is null or not exists (select 1 from public.works where id = p_target_id) then
    raise exception 'target_not_found' using hint = 'atelier.error.workNotFound';
  end if;

  if p_kind = 'titre' then
    if coalesce(p_payload ->> 'lang', '') not in ('pt-BR','fr','es','it','en','de','ca','eo','nl','el') then
      raise exception 'bad_lang' using hint = 'atelier.error.workLang';
    end if;
    if nullif(btrim(coalesce(p_payload ->> 'title', '')), '') is null then
      raise exception 'title_required' using hint = 'atelier.error.workTitle';
    end if;

  elsif p_kind = 'fusion' then
    if p_merge_into_id is null or p_merge_into_id = p_target_id then
      raise exception 'bad_merge_target' using hint = 'atelier.error.workMergeTarget';
    end if;
    if not exists (select 1 from public.works where id = p_merge_into_id) then
      raise exception 'canonical_not_found' using hint = 'atelier.error.workNotFound';
    end if;
    if exists (select 1 from public.work_not_same s
                where (s.work_id_a, s.work_id_b) in ((p_target_id, p_merge_into_id), (p_merge_into_id, p_target_id))) then
      raise exception 'works_declared_distinct' using hint = 'atelier.error.workNotSame';
    end if;

  elsif p_kind = 'rattachement' then
    v_book := (p_payload ->> 'book_id')::bigint;
    if v_book is null or not exists (select 1 from public.books where id = v_book) then
      raise exception 'book_not_found' using hint = 'atelier.error.workBook';
    end if;
    if (select work_id from public.books where id = v_book) = p_target_id then
      raise exception 'book_already_in_work' using hint = 'atelier.error.workBookSame';
    end if;

  elsif p_kind = 'scission' then
    if jsonb_typeof(p_payload -> 'parts') <> 'array' or jsonb_array_length(p_payload -> 'parts') < 2 then
      raise exception 'scission_needs_two_parts' using hint = 'atelier.error.scissionParts';
    end if;
    for v_part in select * from jsonb_array_elements(p_payload -> 'parts') loop
      if nullif(btrim(coalesce(v_part ->> 'uniform_title', '')), '') is null then
        raise exception 'scission_part_incomplete' using hint = 'atelier.error.scissionPartIncomplete';
      end if;
      if jsonb_typeof(v_part -> 'book_ids') <> 'array' or jsonb_array_length(v_part -> 'book_ids') < 1 then
        raise exception 'scission_part_no_books' using hint = 'atelier.error.workPartBooks';
      end if;
      for v_book in select (x #>> '{}')::bigint from jsonb_array_elements(v_part -> 'book_ids') x loop
        if not exists (select 1 from public.books b where b.id = v_book and b.work_id = p_target_id) then
          raise exception 'scission_book_not_in_work: %', v_book using hint = 'atelier.error.workPartBooks';
        end if;
        if v_book = any (v_seen) then
          raise exception 'scission_book_twice: %', v_book using hint = 'atelier.error.workPartBooks';
        end if;
        v_seen := v_seen || v_book;
      end loop;
    end loop;

  elsif p_kind = 'tomes' then
    if jsonb_typeof(p_payload -> 'work_ids') <> 'array' or jsonb_array_length(p_payload -> 'work_ids') < 1 then
      raise exception 'tomes_need_works' using hint = 'atelier.error.workTomes';
    end if;
    for v_w in select (x #>> '{}')::bigint from jsonb_array_elements(p_payload -> 'work_ids') x loop
      if v_w = p_target_id or not exists (select 1 from public.works where id = v_w) then
        raise exception 'tome_not_found: %', v_w using hint = 'atelier.error.workTomes';
      end if;
      if v_w = any (v_seen) then
        raise exception 'tome_twice: %', v_w using hint = 'atelier.error.workTomes';
      end if;
      v_seen := v_seen || v_w;
    end loop;
  end if;
end;
$function$;

revoke execute on function public.fn_work_proposal_check(text, bigint, bigint, jsonb) from public, anon, authenticated;

-- ── 3b. Appliquer une proposition sur une oeuvre (interne) ───────────────
-- Appelee par api.fn_authority_apply, donc par le staff apres consentement.
-- merge_works garde elle-meme l'appelant (staff) : on la reutilise, on ne la
-- recopie pas.
create or replace function public.fn_work_proposal_apply(p_proposal_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_p public.authority_proposals; v_part jsonb; v_new bigint; v_old bigint; v_w bigint; v_book bigint; v_title text;
begin
  select * into v_p from public.authority_proposals where id = p_proposal_id;
  if not found or v_p.target_kind <> 'work' then raise exception 'proposal_not_found'; end if;
  perform public.fn_work_proposal_check(v_p.kind, v_p.target_id, v_p.merge_into_id, v_p.payload);

  if v_p.kind = 'titre' then
    insert into public.work_titles (work_id, lang, title, source, source_book_id, needs_review)
    values (v_p.target_id, v_p.payload ->> 'lang', btrim(v_p.payload ->> 'title'), 'manual', null, false)
    on conflict (work_id, lang) do update
      set title = excluded.title, source = 'manual', source_book_id = null, needs_review = false, updated_at = now();

  elsif v_p.kind = 'fusion' then
    perform public.merge_works(v_p.target_id, v_p.merge_into_id);

  elsif v_p.kind = 'rattachement' then
    v_book := (v_p.payload ->> 'book_id')::bigint;
    select work_id into v_old from public.books where id = v_book;
    update public.books set work_id = v_p.target_id, updated_at = now() where id = v_book;
    perform public.fn_work_titles_reseed(v_p.target_id);
    if not public.fn_work_prune_if_empty(v_old) then perform public.fn_work_titles_reseed(v_old); end if;

  elsif v_p.kind = 'scission' then
    for v_part in select * from jsonb_array_elements(v_p.payload -> 'parts') loop
      v_title := btrim(v_part ->> 'uniform_title');
      insert into public.works (uniform_title, sort_title, primary_author_id, created_by)
      select v_title, public.fn_normalize_name(v_title), w.primary_author_id, auth.uid()
        from public.works w where w.id = v_p.target_id
      returning id into v_new;
      update public.books b set work_id = v_new, updated_at = now()
       where b.work_id = v_p.target_id
         and b.id in (select (x #>> '{}')::bigint from jsonb_array_elements(v_part -> 'book_ids') x);
      perform public.fn_work_titles_reseed(v_new);
    end loop;
    if not public.fn_work_prune_if_empty(v_p.target_id) then perform public.fn_work_titles_reseed(v_p.target_id); end if;

  elsif v_p.kind = 'tomes' then
    for v_w in select (x #>> '{}')::bigint from jsonb_array_elements(v_p.payload -> 'work_ids') x loop
      perform public.merge_works(v_w, v_p.target_id);
    end loop;
    v_title := nullif(btrim(coalesce(v_p.payload ->> 'series_title', '')), '');
    if v_title is not null then
      update public.works set uniform_title = v_title, sort_title = public.fn_normalize_name(v_title), updated_at = now()
       where id = v_p.target_id;
    end if;
    perform public.fn_work_titles_reseed(v_p.target_id);
  end if;
end;
$function$;

revoke execute on function public.fn_work_proposal_apply(uuid) from public, anon, authenticated;

-- ── 3c. Proposer : la branche 'work' ─────────────────────────────────────
create or replace function api.fn_authority_propose(p_kind text, p_target_kind text, p_target_id bigint, p_merge_into_id bigint, p_payload jsonb, p_rationale text)
returns uuid
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_id       uuid;
  v_deadline timestamptz;
  v_part     jsonb;
  v_pref     text;
  v_sort     text;
  v_n        int;
  v_collision text;
begin
  if not (public.fn_caller_is_network_contributor() or public.fn_caller_is_staff()) then
    raise exception 'forbidden' using hint = 'atelier.error.notContributor';
  end if;

  -- ── Les oeuvres (05/09/2026) : validation deleguee, meme file, memes delais ──
  if p_target_kind = 'work' then
    perform public.fn_work_proposal_check(p_kind, p_target_id, p_merge_into_id, p_payload);
    v_deadline := now() + case when p_kind in ('fusion', 'scission', 'tomes')
                               then interval '14 days' else interval '7 days' end;
    insert into public.authority_proposals (kind, target_kind, target_id, merge_into_id, payload, rationale, deadline, proposed_by)
    values (p_kind, 'work', p_target_id, p_merge_into_id, coalesce(p_payload, '{}'::jsonb), p_rationale, v_deadline, auth.uid())
    returning id into v_id;
    perform public.fn_authority_emit('authority.proposal_opened', jsonb_build_object(
      'proposal_id', v_id, 'kind', p_kind, 'target_kind', 'work',
      'target_id', p_target_id, 'merge_into_id', p_merge_into_id, 'proposed_by', auth.uid()));
    return v_id;
  end if;

  if p_kind not in ('creation', 'edition', 'fusion', 'traduction', 'scission') then
    raise exception 'bad_kind';
  end if;
  -- AJOUT PÉRIODIQUES P5 : 'serial'.
  if p_target_kind not in ('author', 'subject', 'serial') then raise exception 'bad_target_kind'; end if;

  if p_kind = 'creation' then
    if p_target_id is not null then raise exception 'creation_has_target'; end if;
  else
    if p_target_id is null then raise exception 'missing_target'; end if;
    if p_target_kind = 'author'  and not exists (select 1 from public.authors  where id = p_target_id) then raise exception 'target_not_found'; end if;
    if p_target_kind = 'subject' and not exists (select 1 from public.subjects where id = p_target_id) then raise exception 'target_not_found'; end if;
    if p_target_kind = 'serial'  and not exists (select 1 from public.serials  where id = p_target_id) then raise exception 'target_not_found'; end if;
  end if;

  if p_kind = 'fusion' then
    if p_merge_into_id is null or p_merge_into_id = p_target_id then raise exception 'bad_merge_target'; end if;
    if p_target_kind = 'author'  and not exists (select 1 from public.authors  where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
    if p_target_kind = 'subject' and not exists (select 1 from public.subjects where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
    if p_target_kind = 'serial'  and not exists (select 1 from public.serials  where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
  elsif p_merge_into_id is not null then
    raise exception 'merge_target_only_for_fusion';
  end if;

  -- ── Gardes propres à la scission ──────────────────────────────────
  if p_kind = 'scission' then
    if p_target_kind <> 'author' then
      raise exception 'scission_author_only' using hint = 'atelier.error.scissionAuthorOnly';
    end if;

    if jsonb_typeof(p_payload -> 'parts') <> 'array'
       or jsonb_array_length(p_payload -> 'parts') < 2 then
      raise exception 'scission_needs_two_parts' using hint = 'atelier.error.scissionParts';
    end if;

    for v_part in select * from jsonb_array_elements(p_payload -> 'parts') loop
      v_pref := btrim(coalesce(v_part ->> 'preferred_name', ''));
      v_sort := btrim(coalesce(v_part ->> 'sort_name', ''));
      if v_pref = '' or v_sort = '' then
        raise exception 'scission_part_incomplete' using hint = 'atelier.error.scissionPartIncomplete';
      end if;
      if coalesce(v_part ->> 'authority_type', 'person') not in ('person', 'collective', 'congress') then
        raise exception 'scission_bad_type' using hint = 'atelier.error.scissionBadType';
      end if;

      select a.sort_name into v_collision
        from public.authors a
       where a.sort_name = v_sort and a.id <> p_target_id
       limit 1;
      if v_collision is not null then
        raise exception 'scission_part_exists: %', v_collision
          using hint = 'atelier.error.scissionPartExists';
      end if;
    end loop;

    select count(distinct btrim(x ->> 'sort_name')) into v_n
      from jsonb_array_elements(p_payload -> 'parts') x;
    if v_n <> jsonb_array_length(p_payload -> 'parts') then
      raise exception 'scission_duplicate_parts' using hint = 'atelier.error.scissionDuplicateParts';
    end if;
  end if;

  v_deadline := now() + case when p_kind in ('fusion', 'scission')
                             then interval '14 days' else interval '7 days' end;

  insert into public.authority_proposals (kind, target_kind, target_id, merge_into_id, payload, rationale, deadline, proposed_by)
  values (p_kind, p_target_kind, p_target_id, p_merge_into_id,
          case
            when p_kind = 'scission'
              then coalesce(p_payload, '{}'::jsonb)
                   || jsonb_build_object('avant',
                        (select a.sort_name from public.authors a where a.id = p_target_id))
            else coalesce(p_payload, '{}'::jsonb)
          end,
          p_rationale, v_deadline, auth.uid())
  returning id into v_id;

  perform public.fn_authority_emit('authority.proposal_opened', jsonb_build_object(
    'proposal_id', v_id, 'kind', p_kind, 'target_kind', p_target_kind,
    'target_id', p_target_id, 'merge_into_id', p_merge_into_id, 'proposed_by', auth.uid()));
  return v_id;
end;
$function$;

-- ── 3d. Objecter : le staff, ou un·e contributeur·rice rattache·e ────────
create or replace function api.fn_authority_object(p_proposal_id uuid, p_library_id uuid, p_reason text)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
DECLARE v_p public.authority_proposals; n_obj int; n_users int; v_new_status text;
BEGIN
  SELECT * INTO v_p FROM public.authority_proposals WHERE id = p_proposal_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'proposal_not_found'; END IF;
  IF v_p.status NOT IN ('open','contested') THEN RAISE EXCEPTION 'proposal_closed'; END IF;

  -- 05/09/2026 : objecte au nom d'une bibliotheque qui en a le droit : son
  -- staff, ou un·e contributeur·rice du reseau qui y adhere (adhesion active,
  -- quel que soit le role). Sans bibliotheque, on propose, on n'objecte pas.
  IF NOT (public.user_can_manage_library(p_library_id)
          OR (public.fn_caller_is_network_contributor()
              AND EXISTS (SELECT 1 FROM public.user_library_memberships m
                           WHERE m.user_id = auth.uid() AND m.library_id = p_library_id AND m.status = 'active'))) THEN
    RAISE EXCEPTION 'forbidden' USING HINT = 'atelier.error.notCoordenador';
  END IF;
  IF v_p.target_id IS NOT NULL AND NOT public.fn_library_uses_authority(p_library_id, v_p.target_kind, v_p.target_id) THEN
    RAISE EXCEPTION 'library_not_concerned' USING HINT = 'atelier.error.notUsingAuthority';
  END IF;
  IF char_length(btrim(coalesce(p_reason,''))) < 20 THEN RAISE EXCEPTION 'reason_too_short'; END IF;

  INSERT INTO public.authority_proposal_objections (proposal_id, objecting_library_id, objecting_by, reason)
  VALUES (p_proposal_id, p_library_id, auth.uid(), p_reason);

  SELECT count(DISTINCT objecting_library_id) INTO n_obj
    FROM public.authority_proposal_objections WHERE proposal_id = p_proposal_id;
  IF v_p.target_id IS NULL THEN
    n_users := 99;
  ELSE
    SELECT count(*) INTO n_users FROM public.fn_authority_using_libraries(v_p.target_kind, v_p.target_id);
  END IF;

  IF n_obj >= 2 OR (n_users <= 2 AND n_obj >= 1) THEN v_new_status := 'refused';
  ELSE v_new_status := 'contested'; END IF;

  UPDATE public.authority_proposals
     SET status = v_new_status,
         resolved_at = CASE WHEN v_new_status='refused' THEN now() ELSE resolved_at END,
         updated_at = now()
   WHERE id = p_proposal_id;

  PERFORM public.fn_authority_emit('authority.proposal_objected', jsonb_build_object(
    'proposal_id', p_proposal_id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
    'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by,
    'objecting_library_id', p_library_id, 'objecting_by', auth.uid(),
    'reason', p_reason, 'new_status', v_new_status));
  IF v_new_status = 'refused' THEN
    PERFORM public.fn_authority_emit('authority.proposal_refused', jsonb_build_object(
      'proposal_id', p_proposal_id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by));
  END IF;
  RETURN v_new_status;
END;
$function$;

-- ── 3e. Appliquer : la branche 'work' ────────────────────────────────────
create or replace function api.fn_authority_apply(p_proposal_id uuid)
returns text
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare v_p public.authority_proposals; v_f jsonb;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'forbidden' using hint = 'atelier.error.notStaff';
  end if;
  select * into v_p from public.authority_proposals where id = p_proposal_id for update;
  if not found then raise exception 'proposal_not_found'; end if;
  if v_p.status <> 'resolved_consent' then
    raise exception 'not_ready' using hint = 'atelier.error.notResolvedConsent';
  end if;

  if v_p.target_kind = 'work' then
    -- 05/09/2026 : les oeuvres, cinq types, une seule fonction d'application.
    perform public.fn_work_proposal_apply(v_p.id);

  elsif v_p.kind = 'fusion' then
    if v_p.target_kind = 'author'  then perform public.merge_author(v_p.merge_into_id, v_p.target_id);
    elsif v_p.target_kind = 'subject' then perform public.merge_subject(v_p.merge_into_id, v_p.target_id);
    elsif v_p.target_kind = 'serial' then perform public.merge_serial(v_p.merge_into_id, v_p.target_id);
    else
      raise exception 'apply_target_kind_not_implemented: %', v_p.target_kind
        using hint = 'atelier.error.applyKindDeferred';
    end if;

  elsif v_p.kind = 'scission' then
    perform public.fn_authority_split(v_p.target_id,
                                      v_p.payload -> 'parts',
                                      v_p.payload ->> 'avant');

  elsif v_p.kind = 'edition' then
    v_f := coalesce(v_p.payload -> 'fields', '{}'::jsonb);
    if v_p.target_kind = 'author' then
      update public.authors set
        preferred_name  = coalesce(v_f ->> 'preferred_name', preferred_name),
        sort_name       = coalesce(v_f ->> 'sort_name', sort_name),
        biography       = coalesce(v_f ->> 'biography', biography),
        birth_year      = coalesce((v_f ->> 'birth_year')::int, birth_year),
        death_year      = coalesce((v_f ->> 'death_year')::int, death_year),
        country         = coalesce(v_f ->> 'country', country),
        viaf_id         = coalesce(v_f ->> 'viaf_id', viaf_id),
        isni            = coalesce(v_f ->> 'isni', isni),
        wikidata_id     = coalesce(v_f ->> 'wikidata_id', wikidata_id),
        notes           = coalesce(v_f ->> 'notes', notes),
        structured_meta = coalesce(v_f -> 'structured_meta', structured_meta),
        variant_forms   = coalesce(v_f -> 'variant_forms', variant_forms),
        updated_at = now(), updated_by = auth.uid()
      where id = v_p.target_id;
    elsif v_p.target_kind = 'subject' then
      update public.subjects set
        label_i18n = coalesce(v_f -> 'label_i18n', label_i18n),
        scope_note = coalesce(v_f ->> 'scope_note', scope_note),
        parent_id  = coalesce((v_f ->> 'parent_id')::bigint, parent_id),
        updated_at = now(), updated_by = auth.uid()
      where id = v_p.target_id;
    elsif v_p.target_kind = 'serial' then
      perform public.fn_serial_apply_payload(v_p.target_id, v_f);
    else
      raise exception 'apply_target_kind_not_implemented: %', v_p.target_kind
        using hint = 'atelier.error.applyKindDeferred';
    end if;

  else
    raise exception 'apply_kind_not_implemented' using hint = 'atelier.error.applyKindDeferred';
  end if;

  update public.authority_proposals set status = 'applied', applied_at = now(), updated_at = now()
   where id = p_proposal_id;

  -- Les evenements existants sont reutilises (une notification morte est
  -- invisible, cf. la scission) : fusion et tomes -> merge_executed, le reste
  -- -> edit_applied. Pour une fusion d'oeuvres, merge_into_id porte la cible ;
  -- pour les tomes c'est target_id qui reste — la fonction Edge resout les
  -- bibliotheques sur merge_into_id pour merge_executed, on le renseigne donc.
  if v_p.kind in ('fusion', 'tomes') then
    perform public.fn_authority_emit('authority.merge_executed', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'merge_into_id', coalesce(v_p.merge_into_id, v_p.target_id), 'proposed_by', v_p.proposed_by));
  else
    perform public.fn_authority_emit('authority.edit_applied', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by));
  end if;
  return 'applied';
end;
$function$;

-- ── 3f. La liste nomme les oeuvres ───────────────────────────────────────
create or replace function api.fn_authority_list()
returns table(id uuid, kind text, target_kind text, target_id bigint, target_label text, merge_into_id bigint, merge_into_label text, status text, deadline timestamp with time zone, rationale text, proposed_by uuid, proposer_name text, objection_count integer, created_at timestamp with time zone)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
BEGIN
  IF NOT (public.fn_caller_is_network_contributor() OR public.fn_caller_is_staff() OR public.fn_caller_is_network_admin()) THEN
    RAISE EXCEPTION 'Atelier reservado a quem participa da rede (contribuinte, equipe ou administracao).' USING ERRCODE = '42501';
  END IF;
  RETURN QUERY
  SELECT p.id, p.kind, p.target_kind, p.target_id,
    CASE p.target_kind
      WHEN 'author'  THEN (SELECT a.preferred_name FROM public.authors a WHERE a.id = p.target_id)
      WHEN 'subject' THEN (SELECT coalesce(s.label_i18n->>'pt-BR', s.slug) FROM public.subjects s WHERE s.id = p.target_id)
      WHEN 'serial'  THEN (SELECT coalesce(se.uniform_title, se.slug) FROM public.serials se WHERE se.id = p.target_id)
      WHEN 'work'    THEN (SELECT coalesce(w.uniform_title, '#' || w.id) FROM public.works w WHERE w.id = p.target_id)
    END,
    p.merge_into_id,
    CASE WHEN p.merge_into_id IS NULL THEN NULL
      WHEN p.target_kind='author'  THEN (SELECT a.preferred_name FROM public.authors a WHERE a.id = p.merge_into_id)
      WHEN p.target_kind='subject' THEN (SELECT coalesce(s.label_i18n->>'pt-BR', s.slug) FROM public.subjects s WHERE s.id = p.merge_into_id)
      WHEN p.target_kind='serial'  THEN (SELECT coalesce(se.uniform_title, se.slug) FROM public.serials se WHERE se.id = p.merge_into_id)
      WHEN p.target_kind='work'    THEN (SELECT coalesce(w.uniform_title, '#' || w.id) FROM public.works w WHERE w.id = p.merge_into_id)
    END,
    p.status, p.deadline, p.rationale, p.proposed_by,
    (SELECT nullif(btrim(coalesce(pr.first_name,'')||' '||coalesce(pr.last_name,'')),'') FROM public.profiles pr WHERE pr.id = p.proposed_by),
    (SELECT count(*)::integer FROM public.authority_proposal_objections o WHERE o.proposal_id = p.id),
    p.created_at
  FROM public.authority_proposals p
  ORDER BY p.created_at DESC;
END;
$function$;

-- ── 4. La file « corrige-moi » et le geste direct du staff ───────────────
create or replace function api.fn_work_titles_review_list(p_lang text default null, p_limit integer default 60)
returns table(work_id bigint, lang text, title text, edition_title text, edition_lang text, author_name text, n_editions bigint)
language sql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
  SELECT wt.work_id, wt.lang, wt.title,
         (SELECT e.title FROM public.work_titles e WHERE e.work_id = wt.work_id AND e.source = 'edition'
           ORDER BY (e.lang = 'pt-BR') DESC, (e.lang = 'fr') DESC, (e.lang = 'en') DESC, e.lang LIMIT 1),
         (SELECT e.lang FROM public.work_titles e WHERE e.work_id = wt.work_id AND e.source = 'edition'
           ORDER BY (e.lang = 'pt-BR') DESC, (e.lang = 'fr') DESC, (e.lang = 'en') DESC, e.lang LIMIT 1),
         (SELECT a.preferred_name FROM public.works w JOIN public.authors a ON a.id = w.primary_author_id WHERE w.id = wt.work_id),
         (SELECT count(*) FROM public.books b WHERE b.work_id = wt.work_id)
    FROM public.work_titles wt
   WHERE wt.needs_review
     AND (p_lang IS NULL OR wt.lang = p_lang)
     AND (public.fn_caller_is_network_contributor() OR public.fn_caller_is_staff() OR public.fn_caller_is_network_admin())
   ORDER BY wt.work_id, wt.lang
   LIMIT greatest(1, least(coalesce(p_limit, 60), 200));
$function$;

revoke execute on function api.fn_work_titles_review_list(text, integer) from public, anon;
grant  execute on function api.fn_work_titles_review_list(text, integer) to authenticated, service_role;

comment on function api.fn_work_titles_review_list(text, integer) is
  'La file « corrige-moi » : titres d''oeuvre pre-traduits (source auto, needs_review) par langue, avec le titre '
  'd''une edition pour se reperer. Participants de l''atelier seulement (05/09/2026).';

create or replace function api.fn_work_title_validate(p_work_id bigint, p_lang text, p_title text default null)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare v_title text;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'forbidden' using hint = 'atelier.error.notStaff';
  end if;
  if coalesce(p_lang, '') not in ('pt-BR','fr','es','it','en','de','ca','eo','nl','el') then
    raise exception 'bad_lang' using hint = 'atelier.error.workLang';
  end if;
  v_title := nullif(btrim(coalesce(p_title, '')), '');
  if v_title is null then
    -- Valider tel quel : la pre-traduction devient un titre assume.
    update public.work_titles set source = 'manual', source_book_id = null, needs_review = false, updated_at = now()
     where work_id = p_work_id and lang = p_lang;
    if not found then raise exception 'title_not_found' using hint = 'atelier.error.workTitle'; end if;
  else
    insert into public.work_titles (work_id, lang, title, source, source_book_id, needs_review)
    values (p_work_id, p_lang, v_title, 'manual', null, false)
    on conflict (work_id, lang) do update
      set title = excluded.title, source = 'manual', source_book_id = null, needs_review = false, updated_at = now();
  end if;
end;
$function$;

revoke execute on function api.fn_work_title_validate(bigint, text, text) from public, anon;
grant  execute on function api.fn_work_title_validate(bigint, text, text) to authenticated, service_role;

comment on function api.fn_work_title_validate(bigint, text, text) is
  'Geste direct du staff sur un titre d''oeuvre : valider la pre-traduction (p_title null) ou la corriger. '
  'Les contributeur·rices passent par une proposition de type titre (05/09/2026).';

-- ── 5. Verification structurelle ─────────────────────────────────────────
do $verif$
declare v_def text; v_n int;
begin
  select pg_get_constraintdef(c.oid) into v_def from pg_constraint c where c.conname = 'authority_proposals_target_kind_check';
  if position('work' in v_def) = 0 then raise exception 'target_kind_check sans work'; end if;
  select pg_get_constraintdef(c.oid) into v_def from pg_constraint c where c.conname = 'authority_proposals_kind_check';
  if position('tomes' in v_def) = 0 or position('titre' in v_def) = 0 or position('rattachement' in v_def) = 0 then
    raise exception 'kind_check sans les types des oeuvres';
  end if;
  for v_def in select pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                where n.nspname = 'api' and p.proname in ('fn_authority_propose', 'fn_authority_apply', 'fn_authority_list') loop
    if position('''work''' in v_def) = 0 then raise exception 'une RPC de l''atelier ignore encore les oeuvres'; end if;
  end loop;
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'api' and p.proname = 'fn_authority_object';
  if position('fn_caller_is_network_contributor' in v_def) = 0 then raise exception 'l''objection ignore les contributeurs rattaches'; end if;
  select count(*) into v_n from information_schema.routine_privileges
   where routine_schema = 'public' and routine_name in ('fn_work_proposal_check', 'fn_work_proposal_apply')
     and grantee in ('anon', 'PUBLIC', 'authenticated');
  if v_n <> 0 then raise exception 'fonctions internes des oeuvres ouvertes (% droit(s))', v_n; end if;
  select count(*) into v_n from information_schema.routine_privileges
   where routine_schema = 'api' and routine_name in ('fn_work_titles_review_list', 'fn_work_title_validate')
     and grantee in ('anon', 'PUBLIC');
  if v_n <> 0 then raise exception 'RPC des titres ouvertes a anon/PUBLIC'; end if;
  raise notice 'Paquet l-atelier-s-ouvre-aux-oeuvres : verifications OK';
end
$verif$;

commit;
