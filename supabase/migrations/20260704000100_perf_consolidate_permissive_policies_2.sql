-- Perf : advisor 0006 multiple_permissive_policies — lot 2 (tables lues).
-- Fusion en OR verbatim des policies permissives qui se chevauchent. Sémantique
-- strictement préservée. Idempotent. Cf. lot 1 (20260703235900).

-- ── user_library_memberships : 4 policies SELECT → 1. ───────────────────────
-- Fusion en `to public` : les branches admin/own/reader valent false pour anon
-- (auth.uid() null), donc anon reste sans visibilité et authenticated garde le OR.
drop policy if exists ulm_select_all_for_network_admin on public.user_library_memberships;
drop policy if exists ulm_select_own_memberships on public.user_library_memberships;
drop policy if exists ulm_select_readers_visible_to_staff_same_lib on public.user_library_memberships;
drop policy if exists ulm_select_staff_visible_to_staff_same_lib on public.user_library_memberships;
drop policy if exists ulm_select_consolidated on public.user_library_memberships;
create policy ulm_select_consolidated on public.user_library_memberships
  for select to public
  using (
    public.fn_caller_is_network_admin()
    or ((select auth.uid()) = user_id)
    or (role = 'reader'::text and public.user_can_act_as_staff_on_library(library_id))
    or (role = any (array['librarian'::text, 'coordenador'::text]) and public.user_can_act_as_staff_on_library(library_id))
  );

-- ── profiles : la policy « librarian » contient déjà la condition « own ». ───
-- Suppression de redondance (SELECT + UPDATE). INSERT inchangée.
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_select_same_library_librarian on public.profiles;
drop policy if exists profiles_select_consolidated on public.profiles;
create policy profiles_select_consolidated on public.profiles
  for select to authenticated
  using ((id = (select auth.uid())) or public.can_manage_profile_from_my_libraries(id));

drop policy if exists profiles_update_own on public.profiles;
drop policy if exists profiles_update_same_library_librarian on public.profiles;
drop policy if exists profiles_update_consolidated on public.profiles;
create policy profiles_update_consolidated on public.profiles
  for update to authenticated
  using ((id = (select auth.uid())) or public.can_manage_profile_from_my_libraries(id))
  with check ((id = (select auth.uid())) or public.can_manage_profile_from_my_libraries(id));

-- ── reservas_v2 : SELECT ×2 → 1, UPDATE ×2 → 1 (OR mien / staff même biblio). ─
drop policy if exists reservas_v2_select_own on public.reservas_v2;
drop policy if exists reservas_v2_select_librarian_same_library on public.reservas_v2;
drop policy if exists reservas_v2_select_consolidated on public.reservas_v2;
create policy reservas_v2_select_consolidated on public.reservas_v2
  for select to public
  using (
    (((select auth.uid()) = user_id) and public.fn_library_has_circulation(library_id))
    or ((exists (select 1 from api.my_access a
                 where a.user_id = (select auth.uid()) and a.can_access_painel = true
                   and a.library_id = reservas_v2.library_id))
        and public.fn_library_has_circulation(library_id))
  );

drop policy if exists reservas_v2_update_own on public.reservas_v2;
drop policy if exists reservas_v2_update_librarian_same_library on public.reservas_v2;
drop policy if exists reservas_v2_update_consolidated on public.reservas_v2;
create policy reservas_v2_update_consolidated on public.reservas_v2
  for update to public
  using (
    (((select auth.uid()) = user_id) and public.fn_library_has_circulation(library_id))
    or ((exists (select 1 from api.my_access a
                 where a.user_id = (select auth.uid()) and a.can_access_painel = true
                   and a.library_id = reservas_v2.library_id))
        and public.fn_library_has_circulation(library_id))
  )
  with check (
    (((select auth.uid()) = user_id) and public.fn_library_has_circulation(library_id))
    or ((exists (select 1 from api.my_access a
                 where a.user_id = (select auth.uid()) and a.can_access_painel = true
                   and a.library_id = reservas_v2.library_id))
        and public.fn_library_has_circulation(library_id))
  );

-- ── reserva_linhas_v2 : SELECT ×2 → 1, UPDATE ×2 → 1. ───────────────────────
drop policy if exists reserva_linhas_v2_select_own on public.reserva_linhas_v2;
drop policy if exists reserva_linhas_v2_select_librarian_same_library on public.reserva_linhas_v2;
drop policy if exists reserva_linhas_v2_select_consolidated on public.reserva_linhas_v2;
create policy reserva_linhas_v2_select_consolidated on public.reserva_linhas_v2
  for select to public
  using (
    exists (select 1 from public.reservas_v2 r
            where r.id = reserva_linhas_v2.reserva_id and r.user_id = (select auth.uid()))
    or exists (select 1 from public.reservas_v2 r join api.my_access a on a.library_id = r.library_id
               where r.id = reserva_linhas_v2.reserva_id and a.user_id = (select auth.uid()) and a.can_access_painel = true)
  );

drop policy if exists reserva_linhas_v2_update_own on public.reserva_linhas_v2;
drop policy if exists reserva_linhas_v2_update_librarian_same_library on public.reserva_linhas_v2;
drop policy if exists reserva_linhas_v2_update_consolidated on public.reserva_linhas_v2;
create policy reserva_linhas_v2_update_consolidated on public.reserva_linhas_v2
  for update to public
  using (
    exists (select 1 from public.reservas_v2 r
            where r.id = reserva_linhas_v2.reserva_id and r.user_id = (select auth.uid()))
    or exists (select 1 from public.reservas_v2 r join api.my_access a on a.library_id = r.library_id
               where r.id = reserva_linhas_v2.reserva_id and a.user_id = (select auth.uid()) and a.can_access_painel = true)
  )
  with check (
    exists (select 1 from public.reservas_v2 r
            where r.id = reserva_linhas_v2.reserva_id and r.user_id = (select auth.uid()))
    or exists (select 1 from public.reservas_v2 r join api.my_access a on a.library_id = r.library_id
               where r.id = reserva_linhas_v2.reserva_id and a.user_id = (select auth.uid()) and a.can_access_painel = true)
  );

-- ── reserva_item_workflow_v2 : SELECT ×2 → 1, UPDATE ×2 → 1. ────────────────
drop policy if exists reserva_item_workflow_v2_select_own on public.reserva_item_workflow_v2;
drop policy if exists reserva_item_workflow_v2_select_librarian_same_library on public.reserva_item_workflow_v2;
drop policy if exists reserva_item_workflow_v2_select_consolidated on public.reserva_item_workflow_v2;
create policy reserva_item_workflow_v2_select_consolidated on public.reserva_item_workflow_v2
  for select to public
  using (
    exists (select 1 from public.reservas_v2 r
            where r.id = reserva_item_workflow_v2.reserva_id and r.user_id = (select auth.uid()))
    or exists (select 1 from public.reservas_v2 r join api.my_access a on a.library_id = r.library_id
               where r.id = reserva_item_workflow_v2.reserva_id and a.user_id = (select auth.uid()) and a.can_access_painel = true)
  );

drop policy if exists reserva_item_workflow_v2_update_own on public.reserva_item_workflow_v2;
drop policy if exists reserva_item_workflow_v2_update_librarian_same_library on public.reserva_item_workflow_v2;
drop policy if exists reserva_item_workflow_v2_update_consolidated on public.reserva_item_workflow_v2;
create policy reserva_item_workflow_v2_update_consolidated on public.reserva_item_workflow_v2
  for update to public
  using (
    exists (select 1 from public.reservas_v2 r
            where r.id = reserva_item_workflow_v2.reserva_id and r.user_id = (select auth.uid()))
    or exists (select 1 from public.reservas_v2 r join api.my_access a on a.library_id = r.library_id
               where r.id = reserva_item_workflow_v2.reserva_id and a.user_id = (select auth.uid()) and a.can_access_painel = true)
  )
  with check (
    exists (select 1 from public.reservas_v2 r
            where r.id = reserva_item_workflow_v2.reserva_id and r.user_id = (select auth.uid()))
    or exists (select 1 from public.reservas_v2 r join api.my_access a on a.library_id = r.library_id
               where r.id = reserva_item_workflow_v2.reserva_id and a.user_id = (select auth.uid()) and a.can_access_painel = true)
  );
