-- ============================================================================
-- Lot 4 — Crons de gouvernance (spec-gouvernance-roles.md)
-- ============================================================================
-- Date : 2026-05-07
-- Auteur : Xavier VAN WELDEN
-- ============================================================================
--
-- Cette migration ajoute 2 fonctions cron + 2 jobs pg_cron qui pilotent
-- automatiquement le cycle de vie des memberships staff (librarian /
-- coordenador) :
--
--   1. fn_cron_team_pending_removal_complete (horaire)
--      - Scanne user_library_memberships où pending_removal_until <= now()
--      - Finalise la retirada : status='removed', vide les champs pending_*
--      - Insère library_membership_audit (action='removal_completed')
--      - Insère team_notification_outbox (event 'team.removal_completed')
--      - Le handler domain/team.ts envoie alors le mail à l'usager·e + admin
--
--   2. fn_cron_team_inactive_cleanup (quotidien)
--      - Mesure l'inactivité via auth.users.last_sign_in_at
--      - 3 seuils :
--        * 240 jours (8 mois) → event 'team.inactive_warning_30d'
--        * 263 jours (8 mois 23 jours) → event 'team.inactive_warning_7d'
--        * 270 jours (9 mois) → status='inactive' + event 'team.inactive_completed'
--      - Anti-doublons : vérifie library_membership_audit pour ne pas réémettre
--        le même warning plusieurs fois pour le même membership
--
-- Note importante sur les rôles staff :
--   Le cron inactivité ne s'applique QUE aux rôles 'librarian' et 'coordenador'
--   (cf. user_library_memberships.role). Les memberships 'reader' ne sont pas
--   soumis à l'expiration pour inactivité (un·e lectrice peut très bien ne
--   pas se connecter pendant des années sans perdre sa qualité de lectrice).
--
--   Les administrateur·rices AnarBib (role='administrador') ne sont pas
--   non plus soumis·es à ce cron — leur rôle ne dépend pas d'une biblio
--   spécifique et leur révocation est un acte politique séparé.
-- ============================================================================

-- ─── Cron 1 : Pending removal complete ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_cron_team_pending_removal_complete()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_membership record;
  v_processed integer := 0;
  v_errors integer := 0;
  v_audit_id uuid;
  v_actor_id uuid;
  v_results jsonb := '[]'::jsonb;
BEGIN
  -- Boucle sur les memberships dont la carence a expiré
  FOR v_membership IN
    SELECT m.id, m.user_id, m.library_id, m.role, m.status,
           m.pending_removal_until, m.pending_removal_requested_by
    FROM public.user_library_memberships m
    WHERE m.pending_removal_until IS NOT NULL
      AND m.pending_removal_until <= now()
      AND m.status = 'active'
      AND m.role IN ('librarian', 'coordenador')
    ORDER BY m.pending_removal_until ASC
  LOOP
    BEGIN
      -- L'acteur·rice est celui·celle qui avait initié la retirada,
      -- avec fallback sur NULL si vidé entre-temps
      v_actor_id := v_membership.pending_removal_requested_by;

      -- 1. UPDATE le membership : status='removed', vider les champs pending
      UPDATE public.user_library_memberships
      SET status = 'removed',
          pending_removal_until = NULL,
          pending_removal_requested_by = NULL,
          updated_at = now()
      WHERE id = v_membership.id;

      -- 2. INSERT audit
      INSERT INTO public.library_membership_audit
        (library_id, target_user_id, actor_user_id,
         action, role, status_before, status_after, reason, metadata)
      VALUES
        (v_membership.library_id, v_membership.user_id, v_actor_id,
         'removal_completed', v_membership.role, 'active', 'removed',
         'Cron : prazo de 7 dias expirou sem anulação',
         jsonb_build_object(
           'cron_job', 'fn_cron_team_pending_removal_complete',
           'cron_run_at', now(),
           'pending_removal_until', v_membership.pending_removal_until
         ))
      RETURNING id INTO v_audit_id;

      -- 3. INSERT outbox event team.removal_completed
      INSERT INTO public.team_notification_outbox (event, payload)
      VALUES (
        'team.removal_completed',
        jsonb_build_object(
          'library_id', v_membership.library_id,
          'target_user_id', v_membership.user_id,
          'actor_user_id', v_actor_id,
          'audit_id', v_audit_id,
          'role', v_membership.role
        )
      );

      v_processed := v_processed + 1;
      v_results := v_results || jsonb_build_object(
        'membership_id', v_membership.id,
        'user_id', v_membership.user_id,
        'library_id', v_membership.library_id,
        'role', v_membership.role,
        'status', 'completed'
      );

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
    'cron_job', 'fn_cron_team_pending_removal_complete',
    'run_at', now(),
    'processed', v_processed,
    'errors', v_errors,
    'results', v_results
  );
END;
$$;

COMMENT ON FUNCTION public.fn_cron_team_pending_removal_complete() IS
'Lot 4 : finalise les retiradas dont la carence de 7 jours a expiré. '
'Appelé horairement par pg_cron. '
'Insère library_membership_audit + team_notification_outbox.';

GRANT EXECUTE ON FUNCTION public.fn_cron_team_pending_removal_complete() TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_cron_team_pending_removal_complete() FROM PUBLIC;

-- ─── Cron 2 : Inactive cleanup ──────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_cron_team_inactive_cleanup()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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
             'inactive_completed', v_membership.role, 'active', 'inactive',
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
            'team.inactive_completed',
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
            'action', 'inactive_completed',
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

COMMENT ON FUNCTION public.fn_cron_team_inactive_cleanup() IS
'Lot 4 : pilote le cycle de vie inactivité des memberships staff. '
'Quotidien. 3 seuils : 240j (warning 30d), 263j (warning 7d), 270j (passage inactif). '
'Anti-doublons via library_membership_audit.';

GRANT EXECUTE ON FUNCTION public.fn_cron_team_inactive_cleanup() TO postgres;
REVOKE EXECUTE ON FUNCTION public.fn_cron_team_inactive_cleanup() FROM PUBLIC;

-- ─── Schedule des jobs pg_cron ─────────────────────────────────────────────

-- Job 1 : Cron horaire — pending removal complete (à xx:00)
SELECT cron.schedule(
  'anarbib-team-pending-removal-complete',
  '0 * * * *',
  'SELECT public.fn_cron_team_pending_removal_complete();'
);

-- Job 2 : Cron quotidien — inactive cleanup (à 04:00 UTC)
SELECT cron.schedule(
  'anarbib-team-inactive-cleanup',
  '0 4 * * *',
  'SELECT public.fn_cron_team_inactive_cleanup();'
);

-- ─── Vérification ──────────────────────────────────────────────────────────

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'anarbib-team-pending-removal-complete'
  ) THEN
    RAISE EXCEPTION 'Échec : job anarbib-team-pending-removal-complete manquant';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'anarbib-team-inactive-cleanup'
  ) THEN
    RAISE EXCEPTION 'Échec : job anarbib-team-inactive-cleanup manquant';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'fn_cron_team_pending_removal_complete'
  ) THEN
    RAISE EXCEPTION 'Échec : fonction fn_cron_team_pending_removal_complete manquante';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_proc WHERE proname = 'fn_cron_team_inactive_cleanup'
  ) THEN
    RAISE EXCEPTION 'Échec : fonction fn_cron_team_inactive_cleanup manquante';
  END IF;

  RAISE NOTICE 'Lot 4 appliqué : 2 fonctions cron + 2 jobs pg_cron en place.';
END $$;
