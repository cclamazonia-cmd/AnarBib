-- ════════════════════════════════════════════════════════════════════════════
-- VALID — Validation physique — C3 : notification staff « compte en attente »
-- Auteur  : Claude (Opus)
-- Session : MULTI P5 (frontend) — volet VALID-C1..C4
-- Date    : 2026-06-10 (UTC)
-- Registre: §9 VALID (spec-validation-physique v1.1, VALID-C3) ; complète §20 MULTI
--
-- Au moment où une lectrice demande son inscription (request_membership crée une
-- appartenance `pending_validation`), on émet l'événement
-- `membership_validation_requested` via fn_dispatch_notify_event. L'Edge Function
-- notify-event le route vers handleMembershipValidationRequested, qui prévient la
-- biblio (e-mail à l'adresse de contact) qu'une demande attend validation — pour
-- que le vetting humain (vraie personne ? camarade ?) se fasse promptement.
--
-- C'est le pendant « staff » de validation_confirmed (P4b, pendant « lectrice »).
-- Best-effort : dispatch wrappé, ne fait jamais échouer l'inscription. Définition
-- reprise à l'identique de la P4 (20260608154320) + le seul PERFORM ajouté avant
-- le RETURN (couvre les deux branches : réactivation ET insertion → v_id posé).
-- ════════════════════════════════════════════════════════════════════════════

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

  SELECT m.id, m.status INTO v_existing
  FROM public.user_library_memberships m
  WHERE m.user_id = v_user AND m.library_id = p_library_id AND m.role = 'reader'
  LIMIT 1;

  IF v_existing.id IS NOT NULL AND v_existing.status IN
     ('active', 'pending_validation', 'pending_removal', 'suspended', 'left_with_pending_circulation') THEN
    RETURN QUERY SELECT false, v_existing.id, v_existing.status,
      'Você já tem uma associação com esta biblioteca.'::text;
    RETURN;
  END IF;

  SELECT count(*) FILTER (WHERE m.status <> 'removed'),
         count(*) FILTER (WHERE m.status = 'active')
    INTO v_total, v_validated
  FROM public.user_library_memberships m WHERE m.user_id = v_user;

  IF v_total > 0 AND v_validated = 0 THEN
    RAISE EXCEPTION 'Valide ao menos uma associação existente antes de solicitar uma nova.'
      USING errcode = 'P0001', hint = 'error.membership.beta1_guard';
  END IF;

  v_is_primary := (v_total = 0);

  IF v_existing.id IS NOT NULL THEN
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

  -- VALID-C3 : prévenir la biblio qu'une demande attend validation (best-effort).
  BEGIN
    PERFORM public.fn_dispatch_notify_event(
      'membership_validation_requested',
      1,
      jsonb_build_object(
        'user_id', v_user::text,
        'library_id', p_library_id::text,
        'membership_id', v_id::text
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'membership_validation_requested dispatch failed for membership %: %', v_id, SQLERRM;
  END;

  RETURN QUERY SELECT true, v_id, 'pending_validation'::text,
    format('Solicitação enviada a %s. Aguardando validação da equipe.', v_lib.name);
END $function$;

REVOKE EXECUTE ON FUNCTION api.request_membership(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.request_membership(uuid) TO authenticated;
