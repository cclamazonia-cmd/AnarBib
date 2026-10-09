-- =====================================================================
-- AnarBib -- Acción directa anarquista : les tomes II et III, catalogués à la
--            BTL et à la MLEG, réunis sous une notice chacun
-- Date     : 2026-10-09  ·  Accord de Xavier (09/10 : « Accord donné, fusionne
--            les paires II et III par migration »)
-- Dépend   : 20261008214306 (les tomes posés), 20260928100501 (fn_fusion_notices),
--            20261005092727 (C18, modèle)
--
-- CONSTAT. Depuis la pose des tomes (20261008214306), le tome II est sous
-- 369 (BTL-TL-000390, « La Fundación », sans date) et 2492 (MLEG-0035, 2005) ;
-- le tome III sous 368 (BTL-TL-000389, « Los primeros años », 2006) et 2493
-- (MLEG-0036, 2006). Même édition (Recortes, Montevideo). L'assistant ne les
-- propose pas : les titres MLEG (« … Uma História de FAU - Tomo II - La
-- Fundación ») passent sous le seuil de similarité. Aucun brouillon ouvert.
--
-- AUTORISATION — À LIRE. Comme pour C18 et les migrations du 08/10, les
-- fusions sont inscrites SOUS L'IDENTITÉ de Xavier (d6710372…) le temps de la
-- transaction, à sa demande écrite. Ce n'est PAS un modèle.
--
-- CE QUI EST FAIT (fn_fusion_notices, gardes comprises)
--   · Notice BTL gardée (plus ancienne, sous-titre propre, CDD, langue) ;
--     le fonds MLEG reçoit sa cote en référence locale avant la fusion.
--   · Rien n'est repris d'office de la notice MLEG (provenance d'import et
--     « Assuntos importados » restent dans merge_log.details), sauf l'année
--     2005 du tome II, absente de la notice BTL.
--   · BTL-TL-000391 (« volume 3 », deuxième exemplaire présumé du tome III)
--     et BTL-TL-000396 (« 4 », non vérifié) ne bougent pas : livres en main.
-- Joué à blanc en production le 09/10 (transaction annulée) : 0 exemplaire
-- décalé. Sur une base sans ces notices (banc d'essai), rien n'est fait.
-- =====================================================================

BEGIN;

DO $$
DECLARE r1 jsonb; r2 jsonb; v_n int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 369 AND bib_ref = 'BTL-TL-000390' AND volume = '2')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 2492 AND bib_ref = 'MLEG-0035' AND volume = '2')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 368 AND bib_ref = 'BTL-TL-000389' AND volume = '3')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 2493 AND bib_ref = 'MLEG-0036' AND volume = '3') THEN
    RAISE NOTICE 'Acción directa anarquista II/III : notices absentes, tomes changés ou déjà fusionnées, rien à faire.';
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.status = 'draft' AND d.published_book_id IN (369, 2492, 368, 2493)) THEN
    RAISE EXCEPTION 'Acción directa anarquista II/III : un brouillon ouvert est apparu — relire avant de fusionner';
  END IF;
  IF ARRAY['ano'] && public.fn_dedup_non_transferable_fields() THEN
    RAISE EXCEPTION 'Acción directa anarquista II/III : ano devenu non reprenable';
  END IF;

  -- La session de Xavier, à sa demande (voir l'en-tête), le temps de la transaction.
  PERFORM set_config('request.jwt.claims', '{"sub":"d6710372-e5e5-4608-800b-99a26817c677","role":"authenticated"}', true);
  UPDATE public.book_holdings h SET local_bib_ref = b.bib_ref FROM public.books b
   WHERE b.id = h.book_id AND b.id IN (2492, 2493) AND nullif(btrim(h.local_bib_ref), '') IS NULL;
  r1 := public.fn_fusion_notices(369, 2492, '{ano}', false);
  r2 := public.fn_fusion_notices(368, 2493, '{}', false);
  PERFORM set_config('request.jwt.claims', '', true);
  RAISE NOTICE 'Acción directa anarquista : 2492 → 369 %, 2493 → 368 %', r1, r2;

  -- Vérification
  IF EXISTS (SELECT 1 FROM public.books WHERE id IN (2492, 2493)) THEN
    RAISE EXCEPTION 'Acción directa anarquista II/III : un doublon subsiste';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id JOIN public.books b ON b.id = h.book_id
   WHERE e.bib_ref IS DISTINCT FROM coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'Acción directa anarquista II/III : % exemplaire(s) dont la référence ne suit pas son fonds', v_n;
  END IF;
  IF (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = 369 AND e.tombo IN ('BTL-TL-EX-000390', 'MLEG-2026-0035')) <> 2
     OR (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = 368 AND e.tombo IN ('BTL-TL-EX-000389', 'MLEG-2026-0036')) <> 2
     OR (SELECT ano FROM public.books WHERE id = 369) IS DISTINCT FROM '2005' THEN
    RAISE EXCEPTION 'Acción directa anarquista II/III : exemplaires ou année inattendus';
  END IF;
END $$;

COMMIT;
