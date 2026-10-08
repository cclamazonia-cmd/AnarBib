-- =====================================================================
-- AnarBib -- Vingt-cinq notices cataloguées deux fois (BTL, BLMF, MLEG) fusionnées
-- Date     : 2026-10-08  ·  Suite de DEDUP-15 (liste des 28 paires tirée le soir)
-- Dépend   : 20260928100501 (fn_fusion_notices), 20261005092727 (C18, modèle),
--            20261008201703 (Goldman, Reclus : les deux paires à ISBN identique)
--
-- CONSTAT (prod, 08/10). Vingt-huit paires inter-bibliothèques de même œuvre,
-- même année, même éditeur (aux mots génériques près), sans ISBN qui les
-- sépare, encore proposées par l'assistant. Deux fusionnées par
-- 20261008201703 (ISBN identique) ; une par Xavier à l'écran le 08/10 à
-- 20 h 32 UTC (A Internacional, merge_log 212). Restent vingt-cinq, toutes
-- relues notice contre notice : même titre (à la casse, à une faute de
-- frappe ou à un sous-titre près), même auteur·rice, même année, même
-- éditeur. Aucun brouillon ouvert.
--
-- AUTORISATION — À LIRE. Xavier, le 08/10 : « pour les autres paires
-- clairement identiques, prends les infos pertinentes de chaque notice, et
-- résous les doublons sans perte de détails en gardant les exemplaires là
-- où existent. » Comme pour C18, les fusions sont inscrites SOUS SON
-- IDENTITÉ (d6710372…) le temps de la transaction. Ce n'est PAS un modèle.
--
-- CE QUI EST FAIT, pour chaque paire (fn_fusion_notices, gardes comprises)
--   · Notice gardée : la BLMF si présente, sinon la BTL (plus ancienne et
--     plus riche : CDD, langue, ISBN) ; pour les deux doublons internes à la
--     BTL (Antígona 1989, Makhno/Tupac 2008), celle qui a déjà deux fonds.
--   · Le fonds MLEG reçoit en référence locale la cote de sa notice avant la
--     fusion : son exemplaire garde sa cote. Les fonds BTL/BLMF ont déjà la
--     leur. Les deux exemplaires BTL d'un doublon interne rejoignent le même
--     fonds en gardant leur numéro d'inventaire.
--   · Champs : quand le doublon est une notice BTL ou BLMF, les champs vides
--     de la gardée sont repris (lieu, langue, sous-titre). Quand le doublon
--     est une notice MLEG, rien n'est repris d'office (sa provenance
--     d'import et ses « Assuntos importados » parlent de l'import, pas du
--     livre ; tout reste dans merge_log.details), sauf les champs choisis :
--       - titre pris sur la notice MLEG quand la BTL porte une faute
--         (« Atiteologismo » → « Antiteologismo » ; « Greve da Arte /
--         Manifesto Neoístas » → « Manifesto Neoísta: Greve da Arte ») ;
--       - année 2005 de Mella (Primeiro de maio) absente de la BTL ;
--       - lieu de publication de Magnani absent de la BLMF ;
--       - éditeur plus complet pris sur le doublon pour Antígona (« Edições
--         Antígona »), Makhno (co-édition Tupac / LaMalatesta, Buenos Aires /
--         Madrid) et Flores Magón (Faísca / FARJ / Achiamé).
--     Sujets et contributeur·rices manquants toujours repris (règle de
--     fn_fusion_notices) : quatorze sujets, deux contributeurs (Guérin, Rocker).
--   · Une faute corrigée au passage : « Edirora Imaginário » (BTL-TL-000606).
-- Joué à blanc en production le 08/10 (transaction annulée) : 25 fusions,
-- 0 exemplaire décalé. Sur une base sans ces notices (banc), rien n'est fait.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  p record; r jsonb; v_n int; v_total int := 0;
BEGIN
  CREATE TEMP TABLE paires_0810 (c bigint, c_ref text, d bigint, d_ref text, champs text[], vides boolean) ON COMMIT DROP;
  INSERT INTO paires_0810 VALUES
    (986,  'BTL-TL-001057', 2567, 'MLEG-0110', '{}',                        false),  -- Rodrigues, Entre Ditaduras
    (49,   'BTL-TL-000046', 43,   'BTL-TL-000040', '{editora}',             true),   -- De Sousa, Antígona 1989 (interne BTL)
    (699,  'BTL-TL-000751', 2504, 'MLEG-0047', '{}',                        false),  -- Colombo
    (1725, 'BTL-TL-001835', 2701, 'MLEG-0244', '{}',                        false),  -- Bakunin, O Socialismo Libertário
    (1837, 'BTL-TL-001957', 2680, 'MLEG-0223', '{}',                        false),  -- Bancal, Proudhon
    (2323, '0000126',       1155, 'BTL-TL-001235', '{}',                    true),   -- Bakunin, Escritos contra Marx
    (1398, 'BTL-TL-001487', 1400, 'BTL-TL-001489', '{editora,local_publicacao}', true), -- Archinov (interne BTL)
    (1134, 'BTL-TL-001213', 2645, 'MLEG-0188', '{}',                        false),  -- Kropotkin, O Estado
    (2303, '0000103',       1956, 'BTL-TL-002088', '{editora}',             true),   -- Abad de Santillán, Flores Magón
    (2404, '0000214',       535,  'BTL-TL-000567', '{}',                    true),   -- Arellano, Chiapas
    (2435, '0000247',       2649, 'MLEG-0192', '{local_publicacao}',        false),  -- Magnani
    (718,  'BTL-TL-000772', 2500, 'MLEG-0043', '{}',                        false),  -- Rago
    (1858, 'BTL-TL-001980', 2653, 'MLEG-0196', '{}',                        false),  -- Kropotkin, O princípio anarquista
    (572,  'BTL-TL-000606', 2512, 'MLEG-0055', '{}',                        false),  -- Raynaud
    (1532, 'BTL-TL-001631', 2644, 'MLEG-0187', '{}',                        false),  -- Enzensberger
    (2329, '0000132',       691,  'BTL-TL-000740', '{}',                    true),   -- Bayer
    (2440, '0000252',       734,  'BTL-TL-000790', '{}',                    true),   -- Makhno, Anarquia & Organização
    (1697, 'BTL-TL-001806', 2662, 'MLEG-0205', '{}',                        false),  -- Guérin ; Rocker
    (1859, 'BTL-TL-001982', 2677, 'MLEG-0220', '{ano}',                     false),  -- Mella, Primeiro de maio
    (494,  'BTL-TL-000525', 2525, 'MLEG-0068', '{}',                        false),  -- Leval, Bakunin
    (2324, '0000127',       2528, 'MLEG-0071', '{}',                        false),  -- Prestes Motta
    (1099, 'BTL-TL-001175', 2574, 'MLEG-0117', '{titulo}',                  false),  -- Bakunin, Federalismo… (faute BTL)
    (1555, 'BTL-TL-001655', 2642, 'MLEG-0185', '{}',                        false),  -- Bookchin ; Boino
    (1026, 'BTL-TL-001100', 2560, 'MLEG-0103', '{}',                        false),  -- Cubero
    (1437, 'BTL-TL-001531', 2624, 'MLEG-0167', '{titulo}',                  false);  -- Home (titre MLEG)

  -- Toutes les notices doivent être là, sous la référence attendue ; sinon
  -- (banc d'essai, ou fusion déjà faite) on ne touche à rien.
  SELECT count(*) INTO v_n FROM paires_0810 x
    JOIN public.books c ON c.id = x.c AND c.bib_ref = x.c_ref
    JOIN public.books d ON d.id = x.d AND d.bib_ref = x.d_ref;
  IF v_n <> 25 THEN
    RAISE NOTICE 'Doublons du 08/10 : % paire(s) sur 25 présentes, rien à faire.', v_n;
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM public.book_drafts bd JOIN paires_0810 x ON bd.published_book_id IN (x.c, x.d) WHERE bd.status = 'draft') THEN
    RAISE EXCEPTION 'Doublons du 08/10 : un brouillon ouvert est apparu — relire avant de fusionner';
  END IF;
  IF ARRAY['titulo', 'editora', 'ano', 'local_publicacao'] && public.fn_dedup_non_transferable_fields() THEN
    RAISE EXCEPTION 'Doublons du 08/10 : un champ choisi est devenu non reprenable';
  END IF;

  -- La session de Xavier, à sa demande (voir l'en-tête), le temps de la transaction.
  PERFORM set_config('request.jwt.claims', '{"sub":"d6710372-e5e5-4608-800b-99a26817c677","role":"authenticated"}', true);

  FOR p IN SELECT * FROM paires_0810 ORDER BY c LOOP
    -- Un fonds sans référence locale (MLEG) garde la cote de la notice qui disparaît.
    UPDATE public.book_holdings h SET local_bib_ref = p.d_ref
     WHERE h.book_id = p.d AND nullif(btrim(h.local_bib_ref), '') IS NULL;
    r := public.fn_fusion_notices(p.c, p.d, p.champs, p.vides);
    v_total := v_total + 1;
    RAISE NOTICE 'Doublons du 08/10 : % ← % (%) : %', p.c_ref, p.d_ref, p.d, r;
  END LOOP;

  UPDATE public.books SET editora = 'Editora Imaginário' WHERE id = 572 AND editora = 'Edirora Imaginário';

  PERFORM set_config('request.jwt.claims', '', true);

  -- Vérification
  IF v_total <> 25 OR EXISTS (SELECT 1 FROM public.books b JOIN paires_0810 x ON x.d = b.id) THEN
    RAISE EXCEPTION 'Doublons du 08/10 : un doublon subsiste';
  END IF;
  SELECT count(*) INTO v_n
    FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id JOIN public.books b ON b.id = h.book_id
   WHERE e.bib_ref IS DISTINCT FROM coalesce(nullif(btrim(h.local_bib_ref), ''), b.bib_ref);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'Doublons du 08/10 : % exemplaire(s) dont la référence ne suit pas son fonds', v_n;
  END IF;
  -- Chaque notice gardée porte au moins deux exemplaires (ceux des deux côtés).
  SELECT count(*) INTO v_n FROM paires_0810 x
   WHERE (SELECT count(*) FROM public.exemplares e JOIN public.book_holdings h ON h.id = e.holding_id WHERE h.book_id = x.c) < 2;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'Doublons du 08/10 : % notice(s) gardée(s) sans ses deux exemplaires', v_n;
  END IF;
  IF (SELECT titulo FROM public.books WHERE id = 1099) <> 'Federalismo, Socialismo, Antiteologismo'
     OR (SELECT ano FROM public.books WHERE id = 1859) IS DISTINCT FROM '2005'
     OR (SELECT editora FROM public.books WHERE id = 572) <> 'Editora Imaginário' THEN
    RAISE EXCEPTION 'Doublons du 08/10 : champs choisis non repris';
  END IF;
END $$;

COMMIT;
