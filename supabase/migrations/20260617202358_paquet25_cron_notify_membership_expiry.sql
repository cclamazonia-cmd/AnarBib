-- ═══════════════════════════════════════════════════════════════════════════
-- #25 — cron de notification d'expiration de cotisation (J-7 / J-0)
-- ───────────────────────────────────────────────────────────────────────────
-- Session : Audit 360 — correctifs P0
-- Auteur  : AnarBib (assist. Claude)
-- Réf     : Audit 360° 17/06/2026, P1 #25 (« pas de cron d'expiration »).
--
-- OBJET
--   Notifier les membres dont la cotisation arrive à échéance : un rappel à
--   J-7 et un avis le jour J (J-0). E-mail (handler notify-event
--   'cotisation_expiring') + bandeau /conta déjà alimenté par days_until_expiry
--   (doctrine §4.4 : cotisation = e-mail + bandeau, pas de réplique in-app).
--
-- AUTO-LIMITATION (sûr par construction)
--   Ne notifie QUE les membres d'une biblio avec membership_enabled = true ET
--   une règle de cotisation REQUISE active. Aujourd'hui : BLMF seulement. Les
--   biblios sans cotisation (MLEG, BTL…) ne déclenchent jamais rien.
--
-- ANTI-DOUBLON
--   Table membership_expiry_notifications : une notif par (adhésion, période
--   valid_until, seuil). On ne (ré)inscrit le doublon que si le dispatch a bien
--   été émis (fn_dispatch_notify_event ≠ NULL) → si les secrets manquent, on
--   réessaiera le lendemain au lieu de « brûler » la notif.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. Table anti-doublon ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.membership_expiry_notifications (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  membership_id uuid NOT NULL REFERENCES public.user_library_memberships(id) ON DELETE CASCADE,
  valid_until   date NOT NULL,
  threshold_days integer NOT NULL,           -- 7 (rappel) ou 0 (jour J)
  notified_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (membership_id, valid_until, threshold_days)
);

-- Table interne (écrite uniquement par la fn SECDEF du cron) : RLS deny-all,
-- aucun accès direct anon/authenticated.
ALTER TABLE public.membership_expiry_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.membership_expiry_notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.membership_expiry_notifications TO service_role;

-- ── 2. Fonction cron ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_cron_notify_membership_expiry()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_rec record;
  v_membership_id uuid;
  v_req bigint;
  v_dispatched integer := 0;
BEGIN
  FOR v_rec IN
    SELECT am.user_id, am.library_id, am.last_valid_until AS valid_until,
           am.days_until_expiry AS d
    FROM public.v_active_memberships am
    WHERE am.membership_enabled = true
      AND am.membership_status = 'active'
      AND am.last_valid_until IS NOT NULL
      AND am.days_until_expiry IN (7, 0)
      AND EXISTS (
        SELECT 1 FROM public.library_membership_rules r
        WHERE r.library_id = am.library_id AND r.is_active AND r.is_required
      )
  LOOP
    -- id d'adhésion (le handler attend membership_id)
    SELECT m.id INTO v_membership_id
    FROM public.user_library_memberships m
    WHERE m.user_id = v_rec.user_id AND m.library_id = v_rec.library_id AND m.status = 'active'
    LIMIT 1;
    IF v_membership_id IS NULL THEN CONTINUE; END IF;

    -- anti-doublon : (adhésion, période, seuil) une seule fois
    IF EXISTS (
      SELECT 1 FROM public.membership_expiry_notifications n
      WHERE n.membership_id = v_membership_id
        AND n.valid_until = v_rec.valid_until
        AND n.threshold_days = v_rec.d
    ) THEN
      CONTINUE;
    END IF;

    v_req := public.fn_dispatch_notify_event(
      'cotisation_expiring', 1,
      jsonb_build_object(
        'membership_id', v_membership_id,
        'user_id',       v_rec.user_id,
        'library_id',    v_rec.library_id,
        'threshold_days', v_rec.d,
        'valid_until',   v_rec.valid_until
      )
    );

    -- N'inscrire le doublon que si le dispatch a réellement été émis.
    IF v_req IS NOT NULL THEN
      INSERT INTO public.membership_expiry_notifications (membership_id, valid_until, threshold_days)
      VALUES (v_membership_id, v_rec.valid_until, v_rec.d)
      ON CONFLICT (membership_id, valid_until, threshold_days) DO NOTHING;
      v_dispatched := v_dispatched + 1;
    END IF;
  END LOOP;

  RETURN v_dispatched;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_cron_notify_membership_expiry() FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_cron_notify_membership_expiry() TO service_role;

-- ── 3. Enregistrement pg_cron (idempotent) ──────────────────────────────────
DO $cron$
DECLARE
  v_has_pg_cron boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') INTO v_has_pg_cron;
  IF NOT v_has_pg_cron THEN
    RAISE WARNING '[#25] pg_cron non installé : fn_cron_notify_membership_expiry créée mais non planifiée.';
    RETURN;
  END IF;

  BEGIN
    PERFORM cron.unschedule('anarbib-membership-expiry-daily');
  EXCEPTION WHEN OTHERS THEN
    NULL;  -- pas de schedule précédent : ok
  END;

  PERFORM cron.schedule(
    'anarbib-membership-expiry-daily',
    '40 6 * * *',  -- chaque jour à 06:40 UTC
    $$SELECT public.fn_cron_notify_membership_expiry();$$
  );
  RAISE NOTICE '[#25] anarbib-membership-expiry-daily planifié (daily 06:40 UTC).';
END
$cron$;

-- ── 4. Vérification ─────────────────────────────────────────────────────────
DO $$
BEGIN
  IF to_regclass('public.membership_expiry_notifications') IS NULL THEN
    RAISE EXCEPTION '#25 : table membership_expiry_notifications absente';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                 WHERE n.nspname='public' AND p.proname='fn_cron_notify_membership_expiry') THEN
    RAISE EXCEPTION '#25 : fonction fn_cron_notify_membership_expiry absente';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_cron')
     AND NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname='anarbib-membership-expiry-daily') THEN
    RAISE EXCEPTION '#25 : job cron anarbib-membership-expiry-daily non enregistré';
  END IF;
  RAISE NOTICE '#25 OK : table + fonction + cron en place.';
END $$;
