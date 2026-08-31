-- =====================================================================
-- AnarBib — Tests : les crons attendus sont planifiés, et eux seuls
-- Date    : 2026-08-31  ·  doctrines DOC-SILENCE-1, DOC-RPC-4 (esprit), OPS-8
-- Réf     : tests/sql/_ci_setup_cron_stub.sql · supabase/migrations/20260510000000 (socle)
--
-- CE QUE CETTE SUITE PROUVE — ET CE QU'ELLE NE PROUVE PAS.
--
--   Elle rejoue TOUTES les migrations sur une base neuve et regarde ce que
--   cette relecture planifie. Elle affirme donc : « le dépôt, appliqué de bout
--   en bout, produit exactement ces trente-six jobs, à ces horaires, dans cet
--   état ». C'est un énoncé sur le DÉPÔT.
--
--   Elle n'affirme RIEN sur la production : le schéma `cron` de ce banc d'essai
--   est un stub, aucun job n'y sera jamais exécuté, et la base de production
--   n'est pas interrogée ici. Un job peut être planifié dans ce test et absent
--   de la prod (un `unschedule` manuel, une restauration, une migration jamais
--   poussée). Le bilan le redit à chaque passage plutôt que de le taire —
--   DOC-SILENCE-1 : un dispositif qui n'agit pas doit le dire.
--
--   Ce que la liste ci-dessous vaut, elle le tient d'un relevé : elle a été
--   comparée à la production le 31/08/2026, par
--       select jobname, schedule, active from cron.job order by jobname;
--   et les deux ensembles coïncidaient — trente-six jobs, mêmes horaires, tous
--   actifs. C'est ce qui distingue cette liste d'une simple recopie du socle :
--   à cette date, elle décrivait aussi le réel. Refaire le relevé de temps en
--   temps est le seul moyen de garder ce lien ; rien ici ne peut le faire seul.
--
-- À QUOI ELLE SERT, CONCRÈTEMENT.
--
--   Jusqu'au 31/08/2026, aucune de ces lignes n'était écrivable : la base de
--   test n'avait pas de schéma `cron`, donc aucun des crons n'était couvert.
--   Trois choses deviennent visibles :
--     * une migration qui retire, renomme ou décale un job sans que personne
--       l'ait décidé fait rougir cette suite (T2, T3, T4) ;
--     * une activation qui échoue en silence se voit (T5). Les migrations
--       d'activation enveloppent leur `cron.alter_job` dans un
--       `exception when others` : sans ce test, un job resté inactif ne dirait
--       rien du tout ;
--     * un cron qui appelle une fonction disparue se voit (T6) — cas réel de ce
--       dépôt : `pg_depend` ne suit pas le contenu d'une commande cron, donc un
--       DROP ne prévient pas, et la panne n'arrive qu'au prochain déclenchement.
--
--   Bilan attendu : 'CRONS-PLANIFIES' suivi de la forme de succès et de N/N.
-- =====================================================================

DO $$
DECLARE
  v_passed int := 0;
  v_failed int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_n int;
  v_liste text;
  v_non_resolues int := 0;
  v_socle text;
BEGIN

  -- Les crons attendus, tels que le dépôt les produit et tels que la production
  -- les portait au 31/08/2026. Toute modification volontaire d'un cron passe
  -- par cette liste : c'est le point où le changement devient une décision.
  -- Table temporaire : la suite se termine par un RAISE EXCEPTION (convention
  -- maison), donc tout est annulé — aucun résidu, y compris celle-ci.
  CREATE TEMP TABLE attendus (jobname text, schedule text, active boolean);
  INSERT INTO attendus VALUES
    ('anarbib-authority-resolve-due-daily',         '45 3 * * *',   true),
    ('anarbib-catalog-audit-snapshot-purge',        '17 4 * * *',   true),
    ('anarbib-circle-resolve-due-daily',            '30 3 * * *',   true),
    ('anarbib-collective-removal-execute-daily',    '15 3 * * *',   true),
    ('anarbib-cooptation-reminders-daily',          '25 9 * * *',   true),
    ('anarbib-gazette-monthly-start',               '0 6 15 * *',   true),
    ('anarbib-gazette-reconcile-tick',              '*/5 * * * *',  true),
    ('anarbib-gazette-translate-submissions',       '*/10 * * * *', true),
    ('anarbib-health-probe',                        '*/5 * * * *',  true),
    ('anarbib-membership-expiry-daily',             '40 6 * * *',   true),
    ('anarbib-notify-cross-library-digest-weekly',  '30 8 * * 1',   true),
    ('anarbib-notify-loan-cycle-daily',             '15 9 * * *',   true),
    ('anarbib-notify-network-weekly-report-weekly', '15 8 * * 1',   true),
    ('anarbib-notify-weekly-report-weekly',         '0 8 * * 1',    true),
    ('anarbib-oai-harvest-weekly',                  '20 4 * * 2',   true),
    ('anarbib-oai-resolve-expired-votes',           '45 3 * * *',   true),
    ('anarbib-peb-detect-overdue-daily',            '40 3 * * *',   true),
    ('anarbib-purge-invitations-expirees',          '40 3 * * *',   true),
    ('anarbib-recompute-holdings-availability',     '43 4 * * *',   true),
    ('anarbib-rede-digest-weekly',                  '0 9 * * 1',    true),
    ('anarbib-request-eval-digest',                 '17 8 * * *',   true),
    ('anarbib-reservation-detect-no-show',          '15 * * * *',   true),
    ('anarbib-reservation-expire-negotiation',      '25 * * * *',   true),
    ('anarbib-reservation-expire-solicitada',       '5 * * * *',    true),
    ('anarbib-rgpd-notify-weekly',                  '0 2 * * 0',    true),
    ('anarbib-rgpd-purge-weekly',                   '0 3 * * 0',    true),
    ('anarbib-tasks-detect-stale-recurrence-daily', '50 3 * * *',   true),
    ('anarbib-team-inactive-cleanup',               '0 4 * * *',    true),
    ('anarbib-team-invitations-expire',             '20 3 * * *',   true),
    ('anarbib-team-pending-removal-complete',       '0 * * * *',    true),
    ('anarbib_execute_profile_proposals',           '*/15 * * * *', true),
    ('anarbib_expire_profile_proposals',            '0 3 * * *',    true),
    ('gc-fonds-deposits',                           '30 4 * * *',   true),
    ('reconcile-authority-dispatch',                '*/5 * * * *',  true),
    ('reconcile-task-dispatch',                     '*/5 * * * *',  true),
    ('refresh-mv-books-catalog-list',               '*/15 * * * *', true);

  -- ─────────────────────────────────────────────────────────────────
  -- Sans schéma `cron`, cette suite ne mesure rien. Elle ÉCHOUE au lieu de
  -- s'ignorer : le stub fait partie du harnais, son absence est une panne du
  -- banc d'essai, pas une circonstance.
  v_t := 'T1 le banc d''essai a bien une interface cron';
  BEGIN
    IF to_regnamespace('cron') IS NULL THEN
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : schéma cron absent — le stub '
        ||'tests/sql/_ci_setup_cron_stub.sql n''a pas été appliqué (cf. run-sql-suites.sh)');
    ELSIF to_regclass('cron.job') IS NULL THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : cron.job absente');
    ELSE v_passed := v_passed+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 aucun cron attendu ne manque';
  BEGIN
    SELECT count(*), string_agg(a.jobname, ', ' ORDER BY a.jobname)
      INTO v_n, v_liste
      FROM attendus a
     WHERE NOT EXISTS (SELECT 1 FROM cron.job j WHERE j.jobname::text = a.jobname);
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' absent(s) — '||v_liste);
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le sens inverse compte autant : sans lui, la liste rétrécirait sans bruit
  -- et un job ajouté par mégarde ne serait jamais regardé.
  v_t := 'T3 aucun cron inattendu';
  BEGIN
    SELECT count(*), string_agg(j.jobname::text, ', ' ORDER BY j.jobname::text)
      INTO v_n, v_liste
      FROM cron.job j
     WHERE NOT EXISTS (SELECT 1 FROM attendus a WHERE a.jobname = j.jobname::text);
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' en trop — '||v_liste
        ||' (si c''est voulu, ajoute-les à la liste de cette suite)');
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 chaque cron tourne a l''horaire voulu';
  BEGIN
    SELECT count(*), string_agg(a.jobname||' : attendu '||a.schedule||', trouvé '||j.schedule, ' | ')
      INTO v_n, v_liste
      FROM attendus a JOIN cron.job j ON j.jobname::text = a.jobname
     WHERE j.schedule IS DISTINCT FROM a.schedule;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_liste);
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- LE TEST QUI COMPTE SUR LA DURÉE. Les migrations d'activation
  -- (20260818000805, 20260821070000, 20260827080000) enveloppent leur
  -- `cron.alter_job` dans un `exception when others` : si l'activation échoue,
  -- elles n'en disent rien et le job reste dormant. Un cron dormant ne se
  -- signale jamais de lui-même — c'est exactement le silence que DOC-SILENCE-1
  -- interdit. Ici, il se voit.
  v_t := 'T5 les crons actifs le sont, les dormants le restent';
  BEGIN
    SELECT count(*), string_agg(a.jobname||' : attendu '
             ||CASE WHEN a.active THEN 'actif' ELSE 'dormant' END
             ||', trouvé '||CASE WHEN j.active THEN 'actif' ELSE 'dormant' END, ' | ')
      INTO v_n, v_liste
      FROM attendus a JOIN cron.job j ON j.jobname::text = a.jobname
     WHERE j.active IS DISTINCT FROM a.active;
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_liste);
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Une commande cron est du TEXTE : `pg_depend` ne la suit pas, un DROP ne
  -- prévient pas, et la panne n'arrive qu'au prochain déclenchement — un mois
  -- plus tard pour la gazette. On résout donc les appels `public.`, `api.` et
  -- `ingest.` de chaque commande et on exige qu'ils existent.
  -- Les commandes qui n'exposent aucun appel de ce genre (celle de la sonde de
  -- santé, qui passe par net.http_post) ne sont PAS vérifiées : le bilan le
  -- dit, plutôt que de les compter comme vérifiées.
  v_t := 'T6 chaque commande cron appelle une fonction qui existe';
  BEGIN
    SELECT count(*), string_agg(DISTINCT j.jobname::text||' → '||m.parts[1]||'.'||m.parts[2], ', ')
      INTO v_n, v_liste
      FROM cron.job j
      CROSS JOIN LATERAL regexp_matches(
        j.command, '\m(public|api|ingest)\.([a-z_][a-z0-9_]*)\s*\(', 'g') AS m(parts)
     WHERE NOT EXISTS (
       SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = m.parts[1] AND p.proname = m.parts[2]);
    SELECT count(*) INTO v_non_resolues
      FROM cron.job j
     WHERE j.command !~ '\m(public|api|ingest)\.[a-z_][a-z0-9_]*\s*\(';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||v_n||' appel(s) vers une fonction absente — '||v_liste);
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le bilan porte la limite, pas seulement le compte : lu seul, « 6/6 » ferait
  -- croire que les crons de production sont testés. Ils ne le sont pas.
  v_socle := CASE
    WHEN to_regnamespace('cron') IS NULL
      THEN 'AUCUNE interface cron ici — rien n''a pu être mesuré'
    WHEN to_regprocedure('cron.is_ci_stub()') IS NOT NULL
      THEN 'interface STUB (aucun job n''y sera exécuté ; rien n''est affirmé sur la production)'
    ELSE 'pg_cron réel — cette suite n''a pas été écrite pour être jouée ici'
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'CRONS-PLANIFIES OK : %/% tests passés — % jobs attendus, % commande(s) non résolue(s) donc non vérifiée(s) ; %',
      v_passed, (v_passed+v_failed), (SELECT count(*) FROM attendus), v_non_resolues, v_socle;
  ELSE
    RAISE EXCEPTION 'CRONS-PLANIFIES ECHEC : %/% OK, % échec(s) | % | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || '), v_socle;
  END IF;
END $$;
