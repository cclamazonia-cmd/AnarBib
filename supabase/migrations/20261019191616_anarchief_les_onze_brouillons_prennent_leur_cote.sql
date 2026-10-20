-- =========================================================================
-- Anarchief.org — les onze brouillons tirés des pages en doublon prennent
-- leur cote ANARCHIEF-<page>
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : sources partenaires — Anarchief.org (bibliothèque source)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — les 17 pages en doublon
-- Ref      : 20261019190037_anarchief_les_doublons_tranches_par_l_archiviste
--            (les onze lignes requalifiées) ; brouillons créés à l'écran
--            Importations par la coordination
--
-- POURQUOI
--   Les 1 002 notices d'Anarchief.Org ont pour cote ANARCHIEF-<page_id> du
--   wiki (posée le 15/10), stable et égale à la clé d'import. La
--   numérotation automatique de la bibliothèque (préfixe ANARCHIEF-, cinq
--   chiffres) donnerait aux onze nouveaux brouillons des numéros sans lien
--   avec leur page : « Attribuer les cotes » ne doit PAS servir ici.
--
-- CE QUE FAIT LE PAQUET (donnée seule)
--   bib_ref = 'ANARCHIEF-' || clé de la ligne, sur les brouillons non
--   publiés créés depuis les onze lignes du run 33. Refus si une de ces
--   cotes existe déjà (notice ou autre brouillon). Compte : 0 si le run 33
--   n'existe pas (banc) ; 11 exactement sinon — un nombre différent veut dire
--   que les brouillons ne sont pas (tous) créés : échec plutôt qu'un
--   « appliqué » vide.
--
-- CHECKLIST DOCTRINE
--   [x] Aucun objet nouveau ; UPDATE de lignes, sans verrou exclusif
--   [x] Liste fermée (id de ligne + clé) ; unicité des cotes vérifiée
-- =========================================================================

BEGIN;

DO $cotes$
DECLARE
  c_lignes constant bigint[] := ARRAY[8798, 8800, 8799, 8881, 8882, 8883, 9362, 9290, 8966, 9138, 8889];
  c_cles   constant text[]   := ARRAY['234', '240', '237', '570', '572', '574', '2982', '2762', '1164', '1917', '591'];
  v_n int;
  v_pris int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = 33) THEN
    RAISE NOTICE 'Cotes Anarchief : run 33 absent (banc), rien à faire';
    RETURN;
  END IF;

  SELECT count(*) INTO v_n
    FROM ingest.partner_catalog_staging_rows sr
    JOIN public.book_drafts d ON d.id = sr.created_book_draft_id
   WHERE sr.run_id = 33
     AND sr.id = ANY (c_lignes)
     AND sr.external_key = c_cles[array_position(c_lignes, sr.id)]
     AND sr.match_status = 'new_record'
     AND d.status IS DISTINCT FROM 'published'
     AND d.published_book_id IS NULL;
  IF v_n <> 11 THEN
    RAISE EXCEPTION 'Cotes Anarchief : % brouillon(s) non publié(s) issus des onze lignes (11 attendus)', v_n;
  END IF;

  SELECT count(*) INTO v_pris
    FROM unnest(c_cles) k
   WHERE EXISTS (SELECT 1 FROM public.books b WHERE b.bib_ref = 'ANARCHIEF-' || k)
      OR EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.bib_ref = 'ANARCHIEF-' || k);
  IF v_pris > 0 THEN
    RAISE EXCEPTION 'Cotes Anarchief : % cote(s) ANARCHIEF-<page> déjà prise(s)', v_pris;
  END IF;

  UPDATE public.book_drafts d
     SET bib_ref = 'ANARCHIEF-' || sr.external_key,
         updated_at = now()
    FROM ingest.partner_catalog_staging_rows sr
   WHERE d.id = sr.created_book_draft_id
     AND sr.run_id = 33
     AND sr.id = ANY (c_lignes)
     AND sr.external_key = c_cles[array_position(c_lignes, sr.id)]
     AND d.status IS DISTINCT FROM 'published'
     AND d.published_book_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 11 THEN
    RAISE EXCEPTION 'Cotes Anarchief : % cote(s) posée(s), 11 attendues', v_n;
  END IF;
  RAISE NOTICE 'Cotes Anarchief : % cotes ANARCHIEF-<page> posées', v_n;
END
$cotes$;

COMMIT;
