-- =====================================================================
-- CONVENTIONS CATALOGRAPHIQUES — 13 · La file cesse de mentir (CONV-O6)
-- Foyer : REGISTRE §37 `CONV`
--
-- ---------------------------------------------------------------------
-- LE DÉFAUT. `catalog_review_queue.avant` est un INSTANTANÉ, figé à la
-- création de la file. Quand une même entité figure dans deux lots,
-- l'application du premier périme l'affichage du second : l'écran montre
-- un état qui n'existe plus, et un verdict posé dessus déferait le travail
-- déjà fait.
--
-- Vécu le 21/08 sur l'autorité 10079 (Luis Di Filippo). Le lot patronyme
-- l'avait corrigée en « Di Filippo, Luis » ; la file de casse montrait
-- toujours « FILIPPO, Luis Di », et le verdict a été posé là-dessus. La
-- garde stricte a refusé l'écriture — deux fois, migrations 11 et 12 —
-- mais l'écran, lui, n'a rien dit. Ce n'est pas un défaut de relecture :
-- lu seul, le verdict était juste.
--
-- LE REMÈDE. La RPC ne renvoie plus seulement l'instantané : elle joint
-- l'état RÉEL de l'entité et dit si les deux divergent. L'écran peut donc
-- montrer ce qui est, et non ce qui était.
--
-- Changement de type de retour ⇒ DROP + CREATE, jamais CREATE OR REPLACE
-- (DOC-OBJ-2).
-- =====================================================================

begin;

drop function if exists api.conv_revue_list(text, text, int, int);

create function api.conv_revue_list(
  p_lot      text,
  p_decision text default 'a_revoir',
  p_max      int  default 50,
  p_offset   int  default 0
)
returns table (id bigint, entity_kind text, entity_id bigint, contexte text,
               avant text, apres_propose text, decision text,
               valeur_retenue text, note text, applique_le timestamptz,
               actuel text, perime boolean)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_catalog'
as $function$
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
        select case q.entity_kind
                 when 'author' then (select a.sort_name from public.authors a where a.id = q.entity_id)
                 when 'book'   then (select b.titulo    from public.books   b where b.id = q.entity_id)
               end as actuel
      ) v on true
     where q.lot = p_lot
       and (p_decision is null or q.decision = p_decision)
     order by q.avant, q.id
     limit greatest(1, least(coalesce(p_max, 50), 200))
    offset greatest(0, coalesce(p_offset, 0));
end;
$function$;

comment on function api.conv_revue_list(text, text, int, int) is
  'CONV §37 · une page de la file de vérification. Staff uniquement. Renvoie '
  'l''instantané (`avant`) ET l''état réel (`actuel`), plus `perime` quand les '
  'deux divergent sur une ligne non appliquée — CONV-O6 : un verdict posé sur '
  'un état périmé déferait le travail d''un autre lot. Plafonnée à 200 lignes. '
  '`p_decision = null` renvoie TOUTES les décisions : sans quoi une ligne '
  'tranchée mais jamais appliquée devient inatteignable depuis l''écran.';

revoke all on function api.conv_revue_list(text, text, int, int) from public, anon;
grant execute on function api.conv_revue_list(text, text, int, int) to authenticated;

-- ---------------------------------------------------------------------
-- Vérification
-- ---------------------------------------------------------------------
do $$
declare
  n_cols   bigint;
  n_grants bigint;
begin
  select count(*) into n_cols
    from information_schema.columns
   where table_schema = 'api' and table_name = 'conv_revue_list'
     and column_name in ('actuel', 'perime');

  select count(*) into n_grants
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace,
         aclexplode(p.proacl) a
    join pg_roles r on r.oid = a.grantee
   where n.nspname = 'api' and p.proname = 'conv_revue_list'
     and r.rolname = 'anon' and a.privilege_type = 'EXECUTE';

  if n_grants > 0 then
    raise exception 'CONV/13 — conv_revue_list executable par anon : abandon.';
  end if;

  raise notice 'CONV/13 — la file expose desormais l''etat reel (% colonne(s) ajoutee(s)).', n_cols;
end $$;

commit;
