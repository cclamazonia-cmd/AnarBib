-- =====================================================================
-- AnarBib -- Deux notices à ISBN identique (BTL / BLMF) fusionnées
-- Date     : 2026-10-08  ·  Suite de DEDUP-15 (liste des 28 paires tirée le soir)
-- Dépend   : 20260928100501 (fn_fusion_notices), 20260928163920 (DEDUP-14 :
--            un même ISBN est une même édition), 20261005092727 (C18, modèle)
--
-- CONSTAT (prod, 08/10). Parmi les 28 paires inter-bibliothèques de même
-- œuvre encore proposées, deux portent un ISBN des DEUX côtés, et le même
-- (fn_isbn_coeur) :
--   · Goldman, O indivíduo, a Sociedade e o Estado, e outros ensaios, Hedra :
--     2377 (BLMF 0000186, 2011, 142 p., coll. Estudos libertários) et
--     1501 (BTL-TL-001599, 2007). Même ISBN 978-85-7715-072-4 : une même
--     édition, deux impressions (DEDUP-14 : un tirage n'est pas une édition).
--   · Reclus, Renovação de uma Cidade / Repartição dos Homens, Imaginário
--     2010 : 2275 (BLMF 0000070) et 1968 (BTL-TL-002100). Même ISBN
--     978-85-7935-000-9.
-- Aucun brouillon ouvert ; un sujet et un·e contributeur·rice par notice.
--
-- AUTORISATION — À LIRE. Xavier, le 08/10 : « Tu as mon accord pour
-- fusionner là où les ISBN concordent. » Comme pour C18 et 20261008185801,
-- les fusions sont inscrites SOUS SON IDENTITÉ (d6710372…) le temps de la
-- transaction. Ce n'est PAS un modèle : une fusion se fait dans l'assistant.
--
-- CE QUI EST FAIT (fn_fusion_notices, gardes comprises)
--   · La notice BLMF est gardée (règle du 31/08 : BLMF si présente) ; chaque
--     fonds porte déjà sa référence locale, les exemplaires gardent leur cote.
--   · Les champs vides de la gardée sont repris du doublon : ici le lieu de
--     publication (São Paulo) dans les deux cas. L'année (2011) et la CDD
--     (910) de la notice BLMF restent ; celles de la notice BTL (2007 ;
--     335.83) sont dans merge_log.details.
--   · L'exemplaire BTL de Goldman reçoit en note son année d'impression
--     (2007), comme les deux tirages de BTL-TL-000881 le 28/09.
-- Joué à blanc en production le 08/10 (transaction annulée) : 0 exemplaire
-- décalé. Sur une base sans ces notices (banc d'essai), rien n'est fait.
-- =====================================================================

BEGIN;

DO $$
DECLARE r1 jsonb; r2 jsonb; v_n int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 2377 AND bib_ref = '0000186')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 1501 AND bib_ref = 'BTL-TL-001599')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 2275 AND bib_ref = '0000070')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 1968 AND bib_ref = 'BTL-TL-002100') THEN
    RAISE NOTICE 'ISBN identiques : notices absentes ou déjà fusionnées, rien à faire.';
    RETURN;
  END IF;
  -- Les ISBN concordent toujours (sinon quelqu'un a corrigé une notice entre-temps : relire).
  IF public.fn_isbn_coeur((SELECT isbn FROM public.books WHERE id = 2377)) IS DISTINCT FROM public.fn_isbn_coeur((SELECT isbn FROM public.books WHERE id = 1501))
     OR public.fn_isbn_coeur((SELECT isbn FROM public.books WHERE id = 2275)) IS DISTINCT FROM public.fn_isbn_coeur((SELECT isbn FROM public.books WHERE id = 1968))
     OR public.fn_isbn_coeur((SELECT isbn FROM public.books WHERE id = 2377)) = '' THEN
    RAISE EXCEPTION 'ISBN identiques : les ISBN ne concordent plus — relire avant de fusionner';
  END IF;
  IF EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.status = 'draft' AND d.published_book_id IN (2377, 1501, 2275, 1968)) THEN
    RAISE EXCEPTION 'ISBN identiques : un brouillon ouvert est apparu — relire avant de fusionner';
  END IF;

  -- La session de Xavier, à sa demande (voir l'en-tête), le temps de la transaction.
  PERFORM set_config('request.jwt.claims', '{"sub":"d6710372-e5e5-4608-800b-99a26817c677","role":"authenticated"}', true);
  r1 := public.fn_fusion_notices(2377, 1501, '{}', true);
  r2 := public.fn_fusion_notices(2275, 1968, '{}', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RAISE NOTICE 'ISBN identiques : 1501 → 2377 %, 1968 → 2275 %', r1, r2;

  UPDATE public.exemplares
     SET notes = concat_ws(' · ', nullif(btrim(notes), ''), 'Impressão de 2007 (ficha BTL-TL-001599, fundida em 0000186 em 08/10/2026)')
   WHERE tombo = 'BTL-TL-EX-001599' AND coalesce(notes, '') NOT LIKE '%Impressão de 2007%';

  -- Vérification
  IF EXISTS (SELECT 1 FROM public.books WHERE id IN (1501, 1968)) THEN
    RAISE EXCEPTION 'ISBN identiques : un doublon subsiste';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id JOIN public.books b ON b.id = h.book_id
   WHERE e.bib_ref IS DISTINCT FROM coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'ISBN identiques : % exemplaire(s) dont la référence ne suit pas son fonds', v_n;
  END IF;
  IF (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
       WHERE h.book_id = 2377 AND e.tombo IN ('BTL-TL-EX-001599', 'CCLA.2023.186')) <> 2
     OR (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
       WHERE h.book_id = 2275 AND e.tombo IN ('BTL-TL-EX-002100', 'CCLA.2023.70')) <> 2 THEN
    RAISE EXCEPTION 'ISBN identiques : les exemplaires n''ont pas rejoint la notice gardée';
  END IF;
  IF (SELECT ano FROM public.books WHERE id = 2377) IS DISTINCT FROM '2011'
     OR (SELECT local_publicacao FROM public.books WHERE id = 2275) IS DISTINCT FROM 'São Paulo' THEN
    RAISE EXCEPTION 'ISBN identiques : champs inattendus sur la notice gardée';
  END IF;
END $$;

COMMIT;
