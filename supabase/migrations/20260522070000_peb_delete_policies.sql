-- ============================================================================
-- 20260522070000_peb_delete_policies.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-delete-rls — le bouton « descartar » d'un PEB echoue.
--
-- PROBLEME
--   fn_peb_delete_loan supprime les exemplaires puis le pret. Mais ni
--   interlibrary_loans_v2 ni interlibrary_loan_items_v2 n'ont de policy
--   DELETE. La RLS etant active, PostgreSQL refuse tout DELETE en l'absence
--   de policy (RLS active + pas de policy = commande refusee). D'ou
--   « fn_peb_delete_loan: DELETE du loan id=N refuse par RLS ».
--
-- CORRECTIF — deux policies DELETE
--   1. interlibrary_loans_v2_delete : autorise le DELETE d'un PEB si
--      l'appelant gere l'une des deux bibliotheques (comme la policy
--      _update) ET si le pret est encore un brouillon non parti.
--   2. interlibrary_loan_items_v2_delete : autorise le DELETE d'un
--      exemplaire si son pret parent satisfait EXACTEMENT la meme
--      condition (autorisation + statut brouillon), via un EXISTS.
--
--   Les deux policies portent la MEME condition sur le pret. Consequence :
--   soit le pret entier est supprimable (brouillon, appelant autorise) et
--   alors items + pret partent ensemble ; soit rien n'est supprimable.
--   Jamais d'etat intermediaire (pret vide de ses items mais subsistant).
--
-- DOCTRINE — suppression ENCADREE (ecole « memoire »)
--   La suppression n'est autorisee que pour les statuts 'preparacao' et
--   'aguardando_saida' : un PEB encore a l'etat de brouillon, dont aucun
--   document n'est physiquement parti. Des qu'un pret est entre en
--   circulation (emprestado, parcialmente_devolvido, devolvido, atrasado,
--   cancelado...), il ne se supprime plus : il constitue une trace de la
--   circulation reelle des fonds entre collectifs. Pour « annuler » un
--   pret en cours, le statut 'cancelado' existe — il clot le pret en
--   conservant sa trace.
--
-- NOTE — FK ON DELETE CASCADE
--   interlibrary_loan_items_v2_header_fkey est ON DELETE CASCADE. La
--   cascade FK ne passe PAS par la RLS : elle sert ici de simple filet
--   anti-orphelins. fn_peb_delete_loan supprime neanmoins les items
--   explicitement (pour les compter) — ce DELETE explicite passe, lui, par
--   la RLS, d'ou la necessite de la policy 2.
--
-- VERIFICATION
--   Bloc DO : les deux policies existent et sont bien de type DELETE.
-- ============================================================================


-- ─── Policy 1 — DELETE sur interlibrary_loans_v2 ─────────────────────────────
DROP POLICY IF EXISTS interlibrary_loans_v2_delete ON public.interlibrary_loans_v2;
CREATE POLICY interlibrary_loans_v2_delete
  ON public.interlibrary_loans_v2
  FOR DELETE
  USING (
    (user_can_manage_library(lender_library_id)
     OR user_can_manage_library(borrower_library_id))
    AND fn_peb_authorized(lender_library_id, borrower_library_id)
    AND status_global IN ('preparacao', 'aguardando_saida')
  );


-- ─── Policy 2 — DELETE sur interlibrary_loan_items_v2 ────────────────────────
-- Meme condition que la policy 1, portee sur le pret parent via EXISTS.
DROP POLICY IF EXISTS interlibrary_loan_items_v2_delete ON public.interlibrary_loan_items_v2;
CREATE POLICY interlibrary_loan_items_v2_delete
  ON public.interlibrary_loan_items_v2
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM interlibrary_loans_v2 h
      WHERE h.id = interlibrary_loan_items_v2.interlibrary_loan_id
        AND (user_can_manage_library(h.lender_library_id)
             OR user_can_manage_library(h.borrower_library_id))
        AND fn_peb_authorized(h.lender_library_id, h.borrower_library_id)
        AND h.status_global IN ('preparacao', 'aguardando_saida')
    )
  );


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_count integer;
begin
  -- (a) Policy DELETE sur interlibrary_loans_v2.
  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'interlibrary_loans_v2'
    and policyname = 'interlibrary_loans_v2_delete'
    and cmd = 'DELETE';
  if v_count <> 1 then
    raise exception 'Verification echouee : policy DELETE absente sur interlibrary_loans_v2.';
  end if;

  -- (b) Policy DELETE sur interlibrary_loan_items_v2.
  select count(*) into v_count
  from pg_policies
  where schemaname = 'public'
    and tablename = 'interlibrary_loan_items_v2'
    and policyname = 'interlibrary_loan_items_v2_delete'
    and cmd = 'DELETE';
  if v_count <> 1 then
    raise exception 'Verification echouee : policy DELETE absente sur interlibrary_loan_items_v2.';
  end if;

  raise notice 'Migration 20260522070000 : verification OK (2 policies DELETE creees, suppression encadree aux brouillons).';
end;
$verif$;
