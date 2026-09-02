-- B20, dernier volet : les différées du 01/09 rejoignent le régime commun.
--
-- ============================================================================
-- LE SOLDE (02/09/2026) — la mesure rejouée, pas recopiée (DOC-CONSTAT-1)
-- ============================================================================
-- La migration `20260901140139` avait mesuré 227 fonctions de `public`
-- exposées à `authenticated` sans appelant en base, en avait révoqué 5 et
-- différé 48 au motif « elles attendent leur écran ». Le GLB v17 a qualifié
-- l'arbitrage de « tenable un mois, pas un trimestre » ; l'échéance est
-- soldée aujourd'hui, sur remesure complète :
--
-- * dépôt : 0 occurrence des 48 noms dans `src/`, `supabase/functions/`,
--   `scripts/` (balayage nominatif, PEB compris) ;
-- * base : 0 appelant SQL, 0 policy, 0 cron — les seuls « appelants » du
--   motif interbibliotecas sont les 3 helpers internes (log, recompute,
--   refresh), déjà fermés, appelés par les 8 exposées ;
-- * tests : six suites exercent 13 de ces fonctions, TOUTES en `postgres`
--   (0 SET ROLE, vérifié fichier par fichier — leçon du run 9186334 : la
--   convention d'appel ne se déduit pas du test voisin, elle se lit).
--
-- UNE fonction sort du solde : `fn_book_due_dates` est dans la liste nommée
-- T10 de `grants_herites_tests` — ouverte à `anon` par verdict écrit (audit
-- B2 du 30/08). Ouverte par décision, appelée par personne : cette
-- contradiction se rejuge au registre de B2, pas par un REVOKE de passage.
--
-- Les 47 restantes ferment. Aucune n'est supprimée ; les corps, les gardes,
-- les suites qui les exercent en `postgres` restent entiers. Le grant
-- `service_role` explicite, là où il existe, est conservé (porte serveur).
-- Familles, pour la relecture : les 8 PEB fn_v2_*_interbibliotecas (phase 2
-- dormante — BIBLIO-9 la conditionne à l'usage réel), la couche RPC réseau
-- des candidatures (l'écran RedePage passe par lecture directe +
-- fn_approve_library_request), l'arbitrage d'autorités (p9-p11 : suites
-- vertes en postgres, l'écran viendra avec le chantier — GRANT ce jour-là),
-- la configuration notifications/règlement/thème, les helpers de mode et
-- de gouvernance, l'enregistrement de source OAI (le geste H5 se fait en
-- console `postgres`, qui garde son EXECUTE).

DO $$
DECLARE
  r record;
  v_fermees int := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN (
        'assign_book_to_work','fn_activate_approved_library_request',
        'fn_book_restricted_digital_state','fn_can_engage_library_for_storage',
        'fn_circle_member_count','fn_import_process_deposit',
        'fn_import_register_oai_source','fn_import_set_rows_review',
        'fn_is_cross_library_action','fn_library_has_staff_roles',
        'fn_library_publishes_catalog','fn_library_uses_governance',
        'fn_network_admin_request_removal','fn_network_dashboard_summary',
        'fn_network_discard_library_request','fn_network_get_library_request',
        'fn_network_library_metrics','fn_network_list_library_requests',
        'fn_notify_document_permission_request_now','fn_notify_library_request_now',
        'fn_required_governance_for_transition','fn_review_library_request',
        'fn_unarchive_transaction','get_book_primary_accessible_digital_asset_v2',
        'list_authors_not_duplicate','mark_authors_not_duplicate',
        'merge_author_with_fields','preview_library_notification',
        'preview_merge_author','set_library_regulation_document_active',
        'set_library_theme_config_by_library_id','suggest_authority_duplicates',
        'suggest_subject_duplicates','test_library_mail_channel',
        'unlink_author_book','unmark_authors_not_duplicate',
        'upsert_library_notification_policies','upsert_library_notification_profile',
        'upsert_library_regulation_document',
        'fn_v2_add_emprestimo_interbibliotecas_itens',
        'fn_v2_cancel_emprestimo_interbibliotecas',
        'fn_v2_create_emprestimo_interbibliotecas',
        'fn_v2_dispatch_emprestimo_interbibliotecas',
        'fn_v2_remove_emprestimo_interbibliotecas_item',
        'fn_v2_remove_emprestimo_interbibliotecas_itens',
        'fn_v2_return_emprestimo_interbibliotecas_linhas',
        'fn_v2_start_devolucao_emprestimo_interbibliotecas')
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
    v_fermees := v_fermees + 1;
  END LOOP;

  IF v_fermees <> 47 THEN
    RAISE EXCEPTION '47 fonctions attendues, % trouvées — la liste et la base divergent, rollback', v_fermees;
  END IF;
END $$;

DO $$
DECLARE
  v_liste text;
BEGIN
  -- 1) fn_book_due_dates n'a pas bougé : le contrat T10 (anon par verdict
  --    écrit) tient toujours.
  IF NOT has_function_privilege('anon', 'public.fn_book_due_dates(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_book_due_dates fermée par erreur — le verdict B2 et T10 seraient contredits — rollback';
  END IF;

  -- 2) Les chemins vivants des mêmes familles restent ouverts : approbation
  --    de candidature, moisson OAI, arbitrage de doublons de notices.
  SELECT string_agg(a.nsp||'.'||a.nom, ', ') INTO v_liste
  FROM (VALUES ('api','fn_approve_library_request'),('public','fn_import_list_oai_sources'),
               ('public','fn_import_harvest_oai'),('public','merge_book_with_fields')) a(nsp, nom)
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = a.nsp AND p.proname = a.nom
      AND has_function_privilege('authenticated', p.oid, 'EXECUTE'));
  IF v_liste IS NOT NULL THEN
    RAISE EXCEPTION 'chemin vivant fermé ou introuvable : % — rollback', v_liste;
  END IF;
END $$;
