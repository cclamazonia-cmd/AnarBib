-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — P2 : RPC de cycle de vie du partenariat stabilisé
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-10 (UTC)
-- Registre: §21 PARTNER (PARTNER-D7 cycle de vie ; D2/D9 droits ; D8 config_version)
--
-- OBJET : propose / accept / refuse / break + set_right. « Deux pour s'unir, un
-- seul pour partir » (D7) : proposition + acceptation requises pour activer,
-- rupture unilatérale. Réservé au staff de coordination (user_can_engage_library
-- = admin réseau OU coordenador).
--
-- SECURITY DEFINER (et non INVOKER comme les RPC déclaratives) : ces RPC écrivent
-- la ligne RÉCIPROQUE (library_id du partenaire) et les tables partnership_rights
-- / partnership_break_log (sans policy d'écriture). L'autorisation est faite
-- EXPLICITEMENT en tête de chaque fonction.
--
-- La symétrie statut+droits entre {A→B} et {B→A} est garantie par les triggers P1.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1. PROPOSE — un·e coordenador de A propose un partenariat à B ───────────
CREATE OR REPLACE FUNCTION public.fn_partnership_propose(
  p_library_id         uuid,
  p_partner_library_id uuid
)
RETURNS public.library_partnerships
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_row    public.library_partnerships;
  v_status text;
BEGIN
  IF NOT public.user_can_engage_library(p_library_id) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação da biblioteca.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;
  IF p_partner_library_id IS NULL OR p_partner_library_id = p_library_id THEN
    RAISE EXCEPTION 'Parceiro inválido.' USING HINT = 'error.partnership.invalid_target';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = p_partner_library_id) THEN
    RAISE EXCEPTION 'Biblioteca parceira inexistente.' USING HINT = 'error.partnership.partner_not_found';
  END IF;

  -- Si la réciproque {B→A} est déjà 'proposed', il faut ACCEPTER, pas re-proposer.
  IF EXISTS (SELECT 1 FROM public.library_partnerships
             WHERE library_id = p_partner_library_id AND partner_library_id = p_library_id
               AND status = 'proposed') THEN
    RAISE EXCEPTION 'A biblioteca parceira já propôs : utilize aceitar.'
      USING HINT = 'error.partnership.use_accept';
  END IF;

  SELECT status INTO v_status FROM public.library_partnerships
   WHERE library_id = p_library_id AND partner_library_id = p_partner_library_id;

  IF v_status IN ('proposed','active') THEN
    RAISE EXCEPTION 'Parceria já em curso ou ativa.' USING HINT = 'error.partnership.already';
  ELSIF v_status IS NULL THEN
    INSERT INTO public.library_partnerships
      (library_id, partner_library_id, status, proposed_by, proposed_at, created_by)
    VALUES (p_library_id, p_partner_library_id, 'proposed', auth.uid(), now(), auth.uid())
    RETURNING * INTO v_row;
  ELSE  -- 'declared' | 'refused' | 'broken' → (re)proposer
    UPDATE public.library_partnerships
       SET status = 'proposed', proposed_by = auth.uid(), proposed_at = now(),
           responded_by = NULL, responded_at = NULL, broken_by = NULL, broken_at = NULL, broken_reason = NULL
     WHERE library_id = p_library_id AND partner_library_id = p_partner_library_id
    RETURNING * INTO v_row;
  END IF;

  RETURN v_row;
END $function$;

-- ── 2. ACCEPT — un·e coordenador de B accepte la proposition {A→B} ──────────
CREATE OR REPLACE FUNCTION public.fn_partnership_accept(p_partnership_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_a uuid;  -- proposeur (library_id de la ligne proposée)
  v_b uuid;  -- partenaire qui accepte (partner_library_id)
  v_status text;
BEGIN
  SELECT library_id, partner_library_id, status INTO v_a, v_b, v_status
    FROM public.library_partnerships WHERE id = p_partnership_id;

  IF v_a IS NULL THEN
    RAISE EXCEPTION 'Parceria inexistente.' USING HINT = 'error.partnership.not_found';
  END IF;
  IF v_status <> 'proposed' THEN
    RAISE EXCEPTION 'Esta parceria não está pendente.' USING HINT = 'error.partnership.not_pending';
  END IF;
  -- Seul le partenaire sollicité (B) accepte.
  IF NOT public.user_can_engage_library(v_b) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação da biblioteca parceira.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  -- Créer/relever la ligne réciproque {B→A} en 'active'.
  IF EXISTS (SELECT 1 FROM public.library_partnerships
             WHERE library_id = v_b AND partner_library_id = v_a) THEN
    UPDATE public.library_partnerships
       SET status = 'active', responded_by = auth.uid(), responded_at = now(),
           broken_by = NULL, broken_at = NULL, broken_reason = NULL
     WHERE library_id = v_b AND partner_library_id = v_a;
  ELSE
    INSERT INTO public.library_partnerships
      (library_id, partner_library_id, status, responded_by, responded_at, created_by)
    VALUES (v_b, v_a, 'active', auth.uid(), now(), auth.uid());
  END IF;

  -- Activer la ligne proposée {A→B} (le trigger de symétrie garde l'égalité).
  UPDATE public.library_partnerships
     SET status = 'active', responded_by = auth.uid(), responded_at = now()
   WHERE id = p_partnership_id;
END $function$;

-- ── 3. REFUSE — un·e coordenador de B refuse la proposition {A→B} ───────────
CREATE OR REPLACE FUNCTION public.fn_partnership_refuse(p_partnership_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_b uuid; v_status text;
BEGIN
  SELECT partner_library_id, status INTO v_b, v_status
    FROM public.library_partnerships WHERE id = p_partnership_id;
  IF v_b IS NULL THEN
    RAISE EXCEPTION 'Parceria inexistente.' USING HINT = 'error.partnership.not_found';
  END IF;
  IF v_status <> 'proposed' THEN
    RAISE EXCEPTION 'Esta parceria não está pendente.' USING HINT = 'error.partnership.not_pending';
  END IF;
  IF NOT public.user_can_engage_library(v_b) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação da biblioteca parceira.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  UPDATE public.library_partnerships
     SET status = 'refused', responded_by = auth.uid(), responded_at = now()
   WHERE id = p_partnership_id;
END $function$;

-- ── 4. BREAK — rupture unilatérale (A OU B), ferme les deux côtés + journal ──
CREATE OR REPLACE FUNCTION public.fn_partnership_break(
  p_partnership_id uuid,
  p_reason         text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_a uuid; v_b uuid; v_status text;
BEGIN
  SELECT library_id, partner_library_id, status INTO v_a, v_b, v_status
    FROM public.library_partnerships WHERE id = p_partnership_id;
  IF v_a IS NULL OR v_b IS NULL THEN
    RAISE EXCEPTION 'Parceria inexistente.' USING HINT = 'error.partnership.not_found';
  END IF;
  IF v_status <> 'active' THEN
    RAISE EXCEPTION 'Apenas uma parceria ativa pode ser rompida.' USING HINT = 'error.partnership.not_active';
  END IF;
  -- Rupture unilatérale : la coordination de l'UNE des deux biblios suffit (D7).
  IF NOT (public.user_can_engage_library(v_a) OR public.user_can_engage_library(v_b)) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação de uma das bibliotecas.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  -- Fermer les deux directions (le trigger propage le statut, mais on horodate les deux).
  UPDATE public.library_partnerships
     SET status = 'broken', broken_by = auth.uid(), broken_at = now(),
         broken_reason = NULLIF(btrim(p_reason), '')
   WHERE (library_id = v_a AND partner_library_id = v_b)
      OR (library_id = v_b AND partner_library_id = v_a);

  -- Sans résidu : retirer les droits actifs des deux côtés (D5).
  DELETE FROM public.partnership_rights pr
   USING public.library_partnerships lp
   WHERE pr.partnership_id = lp.id
     AND ((lp.library_id = v_a AND lp.partner_library_id = v_b)
       OR (lp.library_id = v_b AND lp.partner_library_id = v_a));

  -- Journal immuable de la rupture (D5).
  INSERT INTO public.partnership_break_log
    (partnership_id, library_id, partner_library_id, broken_by, reason)
  VALUES (p_partnership_id, v_a, v_b, auth.uid(), NULLIF(btrim(p_reason), ''));
END $function$;

-- ── 5. SET_RIGHT — activer/désactiver un droit (cases réciproques, D2/D9) ────
CREATE OR REPLACE FUNCTION public.fn_partnership_set_right(
  p_partnership_id uuid,
  p_right_key      text,
  p_enabled        boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_a uuid; v_b uuid; v_status text; v_existe boolean;
BEGIN
  SELECT library_id, partner_library_id, status INTO v_a, v_b, v_status
    FROM public.library_partnerships WHERE id = p_partnership_id;
  IF v_a IS NULL OR v_b IS NULL THEN
    RAISE EXCEPTION 'Parceria inexistente.' USING HINT = 'error.partnership.not_found';
  END IF;
  IF v_status <> 'active' THEN
    RAISE EXCEPTION 'Os direitos só podem ser ajustados numa parceria ativa.'
      USING HINT = 'error.partnership.not_active';
  END IF;
  IF p_right_key NOT IN ('transparence','digital_share','mutualisation','peb') THEN
    RAISE EXCEPTION 'Direito desconhecido.' USING HINT = 'error.partnership.unknown_right';
  END IF;
  IF NOT (public.user_can_engage_library(v_a) OR public.user_can_engage_library(v_b)) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação de uma das bibliotecas.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  IF p_enabled THEN
    v_existe := EXISTS (SELECT 1 FROM public.partnership_rights
                        WHERE partnership_id = p_partnership_id AND right_key = p_right_key);
    -- Insert sur la direction courante ; le trigger réplique sur la réciproque.
    INSERT INTO public.partnership_rights (partnership_id, right_key, granted_by)
      VALUES (p_partnership_id, p_right_key, auth.uid())
    ON CONFLICT (partnership_id, right_key) DO NOTHING;
    -- AJOUT d'un droit = la config s'élargit → bump config_version des deux côtés
    -- (invalide le consentement lectrice, re-sollicitation « vers le haut », D8).
    IF NOT v_existe THEN
      UPDATE public.library_partnerships
         SET config_version = config_version + 1
       WHERE (library_id = v_a AND partner_library_id = v_b)
          OR (library_id = v_b AND partner_library_id = v_a);
    END IF;
  ELSE
    -- RETRAIT : la config se restreint → consentement maintenu, pas de bump (D8).
    DELETE FROM public.partnership_rights
     WHERE partnership_id = p_partnership_id AND right_key = p_right_key;
  END IF;
END $function$;

-- ── Droits d'exécution : pas de PUBLIC/anon ; authenticated (garde interne) ──
REVOKE EXECUTE ON FUNCTION public.fn_partnership_propose(uuid, uuid)            FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_accept(uuid)                   FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_refuse(uuid)                   FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_break(uuid, text)              FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_set_right(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_partnership_propose(uuid, uuid)            TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_partnership_accept(uuid)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_partnership_refuse(uuid)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_partnership_break(uuid, text)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_partnership_set_right(uuid, text, boolean) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
