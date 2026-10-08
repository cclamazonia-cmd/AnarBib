-- =====================================================================
-- AnarBib -- Acción directa anarquista (Mechoso, Recortes) : les tomes posés
--            d'après la table des matières de la série, sur les notices BTL et MLEG
-- Date     : 2026-10-08  ·  Décision de Xavier (table des matières fournie le soir)
-- Dépend   : 20260904170000 (books.volume, fn_volume_rank), OPAC-OEU6 (un tome =
--            une notice dans l'œuvre, jamais posé par script : ici une décision
--            nominative, notice par notice)
--
-- CONSTAT (prod, 08/10). L'œuvre 38 porte sept notices : quatre BTL numérotées
-- 1 à 4 le 04/09 (lot 4, ordre deviné), trois MLEG sans tome mais dont le titre
-- dit « Tomo II - La Fundación », « Tomo III - Los Primeros Años », « Tomo IV ».
-- La série (Juan C. Mechoso, Editorial Recortes, Montevideo) compte quatre
-- tomes : I Raíces (1870-1940), II La Fundación (1956-1957), III Los primeros
-- años (1957-1964), IV Resistencia y confrontación (1965-1973). La numérotation
-- BTL était décalée d'un cran : son « tome 1 » est La Fundación (II), son
-- « tome 2 » Los primeros años (III).
--
-- CE QUI EST POSÉ (books.volume, chiffres arabes comme sur l'œuvre 16)
--   · 369  BTL-TL-000390  « La Fundación »            : 1 → 2
--   · 368  BTL-TL-000389  « Los primeros años » 2006  : 2 → 3
--   · 370  BTL-TL-000391  « : volume 3 » 2006         : 3 (la fiche Zotero de la
--          BTL dit « volume 3 » elle-même ; deuxième exemplaire du tome III ?
--          à confirmer livre en main)
--   · 375  BTL-TL-000396  sans sous-titre, sans date  : 4, inchangé (posé le 04/09,
--          non vérifié : I ou IV, livre en main)
--   · 2492 MLEG-0035 « Tomo II »  : 2 ; 2493 MLEG-0036 « Tomo III » : 3 ;
--     2494 MLEG-0037 « Tomo IV » : 4.
-- Aucune fusion ici : les paires II et III (BTL / MLEG, même édition) sortent
-- désormais dans l'assistant, à trancher à l'écran.
-- Joué à blanc en production le 08/10 (transaction annulée).
-- Sur une base sans ces notices (banc d'essai), rien n'est fait.
-- =====================================================================

BEGIN;

DO $$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM public.books b
   WHERE b.work_id = 38 AND (b.id, b.bib_ref) IN ((369,'BTL-TL-000390'),(368,'BTL-TL-000389'),(370,'BTL-TL-000391'),(375,'BTL-TL-000396'),
                                                   (2492,'MLEG-0035'),(2493,'MLEG-0036'),(2494,'MLEG-0037'));
  IF v_n <> 7 THEN
    RAISE NOTICE 'Acción directa anarquista : % notice(s) sur 7, rien à faire.', v_n;
    RETURN;
  END IF;

  -- La session de Xavier, dont c'est la décision, le temps de la transaction.
  PERFORM set_config('request.jwt.claims', '{"sub":"d6710372-e5e5-4608-800b-99a26817c677","role":"authenticated"}', true);
  UPDATE public.books SET volume = v.vol
    FROM (VALUES (369,'2'),(368,'3'),(370,'3'),(2492,'2'),(2493,'3'),(2494,'4')) v(id, vol)
   WHERE books.id = v.id AND books.work_id = 38 AND books.volume IS DISTINCT FROM v.vol;
  PERFORM set_config('request.jwt.claims', '', true);

  -- Vérification : chaque tome a son rang, I n'est posé nulle part, IV deux fois (BTL, MLEG).
  IF (SELECT string_agg(coalesce(public.fn_volume_rank(b.volume)::text, '-'), ',' ORDER BY b.id)
        FROM public.books b WHERE b.id IN (368,369,370,375,2492,2493,2494)) <> '3,2,3,4,2,3,4' THEN
    RAISE EXCEPTION 'Acción directa anarquista : les tomes posés ne sont pas ceux attendus';
  END IF;
END $$;

COMMIT;
