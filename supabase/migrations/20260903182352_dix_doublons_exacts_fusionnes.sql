-- ============================================================================
-- Évidences de l'audit du 03/09 (1/4) — dix doublons exacts fusionnés
-- Foyer : REGISTRE §37 `CONV` · §40 `DEDUP` · AUDIT_autorites_2026-09-03 §N2
-- ============================================================================
-- DÉCISION. Xavier, 03/09 au soir : « corrige en base tout ce qui est assez
-- évident et ne demande pas de deviner ». Un doublon EXACT — même clé une fois
-- retirés la casse, les accents, les espaces et l'ordre « Nom, Prénom » /
-- « Prénom Nom » — ne demande pas de deviner : c'est la même personne, écrite
-- deux fois. L'audit en a signalé huit à l'Atelier (`authority_duplicate_reports`),
-- plus deux que la clé stricte ratait d'un espace ou d'une date :
-- « ZAMENHOF, L. L. » / « Zamenhof, L.L. » et « Hakim Bey 1945-2022 » / « Bey, Hakim ».
--
-- LA FUSION EST CELLE DE `merge_author`, RECOPIÉE. `merge_author` est gardée par
-- `fn_is_dedup_arbiter()` (auth.uid) : injoignable en migration. On ne l'appelle
-- donc pas, on recopie son corps — contributeurs, book_authors, traductions,
-- alias, brouillons, œuvres, merge_log, suppression — dans une fonction qui
-- ajoute une GARDE PROPRE À CETTE MIGRATION : elle refuse de fusionner deux
-- fiches dont les clés normalisées ne se recoupent pas. Elle ne fusionne donc
-- que des doublons exacts, jamais deux personnes qui se ressemblent.
--
-- CANONIQUE = la fiche corrigée le 21/08 (ou la graphie juste) : celle qui
-- porte les dates, le pays, la langue du nom, les œuvres. Le doublon est la
-- fiche née le 03/09 (`source_kind = 'conv_revue'`). Les lignes de la file qui
-- visaient le doublon passent « écartées » avec la raison ; les signalements
-- disparaissent avec lui (FK en cascade), `merge_log` garde la trace.
--
-- SECURITY INVOKER, aucun grant : migration seulement. Suite : conv_evidence_fusions_tests.sql.
-- ============================================================================
begin;

create or replace function public.fn_conv_fusionner_doublon_exact(p_canonical bigint, p_duplicate bigint)
returns boolean
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare
  v_can  public.authors%rowtype;
  v_dup  public.authors%rowtype;
  v_k_can text[];
  v_k_dup text[];
begin
  if p_canonical is null or p_duplicate is null or p_canonical = p_duplicate then return false; end if;
  select * into v_can from public.authors where id = p_canonical;
  select * into v_dup from public.authors where id = p_duplicate;
  if v_can.id is null or v_dup.id is null then return false; end if;
  if coalesce(v_can.source_label, '') like 'formacao-%' or coalesce(v_dup.source_label, '') like 'formacao-%' then return false; end if;

  -- Clés normalisées : sans casse, sans accents, sans espaces ni points, sans dates
  -- en fin ; forme stockée, forme d'affichage et forme dérivée de chaque côté.
  select array_agg(distinct k) into v_k_can from (
    select regexp_replace(lower(extensions.unaccent(x)), '[\s.]', '', 'g') as k
      from unnest(array[v_can.sort_name, v_can.preferred_name,
                        case when v_can.sort_name ~ ', ' then split_part(v_can.sort_name, ', ', 2) || ' ' || split_part(v_can.sort_name, ', ', 1) end]) x
     where x is not null) s where k <> '';
  select array_agg(distinct k) into v_k_dup from (
    select regexp_replace(lower(extensions.unaccent(regexp_replace(x, '\s+\d{4}\s*[-–]\s*\d{4}\s*$', ''))), '[\s.]', '', 'g') as k
      from unnest(array[v_dup.sort_name, v_dup.preferred_name,
                        case when v_dup.sort_name ~ ', ' then split_part(v_dup.sort_name, ', ', 2) || ' ' || split_part(v_dup.sort_name, ', ', 1) end]) x
     where x is not null) s where k <> '';
  if not (v_k_can && v_k_dup) then
    return false;  -- pas un doublon exact : on ne devine pas
  end if;

  -- Corps de merge_author, recopié.
  update public.book_contributors set author_id = p_canonical where author_id = p_duplicate;
  insert into public.book_authors (book_id, author_id, role, ord)
    select book_id, p_canonical, role, ord from public.book_authors where author_id = p_duplicate
    on conflict (book_id, author_id, role, ord) do nothing;
  delete from public.book_authors where author_id = p_duplicate;
  update public.author_translations t set author_id = p_canonical
    where t.author_id = p_duplicate
      and not exists (select 1 from public.author_translations c where c.author_id = p_canonical and c.lang = t.lang);
  update public.author_name_aliases set author_id = p_canonical where author_id = p_duplicate;
  update public.author_drafts set published_author_id = p_canonical where published_author_id = p_duplicate;
  update public.book_draft_contributors set author_id = p_canonical where author_id = p_duplicate;
  update public.works set primary_author_id = p_canonical where primary_author_id = p_duplicate;

  -- La file : ce qui visait le doublon est écarté, avec la raison.
  update public.catalog_review_queue q
     set decision = 'ecarte', decided_at = now(),
         note = coalesce(q.note || ' · ', '') || 'Fusionnée dans la fiche ' || p_canonical || ' (doublon exact, audit 03/09).'
   where q.entity_kind = 'author' and q.entity_id = p_duplicate and q.applique_le is null;

  insert into public.merge_log (entity_type, canonical_id, duplicate_id, details, merged_by)
  values ('author', p_canonical, p_duplicate,
          jsonb_build_object('duplicate_preferred_name', v_dup.preferred_name,
                             'duplicate_sort_name', v_dup.sort_name,
                             'via', 'migration évidences audit 03/09 (fn_conv_fusionner_doublon_exact)'),
          null);

  delete from public.authors where id = p_duplicate;
  return true;
end;
$$;

comment on function public.fn_conv_fusionner_doublon_exact(bigint, bigint) is
  'Audit 03/09 · fusionne un DOUBLON EXACT (clés normalisées qui se recoupent : casse, '
  'accents, espaces, points, ordre Nom/Prénom, dates en fin) dans sa fiche canonique — '
  'corps de merge_author recopié, plus la garde d''exactitude. Rend false sans rien écrire '
  'si les fiches ne sont pas un doublon exact ou si l''une est une fixture de formation. '
  'Migration seulement (aucun grant).';

revoke all on function public.fn_conv_fusionner_doublon_exact(bigint, bigint) from public, anon, authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_fusionner_doublon_exact(bigint,bigint)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_fusionner_doublon_exact(bigint,bigint)', 'EXECUTE') then
    raise exception 'Évidences 03/09 — la fusion est exécutable depuis l''application : abandon.';
  end if;
end $$;

-- Les dix paires (canonique ← doublon). Sur une base fraîche aucune n'existe : 0.
do $$
declare r record; v_n int := 0; v_refus int := 0;
begin
  for r in select * from (values
      (10074, 11337),  -- Gómez Casas, Juan            ← CASAS, Juan Gómez
      (10164, 11417),  -- Carvalho, Florentino de      ← DE CARVALHO, Florentino
      (10167, 11553),  -- Van Der Walt, Lucien (af)    ← Walt, Lucien van der
      (10180, 11367),  -- Jong, Rudolf de (nl)         ← DE JONG, Rudolf
      (10622, 11383),  -- Freitas, Allan de            ← DE FREITAS, Allan
      (10676, 11391),  -- Guattari, Félix              ← Guattari, Felix
      (10819, 11371),  -- López, Fábio López           ← Fabio López López
      (11471, 11447),  -- Platão                       ← Platao
      (11554, 11536),  -- Zamenhof, L.L.               ← ZAMENHOF, L. L.
      (10334, 11398)   -- Bey, Hakim (1945-2022)       ← Hakim Bey 1945-2022
    ) as t(canonique, doublon)
  loop
    if exists (select 1 from public.authors where id = r.doublon) and exists (select 1 from public.authors where id = r.canonique) then
      if public.fn_conv_fusionner_doublon_exact(r.canonique, r.doublon) then v_n := v_n + 1; else v_refus := v_refus + 1; end if;
    end if;
  end loop;
  raise notice 'Évidences 03/09 — % fusion(s) de doublons exacts, % refusée(s) par la garde.', v_n, v_refus;
end $$;

commit;
