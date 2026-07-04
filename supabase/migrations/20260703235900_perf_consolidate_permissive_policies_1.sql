-- Perf : advisor 0006 multiple_permissive_policies — lot 1 (tables très lues).
-- Consolide des policies permissives qui se chevauchent, SANS changer la sémantique.
-- Idempotent (drop if exists + create). Cf. ETAT-lancement-consolide-2026-07-03 §7.

-- ── libraries : 3 policies SELECT (OR) → 1 seule. ───────────────────────────
-- Équivalent : pour anon, user_can_act_as_staff_on_library(id) vaut toujours false
-- (auth.uid() null), donc anon garde « visible OR signup » et authenticated garde
-- « visible OR signup OR staff ». La policy UPDATE reste inchangée.
drop policy if exists libraries_public_read on public.libraries;
drop policy if exists libraries_public_signup_read on public.libraries;
drop policy if exists libraries_staff_read on public.libraries;
drop policy if exists libraries_read on public.libraries;
create policy libraries_read on public.libraries
  for select to anon, authenticated
  using (
    public.fn_library_visible_to_caller(id)
    or (is_active = true and accepts_public_signup = true and network_mode <> 'isolated'::text)
    or public.user_can_act_as_staff_on_library(id)
  );

-- ── author_translations : la policy d'écriture FOR ALL déborde sur SELECT. ──
-- Le SELECT public est déjà `true` ; on scinde la policy ALL en INSERT/UPDATE/DELETE
-- (même condition) pour retirer la sous-requête EXISTS du chemin de lecture.
-- (Sur une policy ALL, le USING sert aussi de WITH CHECK pour INSERT/UPDATE.)
drop policy if exists author_translations_librarian_write on public.author_translations;
drop policy if exists author_translations_librarian_insert on public.author_translations;
drop policy if exists author_translations_librarian_update on public.author_translations;
drop policy if exists author_translations_librarian_delete on public.author_translations;
create policy author_translations_librarian_insert on public.author_translations
  for insert to public
  with check (
    ((select auth.uid()) is not null)
    and exists (select 1 from public.user_library_memberships m
                where m.user_id = (select auth.uid())
                  and m.role = any (array['librarian'::text, 'coordenador'::text]))
  );
create policy author_translations_librarian_update on public.author_translations
  for update to public
  using (
    ((select auth.uid()) is not null)
    and exists (select 1 from public.user_library_memberships m
                where m.user_id = (select auth.uid())
                  and m.role = any (array['librarian'::text, 'coordenador'::text]))
  )
  with check (
    ((select auth.uid()) is not null)
    and exists (select 1 from public.user_library_memberships m
                where m.user_id = (select auth.uid())
                  and m.role = any (array['librarian'::text, 'coordenador'::text]))
  );
create policy author_translations_librarian_delete on public.author_translations
  for delete to public
  using (
    ((select auth.uid()) is not null)
    and exists (select 1 from public.user_library_memberships m
                where m.user_id = (select auth.uid())
                  and m.role = any (array['librarian'::text, 'coordenador'::text]))
  );
