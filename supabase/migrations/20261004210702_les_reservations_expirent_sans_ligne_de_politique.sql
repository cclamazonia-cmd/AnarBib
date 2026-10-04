-- =====================================================================
-- F20 — sans ligne de politique, une bibliothèque voyait ses réservations ne
-- jamais expirer et ses non-venues ne jamais être détectées.
--
-- fn_expire_solicitada_reservations, fn_expire_negotiation_timeout et
-- fn_detect_no_show_reservations faisaient un INNER JOIN sur
-- library_notification_policies : une réservation d'une bibliothèque sans
-- ligne (le 04/10 : Solidaires, anarchief, blmf-teste) sortait de la requête.
-- Les déclencheurs de notification, eux, ouvrent par défaut (fail-open) : le
-- défaut était donc côté crons seulement. Latent (aucune réservation hors BLMF).
--
-- Correctif : LEFT JOIN, et les délais par défaut DES COLONNES quand la ligne
-- manque — 14 jours (solicitada), 21 jours (négociation), 24 heures
-- (non-venue). La suite vérifie que ces nombres sont toujours les DEFAULT de
-- library_notification_policies. Aucune donnée écrite : pas de ligne de
-- politique créée.
-- Chaque fonction est réécrite depuis sa définition RÉELLE (pg_get_functiondef,
-- retours chariot retirés), remplacements COMPTÉS, empreinte du corps gardée.
-- Suite : tests/sql/reservations_sans_politique_tests.sql.
-- =====================================================================

DO $mig$
DECLARE
  v_fn record;
  v_def text;
  v_n int;
  v_md5 text;
BEGIN
  FOR v_fn IN
    SELECT * FROM (VALUES
      ('public.fn_expire_solicitada_reservations()'::regprocedure,
       '042a0683ce2c96a3cbcfea3b7b443465', 'reservation_solicitada_timeout_days', 14),
      ('public.fn_expire_negotiation_timeout()'::regprocedure,
       'fedd84ad994e30316d48506a4614f1bb', 'reservation_negotiation_timeout_days', 21),
      ('public.fn_detect_no_show_reservations()'::regprocedure,
       '96129f50e026002fde7df246308785bc', 'reservation_no_show_timeout_hours', 24)
    ) AS t(fn, md5, colonne, defaut)
  LOOP
    SELECT md5(replace(prosrc, E'\r', '')) INTO v_md5 FROM pg_proc WHERE oid = v_fn.fn;
    IF v_md5 <> v_fn.md5 THEN
      RAISE EXCEPTION 'F20 : % a changé depuis le relevé du 04/10 — relire avant de réécrire', v_fn.fn;
    END IF;
    v_def := replace(pg_get_functiondef(v_fn.fn), E'\r', '');

    v_n := (length(v_def) - length(replace(v_def, 'JOIN public.library_notification_policies lnp ON', '')))
           / length('JOIN public.library_notification_policies lnp ON');
    IF v_n <> 1 THEN RAISE EXCEPTION 'F20 : % — jointure trouvée % fois (1 attendue)', v_fn.fn, v_n; END IF;
    v_def := replace(v_def, 'JOIN public.library_notification_policies lnp ON',
                            'LEFT JOIN public.library_notification_policies lnp ON');

    v_n := (length(v_def) - length(replace(v_def, 'lnp.' || v_fn.colonne, ''))) / length('lnp.' || v_fn.colonne);
    IF v_n <> 2 THEN RAISE EXCEPTION 'F20 : % — lnp.% trouvé % fois (2 attendues)', v_fn.fn, v_fn.colonne, v_n; END IF;
    v_def := replace(v_def, 'lnp.' || v_fn.colonne,
                            format('coalesce(lnp.%s, %s)', v_fn.colonne, v_fn.defaut));

    EXECUTE v_def;

    v_def := pg_get_functiondef(v_fn.fn);
    IF v_def NOT LIKE '%LEFT JOIN public.library_notification_policies lnp ON%'
       OR v_def NOT LIKE format('%%coalesce(lnp.%s, %s)%%', v_fn.colonne, v_fn.defaut) THEN
      RAISE EXCEPTION 'F20 : réécriture de % incomplète', v_fn.fn;
    END IF;
  END LOOP;
END
$mig$;
