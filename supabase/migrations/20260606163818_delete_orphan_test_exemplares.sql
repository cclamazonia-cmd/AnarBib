-- =========================================================================
-- Paquet fix — suppression de 3 exemplaires orphelins de TEST
-- =========================================================================
-- Date     : 2026-06-06
-- Chantier : Nettoyage donnees / exemplaires orphelins
-- Auteur   : Xavier + Claude
--
-- CONTEXTE
-- --------
-- 3 exemplaires BLMF (ids 2460/2461/2462, tombos BTL-TL-EX-X01220) avec un
-- bib_ref MALFORME 'BTL-TL-EX-001220' (un 'EX-' parasite ; le vrai ref serait
-- 'BTL-TL-001220' = livre 1141 'Essência da Religião', du catalogue Terra Livre).
-- Ils n'ont AUCUN holding (holding_id NULL -> invisibles via la RLS exemplares,
-- non resolvables) et la BLMF ne possede aucun holding pour ce titre. Crees le
-- 2026-04-04 en testant l'import d'exemplaires. Confirme avec l'utilisateur :
-- ce sont des ARTEFACTS DE TEST (la BLMF ne detient pas ce titre).
--
-- Verifie en lecture (MCP, 2026-06-06) : aucune activite (0 emprestimo, 0
-- reserva, 0 consulta). Le livre Terra Livre 1141 et son holding btl ne sont
-- PAS concernes (on ne touche qu'aux 3 exemplaires au bib_ref casse).
-- =========================================================================

BEGIN;

DO $cleanup$
DECLARE
  v_ids bigint[];
  n int;
BEGIN
  SELECT array_agg(id ORDER BY id) INTO v_ids
  FROM public.exemplares
  WHERE bib_ref = 'BTL-TL-EX-001220' AND holding_id IS NULL;

  -- Garde 1 : exactement 3 exemplaires cibles
  IF COALESCE(array_length(v_ids, 1), 0) <> 3 THEN
    RAISE EXCEPTION 'abort : % exemplaire(s) BTL-TL-EX-001220 orphelin(s) au lieu de 3', COALESCE(array_length(v_ids, 1), 0);
  END IF;

  -- Garde 2 : aucune activite
  IF EXISTS (SELECT 1 FROM public.emprestimo_itens_v2 WHERE item_id = ANY (v_ids)) THEN
    RAISE EXCEPTION 'abort : un emprestimo existe sur un exemplaire cible'; END IF;
  IF EXISTS (SELECT 1 FROM public.reserva_linhas_v2 WHERE item_id = ANY (v_ids)) THEN
    RAISE EXCEPTION 'abort : une reserva existe sur un exemplaire cible'; END IF;
  IF EXISTS (SELECT 1 FROM public.consulta_linhas_v2 WHERE item_id = ANY (v_ids)) THEN
    RAISE EXCEPTION 'abort : une consulta existe sur un exemplaire cible'; END IF;

  DELETE FROM public.exemplares WHERE id = ANY (v_ids);
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 3 THEN RAISE EXCEPTION 'suppression : % ligne(s) au lieu de 3', n; END IF;

  IF EXISTS (SELECT 1 FROM public.exemplares WHERE bib_ref = 'BTL-TL-EX-001220') THEN
    RAISE EXCEPTION 'VERIF : des exemplaires BTL-TL-EX-001220 subsistent'; END IF;

  RAISE NOTICE 'cleanup exemplaires orphelins OK — 3 supprimes (%)', v_ids;
END
$cleanup$;

COMMIT;

-- =========================================================================
-- Rollback : non automatique (donnees de test supprimees volontairement).
-- =========================================================================
