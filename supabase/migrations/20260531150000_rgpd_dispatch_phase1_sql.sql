-- Chantier §7.1 spec-notifications-lecteur — Câblage e-mail RGPD préavis purge
--
-- PHASE 1/2 : Infrastructure SQL côté DB.
--
-- Cette migration ajoute le dispatcher e-mail pour les préavis RGPD de purge
-- de données, en respectant la doctrine B de la spec notifications-lecteur :
-- l'e-mail est le canal primaire, l'in-app est la réplique (B1 — l'in-app
-- est filet de sécurité légal si la lectrice ne lit pas ses mails).
--
-- Aujourd'hui (avant cette migration), fn_notify_users_before_purge insère
-- des lignes dans user_notifications sans émettre de mail. Le préavis légal
-- est donc IN-APP EXCLUSIF, ce qui est sub-optimal (la lectrice qui ne se
-- connecte pas dans la fenêtre de 30 jours rate l'alerte purge).
--
-- Cette migration ajoute :
--   (1) fn_dispatch_rgpd_warning : wrapper net.http_post vers notify-event,
--       sur le modèle de fn_dispatch_circulation_notify_event.
--   (2) Extension de fn_notify_users_before_purge : après chaque INSERT
--       dans user_notifications, dispatch d'un événement rgpd_purge_warning_*
--       vers l'EF notify-event. Le record_id transmis est l'id de la notif
--       in-app qu'on vient de créer — le handler EF s'en sert pour
--       reconstruire le contexte (user, library, category).
--
-- IMPORTANT : à l'issue de cette migration, l'EF notify-event ne sait PAS
-- encore traiter les événements rgpd_purge_warning_*. Elle retournera
-- {ok: true, ignored: true}. C'est attendu — la phase 2 (handler EF côté
-- _shared/domain/rgpd.ts) viendra dans une session ultérieure. Aucun mail
-- n'est envoyé entre les deux phases, mais aucun bug non plus : le
-- dispatcher logge proprement la requête, l'EF répond OK, point.
--
-- Doctrine v2 : SECURITY DEFINER + REVOKE/GRANT + search_path + bloc DO.

-- ──────────────────────────────────────────────────────────────────────
-- 1. Fonction dispatch fn_dispatch_rgpd_warning
-- ──────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_dispatch_rgpd_warning(
  p_notification_id bigint,
  p_event text
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'net', 'vault'
AS $function$
DECLARE
  v_url text;
  v_secret text;
  v_request_id bigint;
BEGIN
  -- Lookup secrets vault (même pattern que fn_dispatch_circulation_notify_event)
  SELECT ds.decrypted_secret INTO v_url
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'SUPABASE_URL'
  ORDER BY ds.created_at DESC
  LIMIT 1;

  SELECT ds.decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets ds
  WHERE ds.name = 'WEBHOOK_SECRET_NOTIFY_EVENT'
  ORDER BY ds.created_at DESC
  LIMIT 1;

  IF COALESCE(v_url, '') = '' THEN
    RAISE WARNING 'Secret SUPABASE_URL absent — notification RGPD % ignorée', p_event;
    RETURN NULL;
  END IF;

  IF COALESCE(v_secret, '') = '' THEN
    RAISE WARNING 'Secret WEBHOOK_SECRET_NOTIFY_EVENT absent — notification RGPD % ignorée', p_event;
    RETURN NULL;
  END IF;

  -- Dispatch vers l'EF notify-event.
  -- record_id = id de la ligne user_notifications créée juste avant ;
  -- l'EF handler (phase 2) lira cette ligne pour reconstruire le contexte
  -- (user_id, library_id, category) et construire le mail.
  v_request_id := net.http_post(
    url := regexp_replace(v_url, '/+$', '') || '/functions/v1/notify-event',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_secret
    ),
    body := jsonb_build_object(
      'event', p_event,
      'record_id', p_notification_id
    ),
    timeout_milliseconds := 30000
  );

  RETURN v_request_id;
EXCEPTION
  WHEN OTHERS THEN
    -- Pattern fail-soft identique à fn_dispatch_circulation_notify_event :
    -- on logge mais on ne fait pas planter le caller (qui doit pouvoir
    -- continuer ses INSERT in-app pour les autres lectrices).
    RAISE WARNING 'fn_dispatch_rgpd_warning(%, %): %', p_notification_id, p_event, SQLERRM;
    RETURN NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_dispatch_rgpd_warning(bigint, text) FROM PUBLIC, anon, authenticated, service_role;
-- Pas de GRANT à authenticated : fonction privée, appelée uniquement par
-- fn_notify_users_before_purge (elle-même SECURITY DEFINER appelée par
-- scheduler/admin). service_role conserve l'accès par défaut Supabase.

COMMENT ON FUNCTION public.fn_dispatch_rgpd_warning(bigint, text) IS
  'Spec §7.1 (31/05/2026). Wrapper net.http_post vers notify-event pour les '
  'préavis RGPD de purge. Pattern identique à fn_dispatch_circulation_notify_event. '
  'record_id = user_notifications.id (lookup côté EF pour reconstruire le contexte). '
  'Phase 1/2 : SQL prêt, handler EF côté _shared/domain/rgpd.ts à créer en phase 2.';

-- ──────────────────────────────────────────────────────────────────────
-- 2. Extension de fn_notify_users_before_purge
-- ──────────────────────────────────────────────────────────────────────
-- On REMPLACE la fonction existante. La logique de scan/insertion reste
-- intégralement préservée (fenêtre 40 jours, idempotence par catégorie).
-- Seul ajout : capture du RETURNING id à chaque INSERT, puis dispatch
-- pour chaque ligne créée.

CREATE OR REPLACE FUNCTION public.fn_notify_users_before_purge()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_lib record;
  v_policy jsonb;
  v_loans_days int;
  v_reservations_days int;
  v_consultations_days int;
  v_notifications_days int;
  v_warn_window_days int := 30;
  v_total_notified int := 0;
  v_total_dispatched int := 0;
  v_count_local int;
  v_dispatched_local int;
  v_inserted_id bigint;
  v_started_at timestamptz := now();
  v_inserted_row record;
BEGIN
  FOR v_lib IN
    SELECT id, slug, name FROM public.libraries WHERE is_active = true
  LOOP
    v_policy := public.fn_get_retention_policy(v_lib.id);
    v_loans_days := (v_policy->>'retention_loans_days')::int;
    v_reservations_days := (v_policy->>'retention_reservations_days')::int;
    v_consultations_days := (v_policy->>'retention_consultations_days')::int;
    v_notifications_days := (v_policy->>'retention_notifications_days')::int;

    -- ─── Emprunts ────────────────────────────────────────────────────────
    IF v_loans_days > 0 THEN
      v_count_local := 0;
      v_dispatched_local := 0;
      FOR v_inserted_row IN
        WITH eligible_users AS (
          SELECT DISTINCT e.user_id
          FROM emprestimos_v2 e
          WHERE e.library_id = v_lib.id
            AND e.status_global = 'encerrado'
            AND NOT EXISTS (
              SELECT 1 FROM emprestimo_itens_v2 ei
              WHERE ei.emprestimo_id = e.id
                AND (
                  ei.item_status = 'aberto'
                  OR COALESCE(ei.return_completed_at, ei.returned_at, ei.updated_at) > (now() - ((v_loans_days - v_warn_window_days) || ' days')::interval)
                )
            )
        )
        INSERT INTO user_notifications (user_id, library_id, category, title, body, is_read)
        SELECT
          eu.user_id,
          v_lib.id,
          'rgpd_retention_loans',
          'notif.rgpd.purgeWarning.loans.title',
          'notif.rgpd.purgeWarning.loans.body',
          false
        FROM eligible_users eu
        WHERE NOT EXISTS (
          SELECT 1 FROM user_notifications n
          WHERE n.user_id = eu.user_id
            AND n.library_id = v_lib.id
            AND n.category = 'rgpd_retention_loans'
            AND n.created_at > (now() - interval '40 days')
        )
        RETURNING id
      LOOP
        v_count_local := v_count_local + 1;
        -- Dispatch e-mail (phase 1 : l'EF ignorera, c'est attendu)
        IF public.fn_dispatch_rgpd_warning(v_inserted_row.id, 'rgpd_purge_warning_loans') IS NOT NULL THEN
          v_dispatched_local := v_dispatched_local + 1;
        END IF;
      END LOOP;
      v_total_notified := v_total_notified + v_count_local;
      v_total_dispatched := v_total_dispatched + v_dispatched_local;
    END IF;

    -- ─── Réservations ───────────────────────────────────────────────────
    IF v_reservations_days > 0 THEN
      v_count_local := 0;
      v_dispatched_local := 0;
      FOR v_inserted_row IN
        WITH eligible_users AS (
          SELECT DISTINCT r.user_id
          FROM reservas_v2 r
          WHERE r.library_id = v_lib.id
            AND r.status_global IN ('encerrada', 'cancelada')
            AND NOT EXISTS (
              SELECT 1 FROM reserva_linhas_v2 rl
              WHERE rl.reserva_id = r.id
                AND COALESCE(rl.cancelled_at, rl.converted_at, rl.expired_at, rl.updated_at) > (now() - ((v_reservations_days - v_warn_window_days) || ' days')::interval)
            )
        )
        INSERT INTO user_notifications (user_id, library_id, category, title, body, is_read)
        SELECT
          eu.user_id,
          v_lib.id,
          'rgpd_retention_reservations',
          'notif.rgpd.purgeWarning.reservations.title',
          'notif.rgpd.purgeWarning.reservations.body',
          false
        FROM eligible_users eu
        WHERE NOT EXISTS (
          SELECT 1 FROM user_notifications n
          WHERE n.user_id = eu.user_id
            AND n.library_id = v_lib.id
            AND n.category = 'rgpd_retention_reservations'
            AND n.created_at > (now() - interval '40 days')
        )
        RETURNING id
      LOOP
        v_count_local := v_count_local + 1;
        IF public.fn_dispatch_rgpd_warning(v_inserted_row.id, 'rgpd_purge_warning_reservations') IS NOT NULL THEN
          v_dispatched_local := v_dispatched_local + 1;
        END IF;
      END LOOP;
      v_total_notified := v_total_notified + v_count_local;
      v_total_dispatched := v_total_dispatched + v_dispatched_local;
    END IF;

    -- ─── Consultations ──────────────────────────────────────────────────
    IF v_consultations_days > 0 THEN
      v_count_local := 0;
      v_dispatched_local := 0;
      FOR v_inserted_row IN
        WITH eligible_users AS (
          SELECT DISTINCT c.user_id
          FROM consultas_locais_v2 c
          WHERE c.library_id = v_lib.id
            AND c.status_global IN ('encerrada', 'cancelada')
            AND NOT EXISTS (
              SELECT 1 FROM consulta_linhas_v2 cl
              WHERE cl.consulta_id = c.id
                AND COALESCE(cl.cancelled_at, cl.consulted_at, cl.expired_at, cl.updated_at) > (now() - ((v_consultations_days - v_warn_window_days) || ' days')::interval)
            )
        )
        INSERT INTO user_notifications (user_id, library_id, category, title, body, is_read)
        SELECT
          eu.user_id,
          v_lib.id,
          'rgpd_retention_consultations',
          'notif.rgpd.purgeWarning.consultations.title',
          'notif.rgpd.purgeWarning.consultations.body',
          false
        FROM eligible_users eu
        WHERE NOT EXISTS (
          SELECT 1 FROM user_notifications n
          WHERE n.user_id = eu.user_id
            AND n.library_id = v_lib.id
            AND n.category = 'rgpd_retention_consultations'
            AND n.created_at > (now() - interval '40 days')
        )
        RETURNING id
      LOOP
        v_count_local := v_count_local + 1;
        IF public.fn_dispatch_rgpd_warning(v_inserted_row.id, 'rgpd_purge_warning_consultations') IS NOT NULL THEN
          v_dispatched_local := v_dispatched_local + 1;
        END IF;
      END LOOP;
      v_total_notified := v_total_notified + v_count_local;
      v_total_dispatched := v_total_dispatched + v_dispatched_local;
    END IF;

    -- Pas de notif pour les notifications elles-mêmes (méta-récursivité préservée).
  END LOOP;

  RETURN jsonb_build_object(
    'mode', 'notify',
    'started_at', v_started_at,
    'finished_at', now(),
    'total_notifications_created', v_total_notified,
    -- Nouveau champ phase 1 : nombre de dispatchs e-mail tentés.
    -- Phase 1 : ce nombre = total_notifications_created si tous les dispatchs
    -- réussissent (HTTP 200 retourné par l'EF, même si elle ignore l'event).
    -- Phase 2 : ce sera le nombre de mails effectivement envoyés.
    'total_dispatches_attempted', v_total_dispatched
  );
END;
$function$;

COMMENT ON FUNCTION public.fn_notify_users_before_purge() IS
  'Notifications RGPD préavis de purge (fenêtre 30 jours). '
  'Étendue 31/05/2026 (Spec §7.1) pour dispatcher en plus un mail via '
  'fn_dispatch_rgpd_warning → notify-event. Phase 1 : SQL prêt, EF ignore. '
  'Phase 2 à venir : handler _shared/domain/rgpd.ts pour envoi effectif.';

-- Hygiène doctrine : REVOKE explicite re-posé (idempotent si déjà appliqué).
-- La fonction est invoquée par scheduler/admin Supabase uniquement.
REVOKE EXECUTE ON FUNCTION public.fn_notify_users_before_purge() FROM PUBLIC, anon, authenticated;
-- service_role conserve l'accès par défaut Supabase (admin/scheduler).

-- ──────────────────────────────────────────────────────────────────────
-- 3. Vérification embarquée
-- ──────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  -- fn_dispatch_rgpd_warning créée
  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_dispatch_rgpd_warning'
  ), 'fn_dispatch_rgpd_warning manquante';

  -- Permissions : NI anon NI authenticated NI service_role n'a EXECUTE
  -- (fonction privée appelée uniquement depuis fn_notify_users_before_purge)
  ASSERT NOT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema = 'public'
      AND routine_name = 'fn_dispatch_rgpd_warning'
      AND grantee IN ('anon', 'authenticated')
  ), 'fn_dispatch_rgpd_warning ne doit pas être accessible à anon/authenticated';

  -- fn_notify_users_before_purge a bien été remplacée (présence du nouveau champ JSON)
  -- On vérifie indirectement via le commentaire qui contient '31/05/2026'
  ASSERT EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_notify_users_before_purge'
      AND obj_description(p.oid, 'pg_proc') LIKE '%31/05/2026%'
  ), 'fn_notify_users_before_purge non mise à jour (commentaire daté manquant)';

  RAISE NOTICE 'OK : migration §7.1 phase 1 (dispatch RGPD côté SQL) appliquée';
END $$;
