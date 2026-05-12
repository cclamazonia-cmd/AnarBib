-- =========================================================================
-- Paquet L.3 — Audit des fonctions SECURITY DEFINER exposées
-- =========================================================================
-- Objectif : avant de faire des REVOKE en masse (paquets L.4 et L.5),
-- on cartographie l'état actuel pour décider en connaissance de cause.
--
-- À exécuter dans le SQL Editor Supabase. Pas de modification de schéma.
-- Sauvegarder les sorties pour préparer les paquets L.4 et L.5.
-- =========================================================================

-- -------------------------------------------------------------------------
-- Section 1 : Triggers vs RPC — qui est juste un trigger, qui est aussi RPC ?
-- -------------------------------------------------------------------------
-- Un trigger n'a aucune raison d'être appelable via /rest/v1/rpc/.
-- On liste toutes les fonctions qui SONT attachées comme trigger ET ont aussi
-- EXECUTE pour anon ou authenticated.

SELECT
  n.nspname                                AS schema_name,
  p.proname                                AS function_name,
  p.prosecdef                              AS is_security_definer,
  array_agg(DISTINCT t.tgname) FILTER
    (WHERE t.tgname IS NOT NULL)           AS attached_as_trigger_on,
  array_agg(DISTINCT cl.relname) FILTER
    (WHERE cl.relname IS NOT NULL)         AS trigger_tables,
  has_function_privilege('anon',
    p.oid, 'EXECUTE')                      AS anon_can_execute,
  has_function_privilege('authenticated',
    p.oid, 'EXECUTE')                      AS auth_can_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN pg_trigger t ON t.tgfoid = p.oid AND NOT t.tgisinternal
LEFT JOIN pg_class cl ON cl.oid = t.tgrelid
WHERE n.nspname IN ('public', 'api')
  AND p.prosecdef = true
  AND p.proname ~ '^(tg_|trg_|fn_.*_trigger)$'    -- conventions de nommage trigger
GROUP BY n.nspname, p.proname, p.prosecdef, p.oid
ORDER BY schema_name, function_name;

-- -------------------------------------------------------------------------
-- Section 2 : Toutes les fonctions SECURITY DEFINER exposées
-- -------------------------------------------------------------------------
-- Vue exhaustive avec arguments, langage, qui peut exécuter

SELECT
  n.nspname                                AS schema_name,
  p.proname                                AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args,
  l.lanname                                AS language,
  p.prosecdef                              AS is_definer,
  has_function_privilege('anon',
    p.oid, 'EXECUTE')                      AS anon_exec,
  has_function_privilege('authenticated',
    p.oid, 'EXECUTE')                      AS auth_exec,
  has_function_privilege('public',
    p.oid, 'EXECUTE')                      AS public_exec
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
JOIN pg_language l ON l.oid = p.prolang
WHERE n.nspname IN ('public', 'api')
  AND p.prosecdef = true
  AND p.prokind = 'f'    -- exclut les agrégats et procédures
ORDER BY schema_name, function_name;

-- -------------------------------------------------------------------------
-- Section 3 : Fonctions candidates à la liste blanche anon
-- -------------------------------------------------------------------------
-- Ce sont les RPC qui DOIVENT rester appelables sans authentification :
-- signup, claim, recherche publique, theme. À confirmer manuellement.

SELECT
  n.nspname                                AS schema_name,
  p.proname                                AS function_name,
  pg_get_function_identity_arguments(p.oid) AS args,
  obj_description(p.oid, 'pg_proc')        AS function_comment
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'api')
  AND p.prosecdef = true
  AND p.proname IN (
    -- Login et identité
    'resolve_login_email',
    -- Demandes de bibliothèque (formulaire public + claim email)
    'fn_submit_library_request',
    'fn_submit_library_request_via_claim',
    'fn_consume_library_request_claim',
    'fn_get_library_request_claim_context',
    -- Catalogue public anonyme
    'search_catalog_v1',
    -- Thème (avant login pour /libraries/<slug>)
    'get_library_theme_config',
    'get_library_theme_config_by_library_id',
    -- Asset numérique public (couvertures, PDF libres)
    'get_book_primary_public_digital_asset_v2'
  )
ORDER BY schema_name, function_name;

-- -------------------------------------------------------------------------
-- Section 4 : Comptage final attendu après paquets L.4 + L.5
-- -------------------------------------------------------------------------
-- Combien de fonctions DEFINER auraient encore EXECUTE pour anon
-- après application de la liste blanche stricte ?

WITH whitelist AS (
  SELECT unnest(ARRAY[
    'resolve_login_email',
    'fn_submit_library_request',
    'fn_submit_library_request_via_claim',
    'fn_consume_library_request_claim',
    'fn_get_library_request_claim_context',
    'search_catalog_v1',
    'get_library_theme_config',
    'get_library_theme_config_by_library_id',
    'get_book_primary_public_digital_asset_v2'
  ]) AS name
)
SELECT
  count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE'))
    AS currently_anon_executable,
  count(*) FILTER (WHERE has_function_privilege('anon', p.oid, 'EXECUTE')
                     AND p.proname NOT IN (SELECT name FROM whitelist))
    AS to_revoke_from_anon,
  count(*) FILTER (WHERE p.proname IN (SELECT name FROM whitelist))
    AS whitelist_kept
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'api')
  AND p.prosecdef = true
  AND p.prokind = 'f';

-- =========================================================================
-- Sauvegarder les 4 résultats avant de générer les paquets L.4 et L.5.
-- En particulier :
--   - section 1 : liste exacte des triggers à REVOKE en L.4
--   - section 4 : nombre attendu de WARN éradiqués par L.5
-- =========================================================================
