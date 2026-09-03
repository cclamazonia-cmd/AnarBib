-- ============================================================================
-- Évidences de l'audit du 03/09 (3/4) — les contributeurs dont le nom est
-- exactement celui d'une fiche existante sont liés
-- Foyer : REGISTRE §37 `CONV` · AUDIT_autorites_2026-09-03 §N6
-- ============================================================================
-- DÉCISION. Xavier, 03/09 au soir : corriger ce qui est évident. Parmi les 333
-- contributeurs sans autorité (les « secondes personnes » des chaînes « ; »),
-- vingt-quatre portent un nom qui est, sans casse ni accents et à l'ordre près,
-- EXACTEMENT celui d'une fiche existante : « Addor, Carlos Augusto » et la fiche
-- 10215 « Addor, Carlos Augusto » ; « BETTO, Frei » et « Betto, Frei » ;
-- « Francisco Foot Hardman » et « Hardman, Francisco Foot ». Lier ne demande
-- pas de deviner : c'est ce que fait le formulaire quand on choisit la fiche.
--
-- La recherche est `fn_conv_autorite_homonyme` (migration du soir) — la même
-- que le lot C5 emploie désormais. Le lien ne se pose que si la fiche trouvée
-- n'est pas une fixture de formation et n'est pas déjà liée à ce livre par un
-- autre contributeur. Le nom du contributeur reste tel qu'imprimé (C5 = B).
-- Rejouable : ce qui est lié ne se relie pas.
--
-- Ce qui reste (~309) demande de créer ou de choisir : un lot par contributeur,
-- pas cette migration.
--
-- SECURITY INVOKER, aucun grant. Suite : conv_evidence_liens_exacts_tests.sql.
-- ============================================================================
begin;

create or replace function public.fn_conv_lier_contributeurs_exacts()
returns bigint
language plpgsql
security invoker
set search_path to 'public', 'pg_catalog'
as $$
declare v_n bigint;
begin
  with cand as (
    select c.id as contrib_id, c.book_id, public.fn_conv_autorite_homonyme(c.name) as author_id
      from public.book_contributors c
     where c.author_id is null
       and c.name ~ '[[:alpha:]]'
  ), faits as (
    update public.book_contributors c
       set author_id = cand.author_id
      from cand
      join public.authors a on a.id = cand.author_id
     where c.id = cand.contrib_id
       and cand.author_id is not null
       and coalesce(a.source_label, '') not like 'formacao-%'
       and not exists (select 1 from public.book_contributors c2
                        where c2.book_id = cand.book_id and c2.author_id = cand.author_id)
    returning 1
  )
  select count(*) into v_n from faits;
  return v_n;
end;
$$;

comment on function public.fn_conv_lier_contributeurs_exacts() is
  'Audit 03/09 · pose author_id sur les contributeurs sans autorité dont le nom retrouve '
  'EXACTEMENT une fiche (fn_conv_autorite_homonyme : sans casse, sans accents, ordre '
  'Nom/Prénom), hors fixtures de formation et hors fiche déjà liée au même livre. Le nom '
  'imprimé reste. Rejouable. Migration seulement (aucun grant).';

revoke all on function public.fn_conv_lier_contributeurs_exacts() from public, anon, authenticated;

do $$
begin
  if has_function_privilege('anon', 'public.fn_conv_lier_contributeurs_exacts()', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.fn_conv_lier_contributeurs_exacts()', 'EXECUTE') then
    raise exception 'Évidences 03/09 — le liage est exécutable depuis l''application : abandon.';
  end if;
end $$;

do $$
declare v_n bigint;
begin
  select public.fn_conv_lier_contributeurs_exacts() into v_n;
  raise notice 'Évidences 03/09 — % contributeur(s) lié(s) à leur fiche homonyme exacte (24 attendus en production).', v_n;
end $$;

commit;
