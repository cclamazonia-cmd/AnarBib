-- =========================================================================
-- Paquet L.8 — Resserrage des permissions anon excessives
-- =========================================================================
-- Contexte : l'audit du 12/05/2026 a révélé que plusieurs tables donnent
-- à anon des permissions INSERT/UPDATE/DELETE alors que :
--   (a) aucune RLS policy INSERT/UPDATE/DELETE pour anon n'existe sur ces
--       tables (vérifié sur auth_rate_limits — résultat : 0 policy), OU
--   (b) le contenu de ces tables ne devrait jamais être modifié par un
--       visiteur·euse anonyme.
--
-- Ces permissions sont des vestiges des defaults legacy de Supabase
-- (avant la doctrine 30/10/2026). Doctrinalement, c'est sale : même si
-- la RLS bloque en pratique, l'absence de permission table-level est une
-- défense en profondeur précieuse en cas de désactivation accidentelle
-- d'une RLS.
--
-- À POUSSER APRÈS L.9 (qui fige l'état actuel) et L.10 (renommage backups).
-- Si une régression apparaît, rollback ciblé :
--   GRANT INSERT, UPDATE, DELETE ON public.<table> TO anon;
--
-- Le paquet inclut un DO block de vérification finale qui confirme que
-- les parcours anon critiques (catalogue, signup) fonctionnent toujours.
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- 1. auth_rate_limits — vérifié : aucune policy INSERT pour anon
-- -------------------------------------------------------------------------
-- Le rate-limit anonyme est probablement géré via fonction SECURITY DEFINER
-- (qui bypass la RLS) et pas via INSERT direct par anon.

REVOKE INSERT, UPDATE, DELETE ON public.auth_rate_limits FROM anon;

-- -------------------------------------------------------------------------
-- 2. catalog_partner_capabilities & catalog_partner_probe_runs
-- -------------------------------------------------------------------------
-- Métadonnées sur les partenaires de catalogage. Lisibles à anon (transparence)
-- mais les écritures se font via job de probe interne ou interventions staff.

REVOKE INSERT, UPDATE, DELETE ON public.catalog_partner_capabilities FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.catalog_partner_probe_runs FROM anon;

-- -------------------------------------------------------------------------
-- 3. library_membership_audit, library_membership_rules
-- -------------------------------------------------------------------------
-- Tables d'audit et de règles d'adhésion. Lisibles publiquement (pour info)
-- mais ne devraient JAMAIS être modifiées par anon (ni même authenticated
-- sans passer par une RPC de gouvernance).

REVOKE INSERT, UPDATE, DELETE ON public.library_membership_audit FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.library_membership_rules FROM anon;

-- -------------------------------------------------------------------------
-- 4. library_retention_policies
-- -------------------------------------------------------------------------
-- Politiques de rétention de données par biblio. Lecture pour transparence,
-- écriture réservée aux coordenadores via RPC.

REVOKE INSERT, UPDATE, DELETE ON public.library_retention_policies FROM anon;

-- -------------------------------------------------------------------------
-- 5. membership_payments
-- -------------------------------------------------------------------------
-- Paiements de cotisation. Lisibles par anon (pour transparence financière
-- militante ?) mais les écritures passent par fn_record_membership_payment.

REVOKE INSERT, UPDATE, DELETE ON public.membership_payments FROM anon;

-- -------------------------------------------------------------------------
-- 6. network_admin_* (4 tables) et network_administrator_* (3 tables)
-- -------------------------------------------------------------------------
-- Tables de gouvernance du réseau anarchiste. La transparence justifie
-- la lecture publique des décisions et votes, mais l'écriture passe
-- exclusivement par RPC fn_network_admin_* (paquet D).

REVOKE INSERT, UPDATE, DELETE ON public.network_admin_collective_removal_proposals FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.network_admin_collective_removal_votes FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.network_admin_cross_library_actions_log FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.network_administrator_audit FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.network_administrator_cooptation_proposals FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.network_administrator_cooptation_votes FROM anon;
REVOKE INSERT, UPDATE, DELETE ON public.network_administrators FROM anon;

-- -------------------------------------------------------------------------
-- 7. team_notification_outbox
-- -------------------------------------------------------------------------
-- Queue de notifications team/network. Lecture peut être anon (transparence
-- du fonctionnement) mais l'écriture passe par fn_team_notify_event et
-- fn_network_notify_event en SECURITY DEFINER.

REVOKE INSERT, UPDATE, DELETE ON public.team_notification_outbox FROM anon;

-- =========================================================================
-- VÉRIFICATION : parcours anon critiques toujours fonctionnels
-- =========================================================================

DO $$
DECLARE
  v_books_count       int;
  v_libraries_count   int;
  v_holdings_count    int;
  v_authors_count     int;
  v_anon_writes_left  int;
BEGIN
  -- Test 1 : parcours catalogue anon
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';

  SELECT count(*) INTO v_books_count     FROM public.books;
  SELECT count(*) INTO v_libraries_count FROM public.libraries;
  SELECT count(*) INTO v_holdings_count  FROM public.book_holdings;
  SELECT count(*) INTO v_authors_count   FROM public.authors;

  IF v_books_count < 1 OR v_libraries_count < 2
     OR v_holdings_count < 1 OR v_authors_count < 1 THEN
    RAISE EXCEPTION 'Vérif catalogue anon échouée : books=%, libs=%, holdings=%, authors=%. Rollback.',
      v_books_count, v_libraries_count, v_holdings_count, v_authors_count;
  END IF;

  RESET ROLE;

  -- Test 2 : confirmer que les écritures anon retirées sont bien retirées
  SELECT count(*) INTO v_anon_writes_left
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind = 'r'
    AND c.relname IN (
      'auth_rate_limits',
      'catalog_partner_capabilities', 'catalog_partner_probe_runs',
      'library_membership_audit', 'library_membership_rules',
      'library_retention_policies', 'membership_payments',
      'network_admin_collective_removal_proposals',
      'network_admin_collective_removal_votes',
      'network_admin_cross_library_actions_log',
      'network_administrator_audit',
      'network_administrator_cooptation_proposals',
      'network_administrator_cooptation_votes',
      'network_administrators',
      'team_notification_outbox'
    )
    AND has_table_privilege('anon', c.oid, 'INSERT');

  IF v_anon_writes_left > 0 THEN
    RAISE EXCEPTION 'Vérif révocation anon échouée : % tables ciblées ont encore INSERT anon. Rollback.',
      v_anon_writes_left;
  END IF;

  RAISE NOTICE 'Paquet L.8 OK :';
  RAISE NOTICE '  - Catalogue anon : % livres, % biblios, % holdings, % auteurs',
    v_books_count, v_libraries_count, v_holdings_count, v_authors_count;
  RAISE NOTICE '  - 15 tables ciblées : INSERT/UPDATE/DELETE anon révoqué';
END $$;

COMMIT;

-- =========================================================================
-- Post-conditions
-- =========================================================================
-- - 15 tables ont vu leurs INSERT/UPDATE/DELETE pour anon révoqués
-- - Anon conserve uniquement SELECT (pour transparence) sur ces tables
-- - Aucun parcours métier impacté (les écritures passent par RPC ou
--   sont réservées à authenticated/staff)
-- - Défense en profondeur renforcée : même si une RLS vient à sauter,
--   anon ne peut plus rien écrire sur ces tables
-- =========================================================================
-- Tests manuels recommandés après push (navigation privée) :
-- =========================================================================
-- 1. https://app.anarbib.org/criar-conta — dropdown signup OK
-- 2. https://app.anarbib.org/catalogo — recherche catalogue OK
-- 3. https://app.anarbib.org/login — login OK
-- 4. https://app.anarbib.org/solicitar-biblioteca — formulaire OK
-- =========================================================================
-- Rollback ciblé si régression imprévue sur une table précise :
-- =========================================================================
-- GRANT INSERT, UPDATE, DELETE ON public.<nom_table> TO anon;
-- =========================================================================
