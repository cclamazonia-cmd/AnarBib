-- =========================================================================
-- Paquet L.1 — Bascule des 18 vues SECURITY DEFINER vers security_invoker
-- =========================================================================
-- Contexte : le linter Supabase détecte 18 vues définies en SECURITY DEFINER.
-- Depuis PostgreSQL 15, l'option `security_invoker=true` permet à une vue de
-- s'exécuter avec les droits du caller (ses RLS s'appliquent), ce qui est la
-- bonne pratique. L'architecture AnarBib a déjà aligné les RLS sous-jacentes
-- (paquet C, 47 RLS conformes), donc cette bascule est sûre.
--
-- Vérification post-paquet recommandée : pour chaque vue, tester en SQL Editor
--   SET LOCAL ROLE authenticated;
--   SET LOCAL "request.jwt.claims" = '{"sub": "<UUID test>"}';
--   SELECT * FROM <vue> LIMIT 5;
-- pour s'assurer que le filtrage par auth.uid() retourne bien les bonnes lignes.
-- =========================================================================

BEGIN;

-- Vues exposées dans le schéma api (12)
ALTER VIEW api.consulta_itens_ui                 SET (security_invoker = true);
ALTER VIEW api.emprestimo_itens_ui               SET (security_invoker = true);
ALTER VIEW api.catalog_list_session_v1           SET (security_invoker = true);
ALTER VIEW api.network_administrators_public_v1  SET (security_invoker = true);
ALTER VIEW api.my_reservations_active_v2         SET (security_invoker = true);
ALTER VIEW api.my_access                         SET (security_invoker = true);
ALTER VIEW api.reserva_itens_followup_ui         SET (security_invoker = true);
ALTER VIEW api.books_count_v1                    SET (security_invoker = true);
ALTER VIEW api.network_overview                  SET (security_invoker = true);
ALTER VIEW api.my_network_admin_status           SET (security_invoker = true);
ALTER VIEW api.consulta_itens_followup_ui        SET (security_invoker = true);
ALTER VIEW api.library_circulation_stats         SET (security_invoker = true);
ALTER VIEW api.libraries_public_v1               SET (security_invoker = true);
ALTER VIEW api.catalog_list_anon_v1              SET (security_invoker = true);

-- Vues exposées dans le schéma public (3)
ALTER VIEW public.v_libraries_for_signup         SET (security_invoker = true);
ALTER VIEW public.v_active_memberships           SET (security_invoker = true);
ALTER VIEW public.v_membership_overview_panel    SET (security_invoker = true);

-- Commentaire de traçabilité
COMMENT ON VIEW api.my_reservations_active_v2 IS
  'Vue lecteur des réservations actives. security_invoker=true depuis paquet L.1 (2026-05-11). RLS sous-jacente filtre par auth.uid().';
COMMENT ON VIEW api.libraries_public_v1 IS
  'Vue publique des bibliothèques (catalogue/annuaire). security_invoker=true depuis paquet L.1. Accessible anon par design.';
COMMENT ON VIEW api.catalog_list_anon_v1 IS
  'Catalogue accessible aux visiteurs anonymes. security_invoker=true depuis paquet L.1. Accessible anon par design (cœur projet).';
COMMENT ON VIEW api.network_overview IS
  'Vue d''ensemble du réseau (admins, métriques). security_invoker=true depuis paquet L.1. Filtre via fn_caller_is_network_admin().';

COMMIT;

-- =========================================================================
-- Post-conditions attendues
-- =========================================================================
-- - Le linter Supabase ne doit plus signaler aucune alerte `security_definer_view`
-- - Les 17 vues fonctionnent identiquement côté frontend
-- - Aucun parcours utilisateur (lecteur, biblio, admin) n'est cassé
-- - En cas de régression sur une vue, rollback ciblé :
--     ALTER VIEW <schema>.<vue> SET (security_invoker = false);
-- =========================================================================
