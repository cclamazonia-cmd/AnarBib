-- ===========================================================================
-- La salle des machines reste fermée au lectorat
-- ===========================================================================
--
-- CE QUE CETTE SUITE GARDE. Le paquet 9 de `B14` a cartographié, en transitif,
-- tout ce qu'un compte `authenticated` peut atteindre qui touche à
-- l'exploitation : HTTP sortant (`pg_net`), secrets (`vault`), mécanique cron,
-- files de notification. Verdict : **l'architecture est en couches, et les
-- couches sont étanches** —
--
--   * les ~30 fonctions moteur (`fn_dispatch_*`, `fn_enqueue_*`, `fn_cron_*`,
--     `fn_internal_get_vault_secret`, les appels LLM de la gazette) sont toutes
--     fermées à `authenticated` ;
--   * les fonctions métier exposées ne les atteignent qu'en tant que DEFINER —
--     le droit d'EXECUTE du wrapper n'est jamais celui de l'appelant ;
--   * deux exceptions font de l'HTTP sortant en direct, et chacune porte sa
--     garde de bibliothèque.
--
-- Rien de tout cela n'était gardé par un test : un GRANT distrait sur
-- `fn_internal_get_vault_secret` aurait donné **tous les secrets du vault** à
-- tout compte du réseau, sans qu'aucun voyant ne rougisse. La fuite historique
-- du projet (`fn_gazette_translate_call`, qui déclenchait l'API LLM facturée
-- depuis `/rest/v1/rpc/`) était exactement de cette famille.
--
-- POURQUOI LA SUITE EST STRUCTURELLE ET NON NOMINATIVE. Une liste de noms
-- dérive (`DOC-RECENS-1`) ; le critère « touche `vault.` / `net.http` dans son
-- corps » se remesure à chaque passage et attrape les fonctions qui n'existent
-- pas encore. Seules les EXCEPTIONS sont nommées — c'est le sens d'une
-- exception — et le T3 vérifie qu'elles gardent leur garde.
-- ===========================================================================

DO $$
DECLARE
  v_passed  int := 0;
  v_failed  int := 0;
  v_failures text[] := '{}';
  v_t text;
  v_reste text;
  v_n int;
BEGIN
  -- ---------------------------------------------------------------------
  -- T1 — aucune fonction exposée ne lit le vault, directement
  -- ---------------------------------------------------------------------
  v_t := 'T1 aucune fonction exposee ne touche vault directement';
  BEGIN
    SELECT string_agg(n.nspname||'.'||p.proname, ', ' ORDER BY p.proname) INTO v_reste
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public','api','private','ingest')
       AND p.prosrc ~ 'vault\.'
       AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
            OR has_function_privilege('anon', p.oid, 'EXECUTE'));

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : vault atteignable via -> ' || v_reste
        || ' | un compte du reseau pourrait lire des secrets d''exploitation');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — le lecteur de secrets reste fermé, y compris à PUBLIC
  -- ---------------------------------------------------------------------
  -- Le T1 le couvre par son critère ; celui-ci le nomme, parce que c'est LA
  -- fonction dont un GRANT distrait coûterait le plus : elle rend n'importe
  -- quel secret par son nom. Et il vérifie PUBLIC — le défaut natif de
  -- Postgres accorde EXECUTE à PUBLIC sur toute fonction neuve, et une
  -- recréation sans REVOKE y retomberait.
  v_t := 'T2 fn_internal_get_vault_secret fermee a authenticated, anon et PUBLIC';
  BEGIN
    IF NOT has_function_privilege('authenticated', 'public.fn_internal_get_vault_secret(text)', 'EXECUTE')
       AND NOT has_function_privilege('anon', 'public.fn_internal_get_vault_secret(text)', 'EXECUTE')
       AND NOT has_function_privilege('public', 'public.fn_internal_get_vault_secret(text)', 'EXECUTE') THEN
      v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t
        || ' : ouverte | cette fonction rend N''IMPORTE QUEL secret par son nom'
        || ' — service_role, cles API, secrets webhook');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — l'HTTP sortant exposé : deux exceptions, chacune avec sa garde
  -- ---------------------------------------------------------------------
  v_t := 'T3 http sortant expose = deux exceptions nominees, gardees';
  BEGIN
    SELECT string_agg(n.nspname||'.'||p.proname, ', ' ORDER BY p.proname) INTO v_reste
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public','api')
       AND p.prosrc ~ 'net\.http'
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
       AND p.proname NOT IN ('fn_import_harvest_oai', 'fn_send_weekly_report_now');

    IF v_reste IS NOT NULL THEN
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : http sortant hors exceptions -> ' || v_reste
        || ' | soit le fermer, soit l''ajouter ICI avec sa garde verifiee');
    ELSE
      -- les deux exceptions gardent leur garde
      SELECT count(*) INTO v_n
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE n.nspname = 'public'
         AND ((p.proname = 'fn_import_harvest_oai'
               AND p.prosrc ~ 'fn_caller_is_network_admin')
           OR (p.proname = 'fn_send_weekly_report_now'
               AND p.prosrc ~ 'user_can_manage_library_notifications'));
      IF v_n = 2 THEN v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t || ' : ' || v_n || '/2 exceptions gardees'
          || ' | une exception sans garde n''est plus une exception, c''est un trou');
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T4 — les corps de cron restent l'affaire du cron
  -- ---------------------------------------------------------------------
  v_t := 'T4 aucun corps de cron n est executable par authenticated ou anon';
  BEGIN
    SELECT string_agg(p.proname, ', ' ORDER BY p.proname) INTO v_reste
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname LIKE 'fn\_cron\_%'
       AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
            OR has_function_privilege('anon', p.oid, 'EXECUTE'));

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : atteignables -> ' || v_reste
        || ' | un compte pourrait declencher des envois de masse hors calendrier');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'SALLE_DES_MACHINES OK : %/% tests passés (0 skips)',
      v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'SALLE_DES_MACHINES ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
