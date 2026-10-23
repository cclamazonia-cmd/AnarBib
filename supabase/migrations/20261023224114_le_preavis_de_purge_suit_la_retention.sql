-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — le préavis de purge suit la rétention (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- fn_notify_users_before_purge prévient chaque dimanche (2 h UTC, une heure
-- avant la purge) les personnes dont des données partiront dans les 30 jours.
-- Elle suivait l'ancienne purge : trois domaines, bibliothèques actives
-- seulement. Depuis RET-2/RET-3 (20261023192006, 20261023201346), la purge
-- passe partout et couvre davantage ; le préavis s'aligne :
--   - toutes les bibliothèques, actives ou non ;
--   - les durées bornées comme la purge (plafonds du réseau), et la ligne mère
--     sans mouvement depuis la durée, comme la purge ;
--   - deux familles nouvelles, celles qui appartiennent à la personne :
--       messagerie avec une bibliothèque (12 mois après le dernier message de
--       l'échange) — préavis par bibliothèque ;
--       lecture en cours et liste d'envies (24 mois sans connexion) — préavis
--       sans bibliothèque (library_id NULL) ; se connecter suffit à les garder.
-- Les autres familles de RET-3 (files d'envoi, signalements, PEB, journaux) ne
-- sont pas des données que la personne garde ou exporte : pas de préavis.
--
-- Corps de départ : la définition RÉELLE en production le 23/10/2026. Même
-- format de retour, plus « par_famille ». L'envoi du courriel passe toujours
-- par fn_dispatch_rgpd_warning → notify-event (domain/rgpd.ts, qui apprend
-- les deux familles dans le même commit).
--
-- Tests : tests/sql/preavis_purge_tests.sql ;
-- src/tests/aiguillage-branches-mortes.test.js (deux événements aiguillés).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- Crée les préavis d'une famille pour une liste de personnes, sans doublon à
-- 40 jours, et déclenche le courriel de chacun. Rend {créés, envoyés}.
CREATE OR REPLACE FUNCTION private.fn_preavis_purge_envoyer(p_user_ids uuid[], p_library_id uuid, p_famille text)
 RETURNS integer[]
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_row record;
  v_crees int := 0;
  v_envoyes int := 0;
BEGIN
  IF p_famille NOT IN ('loans', 'reservations', 'consultations', 'messages', 'reading') THEN
    RAISE EXCEPTION 'famille de préavis inconnue : %', p_famille USING ERRCODE = '22023';
  END IF;
  FOR v_row IN
    INSERT INTO public.user_notifications (user_id, library_id, category, title, body, is_read)
    SELECT x.u, p_library_id, 'rgpd_retention_' || p_famille,
           'notif.rgpd.purgeWarning.' || p_famille || '.title',
           'notif.rgpd.purgeWarning.' || p_famille || '.body',
           false
      FROM (SELECT DISTINCT unnest(p_user_ids) AS u) x
     WHERE x.u IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = x.u)
       AND NOT EXISTS (
         SELECT 1 FROM public.user_notifications n
          WHERE n.user_id = x.u
            AND n.library_id IS NOT DISTINCT FROM p_library_id
            AND n.category = 'rgpd_retention_' || p_famille
            AND n.created_at > now() - interval '40 days')
    RETURNING id
  LOOP
    v_crees := v_crees + 1;
    IF public.fn_dispatch_rgpd_warning(v_row.id, 'rgpd_purge_warning_' || p_famille) IS NOT NULL THEN
      v_envoyes := v_envoyes + 1;
    END IF;
  END LOOP;
  RETURN ARRAY[v_crees, v_envoyes];
END;
$function$;

REVOKE ALL ON FUNCTION private.fn_preavis_purge_envoyer(uuid[], uuid, text) FROM PUBLIC, anon, authenticated, service_role;

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
  v_warn_window_days constant int := 30;
  v_users uuid[];
  v_r int[];
  v_familles jsonb := '{}'::jsonb;
  v_total_notified int := 0;
  v_total_dispatched int := 0;
  v_started_at timestamptz := now();
  v_f text;
BEGIN
  -- Toutes les bibliothèques, actives ou non, comme fn_purge_retention.
  FOR v_lib IN SELECT l.id FROM public.libraries l ORDER BY l.slug LOOP
    v_policy := public.fn_get_retention_policy(v_lib.id);
    v_loans_days := COALESCE((v_policy->>'retention_loans_days')::int, 730);
    v_reservations_days := COALESCE((v_policy->>'retention_reservations_days')::int, 365);
    v_consultations_days := COALESCE((v_policy->>'retention_consultations_days')::int, 365);
    v_loans_days := CASE WHEN v_loans_days BETWEEN 1 AND 730 THEN v_loans_days ELSE 730 END;
    v_reservations_days := CASE WHEN v_reservations_days BETWEEN 1 AND 365 THEN v_reservations_days ELSE 365 END;
    v_consultations_days := CASE WHEN v_consultations_days BETWEEN 1 AND 365 THEN v_consultations_days ELSE 365 END;

    -- ─── Emprunts ────────────────────────────────────────────────────────
    SELECT array_agg(DISTINCT e.user_id) INTO v_users
      FROM emprestimos_v2 e
     WHERE e.library_id = v_lib.id
       AND e.status_global = 'encerrado'
       AND GREATEST(e.created_at, e.updated_at) < now() - make_interval(days => GREATEST(v_loans_days - v_warn_window_days, 0))
       AND NOT EXISTS (
         SELECT 1 FROM emprestimo_itens_v2 ei
          WHERE ei.emprestimo_id = e.id
            AND (ei.item_status = 'aberto'
                 OR COALESCE(ei.return_completed_at, ei.returned_at, ei.updated_at)
                    > now() - make_interval(days => GREATEST(v_loans_days - v_warn_window_days, 0))));
    IF v_users IS NOT NULL THEN
      v_r := private.fn_preavis_purge_envoyer(v_users, v_lib.id, 'loans');
      v_familles := v_familles || jsonb_build_object('loans', COALESCE((v_familles->>'loans')::int, 0) + v_r[1]);
      v_total_notified := v_total_notified + v_r[1];
      v_total_dispatched := v_total_dispatched + v_r[2];
    END IF;

    -- ─── Réservations ───────────────────────────────────────────────────
    SELECT array_agg(DISTINCT r.user_id) INTO v_users
      FROM reservas_v2 r
     WHERE r.library_id = v_lib.id
       AND r.status_global IN ('encerrada', 'cancelada')
       AND GREATEST(r.created_at, r.updated_at) < now() - make_interval(days => GREATEST(v_reservations_days - v_warn_window_days, 0))
       AND NOT EXISTS (
         SELECT 1 FROM reserva_linhas_v2 rl
          WHERE rl.reserva_id = r.id
            AND COALESCE(rl.cancelled_at, rl.converted_at, rl.expired_at, rl.updated_at)
                > now() - make_interval(days => GREATEST(v_reservations_days - v_warn_window_days, 0)));
    IF v_users IS NOT NULL THEN
      v_r := private.fn_preavis_purge_envoyer(v_users, v_lib.id, 'reservations');
      v_familles := v_familles || jsonb_build_object('reservations', COALESCE((v_familles->>'reservations')::int, 0) + v_r[1]);
      v_total_notified := v_total_notified + v_r[1];
      v_total_dispatched := v_total_dispatched + v_r[2];
    END IF;

    -- ─── Consultations ──────────────────────────────────────────────────
    SELECT array_agg(DISTINCT c.user_id) INTO v_users
      FROM consultas_locais_v2 c
     WHERE c.library_id = v_lib.id
       AND c.status_global IN ('encerrada', 'cancelada')
       AND GREATEST(c.created_at, c.updated_at) < now() - make_interval(days => GREATEST(v_consultations_days - v_warn_window_days, 0))
       AND NOT EXISTS (
         SELECT 1 FROM consulta_linhas_v2 cl
          WHERE cl.consulta_id = c.id
            AND COALESCE(cl.cancelled_at, cl.consulted_at, cl.expired_at, cl.updated_at)
                > now() - make_interval(days => GREATEST(v_consultations_days - v_warn_window_days, 0)));
    IF v_users IS NOT NULL THEN
      v_r := private.fn_preavis_purge_envoyer(v_users, v_lib.id, 'consultations');
      v_familles := v_familles || jsonb_build_object('consultations', COALESCE((v_familles->>'consultations')::int, 0) + v_r[1]);
      v_total_notified := v_total_notified + v_r[1];
      v_total_dispatched := v_total_dispatched + v_r[2];
    END IF;

    -- ─── Messagerie : la personne lectrice d'un échange éteint depuis près
    -- de 12 mois (même découpage que fn_purge_retention).
    SELECT array_agg(DISTINCT x.lecteur) INTO v_users
      FROM (SELECT CASE WHEN m.direction = 'reader' THEN m.sender_id ELSE m.recipient_id END AS lecteur,
                   max(m.created_at) AS dernier
              FROM reader_library_messages m
             WHERE m.library_id = v_lib.id
             GROUP BY 1) x
     WHERE x.lecteur IS NOT NULL
       AND x.dernier < now() - interval '12 months' + make_interval(days => v_warn_window_days);
    IF v_users IS NOT NULL THEN
      v_r := private.fn_preavis_purge_envoyer(v_users, v_lib.id, 'messages');
      v_familles := v_familles || jsonb_build_object('messages', COALESCE((v_familles->>'messages')::int, 0) + v_r[1]);
      v_total_notified := v_total_notified + v_r[1];
      v_total_dispatched := v_total_dispatched + v_r[2];
    END IF;

    -- Pas de notif pour les notifications elles-mêmes (méta-récursivité préservée).
  END LOOP;

  -- ─── Lecture en cours et liste d'envies : près de 24 mois sans connexion.
  SELECT array_agg(u.id) INTO v_users
    FROM auth.users u
   WHERE COALESCE(u.last_sign_in_at, u.created_at) < now() - interval '24 months' + make_interval(days => v_warn_window_days)
     AND (EXISTS (SELECT 1 FROM reading_progress r WHERE r.user_id = u.id)
          OR EXISTS (SELECT 1 FROM user_wishlist w WHERE w.user_id = u.id));
  IF v_users IS NOT NULL THEN
    v_r := private.fn_preavis_purge_envoyer(v_users, NULL, 'reading');
    v_familles := v_familles || jsonb_build_object('reading', v_r[1]);
    v_total_notified := v_total_notified + v_r[1];
    v_total_dispatched := v_total_dispatched + v_r[2];
  END IF;

  FOREACH v_f IN ARRAY ARRAY['loans', 'reservations', 'consultations', 'messages', 'reading'] LOOP
    IF NOT v_familles ? v_f THEN v_familles := v_familles || jsonb_build_object(v_f, 0); END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'mode', 'notify',
    'started_at', v_started_at,
    'finished_at', now(),
    'total_notifications_created', v_total_notified,
    'total_dispatches_attempted', v_total_dispatched,
    'par_famille', v_familles
  );
END;
$function$;

-- Les droits de production (service_role seul), écrits ici : sur une base
-- rejouée depuis zéro, les privilèges par défaut de l'image laissaient
-- anon et authenticated appeler la fonction (relevé au rejeu du 23/10).
REVOKE ALL ON FUNCTION public.fn_notify_users_before_purge() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_notify_users_before_purge() TO service_role;

-- ─── Garde ─────────────────────────────────────────────────────────────────
DO $garde$
BEGIN
  IF has_function_privilege('anon', 'public.fn_notify_users_before_purge()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_notify_users_before_purge()', 'EXECUTE')
     OR has_function_privilege('service_role', 'private.fn_preavis_purge_envoyer(uuid[], uuid, text)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.fn_preavis_purge_envoyer(uuid[], uuid, text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Préavis : une fonction est ouverte au-delà de ce qu''il faut';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE oid = 'private.fn_preavis_purge_envoyer(uuid[], uuid, text)'::regprocedure AND prosecdef) THEN
    RAISE EXCEPTION 'Préavis : l''aide ne doit pas avoir de droits propres';
  END IF;
END;
$garde$;

COMMIT;
