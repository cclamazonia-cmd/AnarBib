-- ════════════════════════════════════════════════════════════════════════════
-- MULTI — Multi-appartenance lecteur — P4b : notification « inscription validée »
-- Auteur  : Claude (Opus)
-- Session : MULTI P5 (frontend) — volet notification validation
-- Date    : 2026-06-09 (UTC)
-- Registre: §20 MULTI (spec §8) — complète P4 (api.validate_membership)
--
-- Au moment où le staff valide une inscription (validate_membership → active),
-- on émet l'événement `validation_confirmed` via fn_dispatch_notify_event (même
-- mécanisme pg_net que cotisation_payment_recorded / member_restricted_local).
-- L'Edge Function notify-event le route vers handleValidationConfirmed, qui
-- envoie à la lectrice l'e-mail « ton inscription à <biblio> est confirmée ».
--
-- record_id factice = 1 (l'EF exige record_id > 0) ; la donnée utile vit dans
-- le payload (user_id, library_id, membership_id). On reprend à l'identique la
-- définition P4 (20260608154320) en n'ajoutant QUE le PERFORM de dispatch après
-- l'insertion au journal, juste avant le RETURN.
-- ════════════════════════════════════════════════════════════════════════════

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

  -- P4b : notifier la lectrice (e-mail « inscription confirmée »). Best-effort —
  -- on ne fait pas échouer la validation si le dispatch lève (la notif est
  -- secondaire). fn_dispatch_notify_event poste en async via pg_net.
  BEGIN
    PERFORM public.fn_dispatch_notify_event(
      'validation_confirmed',
      1,
      jsonb_build_object(
        'user_id', v_m.user_id::text,
        'library_id', v_m.library_id::text,
        'membership_id', p_membership_id::text
      )
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'validation_confirmed dispatch failed for membership %: %', p_membership_id, SQLERRM;
  END;

  RETURN QUERY SELECT true, 'Associação validada.'::text;
END $function$;

REVOKE EXECUTE ON FUNCTION api.validate_membership(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.validate_membership(uuid, text, text) TO authenticated;
