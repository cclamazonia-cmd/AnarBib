-- Notes de lecture — Lot 2 (support frontend lecteur).
-- Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md
--
-- Le flag library_service_state.reading_notes_enabled est staff-only en RLS :
-- un·e LECTEUR·RICE ne peut donc pas savoir cote client s'il/elle a le droit
-- d'ecrire une note. Cette fonction SECURITY DEFINER encapsule toute la logique
-- d'eligibilite et renvoie au frontend :
--   * origin_library_id : la biblio sous laquelle ecrire (adhesion active, non
--     restreinte, ET fonction activee), en preferant l'adhesion primaire ;
--     NULL / aucune ligne si l'utilisateur·rice n'est eligible nulle part ;
--   * suggested_pseudonym : le dernier pseudonyme utilise par la personne
--     (pre-remplissage du champ), NULL si premiere note.
-- N'expose aucune donnee sensible : juste l'id d'une biblio ou la personne est
-- deja membre + son propre pseudonyme.

create or replace function public.fn_my_reading_note_target()
returns table(origin_library_id uuid, suggested_pseudonym text)
language sql
stable
security definer
set search_path = public
as $$
  select m.library_id,
         (select n.author_pseudonym
            from public.book_reading_notes n
           where n.author_user_id = auth.uid()
           order by n.created_at desc
           limit 1)
    from public.user_library_memberships m
   where m.user_id = auth.uid()
     and m.status = 'active'
     and coalesce(m.is_restricted, false) = false
     and exists (select 1 from public.library_service_state s
                  where s.library_id = m.library_id
                    and s.reading_notes_enabled = true)
   order by coalesce(m.is_primary, false) desc, m.library_id
   limit 1;
$$;

alter function public.fn_my_reading_note_target() owner to postgres;
revoke all on function public.fn_my_reading_note_target() from public;
grant execute on function public.fn_my_reading_note_target() to authenticated, service_role;

comment on function public.fn_my_reading_note_target() is
  'Eligibilite d''ecriture de note de lecture pour l''utilisateur courant : renvoie (origin_library_id, suggested_pseudonym) ou aucune ligne si non eligible. SECURITY DEFINER car reading_notes_enabled est staff-only. Cf. CADRAGE_notes_de_lecture_2026-08-01, Lot 2.';
