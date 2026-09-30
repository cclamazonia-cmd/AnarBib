-- =====================================================================
-- AnarBib — Tests : inviter une personne à une tâche crée une invitation
-- Date    : 2026-09-30
-- Réf     : 20260930195644_l_invitation_a_une_tache_cree_une_invitation.sql
--           backlog F16 ; carte F1 (docs/journal/audits/CARTE_chaine_courriel_2026-09-30.md)
--
-- CE QUE CETTE SUITE PROUVE, en EMPRUNTANT le chemin du bouton « Inviter » :
-- `fn_task_invite` → marqueur `convite:<adresse>` → déclencheur de
-- synchronisation → une invitation `pending` et une ligne `task_invitation`
-- dans la file d'envoi. Jusqu'au 30/09, ce chemin ne créait RIEN (l'adresse
-- était posée brute, la synchronisation ne lit que `convite:`), et l'écran
-- annonçait « invitation envoyée ». Aucune suite ne l'empruntait.
--
-- Convention : bilan « TACHES-INVITATION OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  ok int := 0; total int := 6;
  v_lib uuid; v_task uuid; v_res jsonb; v_n int; v_m int; v_tags text[]; v_txt text;
BEGIN
  -- L'expédition (dispatch_task_invitation_outbox) lit l'adresse et le secret de
  -- notify-internal-task au coffre ; ils existent en production (relevé du 30/09),
  -- pas dans la base jetable du banc. Valeurs factices et publiques : au banc,
  -- net.http_post dépose sa requête dans une file que personne ne vide.
  INSERT INTO vault.decrypted_secrets (name, description, decrypted_secret)
  SELECT v.n, 'banc — factice, PAS un vrai secret', v.s
    FROM (VALUES ('ANARBIB_TASK_INVITE_FUNCTION_URL', 'http://banc.invalid/functions/v1/notify-internal-task'),
                 ('ANARBIB_TASK_INVITE_SECRET', 'secret-de-banc-factice')) v(n, s)
   WHERE NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets d WHERE d.name = v.n);

  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-taches-invitation', 'Essai — invitation', true, 'private')
  RETURNING id INTO v_lib;
  v_res := public.fn_task_create(v_lib, 'Préparer la permanence', 'Tenir la table du samedi.',
                                 'media', 'Essai', current_date + 3, ARRAY['atelier']);
  v_task := (v_res->>'id')::uuid;

  -- T1 : inviter pose le marqueur que la synchronisation lit
  BEGIN
    v_res := public.fn_task_invite(v_task, '  Invitee@Exemple.org ');
    SELECT tags INTO v_tags FROM public.painel_internal_tasks WHERE id = v_task;
    IF 'convite:invitee@exemple.org' = ANY(v_tags) AND NOT ('invitee@exemple.org' = ANY(v_tags)) THEN ok := ok + 1;
    ELSE RAISE WARNING 'T1 marqueurs : %', v_tags; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T1 fn_task_invite a leve : % (%)', SQLERRM, SQLSTATE;
  END;

  -- T2 : une invitation existe pour cette adresse, vivante (l'expédition la passe
  --      aussitôt de « pending » à « sent », une fois la requête déposée)
  SELECT count(*) INTO v_n FROM public.painel_internal_task_invites
   WHERE task_id = v_task AND invite_email = 'invitee@exemple.org' AND invite_status IN ('pending', 'sent');
  IF v_n = 1 THEN ok := ok + 1; ELSE RAISE WARNING 'T2 invitations : %', v_n; END IF;

  -- T3 : une ligne d'envoi « task_invitation » attend dans la file
  SELECT count(*) INTO v_m FROM public.painel_internal_task_invitation_outbox
   WHERE task_id = v_task AND recipient_email = 'invitee@exemple.org' AND event_kind = 'task_invitation';
  IF v_m = 1 THEN ok := ok + 1; ELSE RAISE WARNING 'T3 lignes de file : %', v_m; END IF;

  -- T4 : réinviter la même personne ne double rien
  BEGIN
    v_res := public.fn_task_invite(v_task, 'invitee@exemple.org');
    SELECT count(*) INTO v_m FROM public.painel_internal_task_invitation_outbox WHERE task_id = v_task;
    IF v_res->>'sync_status' = 'already_present' AND v_m = 1 THEN ok := ok + 1;
    ELSE RAISE WARNING 'T4 idempotence : %, % ligne(s)', v_res->>'sync_status', v_m; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T4 a leve : % (%)', SQLERRM, SQLSTATE;
  END;

  -- T5 : une adresse invalide est refusée, sans rien toucher
  BEGIN
    PERFORM public.fn_task_invite(v_task, 'pas-une-adresse');
    RAISE WARNING 'T5 : adresse invalide acceptee';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE '%email invalide%' THEN ok := ok + 1; ELSE RAISE WARNING 'T5 : %', SQLERRM; END IF;
  END;

  -- T6 : retirer le marqueur annule l'invitation (la base suit les marqueurs)
  BEGIN
    UPDATE public.painel_internal_tasks SET tags = array_remove(tags, 'convite:invitee@exemple.org') WHERE id = v_task;
    SELECT invite_status INTO v_txt FROM public.painel_internal_task_invites
     WHERE task_id = v_task AND invite_email = 'invitee@exemple.org';
    IF v_txt = 'cancelled' THEN ok := ok + 1; ELSE RAISE WARNING 'T6 statut apres retrait : %', v_txt; END IF;
  EXCEPTION WHEN OTHERS THEN RAISE WARNING 'T6 a leve : % (%)', SQLERRM, SQLSTATE;
  END;

  IF ok = total THEN
    RAISE NOTICE 'TACHES-INVITATION OK : %/% tests passés', ok, total;
  ELSE
    RAISE EXCEPTION 'TACHES-INVITATION ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
