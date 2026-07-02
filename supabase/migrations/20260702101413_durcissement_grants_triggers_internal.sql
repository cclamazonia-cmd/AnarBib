-- =========================================================================
-- Paquet DURCISSEMENT-GRANTS — retrait des droits EXECUTE superflus
-- =========================================================================
-- Date     : 2026-07-02
-- Chantier : surface d'API — advisors Supabase 0028/0029
--            (anon / authenticated peuvent exécuter des fonctions SECURITY
--             DEFINER)
--
-- Contexte : le schéma `public` accorde EXECUTE à PUBLIC par défaut (la
-- doctrine « REVOKE PUBLIC ; GRANT authenticated » n'est appliquée qu'au
-- schéma `api`). Résultat : ~700 warnings d'advisor, dont la quasi-totalité
-- est *by-design* (les RPC `SECURITY DEFINER` font leur contrôle d'accès dans
-- leur corps). On NE touche PAS à ces RPC légitimes.
--
-- On corrige uniquement les deux catégories qui n'ont AUCUNE raison d'être
-- appelables via l'API REST par un client :
--
--   1. Les fonctions `RETURNS trigger` — Postgres ne vérifie pas le droit
--      EXECUTE au déclenchement d'un trigger (vérifié empiriquement sur
--      staging le 2026-07-02) : leur retirer EXECUTE est sans effet sur le
--      fonctionnement, ça ne fait que supprimer une surface absurde.
--
--   2. Les helpers de plomberie `public.fn_internal_*` — invoqués par
--      d'autres fonctions SECURITY DEFINER (donc sous l'identité de l'owner,
--      qui conserve EXECUTE), jamais directement par le front (grep `src/`
--      le 2026-07-02 : 0 occurrence).
--
-- Portée : schémas `public` et `api`, hors objets appartenant à une extension.
-- On révoque PUBLIC + anon + authenticated ; `service_role`, l'owner et
-- `postgres` conservent leurs droits (chaîne definer inchangée).
-- Idempotent : REVOKE d'un droit absent est un no-op ; ré-exécutable sans erreur.
-- =========================================================================

BEGIN;

-- 1) Fonctions trigger : jamais appelables en RPC ------------------------
DO $$
DECLARE
  r record;
  v_n integer := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN pg_type     t ON t.oid = p.prorettype
    WHERE n.nspname IN ('public', 'api')
      AND t.typname = 'trigger'
      AND NOT EXISTS (                       -- exclut les fonctions d'extension
        SELECT 1 FROM pg_depend d
        WHERE d.objid = p.oid AND d.deptype = 'e'
      )
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      r.sig
    );
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'DURCISSEMENT-GRANTS : % fonction(s) trigger durcie(s).', v_n;
END $$;

-- 2) Helpers internes de plomberie ---------------------------------------
DO $$
DECLARE
  r record;
  v_n integer := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname LIKE 'fn_internal_%'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.objid = p.oid AND d.deptype = 'e'
      )
  LOOP
    EXECUTE format(
      'REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated',
      r.sig
    );
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'DURCISSEMENT-GRANTS : % helper(s) fn_internal_* durci(s).', v_n;
END $$;

COMMIT;
