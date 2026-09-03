-- ============================================================================
-- Suite de l'audit du 03/09 (§N1, §N2) — l'homonymie se cherche sans accents
-- ni casse, la proposition de C5 reconnaît les anonymes inversés, et les
-- doublons exacts sont SIGNALÉS (jamais fusionnés par script)
-- Foyer : REGISTRE §37 `CONV` · AUDIT_autorites_2026-09-03 §N1, §N2
-- ============================================================================
-- CE QUE L'AUDIT A MESURÉ. Le lot `autor_sans_autorite` a créé 227 autorités le
-- 03/09 à 16 h. Neuf d'entre elles sont des DOUBLONS de fiches que le 21/08
-- venait de corriger : `DE CARVALHO, Florentino` (11417) à côté de
-- `Carvalho, Florentino de` (10164), `CASAS, Juan Gómez` (11337) à côté de
-- `Gómez Casas, Juan` (10074), `Guattari, Felix` à côté de `Guattari, Félix`,
-- `Platao` à côté de `Platão` — les deux créées par le même lot, à deux
-- minutes d'écart.
--
-- La cause est dans `conv_revue_appliquer` : la recherche d'homonyme comparait
-- `lower(sort_name)` et `lower(preferred_name)` À LA LETTRE. Trois lettres
-- suffisent à la faire échouer : un accent (`Felix`/`Félix`), une capitale
-- héritée (`Florentino DE CARVALHO`, cf. migration précédente), ou une forme
-- directe là où la fiche est inversée (`Fabio López López` / `López, Fábio
-- López`). Une autorité est la même personne quelle que soit la graphie de la
-- transcription ; c'est la recherche qui doit être tolérante, pas la personne
-- qui doit retaper.
--
-- TROIS CHOSES, DANS CET ORDRE :
--
--   1. `fn_conv_autorite_homonyme(nom)` — UNE fonction de recherche, réutilisée
--      par tout ce qui lie une autorité depuis un nom : clé `lower(unaccent())`,
--      sur les deux formes stockées ET sur la forme dérivée du nom cherché
--      (« Nom, Prénom » ↔ « Prénom Nom »). Les fixtures de la formation BLMF
--      (`source_label = 'formacao-e*'`) passent APRÈS les vraies fiches dans
--      l'ordre de préférence : elles ne doivent jamais recevoir un lien réel.
--
--   2. `fn_conv_autor_proposition` apprend les anonymes INVERSÉS. La
--      transcription `identificado, Não` a reçu une proposition, Xavier l'a
--      validée parmi 464, et une autorité « Não identificado » existe avec deux
--      liens (11431). Le filtre lisait `n[ãa]o identific` — la virgule l'a
--      contourné. Il lit maintenant les deux ordres, sans accents, et refuse
--      aussi ce qui n'a pas une lettre (`??`). La fonction passe de `immutable`
--      à `stable` : elle appelle `unaccent`, qui dépend d'un dictionnaire.
--
--   3. `fn_conv_signaler_doublons_exacts()` — les paires dont la clé normalisée
--      est identique entrent dans `authority_duplicate_reports` (la porte que
--      l'Atelier lit déjà : « signaler un doublon »). AUCUNE fusion : la fusion
--      est un geste humain, `merge_author` depuis l'écran, avec aperçu. Treize
--      paires attendues en production ; la fonction est rejouable (elle ne
--      double pas un signalement ouvert) et exclut les fixtures de formation.
--
-- `conv_revue_appliquer` est recréée pour que sa branche C5 appelle (1). Les
-- autres branches sont RECOPIÉES telles quelles depuis 20260903150117 — une
-- fonction ne se retape pas, elle se recopie et se relit (doctrine du dépôt).
--
-- Suite : tests/sql/conv_homonymie_tests.sql.
-- ============================================================================
begin;

-- ── 1 · La recherche d'homonyme ─────────────────────────────────────────────
create or replace function public.fn_conv_autorite_homonyme(p_nom text)
returns bigint
language sql
stable
set search_path to 'public', 'pg_catalog'
as $$
  with cible as (
    select lower(extensions.unaccent(btrim(regexp_replace(p_nom, '\s+', ' ', 'g')))) as k,
           -- la forme dérivée : « Nom, Prénom » → « Prénom Nom » (une seule virgule,
           -- des prénoms) ; sinon le nom lui-même
           case
             when p_nom ~ ', ' and (length(p_nom) - length(replace(p_nom, ',', ''))) = 1
                  and btrim(split_part(p_nom, ', ', 2)) <> ''
               then lower(extensions.unaccent(btrim(regexp_replace(split_part(p_nom, ', ', 2) || ' ' || split_part(p_nom, ', ', 1), '\s+', ' ', 'g'))))
             else lower(extensions.unaccent(btrim(regexp_replace(p_nom, '\s+', ' ', 'g'))))
           end as k_derive
  )
  select a.id
    from public.authors a, cible c
   where c.k <> ''
     and (   lower(extensions.unaccent(btrim(a.sort_name)))      in (c.k, c.k_derive)
          or lower(extensions.unaccent(btrim(a.preferred_name))) in (c.k, c.k_derive)
          or (a.sort_name ~ ', '
              and lower(extensions.unaccent(btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1)))) in (c.k, c.k_derive)))
   order by (coalesce(a.source_label, '') like 'formacao-%'), a.id
   limit 1
$$;

comment on function public.fn_conv_autorite_homonyme(text) is
  'Audit 03/09 · retrouve UNE autorité par un nom, sans casse ni accents, sur '
  'sort_name, preferred_name et la forme dérivée (« Nom, Prénom » ↔ « Prénom Nom »). '
  'Les fixtures de formation (source_label formacao-*) passent après les vraies fiches. '
  'NULL si rien. C''est la seule recherche que les lots de la file doivent employer.';

-- Pas de porte applicative : seule `conv_revue_appliquer` (SECURITY DEFINER,
-- propriétaire postgres) l'appelle. Rien pour anon, rien pour authenticated.
revoke all on function public.fn_conv_autorite_homonyme(text) from public, anon, authenticated;

-- ── 2 · La proposition de C5 reconnaît les anonymes, dans les deux ordres ──
create or replace function public.fn_conv_autor_proposition(p_autor text)
returns text
language sql
stable
set search_path to 'public', 'pg_catalog'
as $$
  select case
    when p_autor is null then null
    when btrim(split_part(p_autor, ';', 1)) = '' then null
    -- pas une lettre : « ?? », « --- », « . »
    when btrim(split_part(p_autor, ';', 1)) !~ '[[:alpha:]]' then null
    when lower(extensions.unaccent(btrim(split_part(p_autor, ';', 1))))
         ~ '(anonim|anonym|nao identific|identificad[oa], nao|desconhecid|unknown|coletivo|colectivo|collectif|aa\. ?vv|varios autores|autores, varios|autori vari|sem autor|autoria, sem|^s\.? ?n\.?$|^s/a$|^n/a$)'
      then null
    else btrim(split_part(p_autor, ';', 1))
  end
$$;
comment on function public.fn_conv_autor_proposition(text) is
  'C5/B · le premier nom d''une chaîne « A ; B ; C », ou NULL pour les formes '
  'anonymes ou collectives — dans les deux ordres (« Não identificado » comme '
  '« identificado, Não »), sans accents, et jamais pour une chaîne sans lettre. '
  'Une proposition, jamais une décision.';

-- ── 3 · Le signalement des doublons exacts ──────────────────────────────────
create or replace function public.fn_conv_signaler_doublons_exacts()
returns bigint
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare v_n bigint;
begin
  with n as (
    select a.id, a.sort_name,
           lower(extensions.unaccent(btrim(a.sort_name)))      as k_sort,
           lower(extensions.unaccent(btrim(a.preferred_name))) as k_pref,
           case when a.sort_name ~ ', ' and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
                     and btrim(split_part(a.sort_name, ', ', 2)) <> ''
                then lower(extensions.unaccent(btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))))
           end as k_derive
      from public.authors a
     where coalesce(a.source_label, '') not like 'formacao-%'
  ),
  paires as (
    select a.id as id_a, b.id as id_b,
           case when a.k_sort = b.k_sort then 'même point d''accès'
                when a.k_pref = b.k_pref then 'même forme d''affichage'
                when a.k_sort = b.k_pref or a.k_pref = b.k_sort then 'point d''accès de l''une = affichage de l''autre'
                else 'forme directe de l''une = forme inversée de l''autre' end as motif
      from n a
      join n b on a.id < b.id
     where a.k_sort = b.k_sort
        or a.k_pref = b.k_pref
        or a.k_sort = b.k_pref or a.k_pref = b.k_sort
        or (a.k_derive is not null and a.k_derive = b.k_sort)
        or (b.k_derive is not null and b.k_derive = a.k_sort)
  ),
  faits as (
    insert into public.authority_duplicate_reports (author_id_a, author_id_b, note, reported_by)
    select p.id_a, p.id_b,
           'Audit des autorités du 03/09/2026 · doublon exact, sans casse ni accents : ' || p.motif
             || '. Fusionner depuis l''Atelier (aperçu, puis merge_author) — jamais par script.',
           null
      from paires p
     where not exists (select 1 from public.authority_duplicate_reports r
                        where r.author_id_a = p.id_a and r.author_id_b = p.id_b and r.status = 'open')
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$$;

comment on function public.fn_conv_signaler_doublons_exacts() is
  'Audit 03/09 · signale dans authority_duplicate_reports chaque paire d''autorités '
  'dont la clé normalisée (sans casse ni accents, forme directe ↔ inversée) est '
  'identique. Ne fusionne RIEN. Rejouable : un signalement ouvert n''est pas doublé. '
  'Les fixtures de formation sont ignorées. Migration seulement (aucun grant).';

-- SECURITY INVOKER, aucun grant : seule une migration (rôle postgres) l'exécute.
-- Pourquoi pas la garde « staff OU current_user = postgres » du semis C5 ? Parce
-- qu'elle ne garde rien : dans une fonction SECURITY DEFINER, current_user vaut
-- le PROPRIÉTAIRE (postgres), donc la condition est toujours vraie et n'importe
-- quel compte connecté passe. Mesuré en écrivant la suite de la migration
-- précédente. Le semis C5 est refermé ci-dessous pour la même raison.
revoke all on function public.fn_conv_signaler_doublons_exacts() from public, anon, authenticated;

-- Le semis C5 (20260903150117) portait cette garde-là ET un grant à
-- authenticated : tout compte connecté pouvait le lancer. Aucun écran ne
-- l'appelle (grep src/ et supabase/functions/ : rien) — on retire le grant.
revoke execute on function public.fn_conv_lot_autor_sans_autorite_seed() from authenticated;

-- ── 4 · Appliquer : la branche C5 passe par la recherche tolérante ──────────
--     Les autres branches sont recopiées de 20260903150117, inchangées.
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

      -- L'autorité : retrouvée sans casse ni accents, sur les deux formes et la
      -- forme dérivée (audit 03/09, §N2) ; sinon créée.
      v_author := public.fn_conv_autorite_homonyme(v_cible);
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
                        and lower(extensions.unaccent(btrim(c2.name))) = lower(extensions.unaccent(v_cible))
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

-- ── 5 · Grants relus, pas supposés (DOC-OBJ-2) ──────────────────────────────
revoke all on function api.conv_revue_appliquer(text) from public, anon;
grant execute on function api.conv_revue_appliquer(text) to authenticated;
revoke all on function public.fn_conv_autor_proposition(text) from public, anon;
grant execute on function public.fn_conv_autor_proposition(text) to authenticated;

do $$
begin
  if has_function_privilege('anon', 'api.conv_revue_appliquer(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_conv_autorite_homonyme(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_conv_signaler_doublons_exacts()', 'EXECUTE') then
    raise exception 'Audit 03/09 — une fonction de la file est exécutable par anon : abandon.';
  end if;
  if has_function_privilege('authenticated', 'public.fn_conv_autorite_homonyme(text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_signaler_doublons_exacts()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_lot_autor_sans_autorite_seed()', 'EXECUTE') then
    raise exception 'Audit 03/09 — une fonction de maintenance est exécutable depuis l''application : abandon.';
  end if;
  if not has_function_privilege('authenticated', 'api.conv_revue_appliquer(text)', 'EXECUTE') then
    raise exception 'Audit 03/09 — conv_revue_appliquer doit rester exécutable par authenticated (l''écran) : abandon.';
  end if;
  -- La branche C5 doit bien passer par la recherche tolérante (relecture du corps,
  -- commentaires retirés — cf. mémoire prosrc/commentaires).
  if regexp_replace((select p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'api' and p.proname = 'conv_revue_appliquer'), '--[^\n]*', '', 'g')
     not ilike '%fn_conv_autorite_homonyme(v_cible)%' then
    raise exception 'Audit 03/09 — conv_revue_appliquer n''appelle pas fn_conv_autorite_homonyme : abandon.';
  end if;
end $$;

-- ── 6 · Le signalement : 13 paires attendues en production, 0 sur une base fraîche.
do $$
declare v_n bigint;
begin
  select public.fn_conv_signaler_doublons_exacts() into v_n;
  raise notice 'Audit 03/09 — % paire(s) de doublons exacts signalée(s) à l''Atelier.', v_n;
end $$;

commit;
