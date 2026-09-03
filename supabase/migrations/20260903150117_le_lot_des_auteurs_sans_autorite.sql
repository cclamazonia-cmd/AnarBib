-- ============================================================================
-- C5 = B (verdict de Xavier, 03/09/2026) — le lot « autor_sans_autorite »
-- ============================================================================
-- `books.autor` est CONSERVÉ comme forme transcrite (ce que dit la page de
-- titre) ; l'autorité liée est la vérité ; le rendu affiche l'autorité si elle
-- existe, la transcription sinon (`author_display`, déjà en place). Ce que la
-- décision ajoute, c'est un LOT DE LA FILE : les livres dont AUCUN contributeur
-- ne porte d'autorité (`book_contributors.author_id` nul partout, ou aucun
-- contributeur) entrent dans `catalog_review_queue` pour être liés à la main.
--
-- Compté en production le 03/09 : 464 livres. La fiche C5 en comptait 226 —
-- elle regardait `book_authors`, qui est une table DÉRIVÉE (trigger
-- `trg_sync_book_authors`) ; la vérité des contributeurs vit dans
-- `book_contributors`, et c'est elle que `v_book_authors_canonical` lit.
--
-- Sémantique du lot, dans le vocabulaire des quatre autres :
--   avant          = la transcription (`books.autor`)
--   apres_propose  = le PREMIER nom de la chaîne, tel qu'écrit — l'outil propose,
--                    il ne décide pas ; « Anônimo », « Coletivo », « AA. VV. »
--                    et « não identificado » ne reçoivent AUCUNE proposition.
--   valide         = lier ce nom (autorité existante, ou créée)
--   corrige        = lier la valeur saisie (forme « Nom, Prénom »)
--   ecarte         = la transcription suffit — pas d'autorité à créer
--
-- Appliquer, pour ce lot, n'écrit PAS dans `books` : il pose un lien. Une
-- autorité est retrouvée par sa forme de tri OU d'affichage (sans casse) ; à
-- défaut elle est créée avec les deux formes, comme le fait déjà le lot des
-- patronymes. Le lien va sur le contributeur homonyme s'il existe, sinon sur
-- une ligne nouvelle en position suivante. Anti-écrasement (CONV-O6) : rien
-- n'est écrit si `books.autor` a changé depuis le semis, ou si un contributeur
-- porte déjà une autorité. Multi-personnes : seule la première est liée ; le
-- reste est à la main, dans le formulaire.
--
-- Rejouable dans les deux ordres : `create or replace`, semis en
-- `on conflict do nothing`, et la CHECK élargie idempotente.
-- ============================================================================
begin;

-- 1 · La CHECK du lot bouge avec l'allowlist des fonctions (CONV-O7 test 2).
alter table public.catalog_review_queue
  drop constraint if exists catalog_review_queue_lot_chk;
alter table public.catalog_review_queue
  add constraint catalog_review_queue_lot_chk
  check (lot in ('titre_casse', 'autorite_casse', 'autorite_patronyme',
                 'autorite_collectivite', 'autor_sans_autorite'));

-- 2 · La proposition de l'outil : le premier nom de la chaîne, ou rien.
create or replace function public.fn_conv_autor_proposition(p_autor text)
returns text
language sql
immutable
set search_path to 'pg_catalog'
as $$
  select case
    when p_autor is null then null
    when btrim(split_part(p_autor, ';', 1)) = '' then null
    when lower(btrim(split_part(p_autor, ';', 1))) ~ '(an[ôo]nim|n[ãa]o identific|coletivo|colectivo|collectif|aa\. ?vv|vários autores|varios autores|sem autor)'
      then null
    else btrim(split_part(p_autor, ';', 1))
  end
$$;
comment on function public.fn_conv_autor_proposition(text) is
  'C5/B · le premier nom d''une chaîne « A ; B ; C », ou NULL pour les formes '
  'anonymes ou collectives. Une proposition, jamais une décision.';

-- 3 · Le semis, rejouable : les livres sans autorité liée entrent dans la file.
create or replace function public.fn_conv_lot_autor_sans_autorite_seed()
returns bigint
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $$
declare v_n bigint;
begin
  if not (public.fn_caller_is_staff() or current_user in ('postgres', 'supabase_admin')) then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;
  with faits as (
    insert into public.catalog_review_queue (lot, entity_kind, entity_id, contexte, avant, apres_propose)
    select 'autor_sans_autorite', 'book', b.id,
           (select string_agg(distinct l.slug, ',') from public.book_holdings h join public.libraries l on l.id = h.library_id where h.book_id = b.id),
           b.autor, public.fn_conv_autor_proposition(b.autor)
      from public.books b
     where nullif(btrim(coalesce(b.autor, '')), '') is not null
       and not exists (select 1 from public.book_contributors c where c.book_id = b.id and c.author_id is not null)
    on conflict (lot, entity_id) do nothing
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$$;
revoke all on function public.fn_conv_lot_autor_sans_autorite_seed() from public, anon;
grant execute on function public.fn_conv_lot_autor_sans_autorite_seed() to authenticated;

-- 4 · La liste : pour ce lot, « actuel » est la transcription, pas le titre.
create or replace function api.conv_revue_list(p_lot text, p_decision text default 'a_revoir', p_max integer default 50, p_offset integer default 0)
returns table(id bigint, entity_kind text, entity_id bigint, contexte text, avant text, apres_propose text, decision text, valeur_retenue text, note text, applique_le timestamptz, actuel text, perime boolean)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $$
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  return query
    select q.id, q.entity_kind, q.entity_id, q.contexte, q.avant, q.apres_propose,
           q.decision, q.valeur_retenue, q.note, q.applique_le,
           v.actuel,
           -- « périmé » = l'instantané ne décrit plus l'entité. Une ligne DÉJÀ
           -- APPLIQUÉE diverge forcément (c'est nous qui l'avons changée) : elle
           -- n'est donc jamais signalée comme périmée.
           (q.applique_le is null and v.actuel is not null and v.actuel is distinct from q.avant)
      from public.catalog_review_queue q
      left join lateral (
        select case
                 when q.entity_kind = 'author' then (select a.sort_name from public.authors a where a.id = q.entity_id)
                 when q.lot = 'autor_sans_autorite' then (select b.autor from public.books b where b.id = q.entity_id)
                 else (select b.titulo from public.books b where b.id = q.entity_id)
               end as actuel
      ) v on true
     where q.lot = p_lot
       and (p_decision is null or q.decision = p_decision)
     order by q.avant, q.id
     limit greatest(1, least(coalesce(p_max, 50), 200))
    offset greatest(0, coalesce(p_offset, 0));
end;
$$;

-- 5 · Appliquer : la branche du lien, avant les branches existantes (inchangées).
create or replace function api.conv_revue_appliquer(p_lot text)
returns table(applique bigint, refuse bigint, nonfiling_reinit bigint)
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $$
declare
  v_uid  uuid := auth.uid();
  v_app  bigint := 0;
  v_ref  bigint := 0;
  v_nf   bigint := 0;
  r      record;
  v_cible text;
  v_author bigint;
  v_pref  text;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  if p_lot is null or p_lot not in ('titre_casse', 'autorite_casse',
                                    'autorite_patronyme', 'autorite_collectivite',
                                    'autor_sans_autorite') then
    raise exception 'Lote inválido: %', p_lot using errcode = '22023';
  end if;

  -- ── AUTEURS SANS AUTORITÉ (C5/B) ─────────────────────────────────────
  if p_lot = 'autor_sans_autorite' then
    for r in
      select q.id, q.entity_id, public.fn_conv_cible(q.valeur_retenue, q.apres_propose) as cible, q.avant
        from public.catalog_review_queue q
       where q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       order by q.id
    loop
      v_cible := btrim(r.cible);
      -- Anti-écrasement : la transcription doit être celle du semis, et aucun
      -- contributeur ne doit déjà porter d'autorité.
      if not exists (select 1 from public.books b where b.id = r.entity_id and b.autor = r.avant)
         or exists (select 1 from public.book_contributors c where c.book_id = r.entity_id and c.author_id is not null) then
        continue;
      end if;

      -- L'autorité : retrouvée par l'une des deux formes, sans casse ; sinon créée.
      select a.id into v_author
        from public.authors a
       where lower(btrim(a.sort_name)) = lower(v_cible)
          or lower(btrim(a.preferred_name)) = lower(v_cible)
       order by a.id
       limit 1;
      if v_author is null then
        v_pref := case
          when v_cible ~ ', ' and (length(v_cible) - length(replace(v_cible, ',', ''))) = 1
            then btrim(split_part(v_cible, ', ', 2) || ' ' || split_part(v_cible, ', ', 1))
          else v_cible
        end;
        insert into public.authors (sort_name, preferred_name, source_kind, source_label)
        values (v_cible, v_pref, 'conv_revue', 'C5 · lot autor_sans_autorite')
        returning id into v_author;
      end if;

      -- Le lien : sur le contributeur homonyme s'il existe, sinon une ligne neuve.
      update public.book_contributors c
         set author_id = v_author
       where c.id = (select c2.id from public.book_contributors c2
                      where c2.book_id = r.entity_id and c2.author_id is null
                        and lower(btrim(c2.name)) = lower(v_cible)
                      order by c2.position limit 1);
      if not found then
        insert into public.book_contributors (book_id, author_id, position, name, role, is_primary)
        select r.entity_id, v_author,
               coalesce((select max(c3.position) from public.book_contributors c3 where c3.book_id = r.entity_id), 0) + 1,
               v_cible, 'autor',
               not exists (select 1 from public.book_contributors c4 where c4.book_id = r.entity_id and c4.is_primary);
      end if;

      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
       where q.id = r.id
         and exists (select 1 from public.book_contributors c where c.book_id = r.entity_id and c.author_id is not null);
      if found then v_app := v_app + 1; end if;
    end loop;

  -- ── COLLECTIVITÉS ────────────────────────────────────────────────────
  elsif p_lot = 'autorite_collectivite' then

    update public.authors a
       set authority_type = 'collective',
           structured_meta = jsonb_set(coalesce(a.structured_meta, '{}'::jsonb),
                                       '{authorityType}', '"collective"'::jsonb, true),
           sort_name       = public.fn_conv_cible(q.valeur_retenue, q.apres_propose),
           preferred_name  = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      from public.catalog_review_queue q
     where q.entity_id = a.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and a.sort_name = q.avant;

    with faits as (
      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
        from public.authors a
       where a.id = q.entity_id
         and q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and a.sort_name = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
         and a.authority_type = 'collective'
      returning 1
    )
    select count(*) into v_app from faits;

  -- ── AUTORITÉS (casse, patronymes) ────────────────────────────────────
  elsif p_lot in ('autorite_casse', 'autorite_patronyme') then

    update public.authors a
       set preferred_name = case
             when public.fn_conv_cible(q.valeur_retenue, q.apres_propose) ~ ', '
              and (length(public.fn_conv_cible(q.valeur_retenue, q.apres_propose))
                   - length(replace(public.fn_conv_cible(q.valeur_retenue, q.apres_propose), ',', ''))) = 1
             then btrim(split_part(public.fn_conv_cible(q.valeur_retenue, q.apres_propose), ', ', 2)
                        || ' ' ||
                        split_part(public.fn_conv_cible(q.valeur_retenue, q.apres_propose), ', ', 1))
             else public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
           end
      from public.catalog_review_queue q
     where q.entity_id = a.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and a.sort_name = q.avant
       and a.preferred_name = btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1));

    update public.authors a
       set sort_name = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      from public.catalog_review_queue q
     where q.entity_id = a.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and a.sort_name = q.avant;

    with faits as (
      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
        from public.authors a
       where a.id = q.entity_id
         and q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and a.sort_name = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      returning 1
    )
    select count(*) into v_app from faits;

  -- ── NOTICES ──────────────────────────────────────────────────────────
  else
    update public.books b
       set titulo = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      from public.catalog_review_queue q
     where q.entity_id = b.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       and b.titulo = q.avant;

    with faits as (
      update public.catalog_review_queue q
         set applique_le = now(), applique_par = v_uid
        from public.books b
       where b.id = q.entity_id
         and q.lot = p_lot
         and q.decision in ('valide', 'corrige')
         and q.applique_le is null
         and b.titulo = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      returning 1
    )
    select count(*) into v_app from faits;

    with remis as (
      update public.books b
         set title_nonfiling = 0
       where b.title_nonfiling is not null
         and b.title_nonfiling > 0
         and b.id in (select q2.entity_id from public.catalog_review_queue q2
                       where q2.lot = p_lot and q2.applique_le is not null)
         and substr(b.titulo, b.title_nonfiling, 1) not in (' ', '''', '’')
      returning 1
    )
    select count(*) into v_nf from remis;
  end if;

  select count(*) into v_ref
    from public.catalog_review_queue q
   where q.lot = p_lot
     and q.decision in ('valide', 'corrige')
     and q.applique_le is null;

  return query select v_app, v_ref, v_nf;
end;
$$;

-- 6 · Grants relus, pas supposés (DOC-OBJ-2) : `create or replace` les garde,
--     on les ré-affirme et on vérifie qu'anon n'exécute rien.
revoke all on function api.conv_revue_list(text, text, integer, integer) from public, anon;
grant execute on function api.conv_revue_list(text, text, integer, integer) to authenticated;
revoke all on function api.conv_revue_appliquer(text) from public, anon;
grant execute on function api.conv_revue_appliquer(text) to authenticated;
revoke all on function public.fn_conv_autor_proposition(text) from public, anon;
grant execute on function public.fn_conv_autor_proposition(text) to authenticated;

do $$
begin
  if has_function_privilege('anon', 'api.conv_revue_appliquer(text)', 'EXECUTE')
     or has_function_privilege('anon', 'api.conv_revue_list(text,text,integer,integer)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_conv_lot_autor_sans_autorite_seed()', 'EXECUTE') then
    raise exception 'C5/B — une fonction de la file est exécutable par anon : abandon.';
  end if;
end $$;

-- 7 · Le semis : 0 ligne sur une base fraîche (CI), 464 attendues en production.
do $$
declare v_n bigint;
begin
  select public.fn_conv_lot_autor_sans_autorite_seed() into v_n;
  raise notice 'C5/B — lot autor_sans_autorite : % ligne(s) semée(s).', v_n;
end $$;

commit;
