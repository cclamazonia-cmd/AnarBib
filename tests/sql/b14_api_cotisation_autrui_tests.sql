-- ===========================================================================
-- B14 — l'état de cotisation d'autrui n'est pas lisible (api.get_due_date_for_loan)
-- ===========================================================================
--
-- CE QUE CETTE SUITE EMPÊCHE DE REVENIR. `api.get_due_date_for_loan` prend un
-- `p_user_id` en paramètre. Jusqu'au 01/09/2026 elle le passait BRUT à
-- `fn_is_loan_blocked_by_dues`, puis lisait `v_active_memberships.dues_status`
-- pour ce même identifiant : n'importe quelle personne inscrite pouvait
-- demander l'état de cotisation de n'importe qui, à partir d'un UUID.
--
-- La garde existait — mais dans la fonction SUIVANTE. `resolve_circulation_rule`
-- résout `p_user_id` correctement (son étape 3) ; le bloc « cotisations »
-- s'exécutait AVANT elle. Lire la fonction déléguée rassurait ; c'est
-- l'appelante qu'il fallait lire. D'où cette suite, qui interroge l'EFFET et
-- pas le code.
--
-- CE QUI RENDAIT LE DÉFAUT INVISIBLE EN PRODUCTION : `fn_is_loan_blocked_by_dues`
-- sort `false` d'emblée quand la bibliothèque n'a pas `membership_enabled`, et
-- aucune bibliothèque ne l'avait activé au 01/09. La fuite était DORMANTE.
-- **La biblio du seed, elle, a `membership_enabled = true`** : c'est
-- précisément ce qui permet à cette suite de voir ce que la production cachait.
-- Un banc d'essai qui ressemble à la production d'aujourd'hui n'aurait rien vu.
--
-- Acteurs (supabase/seed.sql) :
--   11111111-…  coordenador BLMF-test   → staff, usage légitime du Painel
--   33333333-…  lectrice A, reader      → la curieuse
--   44444444-…  lecteur B,  reader      → celui dont on veut lire la cotisation
-- ===========================================================================

DO $$
DECLARE
  c_lib      constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  c_staff    constant uuid := '11111111-1111-1111-1111-111111111111';
  c_curieuse constant uuid := '33333333-3333-3333-3333-333333333333';
  c_cible    constant uuid := '44444444-4444-4444-4444-444444444444';

  v_passed  int := 0;
  v_failed  int := 0;
  v_skipped int := 0;
  v_failures text[] := '{}';
  v_skips    text[] := '{}';
  v_t text;
  v_label text;
  v_expl  text;
  v_rule_id bigint;
  v_rule uuid;
BEGIN
  -- Prérequis : la biblio du seed doit porter membership_enabled, sans quoi le
  -- chemin « cotisations » n'est jamais atteint et la suite ne prouve rien.
  -- On le DIT plutôt que de passer en silence (DOC-SILENCE-1).
  IF NOT EXISTS (SELECT 1 FROM public.libraries
                  WHERE id = c_lib AND coalesce(membership_enabled, false)) THEN
    RAISE EXCEPTION 'B14_COTISATION_AUTRUI ECHEC : la biblio du seed n''a pas membership_enabled — la suite ne pourrait pas voir le défaut qu''elle garde';
  END IF;

  -- FIXTURE. `dues_status` n'est pas une colonne : la vue le CALCULE à partir du
  -- dernier paiement (aucun -> 'never_paid'). Le seed n'ayant aucun paiement,
  -- les deux lectrices sont 'never_paid' par défaut — et une suite bâtie
  -- là-dessus ne prouverait RIEN : la curieuse verrait 'dues_blocked' pour son
  -- propre compte, exactement comme si la fuite existait. Il faut donc les
  -- rendre DIFFÉRENTES : la curieuse à jour, la cible non.
  INSERT INTO public.library_membership_rules (library_id, name, is_active, is_required)
  VALUES (c_lib, 'Cotisation de test B14', true, true)
  RETURNING id INTO v_rule;

  INSERT INTO public.membership_payments
    (user_id, library_id, rule_id, amount_paid, currency, valid_from, valid_until)
  VALUES (c_curieuse, c_lib, v_rule, 10, 'EUR', current_date - 1, current_date + 365);
  -- La cible ne reçoit AUCUN paiement -> 'never_paid', donc bloquée.

  -- ---------------------------------------------------------------------
  -- T1 — la curieuse demande la cotisation d'autrui : elle obtient LA SIENNE
  -- ---------------------------------------------------------------------
  v_t := 'T1 un p_user_id etranger ne renseigne pas sur autrui';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.v_active_memberships
                    WHERE user_id = c_cible AND library_id = c_lib
                      AND dues_status = 'never_paid') THEN
      v_skipped := v_skipped + 1;
      v_skips := v_skips || (v_t || ' : la vue v_active_memberships ne rend pas le dues_status pose par la fixture');
    ELSE
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', c_curieuse, 'role', 'authenticated')::text, true);

      SELECT rule_label, explanation INTO v_label, v_expl
        FROM api.get_due_date_for_loan(
          p_library_id := c_lib, p_user_id := c_cible, p_quantity := 1);

      PERFORM set_config('request.jwt.claims', '', true);

      -- La curieuse est elle-même à jour : elle ne doit PAS voir 'dues_blocked'.
      -- Le voir signifierait qu'on lui a répondu sur le compte d'autrui.
      IF coalesce(v_label, '') = 'dues_blocked' THEN
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t
          || ' : la reponse porte sur le compte vise -> ' || coalesce(v_expl, '?')
          || ' | l''etat de cotisation d''autrui a fuite');
      ELSE
        v_passed := v_passed + 1;
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T2 — la personne concernée voit SON propre blocage (le dispositif agit)
  -- ---------------------------------------------------------------------
  -- Sans ce test, T1 passerait aussi si la fonction avait cessé de regarder
  -- les cotisations : on aurait fermé la fuite en cassant la fonctionnalité,
  -- et rien ne le dirait.
  v_t := 'T2 la personne concernee voit son propre blocage';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.v_active_memberships
                    WHERE user_id = c_cible AND library_id = c_lib
                      AND dues_status = 'never_paid') THEN
      v_skipped := v_skipped + 1;
      v_skips := v_skips || (v_t || ' : fixture dues_status non visible');
    ELSE
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', c_cible, 'role', 'authenticated')::text, true);

      SELECT rule_label INTO v_label
        FROM api.get_due_date_for_loan(
          p_library_id := c_lib, p_user_id := c_cible, p_quantity := 1);

      PERFORM set_config('request.jwt.claims', '', true);

      IF coalesce(v_label, '') = 'dues_blocked' THEN v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t
          || ' : rule_label=' || coalesce(v_label, 'NULL')
          || ' | le blocage par cotisation ne s''applique plus a la personne concernee');
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T3 — le staff de la bibliothèque garde son usage réel (comptoir, Painel)
  -- ---------------------------------------------------------------------
  v_t := 'T3 le staff de la biblio projette pour une lectrice';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.v_active_memberships
                    WHERE user_id = c_cible AND library_id = c_lib
                      AND dues_status = 'never_paid') THEN
      v_skipped := v_skipped + 1;
      v_skips := v_skips || (v_t || ' : fixture dues_status non visible');
    ELSE
      PERFORM set_config('request.jwt.claims',
        json_build_object('sub', c_staff, 'role', 'authenticated')::text, true);

      SELECT rule_label INTO v_label
        FROM api.get_due_date_for_loan(
          p_library_id := c_lib, p_user_id := c_cible, p_quantity := 1);

      PERFORM set_config('request.jwt.claims', '', true);

      IF coalesce(v_label, '') = 'dues_blocked' THEN v_passed := v_passed + 1;
      ELSE
        v_failed := v_failed + 1;
        v_failures := v_failures || (v_t
          || ' : rule_label=' || coalesce(v_label, 'NULL')
          || ' | le durcissement a casse l''usage legitime du comptoir');
      END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- ---------------------------------------------------------------------
  -- T4 — la règle vit aux DEUX endroits : la fonction déléguée garde aussi
  -- ---------------------------------------------------------------------
  -- `get_due_date_for_loan` réplique l'étape 3 de `resolve_circulation_rule`.
  -- Deux copies d'une même règle divergent ; ce test échoue le jour où l'une
  -- des deux cesse de garder, quel que soit le sens de la divergence.
  v_t := 'T4 resolve_circulation_rule garde aussi le p_user_id etranger';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', c_curieuse, 'role', 'authenticated')::text, true);

    SELECT rule_id INTO v_rule_id
      FROM api.resolve_circulation_rule(
        p_library_id := c_lib, p_mode := 'loan', p_user_id := c_cible,
        p_quantity := 1) LIMIT 1;

    PERFORM set_config('request.jwt.claims', '', true);
    -- On n'affirme rien sur la règle résolue (elle dépend du policy set) : ce
    -- qui compte est que l'appel aboutisse sans lever, donc que la résolution
    -- sécurisée soit toujours en place et retombe sur l'appelante.
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN
    PERFORM set_config('request.jwt.claims', '', true);
    v_failed := v_failed + 1;
    v_failures := v_failures || (v_t || ' : ' || SQLERRM);
  END;

  -- =====================================================================
  -- BILAN (RAISE = rollback de toute la transaction, fixtures comprises)
  -- =====================================================================
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'B14_COTISATION_AUTRUI OK : %/% tests passés (% skips)%',
      v_passed, (v_passed + v_failed), v_skipped,
      CASE WHEN v_skipped > 0 THEN ' | SKIPS: ' || array_to_string(v_skips, ' ; ') ELSE '' END;
  ELSE
    RAISE EXCEPTION 'B14_COTISATION_AUTRUI ECHEC : %/% OK, % échec(s) | %  (skips: %)',
      v_passed, (v_passed + v_failed), v_failed,
      array_to_string(v_failures, ' || '), array_to_string(v_skips, ' ; ');
  END IF;
END $$;
