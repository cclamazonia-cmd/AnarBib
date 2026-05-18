-- =============================================================================
-- Chantier #150 — Audit sécurité fonctions privées
-- Sous-paquet SP2 : REVOKE EXECUTE sur helpers internes notifications / cron /
--                   recompute / refresh / log (Cat 3 — 16 fonctions)
--                 + patch trigger non-DEFINER tg_enqueue_task_level_*
-- =============================================================================
-- Doctrine de référence :
--   docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
-- Découverte 17/05/2026 (B.4) :
--   ALTER DEFAULT PRIVILEGES Supabase grant EXECUTE TO anon/authenticated/
--   service_role automatiquement sur public.functions. REVOKE FROM PUBLIC
--   seul ne suffit pas.
--
-- Périmètre SP2 (16 fonctions Cat 3) :
--   Notifications & enqueue (helpers internes sans garde RBAC) :
--     - enqueue_task_level_notifications_from_task
--     - fn_dispatch_circulation_notify_event
--     - fn_enqueue_library_request_notification
--     - fn_enqueue_document_permission_request_notification
--     - fn_enqueue_emprestimo_interbibliotecas_notification
--     - fn_notify_emprestimo_interbibliotecas_webhook
--   Cron (postgres only) :
--     - fn_cron_cooptation_send_reminders
--   Helpers recompute (appelés par RPC SECURITY DEFINER) :
--     - fn_v2_recompute_from_emprestimo_interbibliotecas_linhas
--     - fn_v2_recompute_from_emprestimo_lines
--     - fn_v2_recompute_from_reserva_lines
--     - fn_v2_recompute_holdings_availability
--   Helpers refresh status_global (appelés par RPC SECURITY DEFINER) :
--     - fn_v2_refresh_consulta_status_global
--     - fn_v2_refresh_emprestimo_interbibliotecas_status_global
--     - fn_v2_refresh_emprestimo_status_global
--     - fn_v2_refresh_reserva_status_global
--   Log audit interne :
--     - fn_v2_log_emprestimo_interbibliotecas_event
--
-- Justification politique :
--   Toutes ces fonctions sont des helpers internes appelés UNIQUEMENT par
--   d'autres SECURITY DEFINER (RPC frontend, triggers, jobs cron). Un appel
--   depuis l'intérieur d'une SECURITY DEFINER s'exécute en postgres (rôle
--   propriétaire), donc le REVOKE FROM authenticated/service_role n'affecte
--   pas les call sites légitimes. Recensement complet effectué le 18/05 :
--   60 callers détectés, tous SECURITY DEFINER, 0 caller HTTP direct
--   (greps frontend + Edge Functions effectués 18/05 → 4 hits, tous
--   commentaires de documentation).
--
-- Cas particulier : enqueue_task_level_notifications_from_task
--   Caller unique : trigger tg_enqueue_task_level_notifications_from_task,
--   actuellement NON-SECURITY DEFINER. Si on REVOKE sans patcher, le trigger
--   échouera (permission denied) au prochain INSERT/UPDATE sur
--   painel_internal_tasks par un user authenticated.
--   Fix : ALTER FUNCTION tg_enqueue_task_level_notifications_from_task()
--         SECURITY DEFINER avant le REVOKE.
-- =============================================================================

BEGIN;

-- =============================================================================
-- ÉTAPE 1 — Patch trigger non-DEFINER (prérequis du REVOKE)
-- =============================================================================
-- Le trigger tg_enqueue_task_level_notifications_from_task doit pouvoir
-- continuer à appeler enqueue_task_level_notifications_from_task même après
-- le REVOKE. La transition non-DEFINER → DEFINER permet l'invocation
-- transparente depuis n'importe quel contexte de trigger.

ALTER FUNCTION public.tg_enqueue_task_level_notifications_from_task()
  SECURITY DEFINER;

-- Fixation du search_path (doctrine) — ALTER ne le pose pas tout seul
ALTER FUNCTION public.tg_enqueue_task_level_notifications_from_task()
  SET search_path TO 'public', 'pg_temp';

-- =============================================================================
-- ÉTAPE 2 — REVOKE EXECUTE étendus
-- =============================================================================

-- Notifications & enqueue helpers
REVOKE EXECUTE ON FUNCTION public.enqueue_task_level_notifications_from_task(uuid, text, text[])
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_dispatch_circulation_notify_event(text, bigint, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_enqueue_library_request_notification(uuid, text, text, uuid)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_enqueue_document_permission_request_notification(uuid, text, text, uuid)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_enqueue_emprestimo_interbibliotecas_notification(bigint, text, text, uuid)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_notify_emprestimo_interbibliotecas_webhook(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

-- Cron (postgres only)
REVOKE EXECUTE ON FUNCTION public.fn_cron_cooptation_send_reminders()
  FROM PUBLIC, anon, authenticated, service_role;

-- Helpers recompute
REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_from_emprestimo_interbibliotecas_linhas(bigint, integer[])
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_from_emprestimo_lines(bigint, integer[])
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_from_reserva_lines(bigint, integer[])
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_v2_recompute_holdings_availability(bigint[], bigint[])
  FROM PUBLIC, anon, authenticated, service_role;

-- Helpers refresh status_global
REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_consulta_status_global(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_interbibliotecas_status_global(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_emprestimo_status_global(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_v2_refresh_reserva_status_global(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

-- Log audit interne
REVOKE EXECUTE ON FUNCTION public.fn_v2_log_emprestimo_interbibliotecas_event(bigint, bigint, text, text, jsonb)
  FROM PUBLIC, anon, authenticated, service_role;

-- =============================================================================
-- ÉTAPE 3 — DO-block de vérification
-- =============================================================================

DO $verif$
DECLARE
  v_remaining_exposure int;
  v_target_functions text[] := ARRAY[
    'enqueue_task_level_notifications_from_task',
    'fn_dispatch_circulation_notify_event',
    'fn_enqueue_library_request_notification',
    'fn_enqueue_document_permission_request_notification',
    'fn_enqueue_emprestimo_interbibliotecas_notification',
    'fn_notify_emprestimo_interbibliotecas_webhook',
    'fn_cron_cooptation_send_reminders',
    'fn_v2_recompute_from_emprestimo_interbibliotecas_linhas',
    'fn_v2_recompute_from_emprestimo_lines',
    'fn_v2_recompute_from_reserva_lines',
    'fn_v2_recompute_holdings_availability',
    'fn_v2_refresh_consulta_status_global',
    'fn_v2_refresh_emprestimo_interbibliotecas_status_global',
    'fn_v2_refresh_emprestimo_status_global',
    'fn_v2_refresh_reserva_status_global',
    'fn_v2_log_emprestimo_interbibliotecas_event'
  ];
  v_critical_rpc_frontend text[] := ARRAY[
    -- RPC consultas v2 (callers de fn_v2_refresh_consulta_status_global)
    'fn_v2_create_consulta_local_by_holdings',
    'fn_v2_cancel_consulta_linhas_as_leitor',
    'fn_v2_set_consulta_linhas_workflow',
    'fn_v2_set_consulta_linhas_workflow_slot',
    -- RPC emprunts v2 (callers de fn_v2_refresh_emprestimo_status_global)
    'fn_v2_create_emprestimo_by_holdings',
    'fn_v2_return_emprestimo_linhas',
    'fn_v2_return_emprestimo_total',
    'fn_v2_extend_emprestimo_once',
    'fn_renew_my_loan',
    -- RPC réservations v2 (callers de fn_v2_refresh_reserva_status_global)
    'fn_v2_create_reserva_by_holdings',
    'fn_v2_cancel_reserva_linhas_as_biblioteca',
    'fn_v2_cancel_reserva_linhas_as_leitor',
    'fn_v2_set_reserva_linhas_workflow',
    'fn_v2_convert_reserva_linhas_to_emprestimo',
    -- RPC notifications "_now" (callers d'enqueue_*)
    'fn_notify_library_request_now',
    'fn_notify_document_permission_request_now'
  ];
  v_rpc_regression_count int;
  v_trigger_secdef boolean;
BEGIN
  -- Test 1 : aucune fonction Cat 3 SP2 ne doit plus être exposée à un rôle applicatif
  SELECT count(*) INTO v_remaining_exposure
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = ANY(v_target_functions)
    AND (
         has_function_privilege('public', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('service_role', p.oid, 'EXECUTE')
    );

  IF v_remaining_exposure > 0 THEN
    RAISE EXCEPTION 'SP2_VERIF_FAIL_1 : % fonctions Cat 3 sont encore exposees a un role applicatif',
      v_remaining_exposure;
  END IF;

  -- Test 2 : non-régression — les RPC frontend critiques doivent rester
  -- accessibles à authenticated (sinon notre REVOKE a touché trop large)
  SELECT count(*) INTO v_rpc_regression_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = ANY(v_critical_rpc_frontend)
    AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_rpc_regression_count > 0 THEN
    RAISE EXCEPTION 'SP2_VERIF_FAIL_2 : % RPC frontend critiques ne sont PLUS accessibles a authenticated (regression)',
      v_rpc_regression_count;
  END IF;

  -- Test 3 : confirmer que tg_enqueue_task_level_notifications_from_task est bien SECURITY DEFINER maintenant
  SELECT prosecdef INTO v_trigger_secdef
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'tg_enqueue_task_level_notifications_from_task';

  IF v_trigger_secdef IS NOT TRUE THEN
    RAISE EXCEPTION 'SP2_VERIF_FAIL_3 : tg_enqueue_task_level_notifications_from_task n est PAS SECURITY DEFINER (le REVOKE va casser les triggers INSERT/UPDATE sur painel_internal_tasks)';
  END IF;

  RAISE NOTICE 'SP2_OK : isolation effective sur 16 fonctions Cat 3 (notifications/cron/recompute/refresh/log v2) + tg_enqueue_task_level patche en SECURITY DEFINER';
END
$verif$;

COMMIT;
