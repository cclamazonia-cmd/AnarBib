-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 14 · L'application depuis l'écran
-- Foyer : REGISTRE §37 `CONV` · CONV-1, CONV-2, CONV-3, CONV-4
--
-- ---------------------------------------------------------------------
-- POURQUOI CETTE RPC EXISTE — et pourquoi elle ne contredit pas
-- DOC-DEPLOY-1.
--
-- Les migrations 10, 11 et 12 ont appliqué les verdicts par `git push`,
-- au motif que « décider et écrire sont deux gestes ». Le principe reste
-- vrai ; ce qui était faux, c'est d'en déduire qu'écrire exige une
-- migration. Appliquer un verdict tranché ligne à ligne est une ÉCRITURE
-- DE DONNÉES par un membre du staff authentifié — la même classe que
-- `merge_author`, `publish_book_draft` ou `mark_books_not_duplicate`, qui
-- passent par des RPC depuis toujours. `DOC-DEPLOY-1` gouverne le SCHÉMA
-- et le déploiement, pas chaque UPDATE métier.
--
-- La conséquence pratique de l'erreur : un aller-retour de dix minutes
-- par lot tranché, et une file qui accumule des décisions non écrites.
--
-- CE QUI NE CHANGE PAS. Les gardes sont identiques à celles des
-- migrations 10-12, parce qu'elles protègent de vrais accidents :
--   * garde stricte anti-écrasement — une fiche modifiée depuis
--     l'instantané n'est PAS écrasée (CONV-O6) ;
--   * `preferred_name` re-dérivé seulement là où il est encore la forme
--     mécanique — on ne recouvre jamais un geste humain (CONV-2) ;
--   * une cible sans virgule (collectivité) prend le point d'accès
--     verbatim : une personne morale ne se range pas « Nom, Prénom » ;
--   * `title_nonfiling` revérifié après coup (CONV-4) — voir plus bas.
-- =====================================================================

begin;

-- Qui a appliqué, en plus de qui a décidé. Deux gestes, deux traces.
alter table public.catalog_review_queue
  add column if not exists applique_par uuid references auth.users(id) on delete set null;

comment on column public.catalog_review_queue.applique_par is
  'Qui a déclenché l''écriture au catalogue. Distinct de decided_by : décider '
  'et appliquer sont deux gestes, parfois de deux personnes.';

-- La valeur a ecrire : celle retenue a la main si elle existe, sinon la
-- proposition de l'outil. Sortie en fonction pour ne pas repeter six fois
-- le meme coalesce/nullif/btrim dans les gardes — une repetition ou l'on
-- finit toujours par oublier un `btrim` a un endroit.
create or replace function public.fn_conv_cible(p_retenue text, p_propose text)
returns text
language sql
immutable
security invoker
set search_path = pg_catalog
as $$ select coalesce(nullif(btrim(coalesce(p_retenue, '')), ''), p_propose) $$;

comment on function public.fn_conv_cible(text, text) is
  'CONV §37 · valeur a ecrire au catalogue : valeur_retenue si posee, sinon '
  'apres_propose. Outil interne du chantier : non expose (DOC-OBJ-2).';

revoke all on function public.fn_conv_cible(text, text)
  from public, anon, authenticated, service_role;

create or replace function api.conv_revue_appliquer(p_lot text)
returns table (applique bigint, refuse bigint, nonfiling_reinit bigint)
language plpgsql
security definer
set search_path to 'public', 'pg_catalog'
as $function$
declare
  v_uid  uuid := auth.uid();
  v_app  bigint := 0;
  v_ref  bigint := 0;
  v_nf   bigint := 0;
begin
  if not public.fn_caller_is_staff() then
    raise exception 'acesso reservado à equipe' using errcode = '42501';
  end if;

  if p_lot is null or p_lot not in ('titre_casse', 'autorite_casse', 'autorite_patronyme') then
    raise exception 'Lote inválido: %', p_lot using errcode = '22023';
  end if;

  -- ── AUTORITÉS ────────────────────────────────────────────────────────
  if p_lot in ('autorite_casse', 'autorite_patronyme') then

    -- Forme d'affichage D'ABORD : sa garde porte sur l'état actuel, qui
    -- disparaît à l'étape suivante.
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

    -- CONV-4 : `title_nonfiling` est un OFFSET dans le titre. Une correction
    -- de casse n'en change pas la longueur, mais une correction à la main,
    -- si. Un offset qui ne tombe plus sur l'espace (ou l'apostrophe de « L' »)
    -- couperait le titre au milieu d'un mot au tri. On le remet à 0 plutôt
    -- que de le laisser faux : perdre l'article non-classant coûte un rang
    -- de tri, garder un offset erroné mutile l'affichage du classement.
    with remis as (
      update public.books b
         set title_nonfiling = 0
       where b.title_nonfiling > 0
         and substr(b.titulo, b.title_nonfiling, 1) not in (' ', '''')
         -- Restreint aux notices de CE lot deja appliquees : reparer au
         -- passage des offsets casses par une autre cause serait un effet
         -- de bord, et une RPC ne doit pas faire ce qu'on ne lui demande pas.
         and b.id in (select q2.entity_id from public.catalog_review_queue q2
                       where q2.lot = p_lot and q2.applique_le is not null)
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
$function$;

comment on function api.conv_revue_appliquer(text) is
  'CONV §37 · applique au catalogue les verdicts tranchés d''un lot. Staff '
  'uniquement. Écriture de données par un·e membre du staff, comme merge_author '
  '— pas une migration (cf. en-tête de la migration 14). Gardes identiques aux '
  'migrations 10-12 : anti-écrasement strict, preferred_name re-dérivé seulement '
  's''il est encore mécanique, cible sans virgule prise verbatim, title_nonfiling '
  'revérifié. Renvoie (appliquées, refusées, offsets réinitialisés).';

revoke all on function api.conv_revue_appliquer(text) from public, anon;
grant execute on function api.conv_revue_appliquer(text) to authenticated;

-- ---------------------------------------------------------------------
-- Vérification
-- ---------------------------------------------------------------------
do $$
declare n_anon bigint;
begin
  select count(*) into n_anon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace, aclexplode(p.proacl) a
    join pg_roles r on r.oid = a.grantee
   where n.nspname = 'api' and p.proname = 'conv_revue_appliquer'
     and r.rolname = 'anon' and a.privilege_type = 'EXECUTE';

  if n_anon > 0 then
    raise exception 'CONV/14 — conv_revue_appliquer executable par anon : abandon.';
  end if;

  raise notice 'CONV/14 — application depuis l''ecran disponible, gatee staff.';
end $$;

commit;
