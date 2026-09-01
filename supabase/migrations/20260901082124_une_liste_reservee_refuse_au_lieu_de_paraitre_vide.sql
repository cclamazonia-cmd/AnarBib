-- B14, lot `api`, paquet 3 : six fonctions de liste refusaient EN SILENCE.
--
-- LE MOTIF. Six fonctions réservées écrivent leur garde ainsi :
--
--     IF NOT public.fn_caller_is_network_admin() THEN
--       RETURN;                     -- <= rend une liste VIDE
--     END IF;
--
-- Pour l'appelant·e, « vous n'avez pas le droit » et « il n'y a rien » sont
-- alors le même octet. C'est `DOC-SILENCE-1` au mot près — un dispositif qui
-- n'agit pas doit le dire — et c'est ici plus trompeur qu'ailleurs, parce que
-- ces listes sont des RAPPORTS DE QUALITÉ : une liste vide y signifie « le
-- catalogue est sain ». Un refus déguisé en bilan rassurant.
--
-- L'INCOHÉRENCE INTERNE QUI LE PROUVE. Dans le MÊME schéma, quatre fonctions de
-- liste du chantier conventions (`conv_controle_qualite`, `conv_controle_resumo`,
-- `conv_revue_list`, `conv_revue_resume`) écrivent la même garde avec
-- `RAISE EXCEPTION … ERRCODE '42501'`. Deux écoles cohabitent dans le même
-- schéma ; celle qui se tait est la mauvaise.
--
-- PORTÉE RÉELLE, mesurée dans le dépôt avant d'écrire — et elle est inégale :
--   * `fn_authority_list` est ATTEIGNABLE PAR L'INTERFACE : `/atelier-autoridades`
--     est sous `<ProtectedRoute>` sans garde de rôle. Toute personne inscrite
--     ouvre l'Atelier et lit « rien à délibérer » au lieu d'« accès réservé ».
--     Le cas qui coûtera : une contributrice dont le statut passe à inactif ne
--     l'apprendra jamais — elle croira la file vide.
--   * les cinq `report_*` ne sont servies que par `ReportsPanel`, lui-même
--     derrière la garde stricte de `RedePage` (admins réseau seuls). Leur
--     silence n'est atteignable qu'en appel direct à `/rest/v1/rpc/`. On les
--     corrige pour la cohérence, pas pour l'urgence — et parce qu'un jour
--     quelqu'un réutilisera la fonction depuis un écran moins gardé.
--
-- Aucun changement de DROIT : ces fonctions refusaient déjà les mêmes
-- appelant·es. On change ce qu'elles DISENT en refusant, pas à qui.
--
-- CÔTÉ INTERFACE, vérifié : `ReportsPanel` porte un état `err` (son bloc
-- « aucun élément » est conditionné à `!err`) et `AtelierAutoridadesPage` passe
-- l'erreur à `localizeError`. Les deux écrans afficheront donc le refus.
--
-- FORME DE LA MIGRATION. On ne recopie pas six corps de fonction (les rapports
-- font des CTE de cent lignes : les retranscrire serait le vrai risque). On
-- reprend le patron du wrap RLS `20260703203953` — lire `pg_get_functiondef`,
-- substituer, ré-exécuter — en y ajoutant ce qui manquait là-bas : la
-- SUBSTITUTION EST VÉRIFIÉE. Si le motif n'est pas trouvé, la migration échoue
-- au lieu de laisser croire qu'elle a agi.

DO $$
DECLARE
  r record;
  v_def text;
  v_new text;
  v_msg text;
  n int := 0;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname
      FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
     WHERE ns.nspname = 'api'
       AND p.proname IN ('report_auteurs_non_resolus', 'report_autorites_a_completer',
                         'report_autorites_doublons', 'report_documents_incomplets',
                         'report_incoherences_auteurs', 'fn_authority_list')
  LOOP
    v_def := pg_get_functiondef(r.oid);

    v_msg := CASE r.proname
      WHEN 'fn_authority_list' THEN 'Atelier reservado a quem participa da rede (contribuinte, equipe ou administracao).'
      ELSE 'Relatorio reservado a administracao da rede.'
    END;

    -- Le motif visé : un `RETURN;` nu (éventuellement suivi d'un commentaire)
    -- placé juste après un `THEN` de garde. On ne touche à aucun autre RETURN :
    -- ceux des corps sont des `RETURN QUERY`, que ce motif ne peut pas attraper.
    v_new := regexp_replace(
      v_def,
      '(THEN\s*\n\s*)RETURN;([^\n]*)',
      '\1RAISE EXCEPTION ''' || v_msg || ''' USING ERRCODE = ''42501'';\2',
      ''
    );

    IF v_new = v_def THEN
      RAISE EXCEPTION 'api.% : motif « RETURN; » de garde introuvable — la fonction a change de forme, migration interrompue plutot que sans effet', r.proname;
    END IF;

    EXECUTE v_new;
    n := n + 1;
  END LOOP;

  IF n <> 6 THEN
    RAISE EXCEPTION 'six fonctions attendues, % traitees — liste desynchronisee', n;
  END IF;

  RAISE NOTICE 'refus muets convertis en refus explicites : % fonctions', n;
END $$;

-- Garde de fin : plus aucune des six ne porte de `RETURN;` nu, et toutes
-- restent exécutables par `authenticated` (le refus est dans le corps, pas
-- dans le droit — c'est la doctrine RPC du projet).
DO $$
DECLARE
  v_reste text;
BEGIN
  SELECT string_agg(p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'api'
     AND p.proname IN ('report_auteurs_non_resolus', 'report_autorites_a_completer',
                       'report_autorites_doublons', 'report_documents_incomplets',
                       'report_incoherences_auteurs', 'fn_authority_list')
     AND p.prosrc ~ 'THEN\s*\n\s*RETURN;';

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'refus muet subsistant sur : % — rollback', v_reste;
  END IF;

  SELECT string_agg(p.proname, ', ')
    INTO v_reste
    FROM pg_proc p JOIN pg_namespace ns ON ns.oid = p.pronamespace
   WHERE ns.nspname = 'api'
     AND p.proname IN ('report_auteurs_non_resolus', 'report_autorites_a_completer',
                       'report_autorites_doublons', 'report_documents_incomplets',
                       'report_incoherences_auteurs', 'fn_authority_list')
     AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'EXECUTE perdu pour authenticated sur : % — les ecrans casseraient, rollback', v_reste;
  END IF;
END $$;
