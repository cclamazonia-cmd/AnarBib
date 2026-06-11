-- ════════════════════════════════════════════════════════════════════════════
-- §21 PARTNER — NOTIF-1 : émission des events de cycle de vie (→ coordenador)
-- Auteur  : Xavier + Claude
-- Session : Catalogação work completion
-- Date    : 2026-06-11 (UTC)
--
-- Les RPC P2 (propose/accept/refuse/break) n'émettaient AUCUNE notification.
-- Ici on ajoute `PERFORM fn_dispatch_notify_event(...)` aux bons endroits, avec
-- un payload uniforme {partnership_id, recipient_library_id, partner_library_id}
-- (record_id factice = 1 ; l'EF exige record_id > 0, la donnée utile vit dans le
-- payload — même convention que validation_confirmed / cotisation_payment_recorded).
-- Destinataire = le CONTACT de la biblio `recipient_library_id` (résolu côté
-- notify-event via adminTarget). Rendu + i18n ×10 : handler partnership.ts.
--   propose  → recipient = partenaire sollicité ; partner = proposeur
--   accept   → recipient = proposeur          ; partner = accepteur
--   refuse   → recipient = proposeur          ; partner = refuseur
--   break    → DEUX émissions (chaque côté) ; message neutre, partner = l'autre
-- CREATE OR REPLACE : grants/exécution préservés.
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.fn_partnership_propose(p_library_id uuid, p_partner_library_id uuid)
RETURNS library_partnerships
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
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
  ELSE
    UPDATE public.library_partnerships
       SET status = 'proposed', proposed_by = auth.uid(), proposed_at = now(),
           responded_by = NULL, responded_at = NULL, broken_by = NULL, broken_at = NULL, broken_reason = NULL
     WHERE library_id = p_library_id AND partner_library_id = p_partner_library_id
    RETURNING * INTO v_row;
  END IF;

  PERFORM public.fn_dispatch_notify_event('partnership_proposed', 1, jsonb_build_object(
    'partnership_id', v_row.id::text,
    'recipient_library_id', p_partner_library_id::text,
    'partner_library_id', p_library_id::text));

  RETURN v_row;
END $function$;

CREATE OR REPLACE FUNCTION public.fn_partnership_accept(p_partnership_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
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
  IF NOT public.user_can_engage_library(v_b) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação da biblioteca parceira.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

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

  UPDATE public.library_partnerships
     SET status = 'active', responded_by = auth.uid(), responded_at = now()
   WHERE id = p_partnership_id;

  PERFORM public.fn_dispatch_notify_event('partnership_accepted', 1, jsonb_build_object(
    'partnership_id', p_partnership_id::text,
    'recipient_library_id', v_a::text,
    'partner_library_id', v_b::text));
END $function$;

CREATE OR REPLACE FUNCTION public.fn_partnership_refuse(p_partnership_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_a uuid; v_b uuid; v_status text;
BEGIN
  SELECT library_id, partner_library_id, status INTO v_a, v_b, v_status
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

  PERFORM public.fn_dispatch_notify_event('partnership_refused', 1, jsonb_build_object(
    'partnership_id', p_partnership_id::text,
    'recipient_library_id', v_a::text,
    'partner_library_id', v_b::text));
END $function$;

CREATE OR REPLACE FUNCTION public.fn_partnership_break(p_partnership_id uuid, p_reason text DEFAULT NULL::text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
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
  IF NOT (public.user_can_engage_library(v_a) OR public.user_can_engage_library(v_b)) THEN
    RAISE EXCEPTION 'Acesso restrito à coordenação de uma das bibliotecas.'
      USING ERRCODE = '42501', HINT = 'error.partnership.forbidden';
  END IF;

  UPDATE public.library_partnerships
     SET status = 'broken', broken_by = auth.uid(), broken_at = now(),
         broken_reason = NULLIF(btrim(p_reason), '')
   WHERE (library_id = v_a AND partner_library_id = v_b)
      OR (library_id = v_b AND partner_library_id = v_a);

  DELETE FROM public.partnership_rights pr
   USING public.library_partnerships lp
   WHERE pr.partnership_id = lp.id
     AND ((lp.library_id = v_a AND lp.partner_library_id = v_b)
       OR (lp.library_id = v_b AND lp.partner_library_id = v_a));

  INSERT INTO public.partnership_break_log
    (partnership_id, library_id, partner_library_id, broken_by, reason)
  VALUES (p_partnership_id, v_a, v_b, auth.uid(), NULLIF(btrim(p_reason), ''));

  -- Notifie LES DEUX côtés (message neutre : partner = l'autre biblio).
  PERFORM public.fn_dispatch_notify_event('partnership_broken', 1, jsonb_build_object(
    'partnership_id', p_partnership_id::text, 'recipient_library_id', v_a::text, 'partner_library_id', v_b::text));
  PERFORM public.fn_dispatch_notify_event('partnership_broken', 1, jsonb_build_object(
    'partnership_id', p_partnership_id::text, 'recipient_library_id', v_b::text, 'partner_library_id', v_a::text));
END $function$;

NOTIFY pgrst, 'reload schema';
