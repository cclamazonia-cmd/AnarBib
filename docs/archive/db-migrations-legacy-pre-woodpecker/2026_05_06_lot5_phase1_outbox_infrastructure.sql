-- ============================================================================
-- Lot 5 — Phase 1 : Infrastructure outbox pour les events team.*
-- ============================================================================
-- Date : 2026-05-06
-- Auteur : Xavier VAN WELDEN
-- Spec de référence : docs/spec-gouvernance-roles.md §11.4 (Option B / outbox)
-- Lots précédents :
--   - 2026_05_05_lot1_governance_db_infrastructure.sql
--   - 2026_05_06_lot2_3_rpc_team_governance.sql (RPCs + helper version pg_net direct)
-- ============================================================================
--
-- Contexte du refactor :
--   La version initiale de fn_team_notify_event (commit du 06/05/2026) faisait
--   un pg_net.http_post direct vers notify-event. Le test fonctionnel a révélé
--   2 problèmes :
--     1. notify-event attend un payload {event, record_id} avec record_id NUMERIC,
--        alors que notre helper envoyait {event_type, data}.
--     2. notify-event renvoyait 401 Unauthorized (mismatch authentification).
--
--   Solution adoptée (Option B de la spec §11.4) :
--   - Création d'une table team_notification_outbox avec id BIGSERIAL.
--   - fn_team_notify_event INSÈRE dans cette outbox au lieu de POSTer directement.
--   - Un trigger AFTER INSERT déclenche un pg_net.http_post vers notify-event
--     avec le bon format (event = team.*, record_id = id BIGSERIAL).
--   - Le handler côté notify-event lira la ligne dans la outbox pour reconstituer
--     le contexte (similaire au pattern handleProfileNotice avec profile_notice_queue).
--
--   Bénéfices :
--   - Format payload conforme à l'architecture notify-event existante
--   - Robustesse : la ligne en base est conservée même en cas de panne de l'EF
--   - Possibilité de re-jouer manuellement un envoi raté (insert manuel ou
--     UPDATE pour relancer le trigger)
--   - Audit trail complet des notifications envoyées
--
--   ⚠️ Pré-requis prod : notify-event doit être déployée avec --no-verify-jwt.
--   Le 06/05/2026, on a découvert que notify-event était déployée avec
--   verify_jwt=true (défaut Supabase), ce qui faisait que TOUS les triggers DB
--   qui POSTent vers cette EF (y compris fn_dispatch_circulation_notify_event
--   pour les notifs circulation, en place depuis avril 2026) recevaient un 401
--   du gateway Supabase avant même d'atteindre le code. Le bug était silencieux :
--   les notifs ne partaient pas, mais aucune erreur visible côté frontend.
--   Solution appliquée : `supabase functions deploy notify-event --no-verify-jwt`.
--   Cf. docs/decisions/REDEPLOY_NOTIFY_EVENT_NO_VERIFY_JWT_2026-05-06.md
-- ============================================================================


-- ─── Section 1 : Table team_notification_outbox ────────────────────────────

CREATE TABLE IF NOT EXISTS public.team_notification_outbox (
  id              BIGSERIAL PRIMARY KEY,
  event           TEXT NOT NULL CHECK (event LIKE 'team.%'),
  payload         JSONB NOT NULL DEFAULT '{}'::jsonb,
  status          TEXT NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'sent', 'failed')),
  pg_net_request_id BIGINT,                -- id retourné par net.http_post pour traçabilité
  attempts        INT NOT NULL DEFAULT 0,
  last_error      TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at         TIMESTAMPTZ
);

COMMENT ON TABLE public.team_notification_outbox IS
  'File d''attente des notifications team.*. Chaque ligne représente un event à envoyer à notify-event Edge Function. Cf. spec-gouvernance-roles.md §11.4 (Option B).';

COMMENT ON COLUMN public.team_notification_outbox.event IS
  'Nom de l''event team.* (ex: team.promoted_to_librarian, team.removal_requested...).';

COMMENT ON COLUMN public.team_notification_outbox.payload IS
  'Données métier de l''event en jsonb (library_id, target_user_id, role, etc.).';

COMMENT ON COLUMN public.team_notification_outbox.status IS
  'pending : créé, en attente d''envoi par le trigger. sent : confirmation reçue (HTTP 200). failed : envoi en erreur (4xx, 5xx, timeout).';

COMMENT ON COLUMN public.team_notification_outbox.pg_net_request_id IS
  'ID retourné par net.http_post, utile pour debug via net._http_response.';

-- Index pour réémission éventuelle (lookups par status)
CREATE INDEX IF NOT EXISTS idx_team_notification_outbox_pending
  ON public.team_notification_outbox (created_at)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_team_notification_outbox_failed
  ON public.team_notification_outbox (created_at DESC)
  WHERE status = 'failed';

-- ─── RLS : lecture pour staff de la biblio concernée + admin AnarBib ──────

ALTER TABLE public.team_notification_outbox ENABLE ROW LEVEL SECURITY;

-- Pas de RLS write : seules les RPCs SECURITY DEFINER (fn_team_notify_event)
-- et le trigger peuvent écrire. Pas de INSERT/UPDATE/DELETE depuis l'API publique.

-- Pas de policy de lecture publique non plus : c'est de l'audit interne,
-- accessible uniquement via service_role pour debug. Si on veut exposer plus
-- tard une vue admin, on créera une policy ou une view dédiée.


-- ─── Section 2 : Refactor de fn_team_notify_event ──────────────────────────
-- L'ancienne version faisait un pg_net.http_post direct.
-- La nouvelle version INSÈRE dans team_notification_outbox.
-- Le trigger sur la table déclenche le POST.

CREATE OR REPLACE FUNCTION public.fn_team_notify_event(
  p_event text,
  p_payload jsonb
)
RETURNS bigint  -- id de la ligne créée dans team_notification_outbox
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_outbox_id bigint;
BEGIN
  -- Validation minimale du nom d'event (le CHECK constraint sur la table
  -- en fera autant, mais autant remonter une erreur claire ici).
  IF p_event IS NULL OR p_event NOT LIKE 'team.%' THEN
    RAISE WARNING 'fn_team_notify_event: event name invalid (must start with "team."): %', p_event;
    RETURN NULL;
  END IF;

  -- Insertion dans la outbox.
  -- Le trigger trg_team_outbox_dispatch (créé en section 3) déclenchera le POST.
  INSERT INTO public.team_notification_outbox (event, payload)
  VALUES (p_event, COALESCE(p_payload, '{}'::jsonb))
  RETURNING id INTO v_outbox_id;

  RETURN v_outbox_id;

EXCEPTION
  WHEN OTHERS THEN
    -- Une erreur d'enregistrement notification ne doit JAMAIS faire échouer
    -- la RPC métier qui appelle ce helper.
    RAISE WARNING 'fn_team_notify_event échec INSERT outbox pour event=% : %', p_event, SQLERRM;
    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.fn_team_notify_event(text, jsonb) IS
  'Helper interne : enregistre un event team.* dans team_notification_outbox. Le trigger trg_team_outbox_dispatch déclenche ensuite un pg_net.http_post vers notify-event Edge Function. Cf. spec-gouvernance-roles.md §11.4 (Option B).';

-- Permissions : interne uniquement (les RPCs SECURITY DEFINER peuvent l'appeler
-- car elles s'exécutent avec les privilèges de postgres).
REVOKE EXECUTE ON FUNCTION public.fn_team_notify_event(text, jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_team_notify_event(text, jsonb) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_team_notify_event(text, jsonb) FROM anon;


-- ─── Section 3 : Trigger trg_team_outbox_dispatch ──────────────────────────
-- Déclenché AFTER INSERT. Lit le secret depuis vault et POST vers notify-event.

CREATE OR REPLACE FUNCTION public.fn_team_outbox_dispatch_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_url text;
  v_secret text;
  v_request_id bigint;
  v_outbox_payload jsonb;
BEGIN
  v_url := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/notify-event';

  -- Lecture du secret depuis vault
  -- Note : on lit WEBHOOK_SECRET_NOTIFY_EVENT (majuscules), aligné avec
  -- fn_dispatch_circulation_notify_event (qui marche en prod depuis avril 2026).
  -- Le secret est aussi disponible côté Edge Function en variable d'env
  -- WEBHOOK_SECRET_NOTIFY_EVENT (lue par _shared/core/env.ts → WEBHOOK_SECRET).
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'WEBHOOK_SECRET_NOTIFY_EVENT';

  IF v_secret IS NULL OR v_secret = '' THEN
    -- Marque la ligne en failed avec message explicite
    UPDATE public.team_notification_outbox
    SET status = 'failed',
        last_error = 'WEBHOOK_SECRET_NOTIFY_EVENT vide ou introuvable dans vault',
        attempts = attempts + 1
    WHERE id = NEW.id;
    RETURN NEW;
  END IF;

  -- Construction du payload conforme à ce que notify-event attend :
  -- {event: "team.xxx", record_id: <bigint id outbox>, ...autres champs optionnels}
  -- Le handler team.ts (Phase 2) lira la ligne via SELECT FROM team_notification_outbox WHERE id = record_id.
  v_outbox_payload := jsonb_build_object(
    'event', NEW.event,
    'record_id', NEW.id
  );

  -- POST asynchrone via pg_net
  BEGIN
    SELECT net.http_post(
      url := v_url,
      body := v_outbox_payload,
      headers := jsonb_build_object(
        'content-type', 'application/json',
        'x-webhook-secret', v_secret
      )
    ) INTO v_request_id;

    -- On enregistre le request_id et on laisse status='pending'.
    -- La transition pending → sent/failed pourrait être faite par un cron
    -- qui lit net._http_response, mais pour la phase 1 on s'en passe :
    -- les logs notify-event suffisent au monitoring.
    UPDATE public.team_notification_outbox
    SET pg_net_request_id = v_request_id,
        attempts = attempts + 1
    WHERE id = NEW.id;

  EXCEPTION
    WHEN OTHERS THEN
      UPDATE public.team_notification_outbox
      SET status = 'failed',
          last_error = SQLERRM,
          attempts = attempts + 1
      WHERE id = NEW.id;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_team_outbox_dispatch_trigger() IS
  'Fonction de trigger : déclenchée AFTER INSERT sur team_notification_outbox. POST vers notify-event Edge Function avec event + record_id (id outbox). Le handler team.ts (côté EF) lit la ligne en base pour récupérer le payload complet.';

-- Création du trigger
DROP TRIGGER IF EXISTS trg_team_outbox_dispatch ON public.team_notification_outbox;

CREATE TRIGGER trg_team_outbox_dispatch
AFTER INSERT ON public.team_notification_outbox
FOR EACH ROW EXECUTE FUNCTION public.fn_team_outbox_dispatch_trigger();


-- ─── Vérifications post-création ───────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class
    WHERE relname = 'team_notification_outbox'
      AND relnamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'Échec création : table team_notification_outbox manquante';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_team_outbox_dispatch'
      AND tgrelid = 'public.team_notification_outbox'::regclass
  ) THEN
    RAISE EXCEPTION 'Échec création : trigger trg_team_outbox_dispatch manquant';
  END IF;

  RAISE NOTICE 'Phase 1 complète : outbox + helper refactoré + trigger en place.';
END $$;
