-- ════════════════════════════════════════════════════════════════════════════
-- Thésaurus matière — nettoyage : retire book_draft_keywords / book_keywords
-- Session : Fédération — Communs & Entraide
--
-- Ces tables (ajoutées à l'étape 1, migration 20260615211001) font DOUBLON avec
-- le champ texte libre `subjects` (book_drafts.subjects) déjà présent dans le
-- formulaire de catalogage, à côté du picker contrôlé. Le registre « mots-clés
-- libres » (D1 du cadrage) s'appuie sur ce champ existant — on n'introduit pas
-- un 3e mécanisme de sujets. Tables jamais utilisées (aucune UI, zéro donnée).
-- ════════════════════════════════════════════════════════════════════════════

DROP TRIGGER  IF EXISTS trg_sync_book_keywords_on_publish ON public.book_drafts;
DROP FUNCTION IF EXISTS public.fn_sync_book_keywords_on_publish();
DROP TABLE    IF EXISTS public.book_keywords;
DROP TABLE    IF EXISTS public.book_draft_keywords;

NOTIFY pgrst, 'reload schema';
