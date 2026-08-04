-- =========================================================================
-- Notes de lecture — Lot 4 : correctif de la policy d'INSERT (bug latent Lot 1).
-- Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md
--
-- Bug : la policy `reading_notes_insert` verifiait l'activation via
--   exists (select 1 from library_service_state s where s.library_id = ...
--           and s.reading_notes_enabled = true)
-- Or `library_service_state` a une RLS SELECT reservee au STAFF
-- (library_service_state_select_team). Les sous-requetes d'une expression RLS
-- s'evaluent AVEC la RLS des tables referencees : pour un simple lecteur, la
-- ligne d'etat de service est INVISIBLE -> l'EXISTS renvoie toujours false ->
-- l'INSERT etait refuse meme pour un lecteur parfaitement valide. (Le CI Lot 1
-- reconstruit le schema mais n'inserait pas de note en tant que `authenticated`,
-- d'ou le bug non detecte ; la suite RLS du Lot 4 le couvre desormais.)
--
-- Correctif : un helper SECURITY DEFINER qui lit reading_notes_enabled en
-- contournant la RLS (meme patron que public.user_can_act_as_staff_on_library
-- et fn_library_timezones), utilise dans la policy d'INSERT. La verification
-- d'adhesion reste inline : un lecteur voit SA propre adhesion (ulm_select_*
-- « own »), donc cet EXISTS-la fonctionne deja correctement.
-- Idempotent (create or replace / drop-create).
-- =========================================================================

-- Helper : la biblio a-t-elle active les notes de lecture ? (bypass RLS lecture
-- de library_service_state, qui est staff-only). STABLE : pur lecture.
create or replace function public.fn_reading_notes_enabled_for(p_library_id uuid)
returns boolean
language sql stable security definer set search_path = public, pg_temp as $$
  select exists (
    select 1 from public.library_service_state s
    where s.library_id = p_library_id
      and s.reading_notes_enabled = true
  );
$$;

comment on function public.fn_reading_notes_enabled_for(uuid) is
  'TRUE si la biblio a active les notes de lecture (library_service_state.reading_notes_enabled). SECURITY DEFINER : contourne la RLS staff-only de library_service_state pour que la policy d''INSERT de book_reading_notes soit evaluable par un simple lecteur. Cadrage CADRAGE_notes_de_lecture_2026-08-01.';

grant execute on function public.fn_reading_notes_enabled_for(uuid) to authenticated, service_role;

-- Redefinition de la policy d'INSERT : meme regle metier, mais l'activation
-- passe par le helper SECURITY DEFINER (visible du lecteur), plus par un EXISTS
-- direct sur library_service_state (invisible du lecteur).
drop policy if exists reading_notes_insert on public.book_reading_notes;
create policy reading_notes_insert on public.book_reading_notes
  for insert to authenticated
  with check (
    author_user_id = auth.uid()
    and exists (
      select 1 from public.user_library_memberships m
      where m.user_id = auth.uid()
        and m.library_id = origin_library_id
        and m.status = 'active'
        and coalesce(m.is_restricted, false) = false
    )
    and public.fn_reading_notes_enabled_for(origin_library_id)
  );
