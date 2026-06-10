-- ════════════════════════════════════════════════════════════════════════════
-- MULTI-F.1 condition 5 — Plafonds de circulation simultanée (par biblio, par mode)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
-- Registre: §20 MULTI (MULTI-F.1 cond. 5, spec §4) ; #CL.10
--
-- OBJET : 5ᵉ et dernière condition de la porte de circulation (P3 en a livré 4).
-- Plafonne le nombre d'engagements SIMULTANÉS d'un·e lecteur·rice dans une biblio,
-- séparément pour 3 modes : emprunts, réservations, consultations sur place.
--
-- DOCTRINE (REGISTRE §20, MULTI-C.1..C.4) : strictement PAR BIBLIO, aucun cumul
-- ni transfert entre appartenances. Décision Xavier : 3 plafonds distincts,
-- configurés au niveau du JEU DE RÈGLES (library_circulation_policy_sets).
--
-- DESIGN : 3 colonnes nullable sur le jeu de règles (NULL = illimité). Un trigger
-- BEFORE INSERT dédié AU PLAFOND (séparé du gate membership P3, pour ne PAS
-- ajouter par effet de bord les conditions 1-4 sur reservas_v2) compte les
-- engagements actifs du mode et bloque si le plafond du jeu ACTIF est atteint.
-- Lecture directe sur le jeu actif : ne touche NI le résolveur api.resolve_*
-- (290 lignes, hors-migration) NI le moteur de règles.
-- ════════════════════════════════════════════════════════════════════════════

-- ── 1. Config : 3 plafonds sur le jeu de règles (NULL = illimité) ───────────
ALTER TABLE public.library_circulation_policy_sets
  ADD COLUMN IF NOT EXISTS max_concurrent_loans         integer,
  ADD COLUMN IF NOT EXISTS max_concurrent_reservations  integer,
  ADD COLUMN IF NOT EXISTS max_concurrent_consultations integer;

ALTER TABLE public.library_circulation_policy_sets
  DROP CONSTRAINT IF EXISTS chk_max_concurrent_loans,
  DROP CONSTRAINT IF EXISTS chk_max_concurrent_reservations,
  DROP CONSTRAINT IF EXISTS chk_max_concurrent_consultations;
ALTER TABLE public.library_circulation_policy_sets
  ADD CONSTRAINT chk_max_concurrent_loans         CHECK (max_concurrent_loans         IS NULL OR max_concurrent_loans         >= 0),
  ADD CONSTRAINT chk_max_concurrent_reservations  CHECK (max_concurrent_reservations  IS NULL OR max_concurrent_reservations  >= 0),
  ADD CONSTRAINT chk_max_concurrent_consultations CHECK (max_concurrent_consultations IS NULL OR max_concurrent_consultations >= 0);

COMMENT ON COLUMN public.library_circulation_policy_sets.max_concurrent_loans IS
  'Plafond d''emprunts simultanés actifs par lecteur·rice dans cette biblio (NULL = illimité). MULTI-F.1 cond.5.';
COMMENT ON COLUMN public.library_circulation_policy_sets.max_concurrent_reservations IS
  'Plafond de réservations actives simultanées par lecteur·rice (NULL = illimité). MULTI-F.1 cond.5.';
COMMENT ON COLUMN public.library_circulation_policy_sets.max_concurrent_consultations IS
  'Plafond de consultations sur place en cours par lecteur·rice (NULL = illimité). MULTI-F.1 cond.5.';

-- ── 2. Helper : plafond du mode pour le jeu ACTIF d'une biblio ──────────────
CREATE OR REPLACE FUNCTION public.fn_circulation_concurrent_max(p_library_id uuid, p_mode text)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT CASE p_mode
           WHEN 'loan'               THEN s.max_concurrent_loans
           WHEN 'reservation'        THEN s.max_concurrent_reservations
           WHEN 'local_consultation' THEN s.max_concurrent_consultations
         END
  FROM public.library_circulation_policy_sets s
  WHERE s.library_id = p_library_id AND s.is_active = true
  ORDER BY s.id DESC
  LIMIT 1;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_circulation_concurrent_max(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_circulation_concurrent_max(uuid, text) TO authenticated;

-- ── 3. Trigger : applique le plafond du mode (déduit de la table) ───────────
CREATE OR REPLACE FUNCTION public.fn_enforce_circulation_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_mode  text;
  v_max   integer;
  v_count integer;
BEGIN
  IF NEW.user_id IS NULL OR NEW.library_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_mode := CASE TG_TABLE_NAME
              WHEN 'emprestimos_v2'     THEN 'loan'
              WHEN 'reservas_v2'        THEN 'reservation'
              WHEN 'consultas_locais_v2' THEN 'local_consultation'
            END;
  IF v_mode IS NULL THEN
    RETURN NEW;
  END IF;

  v_max := public.fn_circulation_concurrent_max(NEW.library_id, v_mode);
  IF v_max IS NULL THEN
    RETURN NEW;  -- aucun plafond configuré = illimité
  END IF;

  IF TG_TABLE_NAME = 'emprestimos_v2' THEN
    SELECT count(*) INTO v_count FROM public.emprestimos_v2
     WHERE user_id = NEW.user_id AND library_id = NEW.library_id
       AND status_global IN ('aberto', 'parcialmente_devolvido')
       AND archived_at IS NULL;
  ELSIF TG_TABLE_NAME = 'reservas_v2' THEN
    SELECT count(*) INTO v_count FROM public.reservas_v2
     WHERE user_id = NEW.user_id AND library_id = NEW.library_id
       AND status_global IN ('ativa', 'parcialmente_encerrada')
       AND archived_at IS NULL;
  ELSE
    SELECT count(*) INTO v_count FROM public.consultas_locais_v2
     WHERE user_id = NEW.user_id AND library_id = NEW.library_id
       AND status_global IN ('ativa', 'parcialmente_encerrada')
       AND archived_at IS NULL;
  END IF;

  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Limite de circulação simultânea atingido nesta biblioteca.'
      USING errcode = 'P0001', hint = 'error.circulation.limit_reached';
  END IF;

  RETURN NEW;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_enforce_circulation_limit() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_enforce_circulation_limit_emprestimos ON public.emprestimos_v2;
CREATE TRIGGER trg_enforce_circulation_limit_emprestimos
  BEFORE INSERT ON public.emprestimos_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_enforce_circulation_limit();

DROP TRIGGER IF EXISTS trg_enforce_circulation_limit_reservas ON public.reservas_v2;
CREATE TRIGGER trg_enforce_circulation_limit_reservas
  BEFORE INSERT ON public.reservas_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_enforce_circulation_limit();

DROP TRIGGER IF EXISTS trg_enforce_circulation_limit_consultas ON public.consultas_locais_v2;
CREATE TRIGGER trg_enforce_circulation_limit_consultas
  BEFORE INSERT ON public.consultas_locais_v2
  FOR EACH ROW EXECUTE FUNCTION public.fn_enforce_circulation_limit();

-- ── 4. RPC de configuration (staff) — pose les 3 plafonds d'un jeu de règles ─
-- Les 3 valeurs sont posées ensemble (NULL = effacer le plafond = illimité).
CREATE OR REPLACE FUNCTION public.fn_set_circulation_limits(
  p_policy_set_id     bigint,
  p_max_loans         integer DEFAULT NULL,
  p_max_reservations  integer DEFAULT NULL,
  p_max_consultations integer DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_library_id uuid;
BEGIN
  SELECT library_id INTO v_library_id
    FROM public.library_circulation_policy_sets WHERE id = p_policy_set_id;
  IF v_library_id IS NULL THEN
    RAISE EXCEPTION 'Jeu de règles introuvable.' USING HINT = 'error.policy_set.not_found';
  END IF;

  IF NOT public.user_has_library_staff_role(auth.uid(), v_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff da biblioteca.' USING ERRCODE = '42501';
  END IF;

  IF (p_max_loans         IS NOT NULL AND p_max_loans         < 0)
   OR (p_max_reservations  IS NOT NULL AND p_max_reservations  < 0)
   OR (p_max_consultations IS NOT NULL AND p_max_consultations < 0) THEN
    RAISE EXCEPTION 'Plafond invalide (doit être >= 0).' USING HINT = 'error.circulation.limit_invalid';
  END IF;

  UPDATE public.library_circulation_policy_sets
     SET max_concurrent_loans         = p_max_loans,
         max_concurrent_reservations  = p_max_reservations,
         max_concurrent_consultations = p_max_consultations
   WHERE id = p_policy_set_id;
END $function$;

REVOKE EXECUTE ON FUNCTION public.fn_set_circulation_limits(bigint, integer, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_set_circulation_limits(bigint, integer, integer, integer) TO authenticated;

NOTIFY pgrst, 'reload schema';
