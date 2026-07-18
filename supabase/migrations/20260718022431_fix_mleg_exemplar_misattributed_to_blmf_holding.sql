-- Corrige un exemplaire mal rattache : le livre "Um Ensaio sobre a Revolucao
-- sexual" (Daniel Guerin, id=2318) n'avait qu'un seul book_holdings (BLMF).
-- L'exemplaire tombo=MLEG-2026-0267 (localisation "Biblioteca: MLEG -
-- Salvador"), catalogue manuellement le 2026-07-17, s'est donc retrouve
-- rattache au holding BLMF au lieu d'un holding MLEG (inexistant jusque-la).
-- Cause racine : ExemplarDraftForm.jsx ne renseignait jamais target_library_id
-- a la creation d'un brouillon -> publish_exemplar_draft retombait sur la
-- biblioteca primaire du catalogueur (BLMF). Cf. migrations suivantes pour le
-- garde-fou DB + le correctif frontend associe.

do $$
declare
  v_book_id bigint := 2318;
  v_mleg_id uuid := 'dfa87c64-4a2f-4a6d-9e92-646d90ac2b22';
  v_new_holding_id bigint;
begin
  -- get-or-create le book_holdings pour (livre, MLEG).
  insert into public.book_holdings (book_id, library_id)
  values (v_book_id, v_mleg_id)
  on conflict (book_id, library_id) do update set updated_at = now()
  returning id into v_new_holding_id;

  update public.exemplares
     set library_id = v_mleg_id,
         holding_id = v_new_holding_id,
         updated_at = now()
   where id = 2745
     and tombo = 'MLEG-2026-0267';

  perform public.fn_v2_recompute_holdings_availability(p_book_ids := ARRAY[v_book_id]);
end $$;
