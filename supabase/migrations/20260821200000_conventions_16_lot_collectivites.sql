-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 16 · Le lot « collectivités inversées »
-- Foyer : REGISTRE §37 `CONV` · CONV-O7 (suite de la migration 15)
--
-- La migration 15 a rendu le type LISIBLE. Celle-ci le rend DÉCIDABLE :
-- elle verse les 16 collectivités repérées dans la file de vérification,
-- où elles attendront un œil humain comme les 61 casses et les 190 titres.
--
-- ELLE NE TRANCHE RIEN. Aucune ligne ne part avec un verdict : le repérage
-- par mots-clés PROPOSE (« ceci ressemble à une collectivité, et son point
-- d'accès a été inversé comme s'il s'agissait d'une personne »). Que ce
-- soit vrai se constate, ça ne se déduit pas d'une liste de mots.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. La CHECK du lot, élargie EN MÊME TEMPS que l'allowlist.
--
--    Piège déjà payé ailleurs dans ce dépôt : ajouter une valeur dans le
--    code appelant sans élargir la CHECK. L'insertion échoue, et selon
--    l'endroit l'erreur est avalée — on obtient une file muette qui a
--    l'air vide alors qu'elle est refusée. Les deux bougent ici, dans la
--    même transaction.
-- ---------------------------------------------------------------------
alter table public.catalog_review_queue
  drop constraint if exists catalog_review_queue_lot_chk;
alter table public.catalog_review_queue
  add constraint catalog_review_queue_lot_chk
  check (lot in ('titre_casse', 'autorite_casse', 'autorite_patronyme',
                 'autorite_collectivite'));

-- ---------------------------------------------------------------------
-- 2. Versement des candidates.
--
--    `on conflict do nothing` sur (lot, entity_id) : la migration peut
--    être rejouée sans écraser un verdict déjà posé. C'est la propriété
--    qui compte le plus ici — un rejeu qui remettrait `a_revoir` sur une
--    ligne déjà tranchée effacerait du travail humain.
-- ---------------------------------------------------------------------
insert into public.catalog_review_queue
  (lot, entity_kind, entity_id, avant, apres_propose, decision, note)
select 'autorite_collectivite',
       'author',
       v.id,
       v.avant,
       v.apres_propose,
       'a_revoir',
       case
         -- Deux fiches méritent un avertissement nommé plutôt qu'une
         -- proposition muette : la dé-inversion mécanique y donne un
         -- résultat qui n'est probablement pas le bon nom.
         when v.avant = 'Dieese, CESIT'
           then 'Deux organismes distincts (CESIT/Unicamp et DIEESE) dans une '
             || 'seule fiche : la dé-inversion mécanique donne « CESIT Dieese », '
             || 'qui n''est le nom de ni l''un ni l''autre. Voir aussi la fiche '
             || '« Socioeconômicos, Departamento Intersindical… » = DIEESE '
             || 'développé. Relève sans doute de CONV-O8 (scission).'
         when v.avant like 'Sindical, Conselho Estadual%'
           then 'Nom composé avec tiret : vérifier que « Conselho Estadual da '
             || 'Condição Feminina-Centro de memória Sindical » est bien la '
             || 'forme voulue, la virgule d''origine pouvant masquer une '
             || 'hiérarchie (organisme mère / sous-organisme).'
         else null
       end
  from private.v_conv_collectivites_inversees v
 where exists (select 1 from public.authors a where a.id = v.id)
on conflict (lot, entity_id) do nothing;

-- ---------------------------------------------------------------------
-- 3. L'application depuis l'écran connaît le nouveau lot.
--
--    DROP + CREATE : la signature ne change pas, mais le corps si, et le
--    `create or replace` d'une fonction `security definer` conserve les
--    grants — ce qu'on veut ici. On garde donc `create or replace` et on
--    re-vérifie les grants dans le bloc final (DOC-OBJ-2).
--
--    CE QUE FAIT LE VERDICT « valider » SUR CE LOT, et qui le distingue
--    des trois autres : il écrit DEUX choses, parce que la décision porte
--    sur deux niveaux.
--      · `authority_type = 'collective'` — la qualification, qui est le
--        fait durable ;
--      · `sort_name` dé-inversé — sa conséquence sur le point d'accès.
--    Écrire la seconde sans la première serait réparer le symptôme et
--    laisser la fiche re-proposable indéfiniment.
--
--    ET AUSSI `structured_meta.authorityType`, ce qui n'est pas un détail :
--    le formulaire de catalogage lit le jsonb, pas la colonne. Sans cette
--    troisième écriture, la fiche curée ici reviendrait dans le formulaire
--    sans type, et une simple réouverture-sauvegarde du brouillon
--    repasserait `authorityType: 'person'` — le trigger de la migration 15
--    ferait alors basculer la colonne, et le verdict humain serait défait
--    en silence par une action anodine. Les deux faces sont écrites
--    ensemble pour qu'elles ne puissent pas diverger.
--
--    CE QUE « ÉCARTER » N'ÉCRIT PAS : rien. Refuser la proposition veut
--    dire « ce n'est pas une collectivité inversée » — ça ne dit pas que
--    c'est une personne (ce peut être un congrès, ou une inversion
--    correcte). Déduire `person` d'un refus fabriquerait une donnée que
--    personne n'a affirmée. La fiche reste non qualifiée, ce qui est
--    exact.
-- ---------------------------------------------------------------------
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

  if p_lot is null or p_lot not in ('titre_casse', 'autorite_casse',
                                    'autorite_patronyme', 'autorite_collectivite') then
    raise exception 'Lote inválido: %', p_lot using errcode = '22023';
  end if;

  -- ── COLLECTIVITÉS ────────────────────────────────────────────────────
  if p_lot = 'autorite_collectivite' then

    update public.authors a
       set authority_type = 'collective',
           structured_meta = jsonb_set(coalesce(a.structured_meta, '{}'::jsonb),
                                       '{authorityType}', '"collective"'::jsonb, true),
           sort_name       = public.fn_conv_cible(q.valeur_retenue, q.apres_propose),
           -- La forme d'affichage d'une collectivité est son nom : pas de
           -- forme inversée, donc les deux coïncident.
           preferred_name  = public.fn_conv_cible(q.valeur_retenue, q.apres_propose)
      from public.catalog_review_queue q
     where q.entity_id = a.id
       and q.lot = p_lot
       and q.decision in ('valide', 'corrige')
       and q.applique_le is null
       and public.fn_conv_cible(q.valeur_retenue, q.apres_propose) is not null
       -- Anti-écrasement : on n'écrit que si la fiche est encore dans
       -- l'état constaté au moment de la proposition (CONV-O6).
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

    -- Le décalage `title_nonfiling` peut ne plus tomber sur une frontière
    -- de mot après la réécriture du titre : on le revérifie et on le remet
    -- à zéro plutôt que de laisser un tri silencieusement faux.
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
$function$;

comment on function api.conv_revue_appliquer(text) is
  'CONV §37 · applique au catalogue les verdicts tranchés d''un lot. Staff '
  'uniquement. Écriture de données par un·e membre du staff, comme merge_author '
  '— pas une migration (cf. en-tête de la migration 14). Gardes identiques aux '
  'migrations 10-12 : anti-écrasement strict, preferred_name re-dérivé seulement '
  's''il est encore mécanique, cible sans virgule prise verbatim, title_nonfiling '
  'revérifié. Le lot autorite_collectivite écrit EN PLUS authority_type et '
  'structured_meta.authorityType, pour que la colonne et le jsonb ne puissent '
  'pas diverger (CONV-O7). Renvoie (appliquées, refusées, offsets réinitialisés).';

revoke all on function api.conv_revue_appliquer(text) from public, anon;
grant execute on function api.conv_revue_appliquer(text) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Vérification
-- ---------------------------------------------------------------------
do $$
declare
  n_anon bigint;
  n_lot  bigint;
  n_tot  bigint;
begin
  select count(*) into n_anon
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace, aclexplode(p.proacl) a
    join pg_roles r on r.oid = a.grantee
   where n.nspname = 'api' and p.proname = 'conv_revue_appliquer'
     and r.rolname = 'anon' and a.privilege_type = 'EXECUTE';

  if n_anon > 0 then
    raise exception 'CONV/16 — conv_revue_appliquer executable par anon : abandon.';
  end if;

  select count(*) into n_tot from public.authors;
  if n_tot = 0 then
    raise notice 'CONV/16 — base sans autorités (reconstruction CI).';
    return;
  end if;

  select count(*) into n_lot
    from public.catalog_review_queue where lot = 'autorite_collectivite';

  raise notice 'CONV/16 — % collectivité(s) en attente de relecture humaine.', n_lot;
end $$;

commit;
