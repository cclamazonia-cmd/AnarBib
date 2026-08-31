-- =====================================================================
-- AnarBib — Tests : un envoi non effectué dit pourquoi
-- Date    : 2026-08-31  ·  Item B12  ·  doctrine DOC-SILENCE-1
-- Ref     : migration 20260831090412_un_saut_dit_desormais_pourquoi
--
-- CE QUE CETTE SUITE GARDE, ET POURQUOI ELLE NE SE CONTENTE PAS DE REGARDER.
--
-- Le défaut d'origine n'était pas qu'une colonne manquait : c'est que sept
-- endroits du code décidaient de ne pas envoyer, nommaient leur raison dans
-- une variable, et la jetaient. Quatre lignes de `team_notification_outbox`
-- en portaient la trace depuis le 8 juin — même event, jamais parti, aucune
-- explication. Vérifier la présence de la colonne ne suffit donc pas : ce qui
-- doit rester vrai, c'est qu'une ligne muette soit REFUSÉE par la base.
--
-- D'où T4 à T7, qui écrivent vraiment. Un test qui n'exécute pas ne prouve
-- rien : c'est la leçon des trois erreurs du 30/08, où le produit avait
-- raison et le test lisait le mauvais champ.
--
-- T8 est le garde-fou sur la durée : il refuse qu'une ligne sautée sans
-- raison survive dans la base, quel qu'en soit l'auteur.
--
--   Bilan attendu : 'OUTBOX-SAUT' suivi de la forme de succès et de N/N.
-- =====================================================================

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_n int;
  v_id bigint;
  v_tables text[] := ARRAY[
    'team_notification_outbox',
    'authority_proposal_notification_outbox',
    'cartography_submission_notification_outbox',
    'gazette_submission_notification_outbox',
    'lettre_notification_outbox'
  ];
BEGIN

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 les cinq outbox portent une colonne skip_reason';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.columns
     WHERE table_schema = 'public' AND column_name = 'skip_reason'
       AND table_name = ANY(v_tables);
    IF v_n = 5 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||'/5');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 chaque outbox refuse un saut sans raison (5 gardes)';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_constraint c
      JOIN pg_class k ON k.oid = c.conrelid
     WHERE k.relname = ANY(v_tables) AND c.conname LIKE '%\_skip\_reason\_chk';
    IF v_n = 5 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||'/5');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 chaque outbox refuse un sent_at sur un saut (5 gardes)';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_constraint c
      JOIN pg_class k ON k.oid = c.conrelid
     WHERE k.relname = ANY(v_tables) AND c.conname LIKE '%\_skipped\_sent\_at\_chk';
    IF v_n = 5 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||'/5');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le cas qui a motivé l'item : la base doit REFUSER, pas seulement pouvoir
  -- accueillir la raison.
  v_t := 'T4 une ligne sautee sans raison est refusee';
  BEGIN
    INSERT INTO public.team_notification_outbox (event, payload, status, attempts)
    VALUES ('team.epreuve_b12', '{}'::jsonb, 'skipped', 0);
    v_failed := v_failed+1;
    v_failures := v_failures||(v_t||' : la base a accepte une ligne muette');
  EXCEPTION
    WHEN check_violation THEN v_passed := v_passed+1;
    WHEN OTHERS THEN v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : refus attendu mais autre erreur -> '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 une ligne sautee datee d''un envoi est refusee';
  BEGIN
    INSERT INTO public.team_notification_outbox (event, payload, status, attempts, skip_reason, sent_at)
    VALUES ('team.epreuve_b12', '{}'::jsonb, 'skipped', 0, 'no_recipients', now());
    v_failed := v_failed+1;
    v_failures := v_failures||(v_t||' : la base a date un envoi qui n''a pas eu lieu');
  EXCEPTION
    WHEN check_violation THEN v_passed := v_passed+1;
    WHEN OTHERS THEN v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : refus attendu mais autre erreur -> '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le sens inverse : les gardes ne doivent pas empecher le cas legitime.
  v_t := 'T6 une ligne sautee avec sa raison est acceptee';
  BEGIN
    INSERT INTO public.team_notification_outbox (event, payload, status, attempts, skip_reason)
    VALUES ('team.epreuve_b12', '{}'::jsonb, 'skipped', 0, 'unknown_team_event')
    RETURNING id INTO v_id;
    IF v_id IS NOT NULL THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun id rendu'); END IF;
    DELETE FROM public.team_notification_outbox WHERE id = v_id;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- `authority` n'avait pas le mot pour dire qu'elle n'avait rien envoye :
  -- son enum valait ('queued','sent','failed'). D'ou le `sent` par defaut.
  v_t := 'T7 authority sait desormais dire qu''elle n''a pas envoye';
  BEGIN
    INSERT INTO public.authority_proposal_notification_outbox (event, payload, status, skip_reason)
    VALUES ('authority.epreuve_b12', '{}'::jsonb, 'skipped', 'unknown_event')
    RETURNING id INTO v_id;
    IF v_id IS NOT NULL THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun id rendu'); END IF;
    DELETE FROM public.authority_proposal_notification_outbox WHERE id = v_id;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1;
    v_failures := v_failures||(v_t||' : statut skipped toujours refuse -> '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 aucune ligne sautee muette ne survit dans la base';
  BEGIN
    SELECT count(*) INTO v_n FROM public.team_notification_outbox
     WHERE status = 'skipped' AND (skip_reason IS NULL OR sent_at IS NOT NULL);
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) muette(s)');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'OUTBOX-SAUT OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'OUTBOX-SAUT ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
