-- Notes de lecture — Lot 3 : activation pour la BLMF (adoptee en AG BLMF).
-- Cadrage : docs/journal/cadrages/CADRAGE_notes_de_lecture_2026-08-01.md
-- Active reading_notes_enabled pour la Biblioteca Libertaria Maxwell Ferreira.
-- Les autres biblios restent en opt-in (defaut false) : chacune decide en AG.
-- Migration de donnees ponctuelle (staging) : gardee derriere une verification
-- d'existence pour rester no-op ailleurs (CI, autres environnements).
do $$
declare
  v_blmf uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
begin
  if not exists (select 1 from public.libraries where id = v_blmf) then
    raise notice 'reading_notes_enable_blmf: biblio BLMF % absente (hors staging) - ignore.', v_blmf;
    return;
  end if;
  -- library_service_state a une ligne par biblio ; on la cree au besoin.
  insert into public.library_service_state (library_id, reading_notes_enabled)
  values (v_blmf, true)
  on conflict (library_id) do update set reading_notes_enabled = true;
end $$;
