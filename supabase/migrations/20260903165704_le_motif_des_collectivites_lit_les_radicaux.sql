-- ============================================================================
-- Suite de l'audit du 03/09 (§A6) — le motif des collectivités lit les radicaux,
-- et le lot `autorite_collectivite` reçoit ce qu'il n'avait pas vu
-- Foyer : REGISTRE §37 `CONV` · CONV-O7, CONV-O2 · AUDIT_autorites_2026-09-03 §A6
-- ============================================================================
-- CE QUE L'AUDIT A MESURÉ. `private.conv_motifs_collectivite()` encadre ses
-- radicaux de `\y…\y` — une frontière de mot DES DEUX CÔTÉS. `federa` ne prend
-- donc ni « Federação » ni « Federation » ni « Federazione » ; `comit` ne prend
-- ni « Comité » ni « Comitê » ; `organiza` ne prend pas « Organização ». Le
-- motif marchait sur les mots ENTIERS de sa liste (« Grupo », « Instituto »,
-- « Departamento ») et sur rien de fléchi. Résultat : quatorze collectivités
-- inversées comme des personnes sont restées hors du lot du 21/08 —
-- « Federation, Anarchist Communist », « Uruguai, Federação Anarquista »,
-- « International, Congrès Anarchiste », « Brasil, República Federativa do »… —
-- et une vingtaine de collectivités NON inversées nées du lot C5 (« Fédération
-- Anarchiste », « Comitê de Resistência Curda », « DIEESE ») n'ont aucun type.
--
-- DEUX MOTIFS, PAS UN. Ouvrir la frontière fermante ne suffit pas : un SIGLE
-- ouvert attrape des personnes — `sni` prend « Snider », `ait` prend « Aitken »,
-- `fai` prend « Fairbanks ». Les radicaux s'ouvrent (`\m(federa|comit|…)`),
-- les sigles restent des mots entiers (`\m(cnt|cgt|…)\M`). Deux faux positifs
-- de l'ancien motif sont retirés au passage : `casa` (prenait « Casas »,
-- « Casanova ») et `cira` nu (prenait « Cirano ») ; `organiza` devient
-- `organiza[çc][aã]o|organizaci[oó]n|organisation|organizzazione` pour ne plus
-- prendre « (Organizador) ». Essayé en lecture seule sur la production le
-- 03/09 : 36 fiches remontent, aucune personne parmi elles.
--
-- CE QUE LE LOT DÉCIDE, ET COMMENT. Pour une collectivité INVERSÉE, comme le
-- 21/08 : valider dé-inverse ET pose `authority_type = 'collective'` (les trois
-- faces, cf. migration 16). Pour une collectivité NON inversée, la proposition
-- est le nom lui-même : valider ne change pas une lettre, il pose le TYPE — c'est
-- CONV-O7 (« le type est la vérité, le SQL le lit »). Écarter n'écrit rien : un
-- refus n'affirme pas « c'est une personne ». Les 16 verdicts du 21/08 sont
-- intouchés (`on conflict do nothing`), les deux « à revoir » aussi.
--
-- Ce qu'on NE sème pas : les fixtures de la formation BLMF (`source_label
-- formacao-*`) et toute fiche engagée dans un signalement de doublon ouvert —
-- un doublon se fusionne d'abord, on ne corrige pas sa forme entre-temps.
--
-- Le semis est une fonction SECURITY INVOKER sans grant (migration seulement) :
-- une garde « staff OU current_user = postgres » dans une fonction DEFINER ne
-- garde rien, cf. migration précédente. Suite : tests/sql/conv_collectivites_radicaux_tests.sql.
-- ============================================================================
begin;

-- ── 1 · Le motif, à radicaux ouverts et sigles fermés ───────────────────────
--     `create or replace` : les grants posés le 22/08 (durcissement_grants_rappel)
--     sont conservés.
create or replace function private.conv_motifs_collectivite()
returns text
language sql
immutable
as $function$
  select '\m(universidade|universidad|universit|faculdade|facultad|facult|instituto|institut'
      || '|editora|editorial|edi[çc][õo]es|ediciones|[ée]ditions|edizioni'
      || '|coletivo|colectivo|collectif|collettivo|collective|grupo|groupe|gruppo|group'
      || '|federa|f[ée]d[ée]ration|confedera|sindicat|syndicat|intersindical|associa|asocia'
      || '|centro|centre|center|biblioteca|biblioth|ateneu|ateneo'
      || '|comit|comiss|comisi|commission|conselho|consejo|conseil|cooperativa'
      || '|n[uú]cleo|c[ií]rculo|movimento|movimiento|mouvement|uni[aã]o|uni[oó]n|union|liga|ligue'
      || '|escola|escuela|[ée]cole|sociedade|sociedad|soci[ée]t[ée]|equipo|equipe'
      || '|organiza[çc][aã]o|organizaci[oó]n|organisation|organizzazione|departamento'
      || '|funda[çc][aã]o|fundaci[oó]n|fondation|arquivo|archivo|archives|museu|museo'
      || '|congr|assembl|coordena[çc]|coordinaci|rede|r[ée]seau|network|writers'
      || '|imprensa|revista|revue|jornal|servi[çc]o|servicio|oficina|laborat|programa|projeto|proyecto'
      || '|partido|partit|juventud|estudantes|students'
      || '|anarquistas|anarchistes|anarchists|anarchici|libert[aá]ri[oa]s|feministas|lesbianas|rep[úu]blica)'
      || '|\m(cnt|cgt|fai|ait|iww|cira|ufpa|ufrgs|cesit|dieese|anteag|enff|cna|sni|nu-sol)\M'
$function$;

comment on function private.conv_motifs_collectivite() is
  'CONV-O7 · motif (regex, insensible à la casse) de repérage des collectivités '
  'dans un point d''accès : radicaux OUVERTS (« federa » prend Federação, Federation, '
  'Federazione) et sigles FERMÉS (« sni » ne prend pas Snider). Refait le 03/09 : '
  'l''ancien \y…\y ne prenait que les mots entiers de sa liste. Une proposition, '
  'jamais une décision : la vue et le lot passent devant un œil humain.';

-- ── 2 · La vue des candidates à typer : inversées ou non ───────────────────
--     La vue du 21/08 (`v_conv_collectivites_inversees`) reste : elle appelle la
--     fonction, elle s'élargit donc d'elle-même. Celle-ci ajoute les NON inversées
--     non typées, avec la proposition « le nom tel quel ».
create or replace view private.v_conv_collectivites_a_typer
with (security_invoker = true)
as
select a.id,
       a.sort_name as avant,
       case when a.sort_name ~ ', '
                 and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
                 and btrim(split_part(a.sort_name, ', ', 2)) <> ''
            then btrim(split_part(a.sort_name, ', ', 2) || ' ' || split_part(a.sort_name, ', ', 1))
            else a.sort_name
       end as apres_propose,
       (a.sort_name ~ ', '
        and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
        and btrim(split_part(a.sort_name, ', ', 2)) <> '') as inversee
  from public.authors a
 where coalesce(a.source_label, '') not like 'formacao-%'
   and (   (a.authority_type is null and a.sort_name ~* private.conv_motifs_collectivite())
        or (a.authority_type in ('collective', 'congress')
            and a.sort_name ~ ', '
            and (length(a.sort_name) - length(replace(a.sort_name, ',', ''))) = 1
            and btrim(split_part(a.sort_name, ', ', 2)) <> ''));

comment on view private.v_conv_collectivites_a_typer is
  'CONV-O7 · candidates du lot autorite_collectivite : non typées dont le nom porte '
  'un radical de collectivité (inversées ou non), et typées collectivité encore '
  'inversées. Hors fixtures de formation. Lecture staff par les fonctions api.*.';

-- ── 3 · Le semis, rejouable ─────────────────────────────────────────────────
create or replace function public.fn_conv_lot_autorite_collectivite_seed()
returns bigint
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare v_n bigint;
begin
  with faits as (
    insert into public.catalog_review_queue (lot, entity_kind, entity_id, avant, apres_propose, decision, note)
    select 'autorite_collectivite', 'author', v.id, v.avant, v.apres_propose, 'a_revoir',
           case when v.inversee
                then 'Audit 03/09 · collectivité inversée comme une personne (radical du motif). '
                  || 'Valider dé-inverse ET pose le type « collective » ; écarter n''écrit rien.'
                else 'Audit 03/09 · collectivité probable, non typée. Valider ne change pas le nom : '
                  || 'il pose le type « collective » (CONV-O7). Écarter = ce n''est pas une collectivité.'
           end
      from private.v_conv_collectivites_a_typer v
     where not exists (select 1 from public.authority_duplicate_reports r
                        where r.status = 'open' and v.id in (r.author_id_a, r.author_id_b))
    on conflict (lot, entity_id) do nothing
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$$;

comment on function public.fn_conv_lot_autorite_collectivite_seed() is
  'CONV-O7 · verse dans la file (lot autorite_collectivite) les candidates de '
  'private.v_conv_collectivites_a_typer, sauf celles engagées dans un signalement '
  'de doublon ouvert. on conflict do nothing : aucun verdict posé n''est touché. '
  'Migration seulement (aucun grant).';

revoke all on function public.fn_conv_lot_autorite_collectivite_seed() from public, anon, authenticated;

-- ── 4 · Gardes (DOC-OBJ-2 + structure) ──────────────────────────────────────
do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_lot_autorite_collectivite_seed()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_lot_autorite_collectivite_seed()', 'EXECUTE') then
    raise exception 'CONV-O7 — le semis est exécutable depuis l''application : abandon.';
  end if;
  if not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                  where n.nspname = 'private' and c.relname = 'v_conv_collectivites_a_typer'
                    and c.reloptions @> array['security_invoker=true']) then
    raise exception 'CONV-O7 — la vue v_conv_collectivites_a_typer n''est pas security_invoker : abandon.';
  end if;
  -- Le motif tient ses deux promesses : radical ouvert, sigle fermé.
  if not ('Uruguai, Federação Anarquista' ~* private.conv_motifs_collectivite())
     or not ('Comitê de Resistência Curda' ~* private.conv_motifs_collectivite())
     or ('Snider, Paul' ~* private.conv_motifs_collectivite())
     or ('Casanova, Pablo González' ~* private.conv_motifs_collectivite())
     or ('Paulo Capra (Organizador)' ~* private.conv_motifs_collectivite()) then
    raise exception 'CONV-O7 — le motif ne tient pas ses promesses (radical ouvert, sigle fermé) : abandon.';
  end if;
end $$;

-- ── 5 · Le semis : ~36 attendues en production, 0 sur une base fraîche ───────
do $$
declare v_n bigint;
begin
  select public.fn_conv_lot_autorite_collectivite_seed() into v_n;
  raise notice 'CONV-O7 — lot autorite_collectivite : % candidate(s) semée(s) par l''audit du 03/09.', v_n;
end $$;

commit;
