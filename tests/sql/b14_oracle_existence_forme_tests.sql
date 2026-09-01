-- ===========================================================================
-- B14 — un refus ne dit pas si la chose existe ailleurs
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. Trois fonctions distinguaient deux
-- refus : « la chose existe, mais pas chez vous » et « la chose n'existe pas ».
-- La différence entre les deux messages est une réponse — elle transforme la
-- fonction en test d'existence :
--
--   * `fn_painel_find_profile_by_lookup` (e-mail) — corrigée le 01/09 au matin.
--     Une adresse se devine : c'était le cas exploitable avec un simple compte.
--   * `fn_painel_get_profile_by_id` (uuid) — sa jumelle, corrigée l'après-midi.
--   * `fn_attach_received_asset_record` (**bigint séquentiel**) — la pire pour
--     l'énumération : on compte les fonds reçus du réseau en incrémentant.
--
-- Les deux dernières ont été trouvées en cherchant le MOTIF (le texte du
-- message) plutôt que les noms — le second chemin qu'exige `DOC-RECENS-1`.
-- Le premier correctif, lui, avait été isolé : corriger une fonction sans
-- chercher ses sœurs.
--
-- D'où cette suite, qui garde la FORME et non les trois noms : elle attrapera
-- la quatrième sœur le jour où quelqu'un écrira ce message-là. La doctrine
-- inverse, à imiter, est celle de `api.resolve_reader_card` : elle rend
-- volontairement le même motif pour « pas staff » et pour « jeton inconnu »,
-- et son commentaire dit que la banalité du motif EST le contrôle.
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
  -- T1 — aucune fonction exposée ne porte le message « existe mais pas ici »
  -- ---------------------------------------------------------------------
  v_t := 'T1 aucun refus ne dit que la chose existe ailleurs';
  BEGIN
    SELECT string_agg(n.nspname||'.'||p.proname, ', ' ORDER BY n.nspname||'.'||p.proname)
      INTO v_reste
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname IN ('public','api')
       AND p.prosecdef
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE')
       AND p.prosrc ~* 'não pertence|nao pertence|pertence à biblioteca|pertence a biblioteca';

    IF v_reste IS NULL THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : motif present sur -> ' || v_reste
        || ' | deux messages de refus distincts font un test d''existence ;'
        || ' unifier le message (voir api.resolve_reader_card)');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — la fonction QUE L'ÉCRAN APPELLE reste exposée
  -- ---------------------------------------------------------------------
  -- T1 passerait aussi si quelqu'un supprimait les fonctions. On vérifie donc
  -- qu'un chemin reste ouvert : le refus doit vivre dans le corps, jamais dans
  -- le droit (`DOC-RPC-3`).
  --
  -- ATTENDU CORRIGÉ LE 01/09/2026, QUELQUES HEURES APRÈS SON ÉCRITURE, ET LA
  -- CORRECTION EST LA LEÇON. Ce test exigeait les TROIS fonctions exposées, en
  -- supposant qu'elles servaient toutes un écran. Le paquet 7 a posé la question
  -- que je n'avais pas posée — QUI LES APPELLE ? — et la réponse est : personne,
  -- pour deux d'entre elles. `fn_painel_get_profile_by_id` et
  -- `fn_painel_find_profile_by_email` sont remplacées par
  -- `…_by_lookup`, la seule que le panneau appelle ; elles ont donc été fermées.
  -- Le test gardait une propriété vraie d'UNE fonction et l'exigeait de trois.
  --
  -- `DOC-RPC-3` ne dit pas « ne jamais révoquer » : il dit que le refus ne doit
  -- pas remplacer un écran vivant par un écran mort. Là où aucun écran n'appelle,
  -- il n'y a pas d'écran à casser.
  v_t := 'T2 la fonction appelee par le panneau reste exposee';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_painel_find_profile_by_lookup','fn_attach_received_asset_record')
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

    IF v_n = 2 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || '/2 exposees'
        || ' | fermer l''EXECUTE de celles-la casse un ecran vivant au lieu de'
        || ' refuser proprement — ce n''est pas le cas des deux remplacees,'
        || ' fermees le 01/09 parce que RIEN ne les appelle');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2b — et les deux remplacées restent fermées
  -- ---------------------------------------------------------------------
  -- L'autre moitié : elles ont été fermées pour une raison mesurée (aucun
  -- appelant, ni en base ni au dépôt). Si un écran venait à les appeler de
  -- nouveau, c'est ce test qui doit forcer à trancher — rouvrir le droit, ou
  -- appeler la remplaçante.
  v_t := 'T2b les deux fonctions remplacees restent fermees';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname IN ('fn_painel_get_profile_by_id','fn_painel_find_profile_by_email')
       AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

    IF v_n = 0 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || ' rouverte(s)'
        || ' | une CREATE OR REPLACE reapplique les droits par defaut du schema :'
        || ' remettre le REVOKE dans la migration qui recree la fonction');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — la doctrine inverse est toujours en place là où elle a été écrite
  -- ---------------------------------------------------------------------
  -- `api.resolve_reader_card` rend deux fois `token_not_found` : une fois pour
  -- le jeton inconnu, une fois pour l'appelant qui n'est pas staff. Si une
  -- « clarification » spécialisait le second, la carte redeviendrait
  -- énumérable — son commentaire l'annonce, ce test le tient.
  v_t := 'T3 resolve_reader_card rend toujours le meme motif deux fois';
  BEGIN
    SELECT count(*) INTO v_n
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     CROSS JOIN LATERAL regexp_matches(p.prosrc, 'token_not_found', 'g')
     WHERE n.nspname = 'api' AND p.proname = 'resolve_reader_card';

    IF v_n >= 2 THEN v_passed := v_passed + 1;
    ELSE
      v_failed := v_failed + 1;
      v_failures := v_failures || (v_t || ' : ' || v_n || ' occurrence(s) de token_not_found'
        || ' | le motif banal a ete specialise : la carte redevient enumerable');
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN (RAISE = rollback ; ici aucune fixture, mais on garde la forme)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'B14_ORACLE_EXISTENCE OK : %/% tests passés (0 skips)',
      v_passed, (v_passed + v_failed);
  ELSE
    RAISE EXCEPTION 'B14_ORACLE_EXISTENCE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed + v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
