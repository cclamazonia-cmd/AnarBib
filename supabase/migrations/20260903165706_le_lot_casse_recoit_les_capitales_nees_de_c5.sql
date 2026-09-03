-- ============================================================================
-- Suite de l'audit du 03/09 (§N1) — le lot `autorite_casse` reçoit les
-- capitales nées du lot C5 (second semis)
-- Foyer : REGISTRE §37 `CONV` · CONV-1 · AUDIT_autorites_2026-09-03 §N1
-- ============================================================================
-- CE QUE L'AUDIT A MESURÉ. Le lot `autor_sans_autorite` crée l'autorité avec la
-- transcription TELLE QU'ÉCRITE — c'est voulu (l'outil propose, il ne
-- normalise pas). Quarante-huit fiches nées le 03/09 portent donc un point
-- d'accès en capitales : `BONANNO, Alfredo`, `DAVRANCHE, Guillaume`,
-- `LÊNIN, Vladimir Illitch`, `ZAMENHOF, L. L.`, `RATGEB`. CONV-1 dit que les
-- capitales sont un RENDU, jamais la donnée stockée.
--
-- Le lot qui traite cela existe depuis le 21/08 (`autorite_casse`, 61 verdicts,
-- 57 appliqués) ; il a été semé une fois, depuis l'instantané
-- `conv_backup.autorites_casse_a_revoir_20260820`. Cette migration lui donne
-- une fonction de SEMIS rejouable, avec la même proposition qu'alors —
-- `initcap()` du patronyme, prénoms intouchés — et les mêmes réserves :
-- initcap() casse « Van der Walt », « McKay », « D'Amico », c'est un POINT DE
-- DÉPART que l'écran annonce déjà comme tel (« initcap() se trompe sur les
-- apostrophes et les particules »).
--
-- PÉRIMÈTRE DU SEMIS, volontairement étroit :
--   · un mot d'au moins deux capitales dans le point d'accès ;
--   · la forme classique « NOM, Prénoms » (UNE virgule), sans parenthèse — pas
--     les chaînes à plusieurs virgules (fiches doubles, §N3), pas les mononymes
--     ni les formes directes ni les mentions de rôle (« RATGEB », « MC CABE Mary
--     Alice (Org,) » : c'est la FORME qui est en cause, lot `autorite_forme`,
--     qui remet aussi la casse au passage — une fiche, un lot) ;
--   · ni collectivité typée, ni nom qui porte un radical de collectivité
--     (« DIEESE », « ANTEAG » vont au lot des collectivités : leurs capitales
--     sont un sigle, pas un défaut) ;
--   · ni fixture de formation, ni fiche engagée dans un signalement de doublon
--     ouvert (on fusionne d'abord).
-- Compté en production le 03/09 : ~40 attendues. 0 sur une base fraîche.
--
-- SECURITY INVOKER, aucun grant : migration seulement (cf. les deux précédentes).
-- Suite : tests/sql/conv_casse_second_semis_tests.sql.
-- ============================================================================
begin;

create or replace function public.fn_conv_lot_autorite_casse_seed()
returns bigint
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare v_n bigint;
begin
  with cand as (
    select a.id, a.sort_name
      from public.authors a
     where a.sort_name ~ '\m[A-ZÀ-Þ]{2,}\M'
       and coalesce(a.authority_type, '') not in ('collective', 'congress')
       and coalesce(a.source_label, '') not like 'formacao-%'
       and a.sort_name !~* private.conv_motifs_collectivite()
       and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
       and a.sort_name ~ ', ' and btrim(split_part(a.sort_name, ', ', 2)) <> ''
       and a.sort_name !~ '[()]'
       -- filiation ou particule en tête : c'est la forme, pas la casse (lot autorite_forme)
       and split_part(a.sort_name, ', ', 1) !~* '^(jr\.?|filho|filha|j[úu]nior|junior|neto|sobrinho)$'
       and split_part(a.sort_name, ', ', 1) !~* '^(de|da|do|dos|das|di|van|von|der|den|le|la|du|des) \S'
       and not exists (select 1 from public.authority_duplicate_reports r
                        where r.status = 'open' and a.id in (r.author_id_a, r.author_id_b))
  ),
  faits as (
    insert into public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose, decision, note)
    select 'autorite_casse', 'author', c.id, c.sort_name,
           initcap(split_part(c.sort_name, ', ', 1)) || ', ' || split_part(c.sort_name, ', ', 2),
           'a_revoir',
           'Audit 03/09 · point d''accès en capitales né du lot C5 (transcription telle qu''écrite). '
             || case
                  when c.sort_name ~ '''' then 'initcap() casse les apostrophes : O''Brien, Dell''Umbria, Sant''Ana.'
                  when c.sort_name ~* '\m(van|von|de|della|di|du|des|le|la|mc|mac)\M' then 'particule : la règle dépend de la langue du nom (CONV-6).'
                  else 'initcap() est un point de départ, pas une vérité.'
                end
      from cand c
    on conflict (lot, entity_id) do nothing
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$$;

comment on function public.fn_conv_lot_autorite_casse_seed() is
  'CONV-1 · verse dans la file (lot autorite_casse) les points d''accès « NOM, Prénoms » '
  'portant un mot en capitales, avec la proposition initcap() du patronyme. '
  'Hors collectivités, hors fixtures de formation, hors doublons signalés. on conflict '
  'do nothing. Migration seulement (aucun grant).';

revoke all on function public.fn_conv_lot_autorite_casse_seed() from public, anon, authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_lot_autorite_casse_seed()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_lot_autorite_casse_seed()', 'EXECUTE') then
    raise exception 'CONV-1 — le semis casse est exécutable depuis l''application : abandon.';
  end if;
end $$;

do $$
declare v_n bigint;
begin
  select public.fn_conv_lot_autorite_casse_seed() into v_n;
  raise notice 'CONV-1 — lot autorite_casse : % point(s) d''accès en capitales semé(s) par l''audit du 03/09.', v_n;
end $$;

commit;
