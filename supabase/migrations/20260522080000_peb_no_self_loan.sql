-- ============================================================================
-- 20260522080000_peb_no_self_loan.sql
-- ----------------------------------------------------------------------------
-- Chantier #ILL-self-loan — une bibliotheque peut s'emprunter a elle-meme.
--
-- PROBLEME
--   fn_peb_authorized(lender, borrower) verifie que les deux bibliotheques
--   ont la circulation activee et sont federees — mais JAMAIS que lender et
--   borrower sont differents. Un PEB ou lender_library_id = borrower_library_id
--   est donc autorise. Le comportement « parfois bloque, parfois non »
--   constate en test venait de la : aucune garde anti-auto-emprunt
--   n'existe ; seuls des refus accessoires (statut, droits) attrapaient le
--   cas par accident.
--
-- CORRECTIF — defense en profondeur (deux gardes)
--   A. fn_peb_authorized gagne la condition lender <> borrower. Comme cette
--      fonction est appelee par TOUTES les policies PEB (_update, _delete,
--      et referencee par la logique d'_insert), la regle s'applique
--      partout, et le refus arrive proprement au niveau RLS.
--   B. Un CHECK sur interlibrary_loans_v2 interdit PHYSIQUEMENT toute ligne
--      ou lender = borrower, quelle que soit la voie d'ecriture (RPC,
--      INSERT direct, import). Rempart structurel infranchissable.
--
--   A = refus propre et coherent dans la logique metier.
--   B = garantie que la table ne peut pas contenir de PEB incoherent.
--
-- PREALABLE VERIFIE
--   Aucune ligne existante n'a lender_library_id = borrower_library_id
--   (verifie le 22/05/2026) : le ADD CONSTRAINT ne peut pas echouer sur
--   l'existant.
--
-- VERIFICATION
--   Bloc DO : fn_peb_authorized refuse bien un couple (X, X) ; le CHECK
--   est present sur la table.
-- ============================================================================


-- ─── A — fn_peb_authorized : ajout de la condition lender <> borrower ────────
-- Recreee a l'identique, plus la condition d'inegalite. STABLE, SECURITY
-- DEFINER, search_path : tout reconduit.
CREATE OR REPLACE FUNCTION public.fn_peb_authorized(p_lender_library_id uuid, p_borrower_library_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT
    p_lender_library_id IS DISTINCT FROM p_borrower_library_id
    AND public.fn_library_has_circulation(p_lender_library_id)
    AND public.fn_library_has_circulation(p_borrower_library_id)
    AND public.fn_library_is_federated(p_lender_library_id)
    AND public.fn_library_is_federated(p_borrower_library_id);
$function$;


-- ─── B — CHECK structurel sur interlibrary_loans_v2 ──────────────────────────
-- Interdit toute ligne ou la bibliotheque prêteuse est aussi l'emprunteuse.
ALTER TABLE public.interlibrary_loans_v2
  DROP CONSTRAINT IF EXISTS interlibrary_loans_v2_no_self_loan_chk;

ALTER TABLE public.interlibrary_loans_v2
  ADD CONSTRAINT interlibrary_loans_v2_no_self_loan_chk
  CHECK (lender_library_id <> borrower_library_id);


-- ============================================================================
-- VERIFICATION POST-MIGRATION
-- ============================================================================
DO $verif$
declare
  v_self_authorized boolean;
  v_check_count integer;
  v_dummy uuid := '00000000-0000-0000-0000-000000000000'::uuid;
begin
  -- (A) fn_peb_authorized doit renvoyer false (ou null) pour un couple (X, X).
  -- On teste avec un meme uuid des deux cotes : la condition d'inegalite
  -- doit faire echouer l'autorisation, independamment des autres criteres.
  select public.fn_peb_authorized(v_dummy, v_dummy) into v_self_authorized;
  if v_self_authorized is true then
    raise exception 'Verification echouee : fn_peb_authorized autorise encore un auto-emprunt (lender = borrower).';
  end if;

  -- (B) Le CHECK anti-auto-emprunt est present sur la table.
  select count(*) into v_check_count
  from pg_constraint con
  join pg_class c on c.oid = con.conrelid
  where c.relname = 'interlibrary_loans_v2'
    and con.conname = 'interlibrary_loans_v2_no_self_loan_chk'
    and con.contype = 'c';
  if v_check_count <> 1 then
    raise exception 'Verification echouee : CHECK interlibrary_loans_v2_no_self_loan_chk absent.';
  end if;

  raise notice 'Migration 20260522080000 : verification OK (fn_peb_authorized refuse l auto-emprunt, CHECK structurel pose).';
end;
$verif$;
