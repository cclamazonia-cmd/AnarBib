-- =========================================================================
-- Refonte du refus d'inscription : modèle à 2 passages (socle backend)
-- =========================================================================
-- Date     : 2026-06-23
-- Chantier : validation des inscriptions (BLMF) — refonte du refus (tâche #10)
-- Auteur   : Claude (livré en fichier, appliqué par Forgejo / supabase db push)
--
-- Contexte : le refus initial (Suite 6) mettait status='removed' → TROU sécurité :
-- une appartenance 'removed' est EXCLUE de v_total dans la garde anti-multi-
-- inscription de api.request_membership → le compte refusé pouvait se reconnecter
-- et demander d'AUTRES bibliothèques (grave pour une biblio masquée).
--
-- Nouveau modèle (spec Xavier) :
--   • refus → status='refused' (compté dans v_total → request_membership bloque
--     les autres biblios) + validation_refusal_count++ + NOTIF STAFF (coordination
--     prévenue ; PAS le candidat).
--   • le/la candidat·e peut RE-SOUMETTRE (réexamen) tant que refusal_count < 2 :
--     api.resubmit_membership repasse en 'pending_validation' (réapparaît dans
--     Validações + Trabalho do dia).
--   • 2e refus (refusal_count=2) → définitif : resubmit bloqué, compte/e-mail
--     reste en base (la colonne mémorise le passé pour éviter les tentatives).
--
-- status est texte libre (aucune contrainte CHECK) → 'refused' s'ajoute sans
-- migration de contrainte. fn_log_reader_membership_event classe déjà
-- pending→'refused' en 'outro' (branche else) et 'refused'→pending en
-- 'solicitacao' : pas de faux départ, rien à modifier côté journal de cycle de vie.
-- =========================================================================

BEGIN;

-- ── 1. Compteur de refus ─────────────────────────────────────────────────
ALTER TABLE public.user_library_memberships
  ADD COLUMN IF NOT EXISTS validation_refusal_count integer NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.user_library_memberships.validation_refusal_count IS
  'Nombre de refus de validation présentielle subis (modèle 2 passages). >=2 = refus définitif (resubmit bloqué). Refonte du refus, 23/06/2026.';

-- ── 2. Journal : autoriser l''action ''resubmitted'' ─────────────────────
ALTER TABLE public.membership_validation_log
  DROP CONSTRAINT membership_validation_log_action_check;
ALTER TABLE public.membership_validation_log
  ADD CONSTRAINT membership_validation_log_action_check
  CHECK (action = ANY (ARRAY['validated', 'revalidated', 'invalidated', 'refused', 'resubmitted']));

-- ── 3. reject_membership : 'refused' + compteur + notif staff ────────────
CREATE OR REPLACE FUNCTION api.reject_membership(p_membership_id uuid, p_note text DEFAULT NULL::text)
RETURNS TABLE(ok boolean, message text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_m record;
  v_count int;
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'Autenticação obrigatória.'; END IF;

  SELECT m.id, m.user_id, m.library_id, m.status INTO v_m
  FROM public.user_library_memberships m WHERE m.id = p_membership_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Associação não encontrada.'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships s
    WHERE s.user_id = v_caller AND s.library_id = v_m.library_id
      AND s.role IN ('librarian', 'coordenador') AND s.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Acesso de equipe obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.staff_required';
  END IF;

  IF v_m.status <> 'pending_validation' THEN
    RAISE EXCEPTION 'Esta associação não está pendente de validação.'
      USING ERRCODE = 'P0001', HINT = 'error.membership.not_pending';
  END IF;

  -- Refus : statut 'refused' (compté dans v_total → bloque les autres biblios),
  -- compteur incrémenté, raison en note. AUCUNE notif candidat.
  UPDATE public.user_library_memberships
    SET status = 'refused',
        validation_refusal_count = validation_refusal_count + 1,
        updated_at = now()
    WHERE id = p_membership_id
    RETURNING validation_refusal_count INTO v_count;

  INSERT INTO public.membership_validation_log
    (membership_id, user_id, library_id, action, performed_by_user_id, local_reader_number, note)
  VALUES
    (p_membership_id, v_m.user_id, v_m.library_id, 'refused', v_caller, NULL, p_note);

  -- Notif STAFF (coordination prévenue — évite les décisions incohérentes par
  -- manque de suivi). Best-effort. Le candidat·e n'est PAS notifié·e.
  BEGIN
    PERFORM public.fn_dispatch_notify_event(
      'membership_refused', 1,
      jsonb_build_object(
        'user_id', v_m.user_id::text,
        'library_id', v_m.library_id::text,
        'membership_id', p_membership_id::text,
        'refusal_count', v_count,
        'is_final', (v_count >= 2),
        'note', p_note
      ));
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'membership_refused dispatch failed for %: %', p_membership_id, SQLERRM;
  END;

  RETURN QUERY SELECT true, 'Inscrição recusada.'::text;
END $function$;

COMMENT ON FUNCTION api.reject_membership(uuid, text) IS
  'Refuse une inscription en attente (staff librarian+). status→refused (compté dans v_total → bloque les autres biblios), validation_refusal_count++, notif STAFF (pas le candidat). Refonte du refus, 23/06/2026.';

-- ── 4. resubmit_membership : réexamen par le/la candidat·e ───────────────
CREATE OR REPLACE FUNCTION api.resubmit_membership(p_membership_id uuid)
RETURNS TABLE(ok boolean, message text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_m record;
BEGIN
  IF v_caller IS NULL THEN RAISE EXCEPTION 'Autenticação obrigatória.'; END IF;

  SELECT m.id, m.user_id, m.library_id, m.status, m.validation_refusal_count
    INTO v_m
  FROM public.user_library_memberships m WHERE m.id = p_membership_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Associação não encontrada.'; END IF;

  -- Seul·e le/la candidat·e peut re-soumettre SA propre demande.
  IF v_m.user_id <> v_caller THEN
    RAISE EXCEPTION 'Acesso negado.' USING ERRCODE = 'P0001', HINT = 'error.forbidden';
  END IF;

  IF v_m.status <> 'refused' THEN
    RAISE EXCEPTION 'Esta inscrição não está recusada.'
      USING ERRCODE = 'P0001', HINT = 'error.membership.not_refused';
  END IF;

  IF v_m.validation_refusal_count >= 2 THEN
    RAISE EXCEPTION 'Inscrição recusada definitivamente.'
      USING ERRCODE = 'P0001', HINT = 'error.membership.refused_final';
  END IF;

  -- Réexamen : repasse en attente (réapparaît dans Validações). Compteur conservé
  -- (un 2e refus le portera à 2 → définitif).
  UPDATE public.user_library_memberships
    SET status = 'pending_validation', updated_at = now()
    WHERE id = p_membership_id;

  INSERT INTO public.membership_validation_log
    (membership_id, user_id, library_id, action, performed_by_user_id, local_reader_number, note)
  VALUES
    (p_membership_id, v_m.user_id, v_m.library_id, 'resubmitted', v_caller, NULL, NULL);

  -- Re-notifier le staff : une demande de réexamen attend (même canal que la 1re).
  BEGIN
    PERFORM public.fn_dispatch_notify_event(
      'membership_validation_requested', 1,
      jsonb_build_object(
        'user_id', v_m.user_id::text,
        'library_id', v_m.library_id::text,
        'membership_id', p_membership_id::text,
        'is_resubmission', true
      ));
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'resubmit dispatch failed for %: %', p_membership_id, SQLERRM;
  END;

  RETURN QUERY SELECT true, 'Pedido reenviado para nova análise.'::text;
END $function$;

REVOKE EXECUTE ON FUNCTION api.resubmit_membership(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.resubmit_membership(uuid) TO authenticated;

COMMENT ON FUNCTION api.resubmit_membership(uuid) IS
  'Réexamen d''une inscription refusée par le/la candidat·e (si validation_refusal_count < 2). Repasse en pending_validation. Refonte du refus, 23/06/2026.';

-- ── 5. list_pending_validations : exposer refusal_count (réexamen visible) ─
DROP FUNCTION IF EXISTS api.list_pending_validations(uuid);
CREATE FUNCTION api.list_pending_validations(p_library_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(membership_id uuid, user_id uuid, library_id uuid, library_name text, email text, first_name text, last_name text, requested_at timestamp with time zone, refusal_count integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT m.id, m.user_id, m.library_id,
         COALESCE(l.short_name, l.name) AS library_name,
         p.email, p.first_name, p.last_name,
         m.created_at AS requested_at,
         m.validation_refusal_count
  FROM public.user_library_memberships m
  JOIN public.libraries l ON l.id = m.library_id
  LEFT JOIN public.profiles p ON p.id = m.user_id
  WHERE m.role = 'reader'
    AND m.status = 'pending_validation'
    AND (p_library_id IS NULL OR m.library_id = p_library_id)
    AND EXISTS (
      SELECT 1 FROM public.user_library_memberships s
      WHERE s.user_id = auth.uid() AND s.library_id = m.library_id
        AND s.role IN ('librarian', 'coordenador') AND s.status = 'active'
    )
  ORDER BY m.created_at ASC;
$function$;
REVOKE EXECUTE ON FUNCTION api.list_pending_validations(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.list_pending_validations(uuid) TO authenticated;

-- ── 6. fn_my_memberships_status : exposer validation_refusal_count (gating) ─
DROP FUNCTION IF EXISTS api.fn_my_memberships_status();
CREATE FUNCTION api.fn_my_memberships_status()
 RETURNS TABLE(library_id uuid, library_slug text, library_name text, role text, status text, is_primary boolean, physically_validated boolean, is_restricted boolean, restricted_reason text, local_reader_number text, membership_enabled boolean, dues_status text, dues_blocking boolean, days_until_expiry integer, validation_refusal_count integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT
    m.library_id,
    l.slug,
    COALESCE(l.short_name, l.name),
    m.role,
    m.status,
    m.is_primary,
    (m.physically_validated_at IS NOT NULL),
    m.is_restricted,
    m.restricted_reason,
    m.local_reader_number,
    COALESCE(l.membership_enabled, false),
    am.dues_status,
    public.fn_is_loan_blocked_by_dues(m.user_id, m.library_id),
    am.days_until_expiry::integer,
    m.validation_refusal_count
  FROM public.user_library_memberships m
  JOIN public.libraries l ON l.id = m.library_id
  LEFT JOIN public.v_active_memberships am
    ON am.user_id = m.user_id AND am.library_id = m.library_id
  WHERE m.user_id = auth.uid()
    AND m.status <> 'removed'
  ORDER BY m.is_primary DESC, l.name;
$function$;
REVOKE EXECUTE ON FUNCTION api.fn_my_memberships_status() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.fn_my_memberships_status() TO authenticated;

NOTIFY pgrst, 'reload schema';

-- ── Vérification ──────────────────────────────────────────────────────────
DO $$
DECLARE v_n int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                 WHERE table_schema='public' AND table_name='user_library_memberships'
                   AND column_name='validation_refusal_count') THEN
    RAISE EXCEPTION 'Vérif : colonne validation_refusal_count absente.';
  END IF;
  SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
   WHERE n.nspname='api' AND p.proname IN ('reject_membership','resubmit_membership','list_pending_validations','fn_my_memberships_status');
  IF v_n <> 4 THEN
    RAISE EXCEPTION 'Vérif : % fonction(s) sur 4 attendues.', v_n;
  END IF;
  RAISE NOTICE 'Refonte du refus (socle) OK.';
END $$;

COMMIT;
