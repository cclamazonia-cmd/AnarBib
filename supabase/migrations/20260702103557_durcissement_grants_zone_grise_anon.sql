-- =========================================================================
-- Paquet DURCISSEMENT-GRANTS #2 — retrait de `anon` sur les RPC non publiques
-- =========================================================================
-- Date     : 2026-07-02
-- Chantier : surface d'API — advisor Supabase 0028 (anon peut exécuter des
--            fonctions SECURITY DEFINER)
--
-- Fait suite à 20260702101413 (triggers + fn_internal_*). Ici on traite la
-- « zone grise » : des RPC `public` `SECURITY DEFINER` d'action staff/membre
-- qui ont hérité du GRANT PUBLIC par défaut et se retrouvent exposées à `anon`,
-- alors qu'elles n'ont aucun usage anonyme légitime.
--
-- Audit préalable (2026-07-02, lecture seule) :
--   * rls_refs = 0 pour toutes ces fonctions -> aucune politique RLS ne les
--     appelle, donc retirer `anon` ne casse pas la lecture publique.
--   * elles gatent déjà en interne (auth.uid()/staff + RAISE) : un appel `anon`
--     échoue déjà aujourd'hui. Retirer le droit ne fait que transformer
--     l'erreur métier en 403 -> aucun flux fonctionnel n'est cassé.
--   * le front connecté passe en rôle `authenticated` (droit conservé) et les
--     Edge Functions en `service_role` (non concerné par ce REVOKE).
--
-- NE SONT PAS TOUCHÉES (volontairement conservées à `anon`) :
--   - helpers d'autorisation appelés par les politiques RLS
--     (user_can_engage_library, fn_caller_is_*, fn_partnership_*, ...)
--   - lecture de catalogue public (search_*, *_public, list_catalog_libraries,
--     get_accessible_digital_asset_by_id_v2, ...)
--   - login (resolve_login_email), onboarding (fn_submit_library_request*,
--     claim), protocole OAI-PMH (fn_oai_harvestable_*), helpers de mode/config.
--
-- Groupe A : REVOKE `anon` seul (elles restent appelables par `authenticated`).
-- Groupe B : cron pur, aucun appel front/RLS -> REVOKE `anon` ET `authenticated`.
-- `service_role`, owner et `postgres` conservent leurs droits.
-- Idempotent, forward-only. (Overloads gérés par résolution sur le nom.)
-- =========================================================================

BEGIN;

-- Groupe A — actions staff/membre : retrait de `anon` uniquement ----------
DO $$
DECLARE
  r record;
  a text[] := array[
    -- préférences par utilisateur
    'fn_get_my_notification_preferences','fn_set_my_notification_preferences',
    -- dépôt de garantie (registre staff + lecture liée à l'emprunt)
    'fn_record_deposit','fn_record_standing_deposit','fn_refund_deposit',
    'fn_retain_deposit','fn_deposit_status_for_loan','fn_standing_deposit_for_loan',
    'fn_deposit_fonds_direct_prepare',
    -- recherche / catalogage staff
    'fn_painel_search_reader','fn_search_library_books','fn_next_tombo',
    'confirm_author_book_link','unlink_author_book','set_author_translation_review',
    'suggest_author_book_matches','suggest_author_duplicates','suggest_subject_duplicates',
    -- exports staff
    'fn_export_catalog_lote','fn_export_fonds_eligible_count',
    'fn_export_fonds_records','fn_export_publishable_resources',
    -- prêt entre bibliothèques (PEB/ILL)
    'fn_ill_acknowledge','fn_ill_close','fn_ill_request','fn_ill_respond',
    'fn_ill_signed_url','fn_ill_start_digitization','fn_ill_transmit',
    -- gouvernance OAI (actions, pas le harvest public)
    'fn_oai_admin_decide_library','fn_oai_cast_vote','fn_oai_close_opening',
    'fn_oai_propose_network_open','fn_oai_request_open_library',
    -- divers staff
    'fn_publish_digital_asset_from_resource','fn_ensure_library_theme',
    'fn_partner_register_deposit_source','fn_partner_search',
    'fn_send_weekly_report_now'
  ];
  v_n integer := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = ANY(a)
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon', r.sig);
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'DURCISSEMENT-GRANTS #2 : anon retiré de % fonction(s) staff/membre (groupe A).', v_n;
END $$;

-- Groupe B — cron pur : retrait de `anon` ET `authenticated` --------------
DO $$
DECLARE
  r record;
  b text[] := array[
    'fn_gazette_build_call','fn_rede_digest_call','fn_oai_resolve_expired_votes'
  ];
  v_n integer := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = ANY(b)
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon, authenticated', r.sig);
    v_n := v_n + 1;
  END LOOP;
  RAISE NOTICE 'DURCISSEMENT-GRANTS #2 : anon+authenticated retiré de % fonction(s) cron (groupe B).', v_n;
END $$;

COMMIT;
