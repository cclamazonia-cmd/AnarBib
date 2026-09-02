-- B20, premier geste : une surface morte ne reste pas ouverte aux anonymes.
--
-- ============================================================================
-- LE CONSTAT, ET D'OÙ IL VIENT
-- ============================================================================
-- Le Grand Livre blanc v17 (01/09) a dénombré la jonction frontale entière :
-- 17 fonctions du schéma `api` n'ont aucun appelant — ni dans `src/`, ni dans
-- `supabase/functions/`, ni dans `scripts/`, ni dans le corps d'une autre
-- fonction SQL, ni dans une policy, ni dans un cron. Contre-vérifié à l'unité
-- le 02/09 par deux chemins indépendants (grep du dépôt : 0 occurrence × 17 ;
-- requête en production : 0 appelant partout) — DOC-CONSTAT-1.
--
-- Le contre-contrôle a trouvé ce que le GLB n'avait pas vu : trois de ces
-- fonctions mortes sont aussi exécutables par `anon`. La ligne rouge v14 —
-- « aucun helper exposé à `anon` sans justification politique écrite » —
-- tranche seule : aucune justification n'existe, personne n'appelle ces
-- fonctions, personne n'a donc rien à y perdre.
--
-- ============================================================================
-- CE QUE CETTE MIGRATION NE CHANGE PAS (DOC-MSG-1, les trois volets)
-- ============================================================================
-- * Comportement : le corps de ces wrappers (SECURITY INVOKER) refuse déjà
--   l'appel sans session — la suite `paquet19_loan_wrappers_tests.sql`
--   (7.01, 7.04) le garde. Le REVOKE fait échouer l'appel anonyme plus tôt
--   (42501 au lieu du refus du corps), mais ce chemin n'a aucun appelant.
-- * Le test observateur : 7.01/7.04 appellent après RESET ROLE + claims
--   vides, donc en `postgres`, qui conserve son EXECUTE — inchangés.
-- * `authenticated` : conservé. Le sort des quatre lots (brancher, révoquer,
--   documenter) reste l'arbitrage de B20, pas celui de cette migration.
--
-- ============================================================================
-- POURQUOI « FROM PUBLIC, anon » ET PAS « FROM anon » (leçon du premier essai)
-- ============================================================================
-- L'ACL réelle de ces trois fonctions est {=X/postgres, postgres=X,
-- authenticated=X} : l'exécution d'`anon` vient de l'entrée `=X` — un GRANT à
-- **PUBLIC** — et `anon` n'a jamais eu d'entrée propre. Un `REVOKE FROM anon`
-- seul est donc un no-op silencieux : `has_function_privilege('anon', …)`
-- reste vrai par héritage. Le premier essai de cette migration l'a payé en
-- CI : sa propre garde a levé « révocation sans effet » et `sql-tests` a
-- rougi — avant que la clôture ne mente. C'est le pendant côté `api` du
-- défaut de baseline documenté sur `public` (B2) : le rempart se retire à la
-- racine (`PUBLIC`), pas au rôle qui en hérite. `authenticated` garde son
-- grant explicite, qui survit au retrait de `PUBLIC`.

REVOKE EXECUTE ON FUNCTION api.clear_loan_return_schedule(bigint, integer[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.mark_loan_return_missed(bigint, integer[]) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION api.schedule_loan_return(bigint, integer[], timestamptz) FROM PUBLIC, anon;

DO $$
DECLARE
  v_encore text;
BEGIN
  SELECT string_agg(p.proname, ', ') INTO v_encore
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('clear_loan_return_schedule','mark_loan_return_missed','schedule_loan_return')
    AND has_function_privilege('anon', p.oid, 'EXECUTE');

  IF v_encore IS NOT NULL THEN
    RAISE EXCEPTION 'révocation sans effet sur : % — rollback', v_encore;
  END IF;

  -- Le volet que la révocation ne devait pas toucher : authenticated garde
  -- l'EXECUTE sur les trois, tant que B20 n'a pas arbitré leur lot.
  SELECT string_agg(p.proname, ', ') INTO v_encore
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('clear_loan_return_schedule','mark_loan_return_missed','schedule_loan_return')
    AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_encore IS NOT NULL THEN
    RAISE EXCEPTION 'authenticated fermé par erreur sur : % — rollback', v_encore;
  END IF;
END $$;
