-- =========================================================================
-- Paquet SECU-LOT1 — Révocation EXECUTE sur fonctions trigger SECURITY DEFINER
-- =========================================================================
-- Date     : 2026-06-15
-- Chantier : Nettoyage des security advisors Supabase (lot sûr)
-- Auteur   : AnarBib
-- Session  : Perf UX + nettoyage advisors sécurité
--
-- CONTEXTE
--   Les security advisors Supabase remontent 440 WARN, dont :
--     - 336 « authenticated_security_definer_function_executable » (0029)
--     - 102 « anon_security_definer_function_executable »          (0028)
--   La majorité = surface RPC légitime (anon publiques + wrappers
--   authenticated), architecture cible : on N'Y TOUCHE PAS.
--
--   MAIS 14 de ces fonctions sont en réalité des FONCTIONS TRIGGER
--   (RETURNS trigger) qui ont conservé un EXECUTE pour PUBLIC/anon/
--   authenticated par défaut Postgres. Elles ne devraient JAMAIS être
--   appelables depuis l'API :
--     - une fonction trigger se déclenche INDÉPENDAMMENT du privilège
--       EXECUTE de l'utilisateur qui fait le DML (le moteur de triggers
--       ne vérifie pas EXECUTE) → révoquer ne casse aucun trigger ;
--     - PostgREST n'expose jamais une fonction qui RETURNS trigger via
--       /rest/v1/rpc → aucune capacité client n'est retirée.
--
--   Effet : -14 occurrences sur 0028 (anon) ET -14 sur 0029 (authenticated)
--           = -28 lignes d'advisors, ZÉRO impact fonctionnel.
--
-- DOCTRINE
--   REVOKE FROM PUBLIC seul est insuffisant (ALTER DEFAULT PRIVILEGES
--   Supabase ré-accorde EXECUTE) → on révoque explicitement de
--   PUBLIC, anon, authenticated, service_role.
--   Réf. doctrine : docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- Révocations — 14 fonctions trigger SECURITY DEFINER (signature à 0 argument)
-- -------------------------------------------------------------------------
REVOKE EXECUTE ON FUNCTION public.fn_create_network_contributor_on_signup()  FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_enforce_circulation_limit()             FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_enforce_membership_circulation_gate()   FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_gazette_outbox_dispatch_trigger()       FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_gazette_submission_enqueue()            FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_sync_rights()               FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_sync_status()               FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_propagate_circulation_default_on_publish() FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_recompute_holdings_on_exemplar_change() FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_seed_draft_contributors()              FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_sync_book_authors_from_contributor()    FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_sync_book_contributors_on_publish()     FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_sync_book_subjects_on_publish()         FROM PUBLIC, anon, authenticated, service_role;
REVOKE EXECUTE ON FUNCTION public.fn_sync_publisher_id_on_publish()          FROM PUBLIC, anon, authenticated, service_role;

-- -------------------------------------------------------------------------
-- Vérification automatique (rollback si une fonction reste exécutable
-- par anon/authenticated, ou si une fonction a disparu)
-- -------------------------------------------------------------------------
DO $verify$
DECLARE
  v_fn  text;
  v_fns text[] := ARRAY[
    'public.fn_create_network_contributor_on_signup()',
    'public.fn_enforce_circulation_limit()',
    'public.fn_enforce_membership_circulation_gate()',
    'public.fn_gazette_outbox_dispatch_trigger()',
    'public.fn_gazette_submission_enqueue()',
    'public.fn_partnership_sync_rights()',
    'public.fn_partnership_sync_status()',
    'public.fn_propagate_circulation_default_on_publish()',
    'public.fn_recompute_holdings_on_exemplar_change()',
    'public.fn_seed_draft_contributors()',
    'public.fn_sync_book_authors_from_contributor()',
    'public.fn_sync_book_contributors_on_publish()',
    'public.fn_sync_book_subjects_on_publish()',
    'public.fn_sync_publisher_id_on_publish()'
  ];
  v_anon boolean;
  v_auth boolean;
BEGIN
  -- anon et authenticated étant membres de PUBLIC, vérifier ces deux rôles
  -- détecte aussi tout EXECUTE résiduel accordé via PUBLIC.
  FOREACH v_fn IN ARRAY v_fns LOOP
    IF to_regprocedure(v_fn) IS NULL THEN
      RAISE EXCEPTION 'Vérif échouée : fonction % introuvable. Rollback automatique.', v_fn;
    END IF;
    v_anon := has_function_privilege('anon',          v_fn, 'EXECUTE');
    v_auth := has_function_privilege('authenticated', v_fn, 'EXECUTE');
    IF v_anon OR v_auth THEN
      RAISE EXCEPTION 'Vérif échouée : % encore exécutable (anon=%, auth=%). Rollback automatique.',
        v_fn, v_anon, v_auth;
    END IF;
  END LOOP;
  RAISE NOTICE 'SECU-LOT1 OK : 14 fonctions trigger SECDEF non exécutables par PUBLIC/anon/authenticated.';
END
$verify$;

-- Rafraîchir le cache de schéma PostgREST (changement de privilèges).
NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback ciblé (à n'utiliser qu'en cas de besoin imprévu — non attendu,
-- les triggers se déclenchent sans EXECUTE) :
-- =========================================================================
-- BEGIN;
--   GRANT EXECUTE ON FUNCTION public.fn_xxx() TO authenticated;  -- etc.
-- COMMIT;
-- =========================================================================
