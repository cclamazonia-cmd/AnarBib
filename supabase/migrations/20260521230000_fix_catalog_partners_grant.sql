-- =============================================================================
-- 20260521230000_fix_catalog_partners_grant.sql
-- =============================================================================
-- Correctif : la table public.catalog_partners porte une politique RLS
-- SELECT correcte (catalog_partners_select_members, pour authenticated)
-- mais le GRANT SELECT de base pour le role `authenticated` est ABSENT.
--
-- Consequence : PostgREST refuse la requete avec un 403 Forbidden AVANT
-- meme d'evaluer la RLS (le GRANT est verifie en premier). La table n'a
-- donc jamais ete lisible par l'application depuis sa creation (31/03/2026) :
-- le bloc « Bibliotecas parceiras » de l'onglet documents de BibliotecaPage
-- recevait systematiquement un 403.
--
-- Constate le 21/05/2026 via l'onglet Network (chantier-cadre Biblioteca,
-- finition etape 6). Verifie : catalog_partners est la SEULE table de la
-- page Biblioteca dans ce cas ; les 13 autres ont bien leur GRANT.
--
-- Le correctif est un simple GRANT. La RLS existante reste l'unique filtre
-- de securite : seuls les `authenticated` membres actifs d'au moins une
-- bibliotheque verront les lignes (politique inchangee).
-- =============================================================================

GRANT SELECT ON public.catalog_partners TO authenticated;

-- --- Verification en fin de transaction (doctrine creation d'objets v2) ------
DO $$
DECLARE
  v_has_grant boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.role_table_grants
    WHERE table_schema = 'public'
      AND table_name = 'catalog_partners'
      AND grantee = 'authenticated'
      AND privilege_type = 'SELECT'
  ) INTO v_has_grant;

  IF NOT v_has_grant THEN
    RAISE EXCEPTION 'Echec : GRANT SELECT sur catalog_partners pour authenticated non applique.';
  END IF;

  RAISE NOTICE 'OK : authenticated dispose du GRANT SELECT sur catalog_partners. La RLS catalog_partners_select_members reste le filtre par ligne.';
END $$;
