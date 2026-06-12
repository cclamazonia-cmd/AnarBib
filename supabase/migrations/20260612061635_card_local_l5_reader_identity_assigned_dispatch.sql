-- ════════════════════════════════════════════════════════════════════════════
-- CARD-LOCAL — Lot 5 (N4) : dispatch « identité attribuée » (réconciliation)
-- Auteur  : Xavier + Claude
-- Session : Identité lecteur·rice locale (CARD-LOCAL §27)
-- Date    : 2026-06-12 (UTC)
--
-- DÉCISION REGISTRE §27 CARD-LOCAL-N4 : notif réconciliation à l'attribution
-- d'identité → lectrice + biblio ; DÉDUP avec validation_confirmed ; via
-- notify-event.
--
-- On rejoue (CREATE OR REPLACE) api.set_local_reader_identity (Lot 2) pour
-- émettre l'événement 'reader_identity_assigned' UNIQUEMENT quand :
--   • l'appartenance est DÉJÀ active (≠ pending_validation) → sinon l'identité
--     sera communiquée à la validation par validation_confirmed (DÉDUP), et
--   • la valeur posée est non nulle ET réellement changée (évite un e-mail sur
--     un effacement ou un enregistrement à l'identique).
-- L'Edge Function notify-event route 'reader_identity_assigned' vers
-- handleReaderIdentityAssigned (lectrice + copie biblio).
--
-- DOCTRINE : SECURITY DEFINER + search_path + REVOKE PUBLIC + GRANT authenticated
-- + NOTIFY pgrst. Dispatch best-effort (n'échoue jamais l'écriture de l'identité).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION api.set_local_reader_identity(
  p_user_id    uuid,
  p_library_id uuid,
  p_value      text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_value  text := nullif(btrim(coalesce(p_value, '')), '');
  v_mid    uuid;
  v_status text;
  v_old    text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  IF NOT public.user_can_act_as_staff_on_library(p_library_id) THEN
    RAISE EXCEPTION 'Acesso de equipe obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.staff_required';
  END IF;

  SELECT m.id, m.status, m.local_reader_number
    INTO v_mid, v_status, v_old
    FROM public.user_library_memberships m
   WHERE m.user_id = p_user_id
     AND m.library_id = p_library_id
     AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
   ORDER BY (m.status = 'active') DESC, m.created_at DESC
   LIMIT 1;

  IF v_mid IS NULL THEN
    RAISE EXCEPTION 'Pessoa não inscrita nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.cardLocal.noMembership';
  END IF;

  UPDATE public.user_library_memberships
     SET local_reader_number = v_value,
         updated_at = now()
   WHERE id = v_mid;

  -- CARD-LOCAL-N4 : e-mail de réconciliation, seulement hors validation (statut
  -- déjà active) et sur une vraie attribution (non nulle, changée). Best-effort.
  IF v_status = 'active' AND v_value IS NOT NULL AND v_value IS DISTINCT FROM v_old THEN
    BEGIN
      PERFORM public.fn_dispatch_notify_event(
        'reader_identity_assigned',
        1,
        jsonb_build_object(
          'user_id', p_user_id::text,
          'library_id', p_library_id::text,
          'membership_id', v_mid::text
        )
      );
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'reader_identity_assigned dispatch failed for membership %: %', v_mid, SQLERRM;
    END;
  END IF;

  RETURN v_value;
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.set_local_reader_identity(uuid, uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.set_local_reader_identity(uuid, uuid, text) TO authenticated;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'set_local_reader_identity'
  ) THEN
    RAISE EXCEPTION 'Vérification échouée : api.set_local_reader_identity absente après replace.';
  END IF;
  RAISE NOTICE 'CARD-LOCAL Lot 5 : dispatch reader_identity_assigned câblé dans set_local_reader_identity.';
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════════════
-- Rollback : ré-appliquer la version Lot 2 (sans le bloc de dispatch).
-- ════════════════════════════════════════════════════════════════════════════
