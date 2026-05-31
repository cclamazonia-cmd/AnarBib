-- Chantier #CL.7 — Préférences de notification lectrice + réplique in-app
--
-- Cette migration couvre la séquence γ doctrinale :
--
--   (1) Table user_notification_preferences : la lectrice peut désactiver
--       certaines catégories de notifications répliquées in-app, dans la
--       limite de ce que sa biblio courante a activé (Position 1 —
--       souveraineté biblio, ajustement lectrice à la baisse uniquement).
--
--   (2) Deux RPC : get_my_notification_preferences, set_my_notification_preferences
--
--   (3) Deux triggers frères qui répliquent in-app les événements
--       "action lectrice attendue" (B2) :
--         - reserva_pronta_para_retirada (workflow réservation)
--         - consulta_agendada (workflow consultation locale)
--
-- Doctrine référente : docs/specs/spec-notifications-lecteur.md v1.0
-- (31/05/2026), notamment §3 (doctrines A/B/C), §4.1 et §4.2 (catégories
-- circulation), §5 (configurabilité).
--
-- Architecture α (décision 31/05/2026) : les triggers in-app respectent
-- le même flag biblio que les triggers e-mail (reservation_mail_*_enabled,
-- local_consultation_enabled + consulta_mail_*_enabled). Pas de flag
-- in-app séparé au niveau biblio aujourd'hui — pourra être ajouté plus
-- tard si un cas réel le justifie.
--
-- Architecture trigger frère (décision 31/05/2026) : on ne modifie PAS
-- les triggers e-mail existants (trg_notify_reserva_workflow_change,
-- trg_notify_consulta_workflow). On crée des triggers frères qui réagissent
-- aux mêmes transitions mais vivent en parallèle. Plus sûr — on peut
-- disable/drop le trigger in-app sans toucher au flux e-mail si problème.
--
-- Doctrine v2 (CHANTIER_doctrine_creation_objets_securises_2026-05-12) :
--   - SECURITY DEFINER + REVOKE FROM PUBLIC, anon, service_role + GRANT TO authenticated
--   - SET search_path TO 'public'
--   - Vérification embarquée en fin de migration

-- ──────────────────────────────────────────────────────────────────────
-- 1. Table user_notification_preferences
-- ──────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  -- Catégories désactivables (NULL ou absence de rangée = défaut biblio respecté)
  disable_reserva_pronta boolean NOT NULL DEFAULT false,
  disable_consulta_pronta boolean NOT NULL DEFAULT false,
  -- Métadonnées
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_notification_preferences IS
  'Chantier #CL.7 (31/05/2026). Préférences de notification de la lectrice. '
  'Position 1 : réduction seule, jamais activation au-dessus du défaut biblio. '
  'Absence de rangée = défaut respecté. Spec : docs/specs/spec-notifications-lecteur.md';

-- GRANT explicites futur-proof (doctrine Supabase 30/10/2026, cf.
-- CHANTIER_doctrine_creation_objets_securises_2026-05-12.md Template 2).
-- Scénario C : table hors Data API, manipulée uniquement par les RPC
-- SECURITY DEFINER fn_get_my_notification_preferences et
-- fn_set_my_notification_preferences. Le frontend NE PEUT PAS faire
-- supabase.from('user_notification_preferences').select() directement —
-- il DOIT passer par les RPC qui ont leur propre GRANT à authenticated.
REVOKE ALL ON public.user_notification_preferences FROM anon, authenticated;
GRANT ALL ON public.user_notification_preferences TO service_role;

-- RLS : obligatoire (linter Supabase ERROR sinon), même si la table n'est
-- pas accessible via PostgREST. Policy lock-down explicite.
ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_notif_prefs_lock_down ON public.user_notification_preferences;
CREATE POLICY user_notif_prefs_lock_down
  ON public.user_notification_preferences
  AS RESTRICTIVE
  FOR ALL
  USING (false)
  WITH CHECK (false);

-- ──────────────────────────────────────────────────────────────────────
-- 2. RPC fn_get_my_notification_preferences — lecture par la lectrice
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_get_my_notification_preferences()
RETURNS TABLE(
  disable_reserva_pronta boolean,
  disable_consulta_pronta boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required'
      USING HINT = 'fn_get_my_notification_preferences: no authenticated user';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(p.disable_reserva_pronta, false),
    COALESCE(p.disable_consulta_pronta, false)
  FROM (SELECT v_user_id AS uid) u
  LEFT JOIN public.user_notification_preferences p ON p.user_id = u.uid;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_get_my_notification_preferences() FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fn_get_my_notification_preferences() TO authenticated;

COMMENT ON FUNCTION public.fn_get_my_notification_preferences() IS
  'Chantier #CL.7 (31/05/2026). Retourne les préférences notification de auth.uid(). '
  'Si pas de rangée en base, retourne toutes les valeurs à false (défaut biblio respecté).';

-- ──────────────────────────────────────────────────────────────────────
-- 3. RPC fn_set_my_notification_preferences — écriture par la lectrice (upsert)
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_set_my_notification_preferences(
  p_disable_reserva_pronta boolean,
  p_disable_consulta_pronta boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'auth required'
      USING HINT = 'fn_set_my_notification_preferences: no authenticated user';
  END IF;

  INSERT INTO public.user_notification_preferences (
    user_id,
    disable_reserva_pronta,
    disable_consulta_pronta,
    updated_at
  )
  VALUES (
    v_user_id,
    COALESCE(p_disable_reserva_pronta, false),
    COALESCE(p_disable_consulta_pronta, false),
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
    SET disable_reserva_pronta  = EXCLUDED.disable_reserva_pronta,
        disable_consulta_pronta = EXCLUDED.disable_consulta_pronta,
        updated_at              = now();
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_set_my_notification_preferences(boolean, boolean) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fn_set_my_notification_preferences(boolean, boolean) TO authenticated;

COMMENT ON FUNCTION public.fn_set_my_notification_preferences(boolean, boolean) IS
  'Chantier #CL.7 (31/05/2026). Upsert des préférences notification de auth.uid(). '
  'Crée la rangée si absente, met à jour sinon. NULL traité comme false (sécurité).';

-- ──────────────────────────────────────────────────────────────────────
-- 4. Fonction trigger fn_replicate_reserva_pronta_to_inapp
-- ──────────────────────────────────────────────────────────────────────
-- Réplique in-app sur transition workflow_stage -> 'pronta_para_retirada'.
-- Pattern : mêmes garde-fous que le trigger e-mail (flag biblio), plus
-- vérification de la préférence lectrice (fail-closed sur la pref :
-- si pref.disable_reserva_pronta = true, on n'insère pas).

CREATE OR REPLACE FUNCTION public.fn_replicate_reserva_pronta_to_inapp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_library_id uuid;
  v_user_id uuid;
  v_mail_enabled boolean := true;       -- défaut fail-open (= comportement trigger e-mail)
  v_user_disabled boolean := false;     -- défaut fail-open (= pas de préférence = on insère)
  v_reserva_ref text;
BEGIN
  -- Détection de la transition cible
  IF NOT (TG_OP = 'UPDATE' AND NEW.workflow_stage = 'pronta_para_retirada'
          AND (OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage)) THEN
    RETURN NEW;
  END IF;

  -- Récupérer library_id et user_id depuis reservas_v2
  SELECT r.library_id, r.user_id
    INTO v_library_id, v_user_id
  FROM public.reservas_v2 r
  WHERE r.id = NEW.reserva_id;

  IF v_user_id IS NULL THEN
    -- Réservation sans user : pas de notification possible. Sort silencieusement.
    RETURN NEW;
  END IF;

  -- Vérifier le flag biblio (même que pour le mail — Architecture α)
  IF v_library_id IS NOT NULL THEN
    SELECT reservation_mail_pronta_para_retirada_enabled
      INTO v_mail_enabled
    FROM public.library_notification_policies
    WHERE library_id = v_library_id;
    v_mail_enabled := COALESCE(v_mail_enabled, true);
  END IF;

  IF NOT v_mail_enabled THEN
    RETURN NEW;  -- biblio a désactivé : ni mail ni in-app
  END IF;

  -- Vérifier la préférence lectrice (réduction seule)
  SELECT COALESCE(p.disable_reserva_pronta, false)
    INTO v_user_disabled
  FROM public.user_notification_preferences p
  WHERE p.user_id = v_user_id;
  v_user_disabled := COALESCE(v_user_disabled, false);

  IF v_user_disabled THEN
    RETURN NEW;  -- la lectrice a désactivé pour elle
  END IF;

  -- Construire une référence courte pour le titre (numéro de réserva)
  v_reserva_ref := COALESCE(NEW.reserva_id::text, '?');

  -- Insertion in-app. Clés i18n côté frontend, body en pt-BR ici par défaut
  -- (cf. paquet RGPD qui utilise déjà ce pattern de clés title/body).
  INSERT INTO public.user_notifications (
    user_id, library_id, category, title, body,
    link_type, link_id, is_read
  )
  VALUES (
    v_user_id,
    v_library_id,
    'reserva',
    'notif.reserva.prontaParaRetirada.title',
    'notif.reserva.prontaParaRetirada.body',
    'reserva',
    v_reserva_ref,
    false
  );

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.fn_replicate_reserva_pronta_to_inapp() IS
  'Chantier #CL.7 (31/05/2026). Trigger frère du e-mail : réplique in-app sur '
  'transition workflow_stage -> pronta_para_retirada (B2 action lectrice). '
  'Respecte le même flag biblio que le mail (Architecture α) + préférence lectrice.';

-- ──────────────────────────────────────────────────────────────────────
-- 5. Trigger frère sur reserva_item_workflow_v2
-- ──────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_replicate_reserva_pronta_inapp ON public.reserva_item_workflow_v2;

CREATE TRIGGER trg_replicate_reserva_pronta_inapp
  AFTER UPDATE ON public.reserva_item_workflow_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_replicate_reserva_pronta_to_inapp();

-- ──────────────────────────────────────────────────────────────────────
-- 6. Fonction trigger fn_replicate_consulta_agendada_to_inapp
-- ──────────────────────────────────────────────────────────────────────
-- Réplique in-app sur transition workflow_stage -> 'consulta_agendada'.
-- Le trigger e-mail réagit aussi sur INSERT (création directe en stage
-- agendada) et sur les changements de plage horaire (consultation_starts_at,
-- consultation_ends_at) dans le même stage. Pour la réplique in-app, on
-- limite au cas le plus simple : transition vers agendada (UPDATE ou INSERT
-- avec stage cible). Les changements de plage ne créent pas une nouvelle
-- notif in-app (l'info est visible dans /conta/reservas onglet consultas).

CREATE OR REPLACE FUNCTION public.fn_replicate_consulta_agendada_to_inapp()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_library_id uuid;
  v_user_id uuid;
  v_local_consultation_enabled boolean := true;
  v_mail_enabled boolean := true;
  v_user_disabled boolean := false;
  v_consulta_ref text;
BEGIN
  -- Détection de la transition cible (UPDATE vers agendada, ou INSERT en agendada)
  IF NOT (
    (TG_OP = 'INSERT' AND NEW.workflow_stage = 'consulta_agendada')
    OR (TG_OP = 'UPDATE' AND NEW.workflow_stage = 'consulta_agendada'
        AND OLD.workflow_stage IS DISTINCT FROM NEW.workflow_stage)
  ) THEN
    RETURN NEW;
  END IF;

  -- Récupérer library_id et user_id depuis consultas_locais_v2
  SELECT cl.library_id, cl.user_id
    INTO v_library_id, v_user_id
  FROM public.consultas_locais_v2 cl
  WHERE cl.id = NEW.consulta_id;

  IF v_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Vérifier le flag macro biblio (local_consultation_enabled)
  IF v_library_id IS NOT NULL THEN
    SELECT lnp.local_consultation_enabled
      INTO v_local_consultation_enabled
    FROM public.library_notification_policies lnp
    WHERE lnp.library_id = v_library_id;
    v_local_consultation_enabled := COALESCE(v_local_consultation_enabled, true);
  END IF;

  IF NOT v_local_consultation_enabled THEN
    RETURN NEW;
  END IF;

  -- Vérifier le flag fin biblio (consulta_mail_agendada_enabled)
  IF v_library_id IS NOT NULL THEN
    SELECT lnp.consulta_mail_agendada_enabled
      INTO v_mail_enabled
    FROM public.library_notification_policies lnp
    WHERE lnp.library_id = v_library_id;
    v_mail_enabled := COALESCE(v_mail_enabled, true);
  END IF;

  IF NOT v_mail_enabled THEN
    RETURN NEW;
  END IF;

  -- Vérifier la préférence lectrice
  SELECT COALESCE(p.disable_consulta_pronta, false)
    INTO v_user_disabled
  FROM public.user_notification_preferences p
  WHERE p.user_id = v_user_id;
  v_user_disabled := COALESCE(v_user_disabled, false);

  IF v_user_disabled THEN
    RETURN NEW;
  END IF;

  -- Construire une référence courte
  v_consulta_ref := COALESCE(NEW.consulta_id::text, '?');

  -- Insertion in-app
  INSERT INTO public.user_notifications (
    user_id, library_id, category, title, body,
    link_type, link_id, is_read
  )
  VALUES (
    v_user_id,
    v_library_id,
    'consulta',
    'notif.consulta.agendada.title',
    'notif.consulta.agendada.body',
    'consulta',
    v_consulta_ref,
    false
  );

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.fn_replicate_consulta_agendada_to_inapp() IS
  'Chantier #CL.7 (31/05/2026). Trigger frère du e-mail : réplique in-app sur '
  'transition workflow_stage -> consulta_agendada (B2 action lectrice). '
  'Respecte les deux flags biblio que le mail + préférence lectrice.';

-- ──────────────────────────────────────────────────────────────────────
-- 7. Trigger frère sur consulta_item_workflow_v2
-- ──────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_replicate_consulta_agendada_inapp ON public.consulta_item_workflow_v2;

CREATE TRIGGER trg_replicate_consulta_agendada_inapp
  AFTER INSERT OR UPDATE ON public.consulta_item_workflow_v2
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_replicate_consulta_agendada_to_inapp();

-- ──────────────────────────────────────────────────────────────────────
-- 8. Vérification embarquée
-- ──────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  -- Table créée
  ASSERT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'user_notification_preferences'
  ), 'table user_notification_preferences manquante';

  -- RLS activée
  ASSERT (
    SELECT relrowsecurity FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'user_notification_preferences'
  ), 'RLS non activée sur user_notification_preferences';

  -- RPC get créée
  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_get_my_notification_preferences'
  ), 'fn_get_my_notification_preferences manquante';

  -- RPC set créée
  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_set_my_notification_preferences'
  ), 'fn_set_my_notification_preferences manquante';

  -- Fonction trigger reserva créée
  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_replicate_reserva_pronta_to_inapp'
  ), 'fn_replicate_reserva_pronta_to_inapp manquante';

  -- Trigger reserva attaché
  ASSERT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_replicate_reserva_pronta_inapp' AND NOT tgisinternal
  ), 'trigger trg_replicate_reserva_pronta_inapp non attaché';

  -- Fonction trigger consulta créée
  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_replicate_consulta_agendada_to_inapp'
  ), 'fn_replicate_consulta_agendada_to_inapp manquante';

  -- Trigger consulta attaché
  ASSERT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'trg_replicate_consulta_agendada_inapp' AND NOT tgisinternal
  ), 'trigger trg_replicate_consulta_agendada_inapp non attaché';

  -- Permissions authenticated sur les deux RPC
  ASSERT (
    SELECT COUNT(*) FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
      AND routine_name IN ('fn_get_my_notification_preferences', 'fn_set_my_notification_preferences')
      AND grantee = 'authenticated'
      AND privilege_type = 'EXECUTE'
  ) = 2, 'permissions authenticated manquantes sur les RPC préférences';

  -- Permissions table : authenticated NE DOIT PAS avoir d'accès direct (Scénario C)
  ASSERT NOT EXISTS (
    SELECT 1 FROM information_schema.table_privileges
    WHERE table_schema = 'public'
      AND table_name = 'user_notification_preferences'
      AND grantee = 'authenticated'
  ), 'authenticated ne doit pas avoir de GRANT direct sur user_notification_preferences (Scénario C)';

  -- service_role doit avoir ALL (pour debug/admin)
  ASSERT EXISTS (
    SELECT 1 FROM information_schema.table_privileges
    WHERE table_schema = 'public'
      AND table_name = 'user_notification_preferences'
      AND grantee = 'service_role'
  ), 'service_role doit avoir GRANT ALL sur user_notification_preferences';

  RAISE NOTICE 'OK : migration #CL.7 (préférences + réplique in-app) appliquée';
END $$;
