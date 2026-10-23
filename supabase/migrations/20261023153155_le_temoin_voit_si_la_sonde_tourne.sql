-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — le témoin voit si la sonde de santé tourne (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- health-probe est appelée par une tâche planifiée de la base, dont l'adresse
-- vient de private.fn_functions_base_url(). Si cette adresse se perd (secret
-- Vault FUNCTIONS_BASE_URL effacé, P2-O1), si la tâche cron casse ou si la
-- fonction échoue avant d'écrire, la sonde se TAIT : elle n'écrit plus de
-- tournée, n'ouvre plus d'incident, n'alerte plus — et rien ne le dit, puisque
-- c'est elle qui alerte. Le témoin externe (deploy/ops/anarbib-temoin.sh), qui
-- vit sur une autre machine, ne voyait que la disponibilité de l'API.
--
-- api.sonde_a_jour() lui permet de voir ce silence par l'API publique : un
-- BOOLÉEN, vrai si une tournée a été écrite dans les 15 dernières minutes (la
-- sonde passe toutes les cinq). Rien d'autre : ni heure, ni résultat, ni
-- incident. Décision de Xavier du 23/10/2026 : une fonction de plus ouverte à
-- anon, qui ne dit que « la supervision tourne ».
--
-- Tests : tests/sql/sonde_a_jour_tests.sql ; grants_herites T12 (liste fermée
-- des fonctions ouvertes à anon) ; src/tests/temoin-panne.test.js.
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION api.sonde_a_jour()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.service_health_probes
     WHERE checked_at > now() - interval '15 minutes'
  );
$$;

COMMENT ON FUNCTION api.sonde_a_jour() IS
  'Vrai si health-probe a écrit une tournée dans les 15 dernières minutes. Lu par le témoin externe (deploy/ops/anarbib-temoin.sh) avec la clé publiable. Ne rend rien d''autre qu''un booléen.';

REVOKE EXECUTE ON FUNCTION api.sonde_a_jour() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.sonde_a_jour() TO anon, authenticated, service_role;

-- ─── Vérification ──────────────────────────────────────────────────────────
DO $verif$
BEGIN
  IF NOT has_function_privilege('anon', 'api.sonde_a_jour()', 'EXECUTE') THEN
    RAISE EXCEPTION 'api.sonde_a_jour() fermée à anon : le témoin ne la lira pas';
  END IF;
  IF (SELECT prorettype FROM pg_proc WHERE oid = 'api.sonde_a_jour()'::regprocedure) <> 'boolean'::regtype THEN
    RAISE EXCEPTION 'api.sonde_a_jour() doit rendre un booléen, rien d''autre';
  END IF;
END $verif$;

COMMIT;
