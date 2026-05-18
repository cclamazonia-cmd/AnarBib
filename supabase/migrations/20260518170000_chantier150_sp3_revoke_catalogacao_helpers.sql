-- =============================================================================
-- Chantier #150 — Audit sécurité fonctions privées
-- Sous-paquet SP3 : REVOKE EXECUTE sur helpers internes catalogage (Cat 3 — 7 fonctions)
-- =============================================================================
-- Doctrine de référence :
--   docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
-- Découverte 17/05/2026 (B.4) :
--   ALTER DEFAULT PRIVILEGES Supabase grant EXECUTE TO anon/authenticated/
--   service_role automatiquement sur public.functions. REVOKE FROM PUBLIC
--   seul ne suffit pas.
--
-- Périmètre SP3 (7 fonctions Cat 3) :
--   Copy helpers (appelés par create_book_draft_from_book) :
--     - copy_book_catalog_context_to_draft        (0 caller SQL — dead code probable)
--     - copy_book_digital_resources_to_draft      (caller : create_book_draft_from_book)
--   Link stub (jumelle de link_book_contributors_to_authors) :
--     - link_author_to_book_contributors          (corps = "select true", 0 caller)
--   Upsert helpers (appelés par triggers trg_sync_*) :
--     - upsert_book_catalog_context_from_marc_json
--     - upsert_book_draft_catalog_context_from_marc_json
--   Publish helper (appelé par publish_book_draft) :
--     - publish_book_draft_digital_resources
--   Bridge resolver (appelé par 4 fonctions catalogage SECURITY DEFINER) :
--     - resolve_library_holding_bridge
--
-- Justification politique :
--   Tous les callers SQL recensés sont SECURITY DEFINER (incluant les triggers
--   trg_sync_book_*_catalog_context_from_marc_json et sync_exemplar_draft_
--   holdings_bridge, tous confirmés SECURITY DEFINER au 18/05/2026). Les
--   callers internes continueront donc d'invoquer ces helpers en contexte
--   postgres, sans être affectés par le REVOKE.
--
--   Greps frontend + Edge Functions effectués 18/05/2026 :
--     - link_book_contributors_to_authors : caller frontend détecté
--       (BookDraftForm.jsx:1026, fire-and-forget try/catch silencieux).
--       Décision politique 18/05 : conservée Cat 1 dégradé, à nettoyer en
--       backlog ("hook stub fire-and-forget BookDraftForm.jsx:1026").
--     - link_author_to_book_contributors : 0 hit — Cat 3.
--     - copy_book_catalog_context_to_draft : 0 hit — Cat 3.
--     - autres fonctions SP3 : pas de pattern frontend probable, Cat 3.
--
-- Hors périmètre SP3 (reporté chantier RBAC catalogage dédié) :
--   Les RPC catalogage callable par authenticated sans garde RBAC interne :
--   create_book_draft_from_book, create_author_draft_from_author,
--   create_exemplar_draft_from_exemplar, publish_book_draft, publish_author_
--   draft, publish_exemplar_draft, publish_catalog_batch, fn_bulk_*,
--   fn_set_partner_catalog_editorial_decision. C'est un trou RBAC, pas un
--   trou ACL — à traiter dans un chantier dédié.
-- =============================================================================

BEGIN;

-- Copy helpers
REVOKE EXECUTE ON FUNCTION public.copy_book_catalog_context_to_draft(bigint, bigint)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.copy_book_digital_resources_to_draft(bigint, bigint)
  FROM PUBLIC, anon, authenticated, service_role;

-- Link stub jumelle
REVOKE EXECUTE ON FUNCTION public.link_author_to_book_contributors(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

-- Upsert helpers
REVOKE EXECUTE ON FUNCTION public.upsert_book_catalog_context_from_marc_json(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.upsert_book_draft_catalog_context_from_marc_json(bigint)
  FROM PUBLIC, anon, authenticated, service_role;

-- Publish helper
REVOKE EXECUTE ON FUNCTION public.publish_book_draft_digital_resources(bigint, bigint)
  FROM PUBLIC, anon, authenticated, service_role;

-- Bridge resolver
REVOKE EXECUTE ON FUNCTION public.resolve_library_holding_bridge(uuid, text)
  FROM PUBLIC, anon, authenticated, service_role;

-- =============================================================================
-- DO-block de vérification
-- =============================================================================

DO $verif$
DECLARE
  v_remaining_exposure int;
  v_target_functions text[] := ARRAY[
    'copy_book_catalog_context_to_draft',
    'copy_book_digital_resources_to_draft',
    'link_author_to_book_contributors',
    'upsert_book_catalog_context_from_marc_json',
    'upsert_book_draft_catalog_context_from_marc_json',
    'publish_book_draft_digital_resources',
    'resolve_library_holding_bridge'
  ];
  v_critical_rpc_frontend text[] := ARRAY[
    -- RPC catalogage callable par authenticated (hors périmètre #150 mais
    -- non-régression à protéger : si on a REVOKE par erreur ces RPC, le
    -- frontend catalogage casse)
    'create_book_draft_from_book',
    'create_author_draft_from_author',
    'create_exemplar_draft_from_exemplar',
    'publish_book_draft',
    'publish_author_draft',
    'publish_exemplar_draft',
    'publish_catalog_batch',
    -- Et la jumelle Cat 1 dégradé qu'on garde callable
    'link_book_contributors_to_authors'
  ];
  v_rpc_regression_count int;
BEGIN
  -- Test 1 : aucune fonction Cat 3 SP3 ne doit plus être exposée à un rôle applicatif
  SELECT count(*) INTO v_remaining_exposure
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = ANY(v_target_functions)
    AND (
         has_function_privilege('public', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE')
      OR has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('service_role', p.oid, 'EXECUTE')
    );

  IF v_remaining_exposure > 0 THEN
    RAISE EXCEPTION 'SP3_VERIF_FAIL_1 : % fonctions Cat 3 sont encore exposees a un role applicatif',
      v_remaining_exposure;
  END IF;

  -- Test 2 : non-régression — les RPC catalogage callable par authenticated
  -- doivent rester accessibles (sinon on a REVOKE par erreur trop large)
  SELECT count(*) INTO v_rpc_regression_count
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = ANY(v_critical_rpc_frontend)
    AND NOT has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_rpc_regression_count > 0 THEN
    RAISE EXCEPTION 'SP3_VERIF_FAIL_2 : % RPC catalogage critiques ne sont PLUS accessibles a authenticated (regression)',
      v_rpc_regression_count;
  END IF;

  RAISE NOTICE 'SP3_OK : isolation effective sur 7 helpers internes catalogage (copy/link/upsert/publish/bridge)';
END
$verif$;

COMMIT;
