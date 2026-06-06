-- =========================================================================
-- Paquet fix — suppression des 3 notices de TEST BTL-STG (seed staging)
-- =========================================================================
-- Date     : 2026-06-06
-- Chantier : Nettoyage donnees / notices fictives
-- Auteur   : Xavier + Claude
--
-- CONTEXTE
-- --------
-- Trois notices BTL-STG-0001/0002/0003 (« Anarquia » / Malatesta, « Deus e o
-- Estado » / Bakunin, « Anarquismo e outros ensaios » / Goldman) creees le
-- 2026-03-18 19:41 (created_by NULL, en lot), editora « Biblioteca Terra Livre »
-- / ano 2024 FICTIFS (la BTL n'a pas publie ces titres en 2024). Elles
-- PREEXISTENT a l'import reel du catalogue Terra Livre (2026-03-19) : ce sont des
-- exemplaires de TEST poses pour valider des hypotheses sur la BTL naissante,
-- rattaches a la BLMF, sous une numerotation provisoire « STG » (staging).
--
-- Verifie en lecture (MCP, 2026-06-06) : AUCUNE activite reelle — 0 emprestimo,
-- 0 reserva, 0 consulta, 0 wishlist, 0 ressource numerique. Dependances = 3
-- holdings, 4 exemplares, 3 book_contributors, 3 book_authors, 1 book_draft
-- (580) + ses draft_contributors. Aucune trace dans les tables d'import.
--
-- ACTION : suppression bottom-up des 3 notices et de leurs dependances, ancree
-- sur bib_ref LIKE 'BTL-STG-%' avec gardes fail-fast (exactement 3 notices ;
-- zero activite, sinon abort). DML pur.
-- =========================================================================

BEGIN;

DO $cleanup$
DECLARE
  v_ids bigint[];
  n int;
BEGIN
  -- Cibles
  SELECT array_agg(id ORDER BY id) INTO v_ids
  FROM public.books WHERE bib_ref LIKE 'BTL-STG-%';

  -- Garde 1 : exactement 3 notices (sinon donnees changees -> abort)
  IF COALESCE(array_length(v_ids, 1), 0) <> 3 THEN
    RAISE EXCEPTION 'abort : % notice(s) BTL-STG trouvee(s) au lieu de 3', COALESCE(array_length(v_ids, 1), 0);
  END IF;

  -- Garde 2 : aucune activite reelle (sinon on n'efface rien)
  IF EXISTS (SELECT 1 FROM public.emprestimo_itens_v2 WHERE book_id = ANY (v_ids)) THEN
    RAISE EXCEPTION 'abort : un emprestimo existe sur une notice BTL-STG'; END IF;
  IF EXISTS (SELECT 1 FROM public.reserva_linhas_v2 WHERE book_id = ANY (v_ids)) THEN
    RAISE EXCEPTION 'abort : une reserva existe sur une notice BTL-STG'; END IF;
  IF EXISTS (SELECT 1 FROM public.consulta_linhas_v2 WHERE book_id = ANY (v_ids)) THEN
    RAISE EXCEPTION 'abort : une consulta existe sur une notice BTL-STG'; END IF;

  -- Suppression bottom-up
  DELETE FROM public.book_draft_contributors
   WHERE draft_id IN (SELECT id FROM public.book_drafts WHERE published_book_id = ANY (v_ids));
  DELETE FROM public.book_drafts WHERE published_book_id = ANY (v_ids);

  DELETE FROM public.exemplares
   WHERE holding_id IN (SELECT id FROM public.book_holdings WHERE book_id = ANY (v_ids));
  DELETE FROM public.book_holdings WHERE book_id = ANY (v_ids);

  DELETE FROM public.book_contributors WHERE book_id = ANY (v_ids);  -- trigger retire book_authors
  DELETE FROM public.book_authors WHERE book_id = ANY (v_ids);       -- defensif

  DELETE FROM public.books WHERE id = ANY (v_ids);
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 3 THEN RAISE EXCEPTION 'suppression books : % ligne(s) au lieu de 3', n; END IF;

  -- Verification finale : plus aucune trace
  IF EXISTS (SELECT 1 FROM public.books WHERE bib_ref LIKE 'BTL-STG-%') THEN
    RAISE EXCEPTION 'VERIF : des notices BTL-STG subsistent'; END IF;

  RAISE NOTICE 'cleanup BTL-STG OK — 3 notices de test supprimees (% )', v_ids;
END
$cleanup$;

COMMIT;

-- =========================================================================
-- Apres COMMIT : REFRESH des MV catalogue (les 3 notices y figuraient).
-- =========================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- =========================================================================
-- Rollback : non automatique (donnees de test supprimees volontairement).
-- =========================================================================
