-- ============================================================================
-- Suite de l'audit du 03/09 (§N1, §A2, §A3) — le lot « autorite_forme » :
-- la forme du point d'accès se relit à la main
-- Foyer : REGISTRE §37 `CONV` · CONV-2, CONV-6 · AUDIT_autorites_2026-09-03 §N1
-- ============================================================================
-- CE QUE L'AUDIT A MESURÉ. Le lot C5 a créé l'autorité avec la transcription
-- telle qu'écrite : 95 des 227 fiches n'ont pas de virgule — 60 formes directes
-- (« Daniel Rodrigues Aurélio », « Mark Bray », « Newton Stadler de Souza ») et
-- 35 mononymes ou pseudonymes (« Voltaire », « Starhawk », « Meltzer ») ; 7
-- portent une mention de rôle dans le nom (« Kauan Willian dos Santos (Org.) »,
-- « LUDMILA, Aline (et al.) ») ; une porte ses dates (« Hakim Bey 1945-2022 »).
-- Et hors C5, trois « Jr. » que le 20/08 ne cherchait pas (« Jr., Armando
-- Boito ») et deux particules en tête (« De Serpa Pimentel, Antonio », « Van
-- Paassen, Pierre »).
--
-- Aucun de ces cas n'est mécanisable : où couper « Fabio López López » (es :
-- « López López, Fabio ») ou « Daniel Rodrigues Aurélio » (pt : « Aurélio,
-- Daniel Rodrigues ») est un jugement ; « Meltzer » est-il à compléter en
-- « Meltzer, Albert » (qui existe) ou à confirmer ; « Filósofo da Selva » est
-- un pseudonyme voulu. Donc un LOT DE LA FILE, sur le patron de 20260903150117 :
-- la CHECK s'élargit avec l'allowlist, une proposition, un semis rejouable, une
-- branche d'application, une carte à l'écran, une clé i18n × 10.
--
-- LA PROPOSITION (`fn_conv_forme_proposition`) est un point de départ :
--   · une mention entre parenthèses en fin de nom est retirée — le rôle va sur
--     `book_contributors.role`, pas dans le nom (« (Org.) », « (et al.) ») ;
--   · des dates en fin de nom sont retirées (« 1945-2022 » : CONV-5 a des colonnes) ;
--   · forme directe → « Dernier mot, le reste », les particules précédant le
--     patronyme passant après les prénoms (« Souza, Newton Stadler de ») ;
--   · filiation en tête → « Patronyme Jr., Prénoms » ; particule en tête →
--     « Patronyme, Prénoms particule » (CONV-6 : rejetée en pt/fr ; conservée en
--     it/af/en, d'où l'exclusion par `name_lang`) ;
--   · mononyme → le nom lui-même : VALIDER = « c'est un mononyme, on le garde »,
--     CORRIGER = le compléter ;
--   · un patronyme tout en capitales est passé en casse naturelle au passage
--     (une fiche, un lot : ces fiches ne vont pas aussi au lot casse) ;
--   · plusieurs personnes dans une fiche → AUCUNE proposition : la scission n'est
--     pas de ce lot (CONV-O8), ces fiches ne sont pas semées.
--
-- Ce qu'on NE sème pas : collectivités (typées, ou au motif — lot des
-- collectivités), fixtures de formation, fiches en signalement de doublon
-- ouvert, fiches doubles, fiches à la forme inversée ordinaire.
--
-- L'application réutilise la branche des autorités (casse/patronyme) : écrire
-- `sort_name`, faire suivre `preferred_name` quand il était dérivé, marquer la
-- ligne. Anti-écrasement CONV-O6 : `a.sort_name = q.avant`.
-- `conv_revue_appliquer` est recopiée de la migration précédente ; seule
-- l'allowlist et le `elsif` des autorités changent.
--
-- Compté en production le 03/09 : ~95 candidates. 0 sur une base fraîche.
-- Suite : tests/sql/conv_forme_tests.sql.
-- ============================================================================
begin;

-- ── 1 · La CHECK du lot bouge avec l'allowlist (CONV-O7 test 2) ─────────────
alter table public.catalog_review_queue
  drop constraint if exists catalog_review_queue_lot_chk;
alter table public.catalog_review_queue
  add constraint catalog_review_queue_lot_chk
  check (lot in ('titre_casse', 'autorite_casse', 'autorite_patronyme',
                 'autorite_collectivite', 'autor_sans_autorite', 'autorite_forme'));

-- ── 2 · La proposition ──────────────────────────────────────────────────────
create or replace function public.fn_conv_forme_proposition(p_sort_name text)
returns text
language plpgsql
immutable
set search_path to 'pg_catalog'
as $$
declare
  v        text;
  v_tete   text;
  v_reste  text;
  v_parts  text[];
  v_n      int;
  v_i      int;
  v_partic text := '';
  c_particules constant text := '^(de|da|do|dos|das|di|del|della|dalla|van|von|der|den|le|la|du|des|y|e|i)$';
begin
  if p_sort_name is null then return null; end if;
  v := btrim(regexp_replace(p_sort_name, '\s+', ' ', 'g'));
  -- mention entre parenthèses en fin (rôle, qualificatif) et dates en fin
  v := btrim(regexp_replace(v, '\s*\([^)]*\)\s*$', ''));
  v := btrim(regexp_replace(v, '\s+\d{4}\s*[-–]\s*\d{4}\s*$', ''));
  if v = '' or v !~ '[[:alpha:]]' then return null; end if;

  -- plusieurs personnes : pas de proposition
  if (length(v) - length(replace(v, ',', ''))) > 1
     or v ~ '(;|&|/| and | y | et |\met al\M)'
     or v ~ ' e [[:upper:]]' then
    return null;
  end if;

  if v ~ ', ' then
    v_tete  := btrim(split_part(v, ', ', 1));
    v_reste := btrim(split_part(v, ', ', 2));
    if v_reste = '' then return null; end if;
    -- filiation en tête : « Jr., Armando Boito » → « Boito Jr., Armando »
    if v_tete ~* '^(jr\.?|filho|filha|j[úu]nior|junior|neto|sobrinho)$' then
      v_parts := regexp_split_to_array(v_reste, ' ');
      v_n := array_length(v_parts, 1);
      if v_n < 2 then return v; end if;
      v := v_parts[v_n] || ' ' || v_tete || ', ' || array_to_string(v_parts[1:v_n-1], ' ');
    -- particule en tête : « De Serpa Pimentel, Antonio » → « Serpa Pimentel, Antonio de »
    elsif v_tete ~* '^(de|da|do|dos|das|di|van|von|der|den|le|la|du|des) \S' then
      v := regexp_replace(v_tete, '^\S+ ', '') || ', ' || v_reste || ' ' || lower(split_part(v_tete, ' ', 1));
    end if;
    -- forme inversée : proposition = le nom nettoyé
  else
    v_parts := regexp_split_to_array(v, ' ');
    v_n := array_length(v_parts, 1);
    if v_n >= 2 then
      -- patronyme = dernier mot ; les particules qui le précèdent passent après les prénoms
      v_i := v_n - 1;
      while v_i >= 1 and v_parts[v_i] ~* c_particules loop
        v_partic := v_parts[v_i] || case when v_partic = '' then '' else ' ' || v_partic end;
        v_i := v_i - 1;
      end loop;
      if v_i >= 1 then
        v := v_parts[v_n] || ', ' || array_to_string(v_parts[1:v_i], ' ')
             || case when v_partic <> '' then ' ' || v_partic else '' end;
      end if;
    end if;
    -- mononyme (v_n = 1) : le nom lui-même — valider = confirmer
  end if;

  -- un patronyme tout en capitales passe en casse naturelle (une fiche, un lot)
  if v ~ ', ' and split_part(v, ', ', 1) ~ '\m[A-ZÀ-Þ]{2,}\M' then
    v := initcap(split_part(v, ', ', 1)) || ', ' || split_part(v, ', ', 2);
  elsif v !~ ', ' and v ~ '\m[A-ZÀ-Þ]{2,}\M' and v !~ ' ' then
    v := initcap(v);
  end if;
  return v;
end;
$$;

comment on function public.fn_conv_forme_proposition(text) is
  'Audit 03/09 · proposition de forme pour le lot autorite_forme : retire une mention '
  'entre parenthèses et des dates en fin, inverse une forme directe (particules après '
  'les prénoms), remet une filiation ou une particule de tête à sa place, rend le '
  'mononyme tel quel (valider = confirmer), NULL pour plusieurs personnes. Un point de '
  'départ, jamais une décision.';

revoke all on function public.fn_conv_forme_proposition(text) from public, anon;
grant execute on function public.fn_conv_forme_proposition(text) to authenticated;

-- ── 3 · Le semis, rejouable ─────────────────────────────────────────────────
create or replace function public.fn_conv_lot_autorite_forme_seed()
returns bigint
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare v_n bigint;
begin
  with cand as (
    select a.id, a.sort_name,
           case
             when a.sort_name ~ '\(' then 'mention'
             when a.sort_name ~ '\s\d{4}\s*[-–]\s*\d{4}\s*$' then 'dates'
             when a.sort_name ~ ', ' and split_part(a.sort_name, ', ', 1) ~* '^(jr\.?|filho|filha|j[úu]nior|junior|neto|sobrinho)$' then 'filiation'
             when a.sort_name ~ ', ' and split_part(a.sort_name, ', ', 1) ~* '^(de|da|do|dos|das|di|van|von|der|den|le|la|du|des) \S' then 'particule'
             when a.sort_name !~ ', ' and a.sort_name ~ ' ' then 'directe'
             when a.sort_name !~ ', ' then 'mononyme'
           end as classe
      from public.authors a
     where coalesce(a.authority_type, '') not in ('collective', 'congress')
       and a.sort_name !~* private.conv_motifs_collectivite()
       and coalesce(a.source_label, '') not like 'formacao-%'
       and not exists (select 1 from public.authority_duplicate_reports r
                        where r.status = 'open' and a.id in (r.author_id_a, r.author_id_b))
       -- pas les fiches doubles (CONV-O8) ni le bruit sans lettre (§N4)
       and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) <= 1
       and a.sort_name !~ '(;|&|/| and | y | et |\met al\M)'
       and a.sort_name !~ ' e [[:upper:]]'
       and a.sort_name ~ '[[:alpha:]]'
  )
  , faits as (
    insert into public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose, decision, note)
    select 'autorite_forme', 'author', c.id, c.sort_name,
           public.fn_conv_forme_proposition(c.sort_name),
           'a_revoir',
           'Audit 03/09 · ' || case c.classe
             when 'mention'   then 'une mention (rôle, qualificatif) est dans le nom : elle en sort ; le rôle va sur le contributeur.'
             when 'dates'     then 'des dates sont dans le nom : elles en sortent (CONV-5 a des colonnes pour elles).'
             when 'filiation' then 'point d''accès posé sur un suffixe de filiation (« Jr. », « Filho ») : il rejoint le patronyme.'
             when 'particule' then 'particule en tête : rejetée après les prénoms en pt/fr, conservée en it/af/en (CONV-6). Écarter si la langue du nom la conserve.'
             when 'directe'   then 'forme directe « Prénom Nom » : où couper est un jugement (double patronyme hispanique, prénom composé). La proposition prend le dernier mot.'
             else                  'mononyme ou pseudonyme : valider = le confirmer tel quel ; corriger = le compléter (« Meltzer, Albert »).'
           end
      from cand c
     where c.classe is not null
       and (c.classe <> 'particule' or not exists (select 1 from public.authors x where x.id = c.id and coalesce(x.name_lang, '') ~ '^(it|af|en|nl-BE)'))
    on conflict (lot, entity_id) do nothing
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$$;

comment on function public.fn_conv_lot_autorite_forme_seed() is
  'Audit 03/09 · verse dans la file (lot autorite_forme) les points d''accès dont la '
  'FORME est à relire : forme directe, mononyme, mention dans le nom, dates dans le '
  'nom, filiation ou particule en tête. Hors collectivités, fixtures de formation, '
  'doublons signalés et fiches doubles. on conflict do nothing. Migration seulement.';

revoke all on function public.fn_conv_lot_autorite_forme_seed() from public, anon, authenticated;

-- ── 4 · Appliquer : l'allowlist et la branche des autorités connaissent le lot ─
--     Recopiée de la migration précédente ; deux lignes changent.
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
                                    'autor_sans_autorite', 'autorite_forme') then
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

  -- ── AUTORITÉS (casse, patronymes, forme) ─────────────────────────────
  elsif p_lot in ('autorite_casse', 'autorite_patronyme', 'autorite_forme') then

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

-- ── 5 · Grants relus (DOC-OBJ-2) et gardes structurelles ────────────────────
revoke all on function api.conv_revue_appliquer(text) from public, anon;
grant execute on function api.conv_revue_appliquer(text) to authenticated;

do $$
begin
  if has_function_privilege('anon', 'api.conv_revue_appliquer(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_conv_forme_proposition(text)', 'EXECUTE')
     or has_function_privilege('anon', 'public.fn_conv_lot_autorite_forme_seed()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_lot_autorite_forme_seed()', 'EXECUTE') then
    raise exception 'autorite_forme — une fonction est exécutable là où elle ne doit pas : abandon.';
  end if;
  if not exists (select 1 from pg_constraint
                  where conrelid = 'public.catalog_review_queue'::regclass
                    and conname = 'catalog_review_queue_lot_chk'
                    and pg_get_constraintdef(oid) like '%autorite_forme%') then
    raise exception 'autorite_forme — la CHECK du lot ne connaît pas le nouveau lot : abandon.';
  end if;
  if regexp_replace((select p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'api' and p.proname = 'conv_revue_appliquer'), '--[^\n]*', '', 'g')
     not ilike '%''autorite_forme''%' then
    raise exception 'autorite_forme — conv_revue_appliquer ne connaît pas le lot : abandon.';
  end if;
  -- la proposition tient ses promesses
  if public.fn_conv_forme_proposition('Newton Stadler de Souza') is distinct from 'Souza, Newton Stadler de'
     or public.fn_conv_forme_proposition('Jr., Armando Boito') is distinct from 'Boito Jr., Armando'
     or public.fn_conv_forme_proposition('Kauan Willian dos Santos (Org.)') is distinct from 'Santos, Kauan Willian dos'
     or public.fn_conv_forme_proposition('Voltaire') is distinct from 'Voltaire'
     or public.fn_conv_forme_proposition('Antonio Serra & Cristina Pereira') is not null then
    raise exception 'autorite_forme — la proposition ne tient pas ses promesses : abandon.';
  end if;
end $$;

-- ── 6 · Le semis : ~95 attendues en production, 0 sur une base fraîche ───────
do $$
declare v_n bigint;
begin
  select public.fn_conv_lot_autorite_forme_seed() into v_n;
  raise notice 'autorite_forme — % point(s) d''accès semé(s) par l''audit du 03/09.', v_n;
end $$;

commit;
