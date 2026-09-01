-- B14, schéma `public`, paquet 4 : ce qu'un numéro suivant raconte du fonds,
-- et deux écritures sans portier.
--
-- ============================================================================
-- CE QUI A ÉTÉ TROUVÉ
-- ============================================================================
-- Le paquet 4 a trié les 188 fonctions `SECURITY DEFINER` de `public` restant
-- exposées à `authenticated` en s'appuyant, cette fois, sur le **vocabulaire
-- réel des gardes** relevé par introspection (21 prédicats extraits des motifs
-- `IF NOT <appel>`) plutôt que sur une liste de noms devinée — les quatre faux
-- positifs des paquets précédents venaient tous de là. 39 fonctions ressortaient
-- sans garde connue ; leur lecture donne quatre cas à traiter.
--
--   * `fn_next_tombo(p_library_id)` — **aucune garde d'appelant**. Elle rend le
--     prochain numéro d'inventaire d'une bibliothèque : son PRÉFIXE (donc sa
--     convention de cotation) et surtout, par le numéro lui-même, **le nombre
--     d'exemplaires déjà catalogués**. Appelée en boucle sur les bibliothèques
--     du réseau, elle donne la volumétrie comparée des fonds — une information
--     que rien ne publie par ailleurs, et que certaines bibliothèques ont de
--     bonnes raisons de ne pas donner.
--   * `link_book_contributors_to_authors(p_book_id)` — aucune garde **et elle
--     écrit** (`UPDATE public.book_contributors SET author_id = …`). N'importe
--     quel compte pouvait réattribuer les contributeur·rices d'une notice de
--     n'importe quelle bibliothèque.
--   * `fn_recompute_serial_holdings(bigint, uuid)` — écrit l'état de collection
--     calculé d'une revue. Aucun appelant frontend ; quatre appelantes SQL, qui
--     sont toutes des RPC `api.*` déjà gardées.
--   * `fn_backup_heartbeat_status()` — état des sauvegardes. Consommée par la
--     seule Edge Function `health-probe`, qui parle en `service_role`.
--
-- ============================================================================
-- POURQUOI DEUX REMÈDES DIFFÉRENTS
-- ============================================================================
-- Le réflexe du lot `api` — révoquer — aurait cassé deux écrans. Le contrôle
-- des appelants, fait avant d'écrire quoi que ce soit, montre que les deux
-- premières sont appelées **directement par le catalogage** :
--
--   fn_next_tombo                     <- src/pages/catalogacao/ExemplarDraftForm.jsx
--   link_book_contributors_to_authors <- src/pages/catalogacao/BookDraftForm.jsx
--
-- C'est exactement le piège de `api.confirm_pickup_v1` au paquet 1 : un `REVOKE`
-- y aurait remplacé un refus propre par un écran mort. `DOC-RPC-3` tranche —
-- **le refus vit dans le corps, pas dans le droit** — et c'est ce qu'on fait ici.
-- Les deux dernières, elles, n'ont aucun appelant qui parle en `authenticated` :
-- pour elles le droit est le bon endroit, et on révoque.
--
-- La garde laisse passer `auth.uid() IS NULL` : c'est le contexte serveur (cron,
-- `service_role`, suites SQL), qui n'a pas de session à contrôler. Elle laisse
-- passer aussi l'administration du réseau, sans quoi la publication d'une notice
-- dans une bibliothèque tierce — geste réservé aux admins depuis le 17/08 —
-- échouerait en catalogage.
--
-- ============================================================================
-- FORME
-- ============================================================================
-- Le corps n'est jamais retapé : on part de `pg_get_functiondef` et on insère la
-- garde après le `begin` de premier niveau, avec contrôle que l'insertion a bien
-- eu lieu (patron du paquet 2, payé par trois CI rouges).
--
-- Éprouvé en production dans une transaction annulée, dans les DEUX sens, ce
-- qu'un seul des deux ne prouvait pas :
--   * sous le JWT d'un lecteur sans rôle    -> next_tombo=REFUSEE  link_book=REFUSEE
--   * sous le JWT d'un membre du staff      -> next_tombo=OK(CCLA.2026.92)  link_book=OK

DO $$
DECLARE
  r record;
  v_def text;
  v_new text;
  v_garde text;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'public'
       AND p.prosecdef
       AND p.proname IN ('fn_next_tombo', 'link_book_contributors_to_authors')
  LOOP
    v_def := pg_get_functiondef(r.oid);

    v_garde := CASE r.proname
      WHEN 'fn_next_tombo' THEN
        E'\n  IF auth.uid() IS NOT NULL\n'
        || E'     AND NOT public.user_has_library_staff_role(auth.uid(), p_library_id)\n'
        || E'     AND NOT public.fn_caller_is_network_admin() THEN\n'
        || E'    RAISE EXCEPTION ''forbidden: tombo numbering is reserved to the staff of that library''\n'
        || E'      USING ERRCODE = ''42501'';\n'
        || E'  END IF;\n'
      ELSE
        E'\n  IF auth.uid() IS NOT NULL\n'
        || E'     AND NOT public.fn_caller_is_network_admin()\n'
        || E'     AND NOT EXISTS (\n'
        || E'       SELECT 1 FROM public.book_holdings h\n'
        || E'        WHERE h.book_id = p_book_id\n'
        || E'          AND public.user_has_library_staff_role(auth.uid(), h.library_id)\n'
        || E'     ) THEN\n'
        || E'    RAISE EXCEPTION ''forbidden: reserved to the staff of a library holding this book''\n'
        || E'      USING ERRCODE = ''42501'';\n'
        || E'  END IF;\n'
    END;

    v_new := regexp_replace(v_def, '(\n[Bb][Ee][Gg][Ii][Nn]\n)', '\1' || v_garde, '');

    IF v_new = v_def THEN
      RAISE EXCEPTION 'public.% : garde non insérée (le « begin » de premier niveau n''a pas été trouvé) — migration interrompue plutôt que sans effet', r.proname;
    END IF;

    EXECUTE v_new;
  END LOOP;
END $$;

-- Les deux sans appelant en session : ici le droit est le bon endroit.
REVOKE EXECUTE ON FUNCTION public.fn_backup_heartbeat_status() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_recompute_serial_holdings(bigint, uuid) FROM authenticated;

COMMENT ON FUNCTION public.fn_next_tombo(uuid) IS
  'Prochain numéro d''inventaire d''une bibliothèque. Réservée à son staff (ou à l''administration du réseau) depuis le 01/09/2026, B14 : le numéro rendu DIT le nombre d''exemplaires déjà catalogués, et le préfixe dit la convention de cotation. Reste exposée à authenticated — le catalogage l''appelle directement (ExemplarDraftForm) : le refus doit être un refus, pas un écran mort.';

COMMENT ON FUNCTION public.link_book_contributors_to_authors(bigint) IS
  'Rattache les contributeur·rices d''une notice aux autorités. ÉCRIT. Réservée au staff d''une bibliothèque détentrice du livre (ou à l''administration du réseau) depuis le 01/09/2026, B14 : elle n''avait aucune garde d''appelant. Reste exposée à authenticated — appelée directement par BookDraftForm.';

COMMENT ON FUNCTION public.fn_recompute_serial_holdings(bigint, uuid) IS
  'Recalcule l''état de collection d''une revue. ÉCRIT. Fermée à authenticated le 01/09/2026 (B14) : ses quatre appelantes sont des RPC api.* déjà gardées, aucun écran ne l''appelle en session.';

COMMENT ON FUNCTION public.fn_backup_heartbeat_status() IS
  'État des sauvegardes. Fermée à authenticated le 01/09/2026 (B14) : seule health-probe la consomme, en service_role. L''état des sauvegardes est une information d''exploitation, pas une information de lectorat.';

-- ============================================================================
-- GARDES DE FIN
-- ============================================================================
DO $$
DECLARE v_manque text;
BEGIN
  -- 1) Les deux gardées portent bien leur garde ET restent appelables : fermer
  --    leur EXECUTE casserait le catalogage au lieu de refuser proprement.
  SELECT string_agg(p.proname, ', ')
    INTO v_manque
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('fn_next_tombo', 'link_book_contributors_to_authors')
     AND (p.prosrc !~ 'user_has_library_staff_role'
          OR NOT has_function_privilege('authenticated', p.oid, 'EXECUTE'));

  IF v_manque IS NOT NULL THEN
    RAISE EXCEPTION 'garde absente ou EXECUTE perdu sur : % — rollback', v_manque;
  END IF;

  -- 2) Les deux révoquées le sont bien.
  IF has_function_privilege('authenticated', 'public.fn_backup_heartbeat_status()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public.fn_recompute_serial_holdings(bigint, uuid)', 'EXECUTE') THEN
    RAISE EXCEPTION 'révocation sans effet — rollback';
  END IF;

  -- 3) Le service continue de passer : health-probe et les RPC api.* tournent
  --    en service_role, et les quatre appelantes SQL appartiennent à postgres.
  IF NOT has_function_privilege('service_role', 'public.fn_backup_heartbeat_status()', 'EXECUTE') THEN
    RAISE EXCEPTION 'service_role a perdu fn_backup_heartbeat_status — health-probe casserait — rollback';
  END IF;
END $$;
