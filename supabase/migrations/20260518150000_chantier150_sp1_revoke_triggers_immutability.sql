-- =============================================================================
-- Chantier #150 — Audit sécurité fonctions privées
-- Sous-paquet SP1 : REVOKE EXECUTE sur les fonctions trigger (Cat 3 absolue)
-- =============================================================================
-- Doctrine de référence :
--   docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
-- Découverte 17/05/2026 (B.4) :
--   ALTER DEFAULT PRIVILEGES Supabase grant EXECUTE TO anon/authenticated/
--   service_role automatiquement sur public.functions. REVOKE FROM PUBLIC
--   seul ne suffit pas.
--
-- Périmètre SP1 (5 fonctions, toutes RETURNS trigger) :
--   - fn_block_lpgl_modification    (paquet B.1 — immutabilité library_profile_grace_locks)
--   - fn_block_lpp_modification     (paquet B.1 — immutabilité library_profile_proposals)
--   - fn_block_lpv_modification     (paquet B.1 — immutabilité library_profile_votes)
--   - trg_notify_consulta_lifecycle (chantier consultas v2 — events item_status)
--   - trg_notify_consulta_workflow  (chantier consultas v2 — events workflow)
--
-- Justification politique :
--   Une fonction trigger ne peut jamais être appelée comme RPC (PostgreSQL
--   refuse l'appel direct hors contexte de trigger). REVOKE n'a donc aucun
--   impact fonctionnel mais respecte la doctrine "REVOKE étendu" et bloque
--   toute confusion future.
--
-- Vérification de non-régression :
--   Greps frontend + Edge Functions effectués 18/05/2026 — 0 appel direct
--   trouvé sur les 5 noms.
-- =============================================================================

BEGIN;

REVOKE EXECUTE ON FUNCTION public.fn_block_lpgl_modification()
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_block_lpp_modification()
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.fn_block_lpv_modification()
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.trg_notify_consulta_lifecycle()
  FROM PUBLIC, anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.trg_notify_consulta_workflow()
  FROM PUBLIC, anon, authenticated, service_role;

-- =============================================================================
-- DO-block de vérification
-- =============================================================================

DO $verif$
DECLARE
  v_remaining_exposure int;
  v_target_functions text[] := ARRAY[
    'fn_block_lpgl_modification',
    'fn_block_lpp_modification',
    'fn_block_lpv_modification',
    'trg_notify_consulta_lifecycle',
    'trg_notify_consulta_workflow'
  ];
BEGIN
  -- Test 1 : aucun des rôles applicatifs ne doit plus avoir EXECUTE
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
    RAISE EXCEPTION 'SP1_VERIF_FAIL : % triggers Cat 3 sont encore exposes a un role applicatif',
      v_remaining_exposure;
  END IF;

  RAISE NOTICE 'SP1_OK : isolation effective sur 5 fonctions trigger (immutabilite B.1 + lifecycle consultas v2)';
END
$verif$;

COMMIT;
