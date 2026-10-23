-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — la rétention a des plafonds et une purge complète (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- RET-2 — Les durées qu'une bibliothèque règle elle-même ont un plafond réseau,
-- égal aux défauts actuels : prêts 730 jours, réservations 365, consultations
-- 365, notifications lues 90. Zéro n'est plus admis (il valait « jamais »).
-- Le plafond tient à deux endroits : une CHECK sur library_retention_policies
-- et les bornes de fn_set_retention_policy (corps repris de la définition
-- RÉELLE en production le 23/10/2026, seules les bornes changent).
--
-- RET-3 — Ce qui n'avait aucune durée en reçoit une :
--   notifications non lues ........ 12 mois après leur création (réseau compris) ;
--   notifications du réseau lues .. 90 jours après lecture ;
--   courriers sortants ............ 90 jours après envoi, renoncement ou abandon ;
--   signalements de bug ........... l'adresse s'efface à la clôture, la ligne
--                                   12 mois après ;
--   PEB et ses événements ......... la durée des prêts de la bibliothèque
--                                   prêteuse, comptée depuis la clôture ;
--   messagerie lectorat ↔ biblio .. 12 mois après le dernier message de l'échange ;
--   lectures en cours, envies ..... 24 mois sans connexion du compte ;
--   journal du double facteur ..... 12 mois ;
--   journaux d'actions du réseau .. 12 mois (actions inter-bibliothèques,
--                                   audit et validations d'adhésion, événements
--                                   d'adhésion, événements de notification).
-- Le journal de l'administration du réseau (network_administrator_audit :
-- cooptations, retraits) reste : il appartient à l'assemblée. La
-- correspondance entre bibliothèques et les cotisations attendent RET-4.
--
-- La purge est une fonction NEUVE, public.fn_purge_retention(p_dry_run), que
-- rien n'appelle encore : le cron hebdomadaire garde fn_purge_expired_data.
-- L'essai à blanc passe par le même code que la purge réelle — mêmes
-- suppressions, mêmes cascades — dans une sous-transaction annulée ensuite.
-- Il parcourt toutes les bibliothèques, actives ou non.
--
-- Le journal inter-bibliothèques reste inaltérable, sauf pour la purge : un
-- effacement passe seulement s'il est demandé par le propriétaire de
-- fn_purge_retention, pendant la purge, sur une ligne de plus de 12 mois.
--
-- Tests : tests/sql/retention_plafonds_purge_tests.sql
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── RET-2 : les plafonds ──────────────────────────────────────────────────
ALTER TABLE public.library_retention_policies
  ADD CONSTRAINT library_retention_policies_loans_plafond
    CHECK (retention_loans_days IS NULL OR retention_loans_days BETWEEN 1 AND 730),
  ADD CONSTRAINT library_retention_policies_reservations_plafond
    CHECK (retention_reservations_days IS NULL OR retention_reservations_days BETWEEN 1 AND 365),
  ADD CONSTRAINT library_retention_policies_consultations_plafond
    CHECK (retention_consultations_days IS NULL OR retention_consultations_days BETWEEN 1 AND 365),
  ADD CONSTRAINT library_retention_policies_notifications_plafond
    CHECK (retention_notifications_days IS NULL OR retention_notifications_days BETWEEN 1 AND 90);

CREATE OR REPLACE FUNCTION public.fn_set_retention_policy(p_library_id uuid, p_loans_days integer, p_reservations_days integer, p_consultations_days integer, p_notifications_days integer, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_can_manage boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  -- F.2 v0.3 : la politique de retention est reservee aux coordenador
  -- de la biblio (role 'administrador' supprime en F.1).
  SELECT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = v_user_id
      AND m.library_id = p_library_id
      AND m.status = 'active'
      AND m.role = 'coordenador'
  ) INTO v_can_manage;

  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Vous n''avez pas le droit de modifier la politique de retention de cette bibliotheque.'
      USING ERRCODE = '42501';
  END IF;

  -- RET-2 (23/10/2026) : une duree se regle entre 1 jour et le plafond du
  -- reseau ; NULL rend le defaut, qui est le plafond.
  IF p_loans_days IS NOT NULL AND (p_loans_days < 1 OR p_loans_days > 730) THEN
    RAISE EXCEPTION 'Duree de retention emprunts invalide (entre 1 et 730 jours).' USING ERRCODE = '23514';
  END IF;
  IF p_reservations_days IS NOT NULL AND (p_reservations_days < 1 OR p_reservations_days > 365) THEN
    RAISE EXCEPTION 'Duree de retention reservations invalide (entre 1 et 365 jours).' USING ERRCODE = '23514';
  END IF;
  IF p_consultations_days IS NOT NULL AND (p_consultations_days < 1 OR p_consultations_days > 365) THEN
    RAISE EXCEPTION 'Duree de retention consultations invalide (entre 1 et 365 jours).' USING ERRCODE = '23514';
  END IF;
  IF p_notifications_days IS NOT NULL AND (p_notifications_days < 1 OR p_notifications_days > 90) THEN
    RAISE EXCEPTION 'Duree de retention notifications invalide (entre 1 et 90 jours).' USING ERRCODE = '23514';
  END IF;

  INSERT INTO public.library_retention_policies (
    library_id,
    retention_loans_days,
    retention_reservations_days,
    retention_consultations_days,
    retention_notifications_days,
    notes,
    updated_by
  ) VALUES (
    p_library_id,
    p_loans_days,
    p_reservations_days,
    p_consultations_days,
    p_notifications_days,
    p_notes,
    v_user_id
  )
  ON CONFLICT (library_id) DO UPDATE
    SET
      retention_loans_days = EXCLUDED.retention_loans_days,
      retention_reservations_days = EXCLUDED.retention_reservations_days,
      retention_consultations_days = EXCLUDED.retention_consultations_days,
      retention_notifications_days = EXCLUDED.retention_notifications_days,
      notes = EXCLUDED.notes,
      updated_by = EXCLUDED.updated_by;

  RETURN public.fn_get_retention_policy(p_library_id);
END;
$function$;

-- ─── RET-3 : la purge complète ─────────────────────────────────────────────
-- Le travail, sans droits propres : seule fn_purge_retention l'appelle.
CREATE OR REPLACE FUNCTION private.fn_purge_retention_appliquer()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_lib record;
  v_pol jsonb;
  v_d_prets int; v_d_resas int; v_d_consult int; v_d_notifs int;
  v_n int;
  v_bib jsonb;
  v_par_bib jsonb := '{}'::jsonb;
  v_tot jsonb := '{}'::jsonb;
  v_sortants jsonb := '{}'::jsonb;
  v_journaux jsonb := '{}'::jsonb;
  v_o record;
BEGIN
  -- ── Domaines réglés par chaque bibliothèque (toutes, actives ou non) ─────
  FOR v_lib IN SELECT l.id, l.slug FROM public.libraries l ORDER BY l.slug LOOP
    v_pol := public.fn_get_retention_policy(v_lib.id);
    -- Le plafond s'applique même à une valeur antérieure à la CHECK.
    v_d_prets   := COALESCE((v_pol->>'retention_loans_days')::int, 730);
    v_d_resas   := COALESCE((v_pol->>'retention_reservations_days')::int, 365);
    v_d_consult := COALESCE((v_pol->>'retention_consultations_days')::int, 365);
    v_d_notifs  := COALESCE((v_pol->>'retention_notifications_days')::int, 90);
    v_d_prets   := CASE WHEN v_d_prets   BETWEEN 1 AND 730 THEN v_d_prets   ELSE 730 END;
    v_d_resas   := CASE WHEN v_d_resas   BETWEEN 1 AND 365 THEN v_d_resas   ELSE 365 END;
    v_d_consult := CASE WHEN v_d_consult BETWEEN 1 AND 365 THEN v_d_consult ELSE 365 END;
    v_d_notifs  := CASE WHEN v_d_notifs  BETWEEN 1 AND 90  THEN v_d_notifs  ELSE 90  END;
    v_bib := '{}'::jsonb;

    -- Prêts clos : tous les exemplaires rendus depuis la durée, et le prêt
    -- lui-même sans mouvement depuis (un prêt sans exemplaire a une date).
    DELETE FROM emprestimos_v2 e
     WHERE e.library_id = v_lib.id
       AND e.status_global = 'encerrado'
       AND GREATEST(e.created_at, e.updated_at) < now() - make_interval(days => v_d_prets)
       AND NOT EXISTS (
         SELECT 1 FROM emprestimo_itens_v2 ei
          WHERE ei.emprestimo_id = e.id
            AND (ei.item_status = 'aberto'
                 OR COALESCE(ei.return_completed_at, ei.returned_at, ei.updated_at)
                    > now() - make_interval(days => v_d_prets)));
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n > 0 THEN v_bib := v_bib || jsonb_build_object('prets', v_n); END IF;

    DELETE FROM reservas_v2 r
     WHERE r.library_id = v_lib.id
       AND r.status_global IN ('encerrada', 'cancelada')
       AND GREATEST(r.created_at, r.updated_at) < now() - make_interval(days => v_d_resas)
       AND NOT EXISTS (
         SELECT 1 FROM reserva_linhas_v2 rl
          WHERE rl.reserva_id = r.id
            AND COALESCE(rl.cancelled_at, rl.converted_at, rl.expired_at, rl.updated_at)
                > now() - make_interval(days => v_d_resas));
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n > 0 THEN v_bib := v_bib || jsonb_build_object('reservations', v_n); END IF;

    DELETE FROM consultas_locais_v2 c
     WHERE c.library_id = v_lib.id
       AND c.status_global IN ('encerrada', 'cancelada')
       AND GREATEST(c.created_at, c.updated_at) < now() - make_interval(days => v_d_consult)
       AND NOT EXISTS (
         SELECT 1 FROM consulta_linhas_v2 cl
          WHERE cl.consulta_id = c.id
            AND COALESCE(cl.cancelled_at, cl.consulted_at, cl.expired_at, cl.updated_at)
                > now() - make_interval(days => v_d_consult));
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n > 0 THEN v_bib := v_bib || jsonb_build_object('consultations', v_n); END IF;

    DELETE FROM user_notifications n
     WHERE n.library_id = v_lib.id
       AND n.is_read
       AND COALESCE(n.read_at, n.created_at) < now() - make_interval(days => v_d_notifs);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n > 0 THEN v_bib := v_bib || jsonb_build_object('notifications_lues', v_n); END IF;

    -- PEB : la durée des prêts de la prêteuse, depuis la clôture. Les
    -- exemplaires, événements et notifications du PEB partent en cascade.
    DELETE FROM interlibrary_loans_v2 p
     WHERE p.lender_library_id = v_lib.id
       AND p.status_global IN ('devolvido', 'cancelado')
       AND GREATEST(p.created_at, p.updated_at, p.returned_at, p.archived_at)
           < now() - make_interval(days => v_d_prets);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n > 0 THEN v_bib := v_bib || jsonb_build_object('peb', v_n); END IF;

    IF v_bib <> '{}'::jsonb THEN
      v_par_bib := v_par_bib || jsonb_build_object(v_lib.slug, v_bib);
    END IF;
  END LOOP;

  SELECT jsonb_build_object(
           'prets',              COALESCE(sum((b->>'prets')::int), 0),
           'reservations',       COALESCE(sum((b->>'reservations')::int), 0),
           'consultations',      COALESCE(sum((b->>'consultations')::int), 0),
           'notifications_lues', COALESCE(sum((b->>'notifications_lues')::int), 0),
           'peb',                COALESCE(sum((b->>'peb')::int), 0))
    INTO v_tot
    FROM jsonb_each(v_par_bib) AS e(slug, b);

  -- ── Notifications ─────────────────────────────────────────────────────────
  DELETE FROM user_notifications n
   WHERE n.library_id IS NULL AND n.is_read
     AND COALESCE(n.read_at, n.created_at) < now() - interval '90 days';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_tot := v_tot || jsonb_build_object('notifications_reseau_lues', v_n);

  DELETE FROM user_notifications n
   WHERE NOT n.is_read AND n.created_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_tot := v_tot || jsonb_build_object('notifications_non_lues', v_n);

  -- ── Courriers sortants : 90 jours après le dernier mouvement connu, en
  -- état final seulement (un échec qui sera rejoué n'est pas final).
  FOR v_o IN
    SELECT * FROM (VALUES
      ('team_notification_outbox',                   'status',          ARRAY['sent','skipped','abandoned'], 'GREATEST(created_at, sent_at, next_attempt_at)'),
      ('lettre_notification_outbox',                 'status',          ARRAY['sent','skipped','abandoned'], 'GREATEST(created_at, sent_at, next_attempt_at)'),
      ('gazette_submission_notification_outbox',     'status',          ARRAY['sent','skipped','abandoned'], 'GREATEST(created_at, sent_at, next_attempt_at)'),
      ('cartography_submission_notification_outbox', 'status',          ARRAY['sent','skipped','abandoned'], 'GREATEST(created_at, sent_at, next_attempt_at)'),
      ('bug_report_notification_outbox',             'status',          ARRAY['sent','skipped','abandoned'], 'GREATEST(created_at, sent_at, next_attempt_at)'),
      ('authority_proposal_notification_outbox',     'status',          ARRAY['sent','skipped','failed'],    'GREATEST(created_at, sent_at)'),
      ('painel_internal_task_notification_outbox',   'dispatch_status', ARRAY['sent','skipped','failed'],    'GREATEST(created_at, sent_at, updated_at, reconciled_at)'),
      ('painel_internal_task_invitation_outbox',     'dispatch_status', ARRAY['sent','skipped','failed'],    'GREATEST(created_at, sent_at, updated_at, reconciled_at)')
    ) AS o(tbl, col, finaux, ref)
  LOOP
    EXECUTE format('DELETE FROM public.%I WHERE %I = ANY ($1) AND %s < now() - interval ''90 days''',
                   v_o.tbl, v_o.col, v_o.ref)
      USING v_o.finaux;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    v_sortants := v_sortants || jsonb_build_object(v_o.tbl, v_n);
  END LOOP;

  -- ── Signalements de bug ───────────────────────────────────────────────────
  UPDATE bug_reports SET reporter_email = NULL
   WHERE status = 'closed' AND reporter_email IS NOT NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_tot := v_tot || jsonb_build_object('signalements_adresses_effacees', v_n);

  DELETE FROM bug_reports
   WHERE status = 'closed' AND COALESCE(closed_at, created_at) < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_tot := v_tot || jsonb_build_object('signalements', v_n);

  -- ── Messagerie lectorat ↔ bibliothèque : un échange par (bibliothèque,
  -- personne lectrice), effacé en entier 12 mois après son dernier message.
  WITH echanges AS (
    SELECT m.library_id,
           CASE WHEN m.direction = 'reader' THEN m.sender_id ELSE m.recipient_id END AS lecteur,
           max(m.created_at) AS dernier
      FROM reader_library_messages m
     GROUP BY 1, 2
  )
  DELETE FROM reader_library_messages m
   USING echanges x
   WHERE m.library_id = x.library_id
     AND (CASE WHEN m.direction = 'reader' THEN m.sender_id ELSE m.recipient_id END)
         IS NOT DISTINCT FROM x.lecteur
     AND x.dernier < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_tot := v_tot || jsonb_build_object('messages_lectorat', v_n);

  -- ── Lectures en cours et envies : 24 mois sans connexion ─────────────────
  DELETE FROM reading_progress r
   USING auth.users u
   WHERE u.id = r.user_id
     AND COALESCE(u.last_sign_in_at, u.created_at) < now() - interval '24 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_tot := v_tot || jsonb_build_object('lectures_en_cours', v_n);

  DELETE FROM user_wishlist w
   USING auth.users u
   WHERE u.id = w.user_id
     AND COALESCE(u.last_sign_in_at, u.created_at) < now() - interval '24 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_tot := v_tot || jsonb_build_object('envies', v_n);

  -- ── Journaux : 12 mois ────────────────────────────────────────────────────
  DELETE FROM private.double_facteur_journal WHERE le < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_journaux := v_journaux || jsonb_build_object('double_facteur_journal', v_n);

  PERFORM set_config('anarbib.purge_retention', 'on', true);
  DELETE FROM network_admin_cross_library_actions_log WHERE created_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  PERFORM set_config('anarbib.purge_retention', '', true);
  v_journaux := v_journaux || jsonb_build_object('network_admin_cross_library_actions_log', v_n);

  DELETE FROM library_membership_audit WHERE created_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_journaux := v_journaux || jsonb_build_object('library_membership_audit', v_n);

  DELETE FROM membership_validation_log WHERE created_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_journaux := v_journaux || jsonb_build_object('membership_validation_log', v_n);

  DELETE FROM reader_membership_events WHERE changed_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_journaux := v_journaux || jsonb_build_object('reader_membership_events', v_n);

  DELETE FROM interlibrary_loan_notification_events WHERE created_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_journaux := v_journaux || jsonb_build_object('interlibrary_loan_notification_events', v_n);

  DELETE FROM library_request_notification_events WHERE created_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_journaux := v_journaux || jsonb_build_object('library_request_notification_events', v_n);

  DELETE FROM document_permission_request_notification_events WHERE created_at < now() - interval '12 months';
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_journaux := v_journaux || jsonb_build_object('document_permission_request_notification_events', v_n);

  RETURN jsonb_build_object(
    'totaux', v_tot,
    'courriers_sortants', v_sortants,
    'journaux', v_journaux,
    'par_bibliotheque', v_par_bib
  );
END;
$function$;

REVOKE ALL ON FUNCTION private.fn_purge_retention_appliquer() FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.fn_purge_retention(p_dry_run boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_debut timestamptz := clock_timestamp();
  v_bilan jsonb;
BEGIN
  IF p_dry_run THEN
    -- Même code que la purge réelle, puis annulation de la sous-transaction :
    -- le bilan (une variable) survit, les suppressions non.
    BEGIN
      v_bilan := private.fn_purge_retention_appliquer();
      RAISE EXCEPTION USING ERRCODE = 'AB901', MESSAGE = 'essai a blanc : annulation';
    EXCEPTION WHEN SQLSTATE 'AB901' THEN
      NULL;
    END;
  ELSE
    v_bilan := private.fn_purge_retention_appliquer();
  END IF;

  RETURN jsonb_build_object(
    'mode', CASE WHEN p_dry_run THEN 'essai_a_blanc' ELSE 'execute' END,
    'debut', v_debut,
    'duree_ms', round(extract(epoch FROM clock_timestamp() - v_debut) * 1000)
  ) || v_bilan;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_purge_retention(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_purge_retention(boolean) TO service_role;

-- ─── Le journal inter-bibliothèques s'ouvre à la seule purge ───────────────
CREATE OR REPLACE FUNCTION public.tg_cross_lib_log_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_catalog'
AS $function$
BEGIN
    -- RET-3 (23/10/2026) : la purge de rétention efface les lignes de plus de
    -- 12 mois. Le drapeau ne suffit pas : il faut aussi être le propriétaire
    -- de fn_purge_retention, ce qu'aucun rôle d'API ne peut devenir.
    IF TG_OP = 'DELETE'
       AND current_setting('anarbib.purge_retention', true) = 'on'
       AND current_user = (SELECT pg_get_userbyid(p.proowner) FROM pg_proc p
                            WHERE p.oid = 'public.fn_purge_retention(boolean)'::regprocedure)
       AND OLD.created_at < now() - interval '12 months' THEN
        RETURN OLD;
    END IF;
    RAISE EXCEPTION 'cross_library_log_immutable: network_admin_cross_library_actions_log is append-only, UPDATE and DELETE are forbidden';
END;
$function$;

-- ─── Vérification ──────────────────────────────────────────────────────────
DO $verif$
BEGIN
  IF (SELECT count(*) FROM pg_constraint
       WHERE conrelid = 'public.library_retention_policies'::regclass
         AND conname LIKE 'library_retention_policies_%_plafond') <> 4 THEN
    RAISE EXCEPTION 'RET-2 : les quatre plafonds ne sont pas posés';
  END IF;
  IF has_function_privilege('anon', 'public.fn_purge_retention(boolean)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_purge_retention(boolean)', 'EXECUTE')
     OR has_function_privilege('service_role', 'private.fn_purge_retention_appliquer()', 'EXECUTE') THEN
    RAISE EXCEPTION 'RET-3 : la purge est ouverte au-delà de service_role';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'private.fn_purge_retention_appliquer()'::regprocedure AND prosecdef) THEN
    RAISE EXCEPTION 'RET-3 : le travail de la purge ne doit pas avoir de droits propres';
  END IF;
END;
$verif$;

COMMIT;
