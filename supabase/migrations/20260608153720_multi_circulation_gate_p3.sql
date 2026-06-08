-- ════════════════════════════════════════════════════════════════════════════
-- MULTI — Multi-appartenance lecteur — Phase 3 : conditions de circulation
-- Auteur  : Claude (Opus)
-- Session : MULTI P3 (gate de circulation)
-- Date    : 2026-06-08 (UTC)
-- Registre: §20 MULTI (MULTI-F.1, spec §4) ; #CL.10
--
-- Gate des conditions d'engagement de circulation, PAR APPARTENANCE. Implémenté
-- via un trigger BEFORE INSERT sur les tables d'en-tête `emprestimos_v2` et
-- `consultas_locais_v2` (et NON inline dans les RPC : additif, zéro réécriture des
-- ~250 lignes, couvre TOUS les chemins — emprunt direct + résa→retrait). Le PEB
-- (`interlibrary_loans_v2`) est une table distincte, non touchée.
--
-- Conditions vérifiées (spec §4 / MULTI-F.1) :
--   1. appartenance `active` à la biblio        ┐  (2 ≡ 1 : dans le modèle actuel,
--   2. validation physique                       │   status='active' EST l'état validé ;
--   3. pas de restriction                        │   physically_validated_at sert au flux
--   4. cotisation à jour (si requise)            ┘   d'audit P4, pas au gate)
--   5. plafonds — DIFFÉRÉ (aucune config de plafonds en base à ce jour)
--
-- Sûr : vérifié — 0 emprunt ouvert existant n'est hors-appartenance active. La RPC
-- lève déjà la cotisation en 1er (message détaillé) ; le trigger = filet complet.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Helper : NULL = autorisé ; sinon code de blocage ────────────────────────
CREATE OR REPLACE FUNCTION public.fn_membership_can_engage_circulation(
  p_user_id uuid, p_library_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF p_user_id IS NULL OR p_library_id IS NULL THEN
    RETURN NULL;  -- données incomplètes : laisser les autres contraintes décider
  END IF;

  -- 1. appartenance active (≡ condition 2 dans le modèle actuel)
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id AND library_id = p_library_id AND status = 'active'
  ) THEN
    RETURN 'no_active_membership';
  END IF;

  -- 3. pas de restriction sur une appartenance active à cette biblio
  IF EXISTS (
    SELECT 1 FROM public.user_library_memberships
    WHERE user_id = p_user_id AND library_id = p_library_id
      AND status = 'active' AND is_restricted = true
  ) THEN
    RETURN 'restricted';
  END IF;

  -- 4. cotisation à jour si la biblio l'exige
  IF public.fn_is_loan_blocked_by_dues(p_user_id, p_library_id) THEN
    RETURN 'dues';
  END IF;

  RETURN NULL;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_membership_can_engage_circulation(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_membership_can_engage_circulation(uuid, uuid) TO authenticated;

-- ── Trigger : applique le gate sur tout insert d'en-tête de circulation ─────
CREATE OR REPLACE FUNCTION public.fn_enforce_membership_circulation_gate()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_block text;
BEGIN
  v_block := public.fn_membership_can_engage_circulation(NEW.user_id, NEW.library_id);

  IF v_block = 'no_active_membership' THEN
    RAISE EXCEPTION 'Este(a) leitor(a) não é membro ativo desta biblioteca.'
      USING errcode = 'P0001', hint = 'error.membership.not_active';
  ELSIF v_block = 'restricted' THEN
    RAISE EXCEPTION 'Este(a) leitor(a) está com restrição nesta biblioteca.'
      USING errcode = 'P0001', hint = 'error.membership.restricted';
  ELSIF v_block = 'dues' THEN
    -- Filet : les RPC lèvent déjà la cotisation en 1er avec un message détaillé.
    RAISE EXCEPTION 'Contribuição obrigatória não está em dia para este(a) leitor(a).'
      USING errcode = 'P0001', hint = 'error.membership.dues';
  END IF;

  RETURN NEW;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_enforce_membership_circulation_gate() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_enforce_membership_gate_emprestimos ON public.emprestimos_v2;
CREATE TRIGGER trg_enforce_membership_gate_emprestimos
  BEFORE INSERT ON public.emprestimos_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_enforce_membership_circulation_gate();

DROP TRIGGER IF EXISTS trg_enforce_membership_gate_consultas ON public.consultas_locais_v2;
CREATE TRIGGER trg_enforce_membership_gate_consultas
  BEFORE INSERT ON public.consultas_locais_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_enforce_membership_circulation_gate();
