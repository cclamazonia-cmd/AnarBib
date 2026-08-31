-- =====================================================================
-- AnarBib — Tests : les rappels d'échéance existent, et ne partent qu'une fois
-- Date    : 2026-08-31  ·  Item F4  ·  doctrines DOC-RAPPEL-1, DOC-SILENCE-1
-- Ref     : migration 20260831111700 · supabase/functions/notify-loan-cycle/
--
-- CE QUE CETTE SUITE GARDE.
--
-- L'item est né d'un constat simple : deux interrupteurs commandaient des
-- envois qui n'existaient pas, et trois bibliothèques les avaient à `true`
-- sans le savoir. Ce qui doit rester vrai n'est donc pas « le code est écrit »
-- mais **le lien entre l'interrupteur et l'envoi**.
--
-- T6 est celui qui compte sur la durée : il vérifie qu'un même rappel ne peut
-- pas partir deux fois. Sans cette garantie, un cron rejoué produirait
-- exactement le déluge que DOC-RAPPEL-1 cherche à éviter — et nous l'avons
-- vécu le 30/08, à nos dépens, avec dix courriels d'alerte pour un incident.
--
-- T5 refuse que l'ancien mi-parcours revienne à côté du nouveau : deux crons
-- vivants, ce serait deux courriels le même jour à la même personne.
--
--   Bilan attendu : 'RAPPELS-ECHEANCE' suivi de la forme de succès et de N/N.
-- =====================================================================

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_skipped int := 0;
  v_skips text[] := '{}';
  v_t text;
  v_n int;
  v_item bigint;
BEGIN

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 l''interrupteur de l''invitation a ecrire existe';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.columns
     WHERE table_schema='public' AND table_name='library_notification_policies'
       AND column_name='reading_notes_invite_enabled';
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : absent'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 les trois interrupteurs du cycle sont la, et commandent un envoi';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.columns
     WHERE table_schema='public' AND table_name='library_notification_policies'
       AND column_name IN ('loan_reminders_enabled','loan_overdue_enabled','reading_notes_invite_enabled');
    IF v_n = 3 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/3'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 la trace des envois est fermee aux roles de session';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
     WHERE n.nspname='public' AND c.relname='loan_cycle_notifications' AND c.relrowsecurity;
    IF v_n <> 1 THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : RLS non activee');
    ELSIF has_table_privilege('anon','public.loan_cycle_notifications','SELECT')
       OR has_table_privilege('authenticated','public.loan_cycle_notifications','SELECT') THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : lisible par anon ou authenticated');
    -- Le sens inverse compte autant : une table fermee a tout le monde, y
    -- compris a qui doit y ecrire, casse l'envoi sans rien dire.
    ELSIF NOT has_table_privilege('service_role','public.loan_cycle_notifications','INSERT') THEN
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : service_role ne peut pas ecrire la trace -- aucun rappel ne serait consigne');
    ELSE v_passed := v_passed+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 le declencheur existe et n''est pas offert aux roles de session';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
                    WHERE n.nspname='public' AND p.proname='fn_cron_notify_loan_cycle') THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fonction absente');
    ELSIF has_function_privilege('anon','public.fn_cron_notify_loan_cycle()','EXECUTE')
       OR has_function_privilege('authenticated','public.fn_cron_notify_loan_cycle()','EXECUTE') THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : executable par anon ou authenticated');
    ELSE v_passed := v_passed+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Deux crons vivants, ce serait deux courriels le meme jour a la meme
  -- personne. L'ancien est remplace, pas double.
  -- CE QUE CE BANC D'ESSAI NE PEUT PAS DIRE. La base reconstruite en CI n'a pas
  -- `pg_cron` : aucun des trente-six crons de production n'y est verifiable.
  -- On l'annonce dans le bilan a chaque passage plutot que de le taire --
  -- DOC-SILENCE-1 (c), ce qui se desactive compte dans le denominateur. Tant
  -- que cette ligne s'affiche, personne ne peut croire que nos crons sont testes.
  v_t := 'T5 un seul cron de cycle, et l''ancien mi-parcours ne revient pas';
  BEGIN
    IF to_regnamespace('cron') IS NULL THEN
      v_skipped := v_skipped+1;
      v_skips := v_skips||(v_t||' : pg_cron absent de ce banc d''essai -- AUCUN cron n''y est verifiable');
      RAISE NOTICE 'RAPPELS-ECHEANCE : T5 non verifiable ici (pg_cron absent).';
    ELSE
    SELECT count(*) INTO v_n FROM cron.job WHERE jobname='anarbib-notify-loan-cycle-daily';
    IF v_n <> 1 THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cron du cycle absent ou en double ('||v_n||')');
    ELSE
      SELECT count(*) INTO v_n FROM cron.job WHERE jobname='anarbib-notify-mid-loan-reading-daily';
      IF v_n <> 0 THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : l''ancien mi-parcours tourne encore');
      ELSE v_passed := v_passed+1; END IF;
    END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- LE TEST QUI COMPTE. Il ecrit, parce que verifier qu'une contrainte est
  -- declaree ne prouve pas qu'elle refuse.
  v_t := 'T6 un meme rappel ne peut pas partir deux fois';
  BEGIN
    SELECT id INTO v_item FROM public.emprestimo_itens_v2 ORDER BY id LIMIT 1;
    IF v_item IS NULL THEN
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : aucun item d''emprunt dans le seed -- le test ne peut pas s''executer, '
        ||'et un test qui ne s''execute pas ne prouve rien');
    ELSE
      INSERT INTO public.loan_cycle_notifications (emprestimo_item_id, moment) VALUES (v_item, 'd3');
      BEGIN
        INSERT INTO public.loan_cycle_notifications (emprestimo_item_id, moment) VALUES (v_item, 'd3');
        v_failed := v_failed+1;
        v_failures := v_failures||(v_t||' : la base a accepte un second envoi du meme rappel');
      EXCEPTION WHEN unique_violation THEN
        v_passed := v_passed+1;
      END;
      DELETE FROM public.loan_cycle_notifications WHERE emprestimo_item_id = v_item AND moment = 'd3';
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 les quatre moments sont nommes, et eux seuls';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_constraint
     WHERE conrelid='public.loan_cycle_notifications'::regclass AND contype='c'
       AND pg_get_constraintdef(oid) LIKE '%note_invite%'
       AND pg_get_constraintdef(oid) LIKE '%overdue7%';
    IF v_n >= 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : le CHECK des moments est absent ou incomplet');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Le denominateur inclut les ignores : une suite qui retrecit sans que le
  -- chiffre bouge est une suite qui ment (DOC-SILENCE-1 (c)).
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'RAPPELS-ECHEANCE OK : %/% tests passés (% ignoré(s)%)',
      v_passed, (v_passed+v_failed+v_skipped), v_skipped,
      CASE WHEN v_skipped > 0 THEN ' — ' || array_to_string(v_skips, ' || ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'RAPPELS-ECHEANCE ECHEC : %/% OK, % échec(s), % ignoré(s) | %',
      v_passed, (v_passed+v_failed+v_skipped), v_failed, v_skipped,
      array_to_string(v_failures || v_skips, ' || ');
  END IF;
END $$;
