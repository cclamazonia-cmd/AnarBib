-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — l'adresse des fonctions ne retombe plus sur la production (23/10/2026)
-- Auteur  : Xavier (CCLA) + Claude
-- Session : Modele de menace
--
-- private.fn_functions_base_url() (I20, migration 20260907123000) lisait le
-- réglage `anarbib.functions_base_url` et, à défaut, rendait l'adresse du projet
-- cloud. Toute pile rejouée depuis le dépôt (pile locale, auto-hébergée,
-- restauration) qui oubliait le réglage envoyait donc ses tâches planifiées et
-- ses déclencheurs de notification aux fonctions de la PRODUCTION, corps
-- compris. Le secret manquant faisait refuser l'appel, mais les données étaient
-- déjà parties. Constat du 23/10 en montant la pile de la phase 2.
--
-- Désormais :
--   1. le réglage `anarbib.functions_base_url` (piles auto-hébergées :
--      deploy/bootstrap.sh ; pile de test : tests/security/reconstruire-base.sh) ;
--   2. sinon le secret Vault `FUNCTIONS_BASE_URL` de l'instance (production :
--      le projet hébergé ne permet pas à `postgres` de poser un réglage) ;
--   3. sinon RIEN : NULL, et net.http_post refuse une URL nulle — aucun appel ne
--      part. Les cinq déclencheurs de dépêche rattrapent l'erreur (l'action de la
--      personne n'est pas cassée) ; les appels des tâches planifiées échouent en
--      clair dans leur journal.
-- Un Vault restauré ailleurs ne se déchiffre pas : une restauration reste fermée.
--
-- ⚠️ ORDRE DE DÉPLOIEMENT. En production, le secret doit exister AVANT le push :
--      select vault.create_secret('<adresse du projet>', 'FUNCTIONS_BASE_URL',
--                                 'Adresse des Edge Functions de cette instance');
--    Le bloc de vérification refuse de s'appliquer sur une instance en service
--    (qui porte des secrets de webhook) sans adresse : la migration échoue, rien
--    ne change, plutôt que de couper les notifications en silence.
--
-- Tests : tests/sql/adresse_des_fonctions_tests.sql (T1, T3, T8 à T10).
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION private.fn_functions_base_url()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog'
AS $$
  SELECT rtrim(coalesce(
    nullif(btrim(current_setting('anarbib.functions_base_url', true)), ''),
    (SELECT nullif(btrim(s.decrypted_secret), '')
       FROM vault.decrypted_secrets s
      WHERE s.name = 'FUNCTIONS_BASE_URL'
      ORDER BY s.created_at DESC
      LIMIT 1)
  ), '/');
$$;

COMMENT ON FUNCTION private.fn_functions_base_url() IS
  'Base des URL des Edge Functions de CETTE instance (sans /functions/v1) : réglage anarbib.functions_base_url, sinon secret Vault FUNCTIONS_BASE_URL, sinon NULL — aucun repli sur une autre instance (P2-O1, 23/10/2026 ; I20, 07/09/2026).';

REVOKE EXECUTE ON FUNCTION private.fn_functions_base_url() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.fn_functions_base_url() TO service_role;

-- ─── Vérification ──────────────────────────────────────────────────────────
DO $verif$
DECLARE
  v_src text;
BEGIN
  SELECT prosrc INTO v_src FROM pg_proc WHERE oid = 'private.fn_functions_base_url()'::regprocedure;
  IF v_src LIKE '%supabase.co%' THEN
    RAISE EXCEPTION 'le helper porte encore une adresse cloud';
  END IF;
  IF has_function_privilege('anon', 'private.fn_functions_base_url()', 'EXECUTE')
     OR has_function_privilege('authenticated', 'private.fn_functions_base_url()', 'EXECUTE') THEN
    RAISE EXCEPTION 'le helper est exécutable par anon ou authenticated';
  END IF;
  -- Une instance en service porte des secrets de webhook : elle doit avoir son adresse.
  IF EXISTS (SELECT 1 FROM vault.decrypted_secrets WHERE name LIKE 'WEBHOOK_SECRET_%')
     AND private.fn_functions_base_url() IS NULL THEN
    RAISE EXCEPTION 'instance en service sans adresse des fonctions : créer le secret Vault FUNCTIONS_BASE_URL avant cette migration (voir l''en-tête)';
  END IF;
END $verif$;

COMMIT;
