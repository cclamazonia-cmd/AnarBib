-- =====================================================================
-- F1, troisième critère — les branches mortes de la chaîne de courriel, côté
-- base, et les deux chantiers que Xavier a tranchés le 30/09/2026.
-- Carte : docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md, section
-- « Les branches mortes ». Le même push retire leurs routes et leurs handlers
-- côté Edge (dispatch.ts, legacy.ts, notify-mid-loan-reading).
--
--   1. trg_notify_reserva_workflow_change perd deux émissions sans objet :
--      - 're-retirada_agendada' → 'retirada_reagendada' : la v3 interdit ce
--        stage (aucune transition n'y mène) ;
--      - le Bloc 2 (pickup_reply_status, modèle v2) : la seule fonction qui
--        pose une valeur, fn_v2_set_reserva_linhas_pickup_reply, n'est appelée
--        que par api.confirm_pickup_slot (encore exécutable par authenticated)
--        et api.refuse_pickup_slot, qu'aucun écran n'appelle ; ces murs restent
--        (B20) — un appel écrirait pickup_reply_status, sans courriel ;
--        20 lignes sur 20 à NULL le 01/10.
--      La liste UPDATE OF du déclencheur ne change pas ; le Bloc 3
--      (contre-propositions v3) reste tel quel.
--   2. fn_cron_notify_mid_loan_reading est supprimée : aucun cron depuis
--      20260831111700, aucun appelant ; sa fonction Edge part avec ce push.
--   3. 'interlibrary_loan_due_soon' sort de la CHECK des événements PEB :
--      aucun émetteur, aucune ligne.
--   4. team.promoted_to_librarian est ÉMIS par fn_team_accept_invitation
--      (branche librarian), comme team.promoted_to_coordenador l'est déjà.
--      Le handler (team.ts) et les clés des dix langues existent.
--   5. Les consultations expirent : fn_cron_expire_consultas() et un cron
--      quotidien, comme le prévoit la spec flux-consultations v2.2 (§5.2 :
--      « system » mène à 'expirada' depuis solicitada, em_preparacao,
--      consulta_agendada ; §5.3 : sur expires_at < now()). Le courriel
--      consulta_v2_expirada part par trg_notify_consulta_lifecycle.
--      La ligne expirée porte la note système consultaExpiredAuto (le courriel
--      affiche la note du workflow : sans elle, il montrerait la note de la
--      demande ou la dernière note de l'équipe). Une consultation archivée
--      (fn_archive_library_circulation) ne bouge pas ; une consultation qui
--      lève n'empêche pas les autres d'expirer.
--      LIMITE CONNUE : aucun écran ne pose expires_at aujourd'hui (22 lignes
--      sur 22 à NULL) ; tant qu'il n'a pas de source, ce cron ne fait rien.
--
-- Aucune donnée n'est supprimée. Restent, documentées sans lecteur par un
-- COMMENT (section 6) : library_notification_policies.reservation_mail_
-- retirada_reagendada_enabled, mid_loan_message_enabled,
-- reading_recommendations_enabled et la table loan_midpoint_message_log
-- (0 ligne ; elle est aussi dans la denylist #BG2). Les supprimer demande une
-- autorisation écrite de Xavier.
-- Chaque fonction est réécrite depuis sa définition RÉELLE (pg_get_functiondef)
-- par remplacements COMPTÉS ; une empreinte (md5 du corps, retours chariot
-- retirés) refuse une définition qui aurait bougé depuis la lecture du 01/10.
-- Suite : tests/sql/branches_mortes_courriel_tests.sql.
-- =====================================================================

-- ── 1. Le déclencheur des réservations ───────────────────────────────
DO $mig$
DECLARE
  v_def text;
  v_n int;
  v_reagendada text := $a$    ELSIF NEW.workflow_stage = 're-retirada_agendada' THEN
      v_event := 'retirada_reagendada';
      v_flag_column := 'reservation_mail_retirada_reagendada_enabled';
$a$;
  v_bloc2 text := $b$  -- =============================================================
  -- Bloc 2 : changement de pickup_reply_status (legacy v2)
  -- (les mails "lecteur confirme/refuse créneau" sont admin-only,
  --  pas concernés par les flags reservation_mail_*_enabled qui
  --  ciblent les notifs lecteur)
  -- =============================================================
  IF TG_OP = 'UPDATE'
     AND OLD.pickup_reply_status IS DISTINCT FROM NEW.pickup_reply_status
     AND NEW.pickup_reply_status IS NOT NULL THEN
    PERFORM fn_dispatch_notify_event(
      CASE WHEN NEW.pickup_reply_status = 'confirmado_leitor'
           THEN 'retirada_confirmada_leitor'
           ELSE 'retirada_recusada_leitor'
      END,
      NEW.reserva_id,
      jsonb_build_object('line_nos', jsonb_build_array(NEW.line_no))
    );
  END IF;
$b$;
  v_bloc2_neuf text := $c$  -- Bloc 2 (pickup_reply_status, modèle v2) retiré le 01/10/2026 (F1) :
  -- la réponse au créneau passe par la négociation v3 (Bloc 1 et Bloc 3).
$c$;
BEGIN
  IF (SELECT md5(replace(prosrc, E'\r', '')) FROM pg_proc
       WHERE oid = 'public.trg_notify_reserva_workflow_change()'::regprocedure)
     <> 'ed883459ba8cb1cdd214afca31a5abf8' THEN
    RAISE EXCEPTION 'F1 : trg_notify_reserva_workflow_change a changé depuis le relevé du 01/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('public.trg_notify_reserva_workflow_change()'::regprocedure), E'\r', '');

  v_n := (length(v_def) - length(replace(v_def, v_reagendada, ''))) / length(v_reagendada);
  IF v_n <> 1 THEN RAISE EXCEPTION 'F1 : branche re-retirada_agendada trouvée % fois (1 attendue)', v_n; END IF;
  v_def := replace(v_def, v_reagendada, '');

  v_n := (length(v_def) - length(replace(v_def, v_bloc2, ''))) / length(v_bloc2);
  IF v_n <> 1 THEN RAISE EXCEPTION 'F1 : Bloc 2 trouvé % fois (1 attendu)', v_n; END IF;
  v_def := replace(v_def, v_bloc2, v_bloc2_neuf);

  EXECUTE v_def;

  SELECT pg_get_functiondef('public.trg_notify_reserva_workflow_change()'::regprocedure) INTO v_def;
  IF v_def LIKE '%retirada_reagendada%' OR v_def LIKE '%confirmado_leitor%'
     OR v_def NOT LIKE '%Bloc 3%' OR v_def NOT LIKE '%reserva_convertida_em_emprestimo%' THEN
    RAISE EXCEPTION 'F1 : réécriture du déclencheur incomplète';
  END IF;
END
$mig$;

-- ── 2. Le cron de l'ancien mi-parcours ───────────────────────────────
DO $mig$
DECLARE
  v_n int;
BEGIN
  IF to_regprocedure('public.fn_cron_notify_mid_loan_reading()') IS NULL THEN
    RETURN;  -- instance sur laquelle elle n'a jamais existé
  END IF;
  SELECT count(*) INTO v_n FROM cron.job WHERE command ILIKE '%fn_cron_notify_mid_loan_reading%';
  IF v_n > 0 THEN RAISE EXCEPTION 'F1 : un cron appelle encore fn_cron_notify_mid_loan_reading'; END IF;
  SELECT count(*) INTO v_n FROM pg_proc
   WHERE prosrc ILIKE '%fn_cron_notify_mid_loan_reading%'
     AND oid <> 'public.fn_cron_notify_mid_loan_reading()'::regprocedure;
  IF v_n > 0 THEN RAISE EXCEPTION 'F1 : % fonction(s) appellent encore fn_cron_notify_mid_loan_reading', v_n; END IF;
END
$mig$;
DROP FUNCTION IF EXISTS public.fn_cron_notify_mid_loan_reading();

-- ── 3. PEB : l'échéance proche n'a pas d'émetteur ─────────────────────
DO $mig$
BEGIN
  IF EXISTS (SELECT 1 FROM public.interlibrary_loan_notification_events
              WHERE event_type = 'interlibrary_loan_due_soon') THEN
    RAISE EXCEPTION 'F1 : des lignes interlibrary_loan_due_soon existent — relire avant de resserrer la CHECK';
  END IF;
END
$mig$;
ALTER TABLE public.interlibrary_loan_notification_events
  DROP CONSTRAINT interlibrary_loan_notification_events_type_chk;
ALTER TABLE public.interlibrary_loan_notification_events
  ADD CONSTRAINT interlibrary_loan_notification_events_type_chk CHECK (event_type = ANY (ARRAY[
    'interlibrary_loan_created'::text, 'interlibrary_loan_prepared'::text,
    'interlibrary_loan_dispatched'::text, 'interlibrary_loan_overdue'::text,
    'interlibrary_loan_return_started'::text, 'interlibrary_loan_returned'::text,
    'interlibrary_loan_cancelled'::text, 'interlibrary_loan_partially_returned'::text]));

-- ── 4. Émettre team.promoted_to_librarian ─────────────────────────────
DO $mig$
DECLARE
  v_def text;
  v_n int;
  v_ancre text := $a$    RETURNING id INTO v_audit_id;

  -- =============== promotion collégiale$a$;
  v_neuf text := $b$    RETURNING id INTO v_audit_id;

    -- F1 (01/10/2026, décision de Xavier) : l'accueil dans l'équipe prévient la
    -- personne et la bibliothèque, comme la promotion collégiale ci-dessous.
    PERFORM public.fn_team_notify_event('team.promoted_to_librarian', jsonb_build_object(
      'library_id', v_inv.library_id,
      'target_user_id', v_inv.invited_user_id,
      'actor_user_id', v_inv.proposed_by,
      'audit_id', v_audit_id));

  -- =============== promotion collégiale$b$;
BEGIN
  IF (SELECT md5(replace(prosrc, E'\r', '')) FROM pg_proc
       WHERE oid = 'public.fn_team_accept_invitation(uuid)'::regprocedure)
     <> '329508c8f819fa62c631bcffcff478de' THEN
    RAISE EXCEPTION 'F1 : fn_team_accept_invitation a changé depuis le relevé du 01/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('public.fn_team_accept_invitation(uuid)'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN RAISE EXCEPTION 'F1 : ancre de la branche librarian trouvée % fois (1 attendue)', v_n; END IF;
  v_def := replace(v_def, v_ancre, v_neuf);
  EXECUTE v_def;

  SELECT pg_get_functiondef('public.fn_team_accept_invitation(uuid)'::regprocedure) INTO v_def;
  IF v_def NOT LIKE '%team.promoted_to_librarian%' OR v_def NOT LIKE '%team.promoted_to_coordenador%' THEN
    RAISE EXCEPTION 'F1 : réécriture de fn_team_accept_invitation incomplète';
  END IF;
END
$mig$;

-- ── 5. Les consultations expirent ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_cron_expire_consultas()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_c record;
  v_lignes integer[];
  v_k integer;
  v_total integer := 0;
BEGIN
  -- Spec flux-consultations v2.2, §5.2 : « system » mène à 'expirada' depuis
  -- solicitada, em_preparacao ou consulta_agendada — la matrice est portée par
  -- fn_check_consulta_transition. Une ligne sans ligne de workflow est
  -- 'solicitada'. Une consultation archivée (fn_archive_library_circulation)
  -- reste gelée. Aucune jointure sur library_notification_policies : une
  -- bibliothèque sans ligne de politique expire comme les autres (défaut F20).
  FOR v_c IN
    SELECT cl.consulta_id, array_agg(cl.line_no ORDER BY cl.line_no) AS lignes
      FROM public.consulta_linhas_v2 cl
      JOIN public.consultas_locais_v2 c ON c.id = cl.consulta_id AND c.archived_at IS NULL
      LEFT JOIN public.consulta_item_workflow_v2 w
        ON w.consulta_id = cl.consulta_id AND w.line_no = cl.line_no
     WHERE cl.item_status = 'ativa'
       AND cl.expires_at IS NOT NULL
       AND cl.expires_at < now()
       AND public.fn_check_consulta_transition(coalesce(w.workflow_stage, 'solicitada'), 'expirada', 'system')
     GROUP BY cl.consulta_id
  LOOP
    BEGIN
      -- Ordre B6 (fn_v2_set_consulta_linhas_workflow) : le workflow d'abord, la
      -- ligne ensuite — trg_notify_consulta_lifecycle lit le workflow quand la
      -- ligne change, et c'est lui qui émet consulta_v2_expirada avec la note.
      -- Le WHERE du DO UPDATE relit l'étape : si l'équipe a agi entre-temps, la
      -- ligne n'est ni réécrite ni expirée.
      WITH ecrits AS (
        INSERT INTO public.consulta_item_workflow_v2 (consulta_id, line_no, workflow_stage, workflow_note, updated_at, updated_by)
        SELECT v_c.consulta_id, l, 'expirada', '@@note:systemNote.consultaExpiredAuto', timezone('utc', now()), NULL
          FROM unnest(v_c.lignes) AS l
        ON CONFLICT (consulta_id, line_no) DO UPDATE
           SET workflow_stage = 'expirada',
               workflow_note = excluded.workflow_note,
               updated_at = excluded.updated_at,
               updated_by = NULL
         WHERE public.fn_check_consulta_transition(public.consulta_item_workflow_v2.workflow_stage, 'expirada', 'system')
        RETURNING line_no
      )
      SELECT array_agg(line_no) INTO v_lignes FROM ecrits;

      UPDATE public.consulta_linhas_v2 cl
         SET item_status = 'expirada',
             expired_at = coalesce(cl.expired_at, timezone('utc', now())),
             updated_at = timezone('utc', now())
       WHERE cl.consulta_id = v_c.consulta_id
         AND cl.line_no = ANY (coalesce(v_lignes, '{}'::integer[]))
         AND cl.item_status = 'ativa';
      GET DIAGNOSTICS v_k = ROW_COUNT;
      v_total := v_total + v_k;

      PERFORM public.fn_v2_refresh_consulta_status_global(v_c.consulta_id);
    EXCEPTION WHEN OTHERS THEN
      -- Une consultation fautive n'arrête pas les autres ; elle reste visible.
      RAISE WARNING 'fn_cron_expire_consultas(consulta %) : %', v_c.consulta_id, SQLERRM;
    END;
  END LOOP;
  RETURN v_total;
END
$fn$;

REVOKE EXECUTE ON FUNCTION public.fn_cron_expire_consultas() FROM PUBLIC, anon, authenticated;
COMMENT ON FUNCTION public.fn_cron_expire_consultas() IS
  'F1 (01/10/2026) : passe en expirada les lignes de consultation actives dont expires_at est passé (spec flux-consultations v2.2 §5.2-5.3). Cron anarbib-consultas-expire-daily. Sans effet tant qu''aucun écran ne pose expires_at.';

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'anarbib-consultas-expire-daily';
SELECT cron.schedule('anarbib-consultas-expire-daily', '10 3 * * *', $c$select public.fn_cron_expire_consultas();$c$);

-- I26 : la liste que restore.sh rejoue suit le cron neuf (même migration).
DO $mig$
DECLARE
  v_def text;
  v_n int;
  v_ancre text := $a$    ('anarbib-conv-file-alimenter', '10 5 * * 1', $c$select private.fn_conv_file_alimenter();$c$, true),$a$;
  v_ligne text := $b$    ('anarbib-consultas-expire-daily', '10 3 * * *', $c$select public.fn_cron_expire_consultas();$c$, true),
$b$;
BEGIN
  IF (SELECT md5(replace(prosrc, E'\r', '')) FROM pg_proc
       WHERE oid = 'private.fn_crons_attendus()'::regprocedure)
     <> '616f603996500dea910c15b5b4488ad8' THEN
    RAISE EXCEPTION 'F1 : private.fn_crons_attendus a changé depuis le relevé du 01/10 — relire avant de réécrire';
  END IF;
  v_def := replace(pg_get_functiondef('private.fn_crons_attendus()'::regprocedure), E'\r', '');
  v_n := (length(v_def) - length(replace(v_def, v_ancre, ''))) / length(v_ancre);
  IF v_n <> 1 THEN RAISE EXCEPTION 'F1 : ancre de fn_crons_attendus trouvée % fois (1 attendue)', v_n; END IF;
  v_def := replace(v_def, v_ancre, v_ligne || v_ancre);
  EXECUTE v_def;
END
$mig$;

-- ── 6. Ce qui reste, documenté dans la base ───────────────────────────
COMMENT ON FUNCTION public.trg_notify_reserva_workflow_change() IS
  'Trigger AFTER INSERT/UPDATE sur reserva_item_workflow_v2. Bloc 1 : transitions de workflow_stage (notifications lecteur+biblio). Bloc 2 (pickup_reply_status, legacy v2) retiré le 01/10/2026 (F1) : la liste UPDATE OF garde pickup_reply_status, sans effet. Bloc 3 : changement intra-stage en négociation v3 (contre-proposition, renégociation). Le stage re-retirada_agendada n''émet plus rien depuis F1 (interdit depuis la v3).';
COMMENT ON COLUMN public.library_notification_policies.reservation_mail_retirada_reagendada_enabled IS
  'Sans lecteur depuis F1 (01/10/2026) : le courriel retirada_reagendada est retiré (stage re-retirada_agendada interdit depuis la v3). Colonne gardée ; la supprimer demande une autorisation écrite.';
COMMENT ON COLUMN public.library_notification_policies.mid_loan_message_enabled IS
  'Sans lecteur depuis F1 (01/10/2026) : notify-mid-loan-reading est retirée ; le courriel de mi-parcours de notify-loan-cycle (note_invite) suit reading_notes_invite_enabled. Colonne gardée ; la supprimer demande une autorisation écrite.';
COMMENT ON COLUMN public.library_notification_policies.reading_recommendations_enabled IS
  'Sans lecteur depuis F1 (01/10/2026) : les recommandations partaient avec notify-mid-loan-reading, retirée. Colonne gardée ; la supprimer demande une autorisation écrite.';
COMMENT ON TABLE public.loan_midpoint_message_log IS
  'Log des messages automatiques à mi-parcours de prêt (notify-mid-loan-reading). Plus aucun écrivain depuis F1 (01/10/2026) ; 0 ligne. Table gardée (denylist #BG2) ; le DROP demande une autorisation écrite. Anon SELECT révoqué le 2026-04-26 (palier 2).';

-- ── Vérifications ─────────────────────────────────────────────────────
DO $mig$
BEGIN
  IF (SELECT count(*) FROM private.fn_crons_attendus()) <> 42 THEN
    RAISE EXCEPTION 'F1 : fn_crons_attendus doit porter 42 jobs';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM cron.job j JOIN private.fn_crons_attendus() a ON a.jobname = j.jobname::text
                  WHERE j.jobname = 'anarbib-consultas-expire-daily' AND j.command = a.command AND j.schedule = a.schedule) THEN
    RAISE EXCEPTION 'F1 : le cron anarbib-consultas-expire-daily ne correspond pas à fn_crons_attendus';
  END IF;
  IF has_function_privilege('anon', 'public.fn_cron_expire_consultas()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_cron_expire_consultas()', 'EXECUTE') THEN
    RAISE EXCEPTION 'F1 : fn_cron_expire_consultas ne doit être exécutable ni par anon ni par authenticated';
  END IF;
END
$mig$;
