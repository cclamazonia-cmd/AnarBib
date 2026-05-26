-- =============================================================================
-- Migration TM-D — chantier #153.B (corrections post-audit #153)
-- =============================================================================
-- Objet : aligner le cron fn_cron_team_inactive_cleanup sur la valeur
--         'inactive_auto' — la seule autorisée par la contrainte CHECK de
--         library_membership_audit pour le passage automatique en inactif.
--
-- Contexte (instruction du 26/05/2026) :
-- Le cron fn_cron_team_inactive_cleanup, dans son cas « 270 jours », écrit
-- deux choses lors d'un passage automatique en inactif :
--   (1) une ligne dans library_membership_audit avec action = 'inactive_completed'
--   (2) un event 'team.inactive_completed' dans team_notification_outbox
--
-- Or la contrainte CHECK library_membership_audit_action_check n'autorise PAS
-- 'inactive_completed' — elle autorise 'inactive_auto'. L'INSERT d'audit du
-- cas 270j est donc rejeté par la contrainte à chaque exécution.
--
-- Le cron enveloppe chaque membership dans un bloc BEGIN ... EXCEPTION WHEN
-- OTHERS : l'exception levée par la contrainte est avalée, le compteur
-- v_errors est incrémenté, la boucle continue. Le bug est donc SILENCIEUX —
-- aucun crash, aucune alerte. Comme l'UPDATE du statut (status = 'inactive')
-- et l'INSERT d'audit sont dans le même bloc, l'exception annule toute la
-- sous-transaction : le membership n'est ni passé en inactif, ni audité, ni
-- notifié. Le cas « passage automatique en inactif » est entièrement
-- inopérant depuis l'introduction de la contrainte.
--
-- Vérifié en base le 26/05/2026 : zéro ligne library_membership_audit avec
-- action 'inactive_completed' ou 'inactive_auto', zéro event
-- 'team.inactive_completed' / 'team.inactive_auto' dans l'outbox — le cas 270j
-- ne s'est jamais conclu. Aucune donnée à migrer : renommage de code pur.
--
-- Correction : renommer 'inactive_completed' en 'inactive_auto' aux trois
-- occurrences du cron —
--   (a) action d'audit (library_membership_audit.action) ;
--   (b) event de notification (team_notification_outbox.event) ;
--   (c) clé 'action' du jsonb de rapport v_results (cosmétique, par cohérence).
-- La contrainte CHECK autorisant déjà 'inactive_auto', l'INSERT d'audit passe
-- alors sans exception, et le cas 270j redevient opérant.
--
-- Volets hors de cette migration (livrés séparément, sous-tâche TM-D) :
--   - team.ts : événement 'team.inactive_completed' -> 'team.inactive_auto',
--     fonction handleInactiveCompleted -> handleInactiveAuto.
--   - mail-strings.ts : clés team.inactive_completed.* -> team.inactive_auto.*
--   Les trois fichiers (cette migration + team.ts + mail-strings.ts) forment
--   un tout : l'event émis par le cron doit correspondre à ce que le handler
--   route et aux clés i18n résolues.
--
-- La contrainte CHECK library_membership_audit_action_check n'est PAS modifiée
-- par cette migration : elle autorise déjà 'inactive_auto'.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Reproduction intégrale de fn_cron_team_inactive_cleanup (dump 26/05/2026)
-- -----------------------------------------------------------------------------
-- À l'identique, à trois exceptions près, toutes dans le cas « 270 jours » :
--   (a) action d'audit : 'inactive_completed' -> 'inactive_auto'
--   (b) event outbox   : 'team.inactive_completed' -> 'team.inactive_auto'
--   (c) clé v_results  : 'inactive_completed' -> 'inactive_auto'
-- Les cas 263j (warning 7d) et 240j (warning 30d) sont inchangés.

CREATE OR REPLACE FUNCTION public.fn_cron_team_inactive_cleanup() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_membership record;
  v_processed_warn30 integer := 0;
  v_processed_warn7 integer := 0;
  v_processed_completed integer := 0;
  v_errors integer := 0;
  v_audit_id uuid;
  v_results jsonb := '[]'::jsonb;
  v_already_warned boolean;
BEGIN
  -- Boucle sur les memberships staff actifs avec leur dernière activité
  FOR v_membership IN
    SELECT m.id, m.user_id, m.library_id, m.role, m.status, m.created_at,
           GREATEST(
             COALESCE(u.last_sign_in_at, m.created_at),
             m.created_at
           ) AS last_active_at
    FROM public.user_library_memberships m
    JOIN auth.users u ON u.id = m.user_id
    WHERE m.role IN ('librarian', 'coordenador')
      AND m.status = 'active'
    ORDER BY m.id
  LOOP
    BEGIN
      -- Calcul du nombre de jours d'inactivité
      DECLARE
        v_days_inactive integer;
      BEGIN
        v_days_inactive := EXTRACT(DAY FROM now() - v_membership.last_active_at)::integer;

        -- Cas 1 : 270 jours (9 mois) → passage en inactif
        IF v_days_inactive >= 270 THEN
          UPDATE public.user_library_memberships
          SET status = 'inactive', updated_at = now()
          WHERE id = v_membership.id;

          INSERT INTO public.library_membership_audit
            (library_id, target_user_id, actor_user_id,
             action, role, status_before, status_after, reason, metadata)
          VALUES
            (v_membership.library_id, v_membership.user_id, NULL,
             'inactive_auto', v_membership.role, 'active', 'inactive',
             format('Cron : %s dias sem conexão (>= 270)', v_days_inactive),
             jsonb_build_object(
               'cron_job', 'fn_cron_team_inactive_cleanup',
               'cron_run_at', now(),
               'days_inactive', v_days_inactive,
               'last_active_at', v_membership.last_active_at
             ))
          RETURNING id INTO v_audit_id;

          INSERT INTO public.team_notification_outbox (event, payload)
          VALUES (
            'team.inactive_auto',
            jsonb_build_object(
              'library_id', v_membership.library_id,
              'target_user_id', v_membership.user_id,
              'actor_user_id', NULL,
              'audit_id', v_audit_id,
              'role', v_membership.role
            )
          );

          v_processed_completed := v_processed_completed + 1;
          v_results := v_results || jsonb_build_object(
            'membership_id', v_membership.id,
            'action', 'inactive_auto',
            'days_inactive', v_days_inactive
          );

        -- Cas 2 : 263 jours → warning 7d (anti-doublon : pas déjà warned 7d)
        ELSIF v_days_inactive >= 263 THEN
          SELECT EXISTS (
            SELECT 1 FROM public.library_membership_audit
            WHERE target_user_id = v_membership.user_id
              AND library_id = v_membership.library_id
              AND action = 'inactive_warning_7d'
              AND created_at >= now() - interval '14 days'
          ) INTO v_already_warned;

          IF NOT v_already_warned THEN
            INSERT INTO public.library_membership_audit
              (library_id, target_user_id, actor_user_id,
               action, role, status_before, status_after, reason, metadata)
            VALUES
              (v_membership.library_id, v_membership.user_id, NULL,
               'inactive_warning_7d', v_membership.role, 'active', 'active',
               format('Cron : %s dias sem conexão (>= 263)', v_days_inactive),
               jsonb_build_object(
                 'cron_job', 'fn_cron_team_inactive_cleanup',
                 'cron_run_at', now(),
                 'days_inactive', v_days_inactive,
                 'last_active_at', v_membership.last_active_at,
                 'deadline', now() + interval '7 days'
               ))
            RETURNING id INTO v_audit_id;

            INSERT INTO public.team_notification_outbox (event, payload)
            VALUES (
              'team.inactive_warning_7d',
              jsonb_build_object(
                'library_id', v_membership.library_id,
                'target_user_id', v_membership.user_id,
                'actor_user_id', NULL,
                'audit_id', v_audit_id,
                'role', v_membership.role,
                'deadline', (now() + interval '7 days')::text
              )
            );

            v_processed_warn7 := v_processed_warn7 + 1;
            v_results := v_results || jsonb_build_object(
              'membership_id', v_membership.id,
              'action', 'inactive_warning_7d',
              'days_inactive', v_days_inactive
            );
          END IF;

        -- Cas 3 : 240 jours → warning 30d (anti-doublon : pas déjà warned 30d)
        ELSIF v_days_inactive >= 240 THEN
          SELECT EXISTS (
            SELECT 1 FROM public.library_membership_audit
            WHERE target_user_id = v_membership.user_id
              AND library_id = v_membership.library_id
              AND action = 'inactive_warning_30d'
              AND created_at >= now() - interval '60 days'
          ) INTO v_already_warned;

          IF NOT v_already_warned THEN
            INSERT INTO public.library_membership_audit
              (library_id, target_user_id, actor_user_id,
               action, role, status_before, status_after, reason, metadata)
            VALUES
              (v_membership.library_id, v_membership.user_id, NULL,
               'inactive_warning_30d', v_membership.role, 'active', 'active',
               format('Cron : %s dias sem conexão (>= 240)', v_days_inactive),
               jsonb_build_object(
                 'cron_job', 'fn_cron_team_inactive_cleanup',
                 'cron_run_at', now(),
                 'days_inactive', v_days_inactive,
                 'last_active_at', v_membership.last_active_at,
                 'deadline', now() + interval '30 days'
               ))
            RETURNING id INTO v_audit_id;

            INSERT INTO public.team_notification_outbox (event, payload)
            VALUES (
              'team.inactive_warning_30d',
              jsonb_build_object(
                'library_id', v_membership.library_id,
                'target_user_id', v_membership.user_id,
                'actor_user_id', NULL,
                'audit_id', v_audit_id,
                'role', v_membership.role,
                'deadline', (now() + interval '30 days')::text
              )
            );

            v_processed_warn30 := v_processed_warn30 + 1;
            v_results := v_results || jsonb_build_object(
              'membership_id', v_membership.id,
              'action', 'inactive_warning_30d',
              'days_inactive', v_days_inactive
            );
          END IF;
        END IF;
      END;

    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors + 1;
      v_results := v_results || jsonb_build_object(
        'membership_id', v_membership.id,
        'status', 'error',
        'sqlerrm', SQLERRM,
        'sqlstate', SQLSTATE
      );
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'cron_job', 'fn_cron_team_inactive_cleanup',
    'run_at', now(),
    'processed_warn30', v_processed_warn30,
    'processed_warn7', v_processed_warn7,
    'processed_completed', v_processed_completed,
    'errors', v_errors,
    'results', v_results
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- Vérification en fin de transaction
-- -----------------------------------------------------------------------------
-- RAISE EXCEPTION ici => rollback automatique de toute la migration.

DO $verify$
DECLARE
  v_src text;
BEGIN
  -- La fonction doit toujours exister.
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'fn_cron_team_inactive_cleanup'
      AND pronamespace = 'public'::regnamespace
  ) THEN
    RAISE EXCEPTION 'TM-D : fn_cron_team_inactive_cleanup introuvable après migration.';
  END IF;

  -- Le corps ne doit plus contenir 'inactive_completed' ...
  SELECT pg_get_functiondef('public.fn_cron_team_inactive_cleanup()'::regprocedure)
    INTO v_src;
  IF v_src LIKE '%inactive_completed%' THEN
    RAISE EXCEPTION 'TM-D : le corps du cron contient encore inactive_completed.';
  END IF;
  -- ... et doit bien contenir 'inactive_auto' et 'team.inactive_auto'.
  IF v_src NOT LIKE '%inactive_auto%' THEN
    RAISE EXCEPTION 'TM-D : le corps du cron ne contient pas inactive_auto.';
  END IF;
  IF v_src NOT LIKE '%team.inactive_auto%' THEN
    RAISE EXCEPTION 'TM-D : le corps du cron ne contient pas l''event team.inactive_auto.';
  END IF;

  -- La contrainte CHECK doit autoriser 'inactive_auto' (inchangée, on vérifie).
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'library_membership_audit_action_check'
      AND pg_get_constraintdef(oid) LIKE '%inactive_auto%'
  ) THEN
    RAISE EXCEPTION 'TM-D : la contrainte n''autorise pas inactive_auto — incohérence.';
  END IF;

  RAISE NOTICE 'TM-D : migration vérifiée — cron aligné sur inactive_auto, contrainte cohérente.';
END;
$verify$;
