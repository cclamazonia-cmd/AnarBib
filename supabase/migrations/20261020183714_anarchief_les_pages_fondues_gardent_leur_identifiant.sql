-- =========================================================================
-- Anarchief.org — les pages fondues gardent leur identifiant d'origine sur
-- la notice qui les absorbe
-- =========================================================================
-- Date     : 2026-10-20
-- Chantier : sources partenaires — Anarchief.org (bibliothèque source)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — les 17 pages en doublon (reprise du 20/10)
-- Ref      : 20261019190037 (pages fondues le 19/10) ;
--            20261020182804_anarchief_stellingen_et_theorie_selon_l_archiviste
--            (pages fondues le 20/10, lot 69) ; réponses de J/M des 19 et
--            20/10/2026
--
-- POURQUOI
--   Cinq pages du wiki n'ont pas de notice à elles : leur document est
--   décrit par une autre page (réponses de l'archiviste). Leur identifiant
--   d'import (book_external_ids, schéma import:33 = id de page du wiki) se
--   pose sur la notice qui les absorbe : un prochain import ou moissonnage
--   du wiki les reconnaîtra au lieu d'en refaire des nouveautés.
--     3297 → ANARCHIEF-2982   (De zwarte revolutie in de jaren '90)
--     4605 → ANARCHIEF-2762   (La fin de la guerre)
--     3898 → ANARCHIEF-1917   (Werk zat)
--     1164 → ANARCHIEF-2962   (Stellingen ; page supprimée du wiki)
--      322 → ANARCHIEF-3027   (Theorie en praktijk)
--   L'unicité est (bibliothèque, schéma, valeur) : une notice peut porter
--   plusieurs valeurs. Le lien vers le wiki des notices sans PDF est déjà
--   posé (20261020182804) : private.fn_lien_vers_la_page_source, qui
--   prendrait la plus petite valeur, ne sert pas ici.
--
-- CE QUE FAIT LE PAQUET (donnée seule)
--   ingest.fn_record_book_external_id(notice, Anarchief.Org, 33, page fondue)
--   — la fonction de la publication (ON CONFLICT DO NOTHING).
--   Compte gardé : 0 notice trouvée (banc, ou lot 69 pas encore publié :
--   rien) ou 5 ; sinon échec. À pousser APRÈS la publication du lot 69.
--
-- CHECKLIST DOCTRINE
--   [x] Aucun objet nouveau ; INSERT de lignes via la fonction existante
--   [x] Liste fermée (clé retenue → clé fondue), bibliothèque par uuid
--   [x] Aucun nom de lieu lié à l'archiviste (règle du 19/10/2026)
-- =========================================================================

BEGIN;

DO $fondues$
DECLARE
  c_lib constant uuid := '1bb157fd-4d1f-415b-9e5d-490f4f8d0895';   -- Anarchief.Org
  v_trouvees int;
  v_n int;
  r record;
  c_gardees constant text[] := ARRAY['2982', '2762', '1917', '2962', '3027'];
  c_fondues constant text[] := ARRAY['3297', '4605', '3898', '1164', '322'];
BEGIN

  SELECT count(*) INTO v_trouvees
    FROM unnest(c_gardees, c_fondues) AS f(gardee, fondue)
    JOIN public.book_external_ids e ON e.library_id = c_lib AND e.scheme = 'import:33' AND e.value = f.gardee
    JOIN public.books b ON b.id = e.book_id AND b.bib_ref = 'ANARCHIEF-' || f.gardee;

  IF v_trouvees = 0 THEN
    RAISE NOTICE 'Pages fondues d''Anarchief : notices absentes (banc ou lot 69 non publié), rien à faire';
    RETURN;
  END IF;
  IF v_trouvees <> 5 THEN
    RAISE EXCEPTION 'Pages fondues d''Anarchief : % notice(s) retenue(s) trouvée(s), 5 attendues', v_trouvees;
  END IF;

  -- Une page fondue déjà portée par une AUTRE notice serait un conflit muet
  -- (ON CONFLICT DO NOTHING) : on le refuse.
  SELECT count(*) INTO v_n
    FROM unnest(c_gardees, c_fondues) AS f(gardee, fondue)
    JOIN public.book_external_ids e ON e.library_id = c_lib AND e.scheme = 'import:33' AND e.value = f.fondue
    JOIN public.book_external_ids g ON g.library_id = c_lib AND g.scheme = 'import:33' AND g.value = f.gardee
   WHERE e.book_id <> g.book_id;
  IF v_n > 0 THEN
    RAISE EXCEPTION 'Pages fondues d''Anarchief : % page(s) fondue(s) déjà portée(s) par une autre notice', v_n;
  END IF;

  FOR r IN
    SELECT e.book_id, f.fondue
      FROM unnest(c_gardees, c_fondues) AS f(gardee, fondue)
      JOIN public.book_external_ids e ON e.library_id = c_lib AND e.scheme = 'import:33' AND e.value = f.gardee
  LOOP
    PERFORM ingest.fn_record_book_external_id(r.book_id, c_lib, 33, r.fondue);
  END LOOP;

  SELECT count(*) INTO v_n
    FROM unnest(c_gardees, c_fondues) AS f(gardee, fondue)
    JOIN public.book_external_ids e ON e.library_id = c_lib AND e.scheme = 'import:33' AND e.value = f.fondue
    JOIN public.book_external_ids g ON g.library_id = c_lib AND g.scheme = 'import:33' AND g.value = f.gardee
   WHERE e.book_id = g.book_id;
  IF v_n <> 5 THEN
    RAISE EXCEPTION 'Pages fondues d''Anarchief : % identifiant(s) en place, 5 attendus', v_n;
  END IF;
  RAISE NOTICE 'Pages fondues d''Anarchief : 5 identifiants import:33 posés sur leur notice';
END
$fondues$;

COMMIT;
