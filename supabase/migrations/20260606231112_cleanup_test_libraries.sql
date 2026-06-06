-- =========================================================================
-- Nettoyage des bibliotheques de test
-- =========================================================================
-- Date     : 2026-06-06 23:11 UTC (horodatage reel)
-- Session  : Catalogacao work completion
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- Supprime deux entrees de test qui n'ont plus de raison d'etre :
-- 1. blt-test-informal (f70e1127-...) : bibliotheque test informelle,
--    1 membership Xavier (coordenador), aucune autre dependance.
-- 2. frt : ligne orpheline dans library_email_identity, aucune
--    bibliotheque correspondante dans libraries.
--
-- Les suppressions ont ete appliquees directement via MCP SQL ;
-- cette migration formalise le changement (idempotente).
-- =========================================================================

-- 1. Membership de test (si encore present)
DELETE FROM user_library_memberships
WHERE library_id = 'f70e1127-de75-4c4f-9824-0c6c538f2da5';

-- 2. Bibliotheque test blt-test-informal
DELETE FROM libraries
WHERE id = 'f70e1127-de75-4c4f-9824-0c6c538f2da5';

-- 3. Identite email frt orpheline
DELETE FROM library_email_identity
WHERE library_slug = 'frt';

NOTIFY pgrst, 'reload schema';
