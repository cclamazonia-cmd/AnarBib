-- Deux régressions d'hygiène nées le 05/09/2026, vues par les advisors le 06/09
-- (photo du backlog) et corrigées à une ligne chacune.
--
-- 1. `private.conv_motifs_collectivite()` — recréée le 03/09 (`20260903165704`)
--    sans `SET search_path`. SQL IMMUTABLE, sans table, réservée à `postgres` ;
--    le hook pre-commit ne garde que les SECURITY DEFINER, l'advisor
--    `function_search_path_mutable` la voit quand même, et la doctrine du dépôt
--    est « aucune fonction applicative sans search_path figé » (0 sur 805 le
--    30/08). `pg_catalog` suffit : la fonction ne cite rien d'autre.
--
-- 2. `catalog_batch_reviews_read_staff` (`20260905093000`) — `m.user_id = auth.uid()`
--    dans une sous-requête EXISTS : `auth.uid()` réévaluée à chaque ligne
--    (`auth_rls_initplan`), le motif que B5 avait résorbé sur neuf policies le
--    31/08. `(select auth.uid())` la fait évaluer une fois par requête. Même
--    prédicat, mêmes droits.
--
-- La suite `hygiene_search_path_et_initplan_tests.sql` garde les deux motifs
-- sur toute la base : plus une fonction sans search_path dans public/api/ingest/
-- private, plus une policy qui appelle `auth.uid()` hors d'un `(select …)`.

alter function private.conv_motifs_collectivite() set search_path = pg_catalog;

drop policy if exists catalog_batch_reviews_read_staff on public.catalog_batch_reviews;
create policy catalog_batch_reviews_read_staff on public.catalog_batch_reviews
  for select to authenticated
  using (
    public.fn_caller_is_network_admin()
    or exists (
      select 1 from public.user_library_memberships m
       where m.user_id = (select auth.uid())
         and m.status = 'active'
         and m.role in ('librarian', 'coordenador')
    )
  );

do $$
declare
  n int;
begin
  if not exists (select 1 from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
                  where ns.nspname = 'private' and p.proname = 'conv_motifs_collectivite'
                    and exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')) then
    raise exception 'private.conv_motifs_collectivite : search_path toujours absent';
  end if;
  select count(*) into n from pg_policy p
   where p.polname = 'catalog_batch_reviews_read_staff'
     and pg_get_expr(p.polqual, p.polrelid) ~ 'SELECT auth\.uid\(\)';
  if n <> 1 then
    raise exception 'catalog_batch_reviews_read_staff : auth.uid() n''est pas enveloppé';
  end if;
end
$$;
