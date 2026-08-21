-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 17 · La scission d'autorité
-- Foyer : REGISTRE §37 `CONV` · CONV-O8
--
-- ---------------------------------------------------------------------
-- LE DÉPÔT SAIT FUSIONNER, PAS SÉPARER.
--
-- `merge_author` réunit deux fiches qui désignent la même personne. Rien
-- ne fait l'inverse : séparer une fiche qui en contient deux. Or l'import
-- en a fabriqué — `KAISER, William Young and David E.` est UN
-- enregistrement pour DEUX personnes.
--
-- OÙ CETTE OPÉRATION VA, ET POURQUOI PAS AILLEURS. Pas dans la file de
-- vérification du chantier CONV : celle-ci recueille des verdicts
-- mécaniques et réversibles sur des propositions d'outil. Scinder engage
-- le corpus PARTAGÉ du réseau, exactement comme la fusion — qui passe
-- déjà par le circuit de propositions de l'Atelier, avec délai de
-- consentement et objection motivée (FED-O5). `scission` prend donc sa
-- place parmi les `kind` de ce circuit, pas dans un bouton de plus.
--
-- ---------------------------------------------------------------------
-- CETTE MIGRATION NE SCINDE RIEN. Elle pose le mécanisme, vide.
--
-- Les trois fiches connues ne sont PAS pré-remplies, et ce n'est pas de
-- la prudence de façade : leur découpage demande un savoir que le SQL
-- n'a pas. `KAISER, William Young and David E.` n'est pas deux Kaiser —
-- c'est « William Young » ET « David E. Kaiser », co-auteurs de
-- *Postmortem*, dont le nom composé a été mal analysé à l'import. Une
-- fonction qui couperait à la virgule fabriquerait deux fiches fausses
-- avec l'assurance d'avoir réparé quelque chose.
--
-- De même `CHRISTIAN BAY, Charles Walter` : *Desobediência Civil* est de
-- Christian Bay et Charles C. Walker — le second nom est probablement
-- corrompu, ce qui ne se devine pas non plus.
--
-- Le mécanisme propose donc un formulaire, jamais un découpage.
--
-- ---------------------------------------------------------------------
-- CE QUE LA SCISSION FAIT, EXACTEMENT.
--
-- La fiche d'origine est CONSERVÉE et devient la première part. Elle
-- n'est pas détruite puis recréée : elle garde son id, donc son
-- `public_id`, donc les adresses publiques qui pointent dessus, et les
-- liaisons qu'elle porte déjà. Les autres parts sont créées, et les
-- liaisons de l'originale leur sont RECOPIÉES — parce qu'une fiche
-- composée tenait lieu de plusieurs personnes sur les mêmes livres.
--
-- UNE ASYMÉTRIE ASSUMÉE : `works.primary_author_id` ne vaut qu'un seul
-- identifiant. Une scission ne peut pas le dédoubler. Il reste sur la
-- première part. Ce n'est pas un oubli — c'est le modèle qui ne permet
-- qu'un auteur principal par œuvre, et le dire vaut mieux que de choisir
-- en silence.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Le `kind` et sa contrainte de forme.
--
--    Les deux CHECK existantes restent vraies sans y toucher :
--    `creation_no_target` — scission a une cible, `creation` non ;
--    `fusion_has_canonical` — scission n'a pas de canonique, `fusion` si.
-- ---------------------------------------------------------------------
alter table public.authority_proposals
  drop constraint if exists authority_proposals_kind_check;
alter table public.authority_proposals
  add constraint authority_proposals_kind_check
  check (kind in ('creation', 'edition', 'fusion', 'traduction', 'scission'));

-- Une scission sans au moins deux parts n'est pas une scission.
-- `case` plutôt qu'un `and` : l'ordre d'évaluation d'un `and` n'est pas
-- garanti, et `jsonb_array_length` lève une erreur si on la lui applique
-- sur autre chose qu'un tableau.
alter table public.authority_proposals
  drop constraint if exists authority_proposals_scission_has_parts;
alter table public.authority_proposals
  add constraint authority_proposals_scission_has_parts
  check (
    kind <> 'scission'
    or (case when jsonb_typeof(payload -> 'parts') = 'array'
             then jsonb_array_length(payload -> 'parts') >= 2
             else false end)
  );

comment on table public.authority_proposals is
  'Atelier autorités : file de propositions de contribution. '
  'kind=creation/edition/fusion/traduction/scission ; target_kind=author/subject '
  '(bigint). Consentement opt-out (FED-O5) ; exécution via merge_author/'
  'merge_subject, scission, ou écriture directe à la résolution. Écritures via RPC. '
  'Une scission porte ses parts dans payload->parts (>= 2), et l''état constaté '
  'de la fiche dans payload->avant (garde anti-écrasement, CONV-O6).';

-- ---------------------------------------------------------------------
-- 2. Proposer une scission.
--
--    Les gardes sont posées ICI, à la proposition, et non à l'exécution :
--    une proposition part en délibération pour sept jours et son texte est
--    lu par d'autres bibliothèques. Découvrir à l'application, une semaine
--    plus tard, qu'elle était malformée ferait perdre la délibération avec.
-- ---------------------------------------------------------------------
create or replace function api.fn_authority_propose(
  p_kind text, p_target_kind text, p_target_id bigint,
  p_merge_into_id bigint, p_payload jsonb, p_rationale text)
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
  if p_kind not in ('creation', 'edition', 'fusion', 'traduction', 'scission') then
    raise exception 'bad_kind';
  end if;
  if p_target_kind not in ('author', 'subject') then raise exception 'bad_target_kind'; end if;

  if p_kind = 'creation' then
    if p_target_id is not null then raise exception 'creation_has_target'; end if;
  else
    if p_target_id is null then raise exception 'missing_target'; end if;
    if p_target_kind = 'author'  and not exists (select 1 from public.authors  where id = p_target_id) then raise exception 'target_not_found'; end if;
    if p_target_kind = 'subject' and not exists (select 1 from public.subjects where id = p_target_id) then raise exception 'target_not_found'; end if;
  end if;

  if p_kind = 'fusion' then
    if p_merge_into_id is null or p_merge_into_id = p_target_id then raise exception 'bad_merge_target'; end if;
    if p_target_kind = 'author'  and not exists (select 1 from public.authors  where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
    if p_target_kind = 'subject' and not exists (select 1 from public.subjects where id = p_merge_into_id) then raise exception 'canonical_not_found'; end if;
  elsif p_merge_into_id is not null then
    raise exception 'merge_target_only_for_fusion';
  end if;

  -- ── Gardes propres à la scission ──────────────────────────────────
  if p_kind = 'scission' then
    -- Une matière ne se scinde pas par ce chemin : le repointage
    -- ci-dessous ne connaît que les liaisons de livres à auteurs.
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

      -- Une part qui porte le nom d'une AUTRE fiche existante ferait un
      -- doublon. On refuse en nommant la fiche en cause plutôt que de
      -- rattacher d'autorité : rattacher serait souvent juste, parfois
      -- faux, et toujours une décision qu'on aurait prise à la place de
      -- quelqu'un. Le chemin qui existe pour ce cas est la fusion.
      select a.sort_name into v_collision
        from public.authors a
       where a.sort_name = v_sort and a.id <> p_target_id
       limit 1;
      if v_collision is not null then
        raise exception 'scission_part_exists: %', v_collision
          using hint = 'atelier.error.scissionPartExists';
      end if;
    end loop;

    -- Deux parts identiques entre elles : même défaut, autre source.
    select count(distinct btrim(x ->> 'sort_name')) into v_n
      from jsonb_array_elements(p_payload -> 'parts') x;
    if v_n <> jsonb_array_length(p_payload -> 'parts') then
      raise exception 'scission_duplicate_parts' using hint = 'atelier.error.scissionDuplicateParts';
    end if;
  end if;

  -- Une scission engage autant qu'une fusion : même délai de délibération.
  v_deadline := now() + case when p_kind in ('fusion', 'scission')
                             then interval '14 days' else interval '7 days' end;

  insert into public.authority_proposals (kind, target_kind, target_id, merge_into_id, payload, rationale, deadline, proposed_by)
  values (p_kind, p_target_kind, p_target_id, p_merge_into_id,
          case
            -- L'état constaté est figé À LA PROPOSITION, pour que
            -- l'application puisse refuser d'écrire sur une fiche qui a
            -- bougé pendant les quatorze jours (CONV-O6).
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

revoke all on function api.fn_authority_propose(text, text, bigint, bigint, jsonb, text)
  from public, anon;
grant execute on function api.fn_authority_propose(text, text, bigint, bigint, jsonb, text)
  to authenticated;

-- ---------------------------------------------------------------------
-- 3. Le découpage lui-même.
-- ---------------------------------------------------------------------
create or replace function public.fn_authority_split(p_author_id bigint, p_parts jsonb, p_avant text)
returns bigint
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_part  jsonb;
  v_new   bigint;
  v_i     int := 0;
  v_crees bigint := 0;
  v_pref0 text;
  v_sort0 text;
  v_type0 text;
  v_actuel text;
  v_noms  text;
begin
  select a.sort_name into v_actuel from public.authors a where a.id = p_author_id for update;
  if not found then raise exception 'split_target_not_found'; end if;

  -- Anti-écrasement (CONV-O6) : la fiche a-t-elle bougé depuis la
  -- proposition ? Quatorze jours, c'est le temps qu'il faut pour que
  -- quelqu'un d'autre la corrige entre-temps. Écrire quand même
  -- effacerait son travail sans que personne ne le voie.
  if p_avant is not null and v_actuel is distinct from p_avant then
    raise exception 'split_target_changed: % (proposition faite sur « % »)', v_actuel, p_avant
      using hint = 'atelier.error.splitTargetChanged';
  end if;

  -- Le nom composé recomposé, pour réparer le champ libre `books.autor`.
  select string_agg(btrim(x ->> 'sort_name'), ' ; ' order by x.ord)
    into v_noms
    from jsonb_array_elements(p_parts) with ordinality as x(x, ord);

  -- ── Part 0 : la fiche d'origine, renommée ─────────────────────────
  v_part  := p_parts -> 0;
  v_pref0 := btrim(v_part ->> 'preferred_name');
  v_sort0 := btrim(v_part ->> 'sort_name');
  v_type0 := coalesce(v_part ->> 'authority_type', 'person');

  update public.authors
     set preferred_name  = v_pref0,
         sort_name       = v_sort0,
         authority_type  = v_type0,
         structured_meta = jsonb_set(coalesce(structured_meta, '{}'::jsonb),
                                     '{authorityType}', to_jsonb(v_type0), true),
         updated_at      = now(),
         updated_by      = auth.uid()
   where id = p_author_id;

  -- `book_contributors.name` est une COPIE du nom, pas une jointure :
  -- sans cette ligne la fiche serait scindée et le livre continuerait
  -- d'afficher le nom composé.
  update public.book_contributors
     set name = v_pref0, updated_at = now()
   where author_id = p_author_id;

  -- ── Parts 1..n : fiches créées, liaisons recopiées ────────────────
  for v_part in select * from jsonb_array_elements(p_parts) offset 1 loop
    v_i := v_i + 1;

    insert into public.authors (preferred_name, sort_name, authority_type, structured_meta)
    values (btrim(v_part ->> 'preferred_name'),
            btrim(v_part ->> 'sort_name'),
            coalesce(v_part ->> 'authority_type', 'person'),
            jsonb_build_object('authorityType', coalesce(v_part ->> 'authority_type', 'person')))
    returning id into v_new;
    v_crees := v_crees + 1;

    -- `ord` doit rester libre dans (book_id, author_id, role, ord).
    -- `row_number()` en plus du max : si la fiche d'origine figure DEUX
    -- fois sur le même livre (deux rôles), un max seul donnerait deux
    -- fois la même valeur et la clé primaire sauterait.
    insert into public.book_authors (book_id, author_id, role, ord)
    select ba.book_id, v_new, ba.role,
           ((select coalesce(max(b2.ord), 0) from public.book_authors b2 where b2.book_id = ba.book_id)
            + row_number() over (partition by ba.book_id order by ba.ord, ba.role))::smallint
      from public.book_authors ba
     where ba.author_id = p_author_id
    on conflict do nothing;

    insert into public.book_contributors (book_id, author_id, position, name, role, is_primary)
    select bc.book_id, v_new,
           ((select coalesce(max(c2.position), 0) from public.book_contributors c2 where c2.book_id = bc.book_id)
            + row_number() over (partition by bc.book_id order by bc.position))::int,
           btrim(v_part ->> 'preferred_name'), bc.role, false
      from public.book_contributors bc
     where bc.author_id = p_author_id
    on conflict do nothing;
  end loop;

  -- ── Le champ libre `books.autor` ──────────────────────────────────
  -- Déprécié (CONV-O3) mais toujours affiché : le laisser porter le nom
  -- composé après la scission serait réparer à moitié. Réécrit seulement
  -- s'il vaut EXACTEMENT l'ancien nom — s'il dit autre chose, quelqu'un
  -- l'a saisi à la main et ce n'est pas à nous de l'écraser.
  update public.books b
     set autor = v_noms
    from public.book_authors ba
   where ba.book_id = b.id
     and ba.author_id = p_author_id
     and p_avant is not null
     and b.autor = p_avant;

  return v_crees;
end;
$function$;

comment on function public.fn_authority_split(bigint, jsonb, text) is
  'CONV-O8 · scinde une autorité composée. La fiche d''origine devient la '
  'première part (id, public_id et works.primary_author_id conservés) ; les '
  'autres sont créées et reçoivent une copie des liaisons. Refuse d''écrire si '
  'la fiche a changé depuis la proposition. Outil interne : appelé par '
  'api.fn_authority_apply seulement, non exposé (DOC-OBJ-2).';

revoke all on function public.fn_authority_split(bigint, jsonb, text)
  from public, anon, authenticated, service_role;

-- ---------------------------------------------------------------------
-- 4. L'application de la proposition connaît le nouveau `kind`.
-- ---------------------------------------------------------------------
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

  if v_p.kind = 'fusion' then
    if v_p.target_kind = 'author'  then perform public.merge_author(v_p.merge_into_id, v_p.target_id);
    elsif v_p.target_kind = 'subject' then perform public.merge_subject(v_p.merge_into_id, v_p.target_id);
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
    end if;

  else
    raise exception 'apply_kind_not_implemented' using hint = 'atelier.error.applyKindDeferred';
  end if;

  update public.authority_proposals set status = 'applied', applied_at = now(), updated_at = now()
   where id = p_proposal_id;

  -- Notification aux bibliothèques utilisatrices.
  --
  -- LA SCISSION RÉUTILISE `authority.edit_applied` PLUTÔT QUE D'INVENTER
  -- UN ÉVÉNEMENT. Ce n'est pas de la paresse : un `authority.split_executed`
  -- neuf devrait être ajouté au routage de la fonction Edge `notify-event`
  -- ET à ses libellés de courriel dans les dix langues. Un seul de ces
  -- endroits oublié, et la notification part dans le vide sans erreur —
  -- une notification morte est invisible, c'est ce qui la rend coûteuse.
  -- `edit_applied` résout déjà `target_id` sur la fiche d'origine, qui est
  -- exactement celle que les bibliothèques utilisaient. Le libellé
  -- sous-décrit l'événement ; c'est un défaut visible, préférable à un
  -- silence invisible.
  if v_p.kind = 'fusion' then
    perform public.fn_authority_emit('authority.merge_executed', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'merge_into_id', v_p.merge_into_id, 'proposed_by', v_p.proposed_by));
  else
    perform public.fn_authority_emit('authority.edit_applied', jsonb_build_object(
      'proposal_id', v_p.id, 'kind', v_p.kind, 'target_kind', v_p.target_kind,
      'target_id', v_p.target_id, 'proposed_by', v_p.proposed_by));
  end if;
  return 'applied';
end;
$function$;

revoke all on function api.fn_authority_apply(uuid) from public, anon;
grant execute on function api.fn_authority_apply(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 5. Vérification
-- ---------------------------------------------------------------------
do $$
declare
  n_anon bigint;
  n_kind bigint;
begin
  select count(*) into n_anon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace, aclexplode(p.proacl) a
    join pg_roles r on r.oid = a.grantee
   where n.nspname = 'api' and p.proname in ('fn_authority_apply', 'fn_authority_propose')
     and r.rolname = 'anon' and a.privilege_type = 'EXECUTE';
  if n_anon > 0 then
    raise exception 'CONV/17 — RPC de l''Atelier exécutable par anon : abandon.';
  end if;

  select count(*) into n_anon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace, aclexplode(p.proacl) a
    join pg_roles r on r.oid = a.grantee
   where n.nspname = 'public' and p.proname = 'fn_authority_split'
     and r.rolname in ('anon', 'authenticated') and a.privilege_type = 'EXECUTE';
  if n_anon > 0 then
    raise exception 'CONV/17 — fn_authority_split exposée : abandon (DOC-OBJ-2).';
  end if;

  select count(*) into n_kind from public.authority_proposals where kind = 'scission';
  raise notice 'CONV/17 — scission disponible dans le circuit de l''Atelier '
               '(% proposition(s) existante(s), aucune créée par cette migration).', n_kind;
end $$;

commit;
