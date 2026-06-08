-- ════════════════════════════════════════════════════════════════════════════
-- MULTI — Multi-appartenance lecteur — Phase 4 : auto-inscription + validation
-- Auteur  : Claude (Opus)
-- Session : MULTI P4 (auto-inscription)
-- Date    : 2026-06-08 (UTC)
-- Registre: §20 MULTI (MULTI-β.1, spec §8) ; #CL.10
--
-- Deux RPC :
--  - api.request_membership(library) : auto-inscription lecteur·rice. Crée une
--    appartenance `pending_validation`. **Garde β.1** (spec §8) : la 1re inscription
--    est libre ; toute inscription supplémentaire exige ≥1 appartenance déjà
--    validée (active) — protège contre l'inscription parallèle malveillante.
--    Gate : `libraries.accepts_public_signup` + `is_active`.
--  - api.validate_membership(membership, num, note) : validation STAFF (librarian/
--    coordenador de la biblio) → `active` + validation par-appartenance + numéro
--    lecteur local + journal `membership_validation_log`.
--
-- (La notification `validation_confirmed` est différée — elle requiert un handler
-- notify-event/EF dédié, hors d'une migration SQL ; ticket de suivi P4b.)
-- ════════════════════════════════════════════════════════════════════════════

-- ── Auto-inscription (garde β.1) ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.request_membership(p_library_id uuid)
RETURNS TABLE (ok boolean, membership_id uuid, status text, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_user uuid := auth.uid();
  v_lib  record;
  v_existing record;
  v_total integer;
  v_validated integer;
  v_is_primary boolean;
  v_id uuid;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT l.id, l.is_active, l.accepts_public_signup, COALESCE(l.short_name, l.name) AS name
    INTO v_lib
  FROM public.libraries l WHERE l.id = p_library_id;

  IF NOT FOUND OR NOT v_lib.is_active THEN
    RAISE EXCEPTION 'Biblioteca indisponível.'
      USING errcode = 'P0001', hint = 'error.membership.library_unavailable';
  END IF;
  IF NOT COALESCE(v_lib.accepts_public_signup, false) THEN
    RAISE EXCEPTION 'Esta biblioteca não aceita inscrições públicas no momento.'
      USING errcode = 'P0001', hint = 'error.membership.no_public_signup';
  END IF;

  -- Appartenance lecteur·rice existante à cette biblio (la clé unique est
  -- (user, library, role) — on réactive une appartenance terminée plutôt que
  -- d'en insérer une seconde).
  SELECT m.id, m.status INTO v_existing
  FROM public.user_library_memberships m
  WHERE m.user_id = v_user AND m.library_id = p_library_id AND m.role = 'reader'
  LIMIT 1;

  -- NB : ne PAS se fier à FOUND ici — la requête count(*) plus bas le réinitialise.
  IF v_existing.id IS NOT NULL AND v_existing.status IN
     ('active', 'pending_validation', 'pending_removal', 'suspended', 'left_with_pending_circulation') THEN
    RETURN QUERY SELECT false, v_existing.id, v_existing.status,
      'Você já tem uma associação com esta biblioteca.'::text;
    RETURN;
  END IF;

  -- Garde β.1 : 1re inscription libre ; suivantes exigent ≥1 appartenance active.
  SELECT count(*) FILTER (WHERE m.status <> 'removed'),
         count(*) FILTER (WHERE m.status = 'active')
    INTO v_total, v_validated
  FROM public.user_library_memberships m WHERE m.user_id = v_user;

  IF v_total > 0 AND v_validated = 0 THEN
    RAISE EXCEPTION 'Valide ao menos uma associação existente antes de solicitar uma nova.'
      USING errcode = 'P0001', hint = 'error.membership.beta1_guard';
  END IF;

  v_is_primary := (v_total = 0);  -- la toute première appartenance devient primaire

  IF v_existing.id IS NOT NULL THEN
    -- réactivation d'une appartenance terminée (removed/terminated/inactive)
    UPDATE public.user_library_memberships
      SET status = 'pending_validation', is_primary = v_is_primary, updated_at = now()
      WHERE id = v_existing.id;
    v_id := v_existing.id;
  ELSE
    INSERT INTO public.user_library_memberships
      (user_id, library_id, role, status, is_primary, created_at, updated_at)
    VALUES (v_user, p_library_id, 'reader', 'pending_validation', v_is_primary, now(), now())
    RETURNING id INTO v_id;
  END IF;

  RETURN QUERY SELECT true, v_id, 'pending_validation'::text,
    format('Solicitação enviada a %s. Aguardando validação da equipe.', v_lib.name);
END $function$;

REVOKE EXECUTE ON FUNCTION api.request_membership(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.request_membership(uuid) TO authenticated;

-- ── Validation staff ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION api.validate_membership(
  p_membership_id uuid,
  p_local_reader_number text DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS TABLE (ok boolean, message text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_m record;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  SELECT m.id, m.user_id, m.library_id, m.status INTO v_m
  FROM public.user_library_memberships m WHERE m.id = p_membership_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Associação não encontrada.';
  END IF;

  -- Staff actif (librarian/coordenador) de CETTE biblio.
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships s
    WHERE s.user_id = v_caller AND s.library_id = v_m.library_id
      AND s.role IN ('librarian', 'coordenador') AND s.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Acesso de equipe obrigatório nesta biblioteca.'
      USING errcode = 'P0001', hint = 'error.staff_required';
  END IF;

  IF v_m.status <> 'pending_validation' THEN
    RAISE EXCEPTION 'Esta associação não está pendente de validação.'
      USING errcode = 'P0001', hint = 'error.membership.not_pending';
  END IF;

  UPDATE public.user_library_memberships
    SET status = 'active',
        physically_validated_at = now(),
        physically_validated_by_user_id = v_caller,
        physical_validation_note = p_note,
        local_reader_number = COALESCE(p_local_reader_number, local_reader_number),
        updated_at = now()
    WHERE id = p_membership_id;

  INSERT INTO public.membership_validation_log
    (membership_id, user_id, library_id, action, performed_by_user_id, local_reader_number, note)
  VALUES
    (p_membership_id, v_m.user_id, v_m.library_id, 'validated', v_caller, p_local_reader_number, p_note);

  RETURN QUERY SELECT true, 'Associação validada.'::text;
END $function$;

REVOKE EXECUTE ON FUNCTION api.validate_membership(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.validate_membership(uuid, text, text) TO authenticated;
