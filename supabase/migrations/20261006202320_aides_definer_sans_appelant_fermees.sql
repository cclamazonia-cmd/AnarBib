-- ===========================================================================
-- Advisor 0029 — trente-quatre fonctions SECURITY DEFINER fermées aux comptes
-- connectés, parce qu'aucun appelant ne s'exécute sous ce rôle.
--
-- Relevé du 06/10/2026 (export du tableau de bord, 19 h 22 UTC) : 481 WARN =
-- 451 (0029) + 29 (0028) + 1 (0011).
--   * 0028 = 29 = exactement la liste nommée T10 de grants_herites_tests :
--     chaque ouverture à anon est une décision écrite. Rien à réduire.
--   * 0011 = public.fn_locale_from_idioma : VOULU (B32, 28/09 — SQL IMMUTABLE
--     sans SET pour être insérée en ligne). Ne pas « corriger ».
--   * 0029 = 451 : la question est « QUI appelle sous authenticated ? ».
--
-- Méthode (production, lecture seule), sur les 451 :
--   1. appelants qui s'exécutent sous le rôle du lecteur : politiques
--      (pg_policy, tous schémas, storage compris), vues (pg_views), fonctions
--      INVOKER (prosrc, tous schémas), commandes cron, dépendances de
--      catalogue (pg_depend : défaut, contrainte, index, règle, corps SQL
--      standard) → 52 en ont, 399 n'en ont aucun ;
--   2. pour ces 399 : appel du front (src/, noms littéraux — les sept appels
--      .rpc(variable) du front prennent tous leur nom dans un littéral du même
--      fichier, aucun nom construit), d'une Edge Function (supabase/functions/)
--      ou d'un script (scripts/, deploy/) → 356 sont appelées, 43 non ;
--   3. sur ces 43, on en garde ouvertes neuf :
--      - les sept de la liste nommée T10 (ouvertes à anon par décision :
--        modes de bibliothèque, réclamation, PDF restreint, moissonnage OAI) —
--        on ne ferme pas à authenticated ce que l'audit a ouvert au public ;
--      - api.fn_outbox_abandonnees, api.fn_outbox_acquitter : RPC d'admin
--        réseau voulues par F12 (25/09), sans écran à ce jour ;
--      - public.fn_import_row_comparison : H21 lot 3, née aujourd'hui, son
--        écran est le chantier en cours d'une autre session.
--
-- Restent les 34 ci-dessous. Leurs seuls appelants sont des fonctions
-- SECURITY DEFINER (propriétaire postgres), qui les exécutent sous leur
-- propriétaire ; ou bien elles n'ont aucun appelant :
--   * deux fonctions de déclencheur (fn_audit_draft_deletion,
--     fn_guard_catalog_batch_delete) : Postgres ne vérifie EXECUTE qu'à la
--     création du déclencheur, jamais au déclenchement ;
--   * vingt-neuf aides servies par des DEFINER : la façade
--     api.get_library_institutional_workspace (5), la circulation v2 et ses
--     façades api (4), les lots (fn_batch_caller_can_edit), les assemblées,
--     les partenariats (4), les changements de profil (2), l'appartenance
--     (3), la fusion d'autorités (merge_serial, merge_subject), etc. ;
--   * trois sans aucun appelant (api.revoke_my_reader_card — carte-lecteur
--     bêta jamais câblée —, public.discard_book — supplantée par
--     discard_book_cascade —, public.fn_ensure_current_user_profile).
--
-- Ce ne sont pas des fuites : chacune a été lue à l'audit du 01/09 ou à ses
-- compléments. On les ferme parce qu'une ouverture doit servir (DOC-GRANT-1,
-- appliquée à authenticated comme le 27/09) : 0029 passe de 451 à 417.
--
-- Rien d'autre ne change : ni corps, ni politique, ni donnée. service_role
-- garde ce qu'il avait. Rouvrir l'une d'elles = un GRANT écrit dans la
-- migration qui crée son premier appelant sous authenticated.
--
-- Gardes : le bloc DO final (les deux camps, et l'absence d'appelant sous
-- authenticated revérifiée au déploiement) ; en continu,
-- tests/sql/aides_definer_fermees_tests.sql, qui joue aussi les porteurs
-- DEFINER sous le rôle authenticated.
-- ===========================================================================

-- Déclencheurs
REVOKE EXECUTE ON FUNCTION public.fn_audit_draft_deletion() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_guard_catalog_batch_delete() FROM PUBLIC, anon, authenticated;

-- Aides servies par des fonctions SECURITY DEFINER
REVOKE EXECUTE ON FUNCTION api.get_due_date_after_renewal(uuid, uuid, bigint, bigint, integer, date, integer, date) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION api.get_future_availability(uuid, bigint, bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION api.get_library_circulation_policy_sets_ui(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION api.get_library_regulation_documents_ui(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION api.resolve_circulation_rule(uuid, text, uuid, bigint, bigint, integer, date, date, integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_batch_caller_can_edit(bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_caller_is_assembleia_facilitator(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_circulation_concurrent_max(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_classify_transition(text, text, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_compute_membership_validity(uuid, timestamp with time zone) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_current_user_is_in_network() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_current_user_is_member_of(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_current_user_is_member_of_holding_library(bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_library_active_staff_count(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_library_is_federated(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_library_uses_authority(uuid, text, bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_painel_find_profile_by_lookup(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_canonical_id(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_has_active_right(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_reciprocal_id(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_partnership_transparence_active(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_request_caller_is_owner(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_library_notification_context(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_library_theme_config(text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_library_theme_config_by_library_id(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.merge_serial(bigint, bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.merge_subject(bigint, bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.resolve_managed_library_id(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_library_theme_config(text, text, text, text) FROM PUBLIC, anon, authenticated;

-- Sans aucun appelant
REVOKE EXECUTE ON FUNCTION api.revoke_my_reader_card(uuid) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.discard_book(bigint) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.fn_ensure_current_user_profile() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Garde des deux camps. Un appelant apparu entre le relevé et le déploiement
-- (politique, vue, défaut, index, fonction INVOKER) ferait échouer la
-- migration au lieu de casser un écran : c'est lui qu'on redoute.
-- ---------------------------------------------------------------------------
DO $garde$
DECLARE
  v_fermees text[] := ARRAY[
    'public.fn_audit_draft_deletion()',
    'public.fn_guard_catalog_batch_delete()',
    'api.get_due_date_after_renewal(uuid, uuid, bigint, bigint, integer, date, integer, date)',
    'api.get_future_availability(uuid, bigint, bigint)',
    'api.get_library_circulation_policy_sets_ui(uuid)',
    'api.get_library_regulation_documents_ui(uuid)',
    'api.resolve_circulation_rule(uuid, text, uuid, bigint, bigint, integer, date, date, integer)',
    'public.fn_batch_caller_can_edit(bigint)',
    'public.fn_caller_is_assembleia_facilitator(uuid)',
    'public.fn_circulation_concurrent_max(uuid, text)',
    'public.fn_classify_transition(text, text, text)',
    'public.fn_compute_membership_validity(uuid, timestamp with time zone)',
    'public.fn_current_user_is_in_network()',
    'public.fn_current_user_is_member_of(uuid)',
    'public.fn_current_user_is_member_of_holding_library(bigint)',
    'public.fn_library_active_staff_count(uuid)',
    'public.fn_library_is_federated(uuid)',
    'public.fn_library_uses_authority(uuid, text, bigint)',
    'public.fn_painel_find_profile_by_lookup(text)',
    'public.fn_partnership_canonical_id(uuid)',
    'public.fn_partnership_has_active_right(uuid, uuid, text)',
    'public.fn_partnership_reciprocal_id(uuid)',
    'public.fn_partnership_transparence_active(uuid, uuid, uuid)',
    'public.fn_request_caller_is_owner(uuid)',
    'public.get_library_notification_context(uuid)',
    'public.get_library_theme_config(text)',
    'public.get_library_theme_config_by_library_id(uuid)',
    'public.merge_serial(bigint, bigint)',
    'public.merge_subject(bigint, bigint)',
    'public.resolve_managed_library_id(uuid)',
    'public.set_library_theme_config(text, text, text, text)',
    'api.revoke_my_reader_card(uuid)',
    'public.discard_book(bigint)',
    'public.fn_ensure_current_user_profile()'
  ];
  -- Les porteurs : les portes par lesquelles le front atteint les fermées.
  v_servies text[] := ARRAY[
    'api.get_library_institutional_workspace(uuid)',
    'api.get_batch_loan_projection(uuid, uuid, bigint[], bigint[], integer, date)',
    'public.fn_v2_book_session_availability_for_current_user(bigint[])',
    'public.fn_v2_extend_core(bigint, integer[], boolean)',
    'public.fn_batch_rubrics(bigint)',
    'public.catalog_digital_access_v1(bigint[])',
    'public.fn_library_visible_to_caller(uuid)',
    'public.fn_record_membership_payment(uuid, uuid, numeric, membership_payment_method, timestamp with time zone, text, date, date)',
    'public.fn_propose_library_profile_change(uuid, text, text, text)',
    'public.fn_painel_reader_other_memberships(uuid, uuid)',
    'public.fn_ill_request(uuid, uuid, bigint, text, text)',
    'api.fn_authority_apply(uuid)',
    'api.fn_authority_object(uuid, uuid, text)',
    'api.fn_assembleia_set_status(uuid, text)',
    'api.fn_request_mark_messages_read(uuid)'
  ];
  v_f      text;
  v_oid    oid;
  v_nom    text;
  v_ecarts text := '';
BEGIN
  IF cardinality(v_fermees) <> 34 THEN
    RAISE EXCEPTION 'liste des fermées : % entrées, 34 attendues', cardinality(v_fermees);
  END IF;

  FOREACH v_f IN ARRAY v_fermees LOOP
    v_oid := v_f::regprocedure;
    SELECT p.proname INTO v_nom FROM pg_proc p WHERE p.oid = v_oid;
    IF has_function_privilege('authenticated', v_oid, 'EXECUTE')
       OR has_function_privilege('anon', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' encore-ouverte:' || v_f;
    END IF;
    -- Tout objet du catalogue qui dépend d'elle (politique, vue, défaut,
    -- contrainte, index, corps SQL standard), sauf une fonction DEFINER et
    -- un déclencheur (qui ne vérifie pas EXECUTE).
    IF EXISTS (SELECT 1 FROM pg_depend d
                WHERE d.refclassid = 'pg_proc'::regclass AND d.refobjid = v_oid
                  AND d.classid <> 'pg_trigger'::regclass
                  AND (d.classid <> 'pg_proc'::regclass
                       OR NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = d.objid))) THEN
      v_ecarts := v_ecarts || ' dependance:' || v_f;
    END IF;
    -- Les expressions de politique et les vues, par leur texte aussi.
    IF EXISTS (SELECT 1 FROM pg_policy pol
                WHERE (coalesce(pg_get_expr(pol.polqual, pol.polrelid), '') || ' '
                       || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')) ~ ('\m' || v_nom || '\M')) THEN
      v_ecarts := v_ecarts || ' politique:' || v_f;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_views v
                WHERE v.schemaname NOT IN ('pg_catalog', 'information_schema')
                  AND v.definition ~ ('\m' || v_nom || '\M')) THEN
      v_ecarts := v_ecarts || ' vue:' || v_f;
    END IF;
    -- Un corps PL/pgSQL ou SQL classique n'est pas dans pg_depend : son
    -- texte. L'appel seulement (nom suivi d'une parenthèse) : un nom cité en
    -- commentaire n'est pas un appelant.
    IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                WHERE NOT p.prosecdef AND p.oid <> v_oid
                  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
                  AND p.prosrc ~ ('\m' || v_nom || '\s*\(')) THEN
      v_ecarts := v_ecarts || ' appelant-invoker:' || v_f;
    END IF;
  END LOOP;

  FOREACH v_f IN ARRAY v_servies LOOP
    v_oid := v_f::regprocedure;
    IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE') THEN
      v_ecarts := v_ecarts || ' porteur-ferme:' || v_f;
    END IF;
    IF NOT (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = v_oid) THEN
      v_ecarts := v_ecarts || ' porteur-invoker:' || v_f;
    END IF;
  END LOOP;

  IF v_ecarts <> '' THEN
    RAISE EXCEPTION 'aides DEFINER sans appelant : écart(s) —%', v_ecarts;
  END IF;
END
$garde$;
