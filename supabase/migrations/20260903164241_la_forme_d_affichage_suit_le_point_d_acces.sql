-- ============================================================================
-- CONV-2, suite de l'audit du 03/09 — la forme d'affichage suit le point d'accès
-- Foyer : REGISTRE §37 `CONV` · AUDIT_autorites_2026-09-03 §A1′
-- ============================================================================
-- CE QUE L'AUDIT A MESURÉ. Le 21/08, la migration `10` et le lot
-- `autorite_patronyme` ont réécrit le POINT D'ACCÈS de vingt et une fiches
-- (`DE BEAUVOIR, Simone` → `Beauvoir, Simone de`). La forme d'affichage, elle,
-- avait été dérivée le 20/08 depuis l'ANCIEN point d'accès en capitales, et
-- personne ne l'a refaite : dix-sept fiches montrent aujourd'hui
-- `Simone DE BEAUVOIR` sous `Beauvoir, Simone de`. CONV-2 dit pourtant que
-- `preferred_name` DÉRIVE de `sort_name` — jamais l'inverse.
--
-- Ce n'est pas un défaut d'affichage seulement : c'est LUI qui a fait rater la
-- recherche d'homonyme du lot C5 le 03/09. La transcription `DE CARVALHO,
-- Florentino` ne trouvait ni `Carvalho, Florentino de` ni `Florentino DE
-- CARVALHO` à la lettre — et une fiche doublon est née (11417). Réparer la
-- forme d'affichage, c'est fermer la moitié de la porte par laquelle les
-- doublons sont entrés (l'autre moitié est la recherche elle-même, migration
-- suivante).
--
-- LA RÈGLE, ET SA GARDE. On ne réécrit `preferred_name` que si :
--   · `sort_name` porte une seule virgule et des prénoms (une personne inversée) ;
--   · la fiche n'est pas une collectivité ni un congrès (leur nom ne s'inverse pas) ;
--   · `sort_name` est en CASSE NATURELLE — aucun mot de deux capitales ou plus.
--     Sans cette garde on dériverait `Fábio Luz FILHO` depuis `FILHO, Fábio Luz`
--     et l'on abîmerait ce que le lot `autorite_casse` doit corriger d'abord
--     (dont les fixtures de la formation BLMF, `source_label = 'formacao-e*'`) ;
--   · et la forme actuelle est ÉGALE à la forme dérivée SANS CASSE. On ne
--     réordonne rien, on ne devine rien : on ne fait que remettre la casse
--     d'accord avec le point d'accès. `Eric HOBSBAWM` sous `Hobsbawm, Eric J.`
--     n'est pas touché — l'écart n'est pas de casse.
--
-- La règle vit dans une FONCTION plutôt qu'en UPDATE nu, pour deux raisons :
-- elle est ainsi TESTABLE (suite `tests/sql/conv_a1prime_preferred_name_tests.sql`,
-- qui l'exerce sur des fixtures : la CI ne voit aucune donnée réelle), et elle
-- est REJOUABLE le jour où un autre lot laisse le même résidu. Elle n'a PAS
-- de porte applicative : SECURITY INVOKER, aucun grant à `authenticated` — seule
-- une migration (rôle postgres) l'exécute. Leçon du premier essai de la suite :
-- une garde « staff OU current_user = postgres » dans une fonction SECURITY
-- DEFINER est toujours vraie, puisque current_user y vaut le propriétaire.
--
-- Compté en production le 03/09 : 17 fiches (18, 19, 28, 10154, 10164, 10180,
-- 10199, 10488, 10489, 10493, 10593, 10594, 10595, 10743, 10952, 10953, 10954).
-- Sur une base fraîche (CI) : 0, et c'est normal.
-- ============================================================================
begin;

create or replace function public.fn_conv_preferred_name_derive()
returns bigint
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare v_n bigint;
begin
  with faits as (
    update public.authors a
       set preferred_name = btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))
     where a.sort_name ~ ', '
       and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
       and btrim(split_part(a.sort_name, ', ', 2)) <> ''
       and coalesce(a.authority_type, '') not in ('collective', 'congress')
       -- casse naturelle : aucun mot d'au moins deux capitales (À-Þ couvre les
       -- capitales accentuées latines : É, Ç, Ê…)
       and a.sort_name !~ '\m[A-ZÀ-Þ]{2,}\M'
       -- même forme sans casse, forme différente à la lettre
       and a.preferred_name <> btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))
       and lower(a.preferred_name) = lower(btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1)))
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$$;

comment on function public.fn_conv_preferred_name_derive() is
  'CONV-2 · remet preferred_name en accord de CASSE avec la forme dérivée de '
  'sort_name (« Prénoms Nom »), uniquement quand les deux sont déjà égales sans '
  'casse et que sort_name est en casse naturelle. Ne réordonne jamais, ne touche '
  'ni collectivité ni congrès. Rejouable. Migration seulement (aucun grant).';

revoke all on function public.fn_conv_preferred_name_derive() from public, anon, authenticated;

-- Grants relus, pas supposés (DOC-OBJ-2) : ni anon ni authenticated.
do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_preferred_name_derive()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_preferred_name_derive()', 'EXECUTE') then
    raise exception 'CONV-2 — fn_conv_preferred_name_derive est exécutable depuis l''application : abandon.';
  end if;
end $$;

-- L'application : 17 attendues en production, 0 sur une base fraîche.
do $$
declare v_n bigint;
begin
  select public.fn_conv_preferred_name_derive() into v_n;
  raise notice 'CONV-2 — % forme(s) d''affichage remise(s) en accord avec le point d''accès.', v_n;
end $$;

-- Garde structurelle : après passage, plus aucune fiche « personne, casse
-- naturelle » n'a de forme d'affichage qui diverge seulement par la casse.
do $$
declare v_reste bigint;
begin
  select count(*) into v_reste
    from public.authors a
   where a.sort_name ~ ', '
     and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
     and btrim(split_part(a.sort_name, ', ', 2)) <> ''
     and coalesce(a.authority_type, '') not in ('collective', 'congress')
     and a.sort_name !~ '\m[A-ZÀ-Þ]{2,}\M'
     and a.preferred_name <> btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))
     and lower(a.preferred_name) = lower(btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1)));
  if v_reste <> 0 then
    raise exception 'CONV-2 — % fiche(s) divergent encore par la casse après application.', v_reste;
  end if;
end $$;

commit;
