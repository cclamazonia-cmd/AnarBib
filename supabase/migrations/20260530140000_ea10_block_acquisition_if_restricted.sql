-- Migration : EA-10 enforcement — bloquer toute acquisition pour un·e emprunteur·se
-- gelé·e (réseau) ou restreint·e (locale). 30/05/2026.
--
-- Constat (audit 30/05) : aucun chemin de création (fn_v2_create_emprestimo_by_holdings,
-- fn_v2_convert_reserva_linhas_to_emprestimo, fn_v2_create_reserva_by_holdings) ne lisait
-- le statut de restriction de l'emprunteur·se. La restriction était signalétique et tracée,
-- mais jamais bloquante (un·e coordinateur·rice pouvait prêter à un compte gelé globalement).
--
-- Doctrine arbitrée (30/05) : gel global → blocage DUR ; restriction locale → blocage à la
-- biblio concernée. Enforcement posé au plus près de la vérité, par trigger BEFORE INSERT
-- SECURITY DEFINER (voit hors RLS), couvrant tous les chemins présents et futurs en 2 objets.
-- Le message suit le motif existant du blocage cotisations : RAISE EXCEPTION + ERRCODE P0001
-- + HINT = clé i18n (mappée côté frontend).
--
-- Doctrine : fichier appliqué par Woodpecker (supabase db push --linked).

-- ── Emprunts ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_trg_block_acquisition_if_restricted_emprestimo()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
BEGIN
  -- Gel global réseau : aucun emprunt, nulle part.
  IF EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = NEW.user_id AND COALESCE(is_restricted, false) IS TRUE
  ) THEN
    RAISE EXCEPTION 'Conta congelada pela rede. Empréstimo bloqueado.'
      USING ERRCODE = 'P0001', HINT = 'error.borrower.frozen';
  END IF;

  -- Restriction locale staff : aucun emprunt dans la biblio concernée.
  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships
     WHERE user_id = NEW.user_id AND library_id = NEW.library_id
       AND status = 'active' AND COALESCE(is_restricted, false) IS TRUE
  ) THEN
    RAISE EXCEPTION 'Leitor(a) com restrição local nesta biblioteca. Empréstimo bloqueado.'
      USING ERRCODE = 'P0001', HINT = 'error.borrower.restricted_local';
  END IF;

  RETURN NEW;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.fn_trg_block_acquisition_if_restricted_emprestimo() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_block_acquisition_if_restricted ON public.emprestimos_v2;
CREATE TRIGGER trg_block_acquisition_if_restricted
  BEFORE INSERT ON public.emprestimos_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_block_acquisition_if_restricted_emprestimo();

-- ── Réservations ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_trg_block_acquisition_if_restricted_reserva()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.profiles
     WHERE id = NEW.user_id AND COALESCE(is_restricted, false) IS TRUE
  ) THEN
    RAISE EXCEPTION 'Conta congelada pela rede. Reserva bloqueada.'
      USING ERRCODE = 'P0001', HINT = 'error.borrower.frozen';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships
     WHERE user_id = NEW.user_id AND library_id = NEW.library_id
       AND status = 'active' AND COALESCE(is_restricted, false) IS TRUE
  ) THEN
    RAISE EXCEPTION 'Leitor(a) com restrição local nesta biblioteca. Reserva bloqueada.'
      USING ERRCODE = 'P0001', HINT = 'error.borrower.restricted_local';
  END IF;

  RETURN NEW;
END;
$fn$;
REVOKE EXECUTE ON FUNCTION public.fn_trg_block_acquisition_if_restricted_reserva() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_block_acquisition_if_restricted ON public.reservas_v2;
CREATE TRIGGER trg_block_acquisition_if_restricted
  BEFORE INSERT ON public.reservas_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_block_acquisition_if_restricted_reserva();

-- ── Vérification (RAISE EXCEPTION => rollback de la migration) ───────────────
DO $verify$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'trg_block_acquisition_if_restricted'
       AND tgrelid = 'public.emprestimos_v2'::regclass AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION '[EA-10] trigger emprunt absent';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgname = 'trg_block_acquisition_if_restricted'
       AND tgrelid = 'public.reservas_v2'::regclass AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION '[EA-10] trigger réservation absent';
  END IF;
  RAISE NOTICE '[EA-10] enforcement OK : gel global + restriction locale bloquent emprunt et réservation à l''INSERT.';
END
$verify$;
