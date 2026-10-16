-- =====================================================================
-- 20261016085021_rede_compteurs_des_bibliotheques_privees
-- La page Réseau compte les documents d'une bibliothèque privée
-- (décision de Xavier, 16/10/2026, option 2).
--
-- POURQUOI. Les cartes de la page Réseau lisent api.library_circulation_stats,
-- une vue security_invoker : chaque compteur s'y calcule sous la RLS de la
-- personne qui regarde. Les holdings d'une bibliothèque privée ne sont
-- lisibles que par ses membres (fn_library_visible_to_caller), et le rôle
-- d'administration du réseau n'y fait pas exception. Constat du 16/10 :
-- Anarchief.Org, privée, 1 002 notices publiées la veille, s'affichait avec
-- « 0 document » aux yeux de l'administration. Un nombre n'est pas une donnée
-- sensible ; une carte à 0 trompe.
--
-- CE QUE FAIT LE PAQUET. public.fn_rede_library_counters() rend, pour chaque
-- bibliothèque, les compteurs des cartes (documents = holdings, exemplaires,
-- lecteur·rices et équipe actives, prêts ouverts et en retard, réservations
-- actives), tirés de la même vue — donc mêmes définitions qu'aux Rapports de
-- chaque bibliothèque. SECURITY DEFINER : la vue se calcule sous le
-- propriétaire des tables, sans la RLS. Réservée à l'administration du réseau
-- (fn_assert_network_admin, 42501 sinon) ; ni titre, ni nom, ni identifiant de
-- personne ne sort, seulement des nombres par bibliothèque.
--
-- CE QUE LE PAQUET NE FAIT PAS. Il ne change ni la vue, ni la visibilité des
-- notices au catalogue : une bibliothèque privée reste privée.
--
-- Garde : tests/sql/rede_compteurs_tests.sql.
-- =====================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_rede_library_counters()
RETURNS TABLE (
  library_id          uuid,
  holdings_count      bigint,
  exemplars_count     bigint,
  readers_active      bigint,
  librarians_active   bigint,
  loans_open          bigint,
  loans_overdue       bigint,
  reservations_active bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- La garde porte sur l'appelant (auth.uid() du jeton), pas sur current_user,
  -- qui vaut le propriétaire dans une fonction DEFINER.
  PERFORM public.fn_assert_network_admin();

  RETURN QUERY
  SELECT s.library_id, s.holdings_count, s.exemplars_count, s.readers_active,
         s.librarians_active, s.loans_open, s.loans_overdue, s.reservations_active
    FROM api.library_circulation_stats s;
END;
$$;

COMMENT ON FUNCTION public.fn_rede_library_counters() IS
  'Compteurs des cartes de la page Réseau, toutes bibliothèques, privées comprises ; administration du réseau seulement (16/10/2026).';

REVOKE ALL ON FUNCTION public.fn_rede_library_counters() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_rede_library_counters() TO authenticated, service_role;

COMMIT;
