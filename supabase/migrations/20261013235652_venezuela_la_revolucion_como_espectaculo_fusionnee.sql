-- =====================================================================
-- AnarBib -- Venezuela, La Revolución como espectáculo (Uzcátegui, 2010) :
--            deux notices BTL réunies
-- Date     : 2026-10-14  ·  Accord de Xavier (« Vas-y pour les deux »)
-- Dépend   : 20261013235651 (DEDUP-16, la paire devient visible),
--            20260928100501 (fn_fusion_notices), 20261005092727 (C18, modèle)
--
-- CONSTAT. 10 (BTL-TL-000005, co-édition El Libertario / La Cucaracha
-- Ilustrada / Libros de Anarres / Tierra de fuego / LaMalatesta Editorial,
-- Caracas / Madrid / Tenerife / Buenos Aires) et 17 (BTL-TL-000012,
-- « La Malatesta », Madrid) : même œuvre, même titre, même année, sans ISBN.
-- Deux exemplaires de la même édition à la BTL. Aucun brouillon ouvert.
--
-- AUTORISATION — À LIRE. Comme pour C18 et les migrations du 08/10, la
-- fusion est inscrite SOUS L'IDENTITÉ de Xavier (d6710372…) le temps de la
-- transaction, à sa demande écrite. Ce n'est PAS un modèle.
--
-- CE QUI EST FAIT (fn_fusion_notices, gardes comprises) : notice 10 gardée
-- (la plus ancienne, la co-édition complète) ; l'exemplaire BTL-TL-EX-000012
-- rejoint son fonds et garde son numéro d'inventaire (il affiche désormais la
-- cote BTL-TL-000005, étiquette à refaire) ; champs vides repris (aucun ici) ;
-- le doublon entier dans merge_log.details.
-- Joué à blanc en production le 13/10 (transaction annulée) : 0 exemplaire
-- décalé. Sur une base sans ces notices (banc d'essai), rien n'est fait.
-- =====================================================================

BEGIN;

DO $$
DECLARE r jsonb; v_n int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 10 AND bib_ref = 'BTL-TL-000005')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 17 AND bib_ref = 'BTL-TL-000012') THEN
    RAISE NOTICE 'Venezuela : notices absentes ou déjà fusionnées, rien à faire.';
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.status = 'draft' AND d.published_book_id IN (10, 17)) THEN
    RAISE EXCEPTION 'Venezuela : un brouillon ouvert est apparu — relire avant de fusionner';
  END IF;

  PERFORM set_config('request.jwt.claims', '{"sub":"d6710372-e5e5-4608-800b-99a26817c677","role":"authenticated"}', true);
  r := public.fn_fusion_notices(10, 17, '{}', true);
  PERFORM set_config('request.jwt.claims', '', true);
  RAISE NOTICE 'Venezuela : 17 → 10 %', r;

  IF EXISTS (SELECT 1 FROM public.books WHERE id = 17) THEN
    RAISE EXCEPTION 'Venezuela : le doublon subsiste';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id JOIN public.books b ON b.id = h.book_id
   WHERE e.bib_ref IS DISTINCT FROM coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'Venezuela : % exemplaire(s) dont la référence ne suit pas son fonds', v_n;
  END IF;
  IF (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id
       WHERE h.book_id = 10 AND e.tombo IN ('BTL-TL-EX-000005', 'BTL-TL-EX-000012')) <> 2 THEN
    RAISE EXCEPTION 'Venezuela : les deux exemplaires n''ont pas rejoint la notice gardée';
  END IF;
END $$;

COMMIT;
