-- =========================================================================
-- Paquet fix — GRANT ecriture author_translations a authenticated
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / bios multilingues (bug fiche auteur)
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- La table public.author_translations a une policy RLS d'ecriture
-- (author_translations_librarian_write, cmd ALL, gated librarian/coordenador)
-- mais le GRANT pour le role authenticated etait limite a SELECT. En Postgres
-- le privilege de table est verifie AVANT la RLS : la policy etait donc
-- inoperante et le upsert frontend (.from('author_translations').upsert)
-- echouait en "permission denied for table author_translations".
--
-- CORRECTIF
-- ---------
-- Ajouter INSERT/UPDATE/DELETE au role authenticated. La RLS existante
-- (librarian_write) reste le seul filtre metier : seuls librarian/coordenador
-- passent le WITH CHECK/USING. Pas de nouvelle policy, pas de changement RLS.
-- =========================================================================

BEGIN;

GRANT INSERT, UPDATE, DELETE ON public.author_translations TO authenticated;

-- Verification : le grant est bien pose.
DO $$
DECLARE
  v_has_insert boolean;
BEGIN
  SELECT has_table_privilege('authenticated', 'public.author_translations', 'INSERT')
    INTO v_has_insert;
  IF NOT v_has_insert THEN
    RAISE EXCEPTION 'GRANT INSERT non applique sur author_translations. Rollback.';
  END IF;
  RAISE NOTICE 'author_translations : INSERT/UPDATE/DELETE accordes a authenticated.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback cible (si regression) :
-- =========================================================================
-- BEGIN;
--   REVOKE INSERT, UPDATE, DELETE ON public.author_translations FROM authenticated;
-- COMMIT;
-- =========================================================================
