-- =========================================================================
-- Anarchief.org — les pages « en doublon » tranchées par l'archiviste :
-- onze deviennent des nouveautés, quatre sont fondues dans une autre
-- =========================================================================
-- Date     : 2026-10-19
-- Chantier : sources partenaires — Anarchief.org (bibliothèque source)
-- Auteur   : Claude (assistant·e), pour la coordination
-- Session  : Anarchief — les 17 pages en doublon
-- Ref      : réponse de J/M du 19/10/2026 (mail) ; tableau du point 5 de
--            REPONSE_anarchief_commune_nom_lots_doublons_2026-10-19.md et
--            PROPOSITION_doublons_anarchief_2026-10-19.md (hors dépôt,
--            dossier de la coordination) ; décision de Xavier du 19/10/2026
--            (« 11 notices, Conquête du pain comprise, Werk zat sur 1917 »)
--
-- POURQUOI
--   Le run d'import 33 (wiki anarchief.org, source de dépôt 33) a laissé 17
--   lignes en « doublon possible » le 15/10 : 16 pages du wiki au même titre
--   (doublons internes, intra_run_duplicate) et « La conquête du pain »,
--   rapprochée d'un brouillon d'une AUTRE bibliothèque. Rien n'a été promu.
--   L'archiviste a répondu le 19/10 :
--     Bakoenin, Brief … aan Herzen en Ogareff   : trois lettres, trois notices ;
--     Figner, Nacht over Rusland               : trois parties, trois notices ;
--     De zwarte revolutie in de jaren '90      : une notice, la page 2982 (texte,
--                                                et le PDF qu'il y a lié le 19/10) ;
--     Ernestan, La fin de la guerre (1938)     : une notice, deux scans ;
--     Stellingen over libertair municipalisme  : une notice pour l'instant ;
--     De Vieze Gasten, Werk zat                : une notice, deux scans ;
--     Kropotkin, Theorie en praktijk           : question en attente — RIEN ici.
--   « La conquête du pain » n'est pas un doublon d'Anarchief : le brouillon
--   rapproché (5951) appartient à une autre bibliothèque. Notice propre.
--
--   L'écran Importations ne sait pas promouvoir un « doublon possible » comme
--   nouveauté : « Accepté (nouveau) » n'est permis qu'aux lignes new_record
--   (ingest.fn_is_editorial_decision_compatible), et pour un doublon l'écran
--   n'offre que « Rapprocher » (il faut une notice proposée) ou « Rejeter ».
--   La décision de l'archiviste se pose donc ici, sur les lignes ; le geste
--   de promotion reste humain, à l'écran.
--
-- CE QUE FAIT LE PAQUET (donnée seule, run 33)
--   1. Onze lignes : possible_duplicate → new_record ; décision éditoriale
--      laissée « en attente » (la coordination accepte et crée les brouillons
--      à l'écran) ; la suggestion de rapprochement de « La conquête du pain »
--      (brouillon 5951) est retirée ; sous-titre qui distingue chaque lettre
--      de Bakoenin et chaque partie de Figner (texte des pages du wiki),
--      volume 1/2/3 pour Figner ; trace « doublon_tranche » dans warnings.
--   2. Quatre lignes : rejetées, note « fondue dans ANARCHIEF-<page> » —
--      3297 → 2982, 4605 → 2762, 2962 → 1164, 3898 → 1917. Leur PDF sera
--      rattaché à la notice qui les absorbe (file NUMDIF, plus tard).
--   3. 322 et 3027 (Theorie en praktijk) : intouchées.
--   4. Compteurs du run recalculés (ingest.fn_refresh_partner_catalog_run_counters).
--   Compte gardé : 0 (banc, le run 33 n'existe pas) ou 15 (production),
--   sinon échec. Critère : id de ligne ET clé ET run ET état du 15/10
--   (possible_duplicate, en attente, sans brouillon).
--
-- CHECKLIST DOCTRINE
--   [x] Aucun objet nouveau ; UPDATE de lignes de staging, sans verrou exclusif
--   [x] Liste fermée (id + clé), compte gardé IN (0, 15)
--   [x] Aucun nom de lieu lié à l'archiviste (règle du 19/10/2026)
-- =========================================================================

BEGIN;

DO $doublons$
DECLARE
  v_attendues int;
  v_n int;
  v_m int;
BEGIN
  CREATE TEMP TABLE _doublons_anarchief (
    ligne      bigint PRIMARY KEY,
    cle        text   NOT NULL,
    geste      text   NOT NULL CHECK (geste IN ('nouveaute', 'fondue')),
    sous_titre text,
    volume     text,
    dans       text            -- page qui absorbe une page fondue
  ) ON COMMIT DROP;

  INSERT INTO _doublons_anarchief (ligne, cle, geste, sous_titre, volume, dans) VALUES
    -- Bakoenin : trois lettres (date et lieu en tête de chaque lettre, sur le wiki)
    (8798, '234',  'nouveaute', '1861 - 1',                      NULL, NULL),
    (8800, '240',  'nouveaute', 'San Francisco, 3 oktober 1861', NULL, NULL),
    (8799, '237',  'nouveaute', 'Stockholm, 17 augustus 1863',   NULL, NULL),
    -- Figner : trois parties (titres des pages du wiki)
    (8881, '570',  'nouveaute', 'Deel 1: Vrijheid of dood',          '1', NULL),
    (8882, '572',  'nouveaute', 'Deel 2: 20 jaar in de Kazematten',  '2', NULL),
    (8883, '574',  'nouveaute', 'Deel 3: Terug in de wereld',        '3', NULL),
    -- Une notice par groupe : la page désignée (2982), sinon la plus ancienne
    (9362, '2982', 'nouveaute', NULL, NULL, NULL),
    (9290, '2762', 'nouveaute', NULL, NULL, NULL),
    (8966, '1164', 'nouveaute', NULL, NULL, NULL),
    (9138, '1917', 'nouveaute', NULL, NULL, NULL),
    -- La conquête du pain : notice propre d'Anarchief
    (8889, '591',  'nouveaute', NULL, NULL, NULL),
    -- Pages fondues
    (9489, '3297', 'fondue', NULL, NULL, '2982'),
    (9705, '4605', 'fondue', NULL, NULL, '2762'),
    (9345, '2962', 'fondue', NULL, NULL, '1164'),
    (9601, '3898', 'fondue', NULL, NULL, '1917');

  SELECT count(*) INTO v_attendues FROM _doublons_anarchief;

  SELECT count(*) INTO v_n
    FROM ingest.partner_catalog_staging_rows sr
    JOIN _doublons_anarchief d ON d.ligne = sr.id AND d.cle = sr.external_key
   WHERE sr.run_id = 33
     AND sr.match_status = 'possible_duplicate'
     AND sr.editorial_decision = 'pending'
     AND sr.created_book_draft_id IS NULL
     AND sr.created_exemplar_draft_id IS NULL
     AND sr.discarded_draft_id IS NULL;

  IF v_n NOT IN (0, v_attendues) THEN
    RAISE EXCEPTION 'Doublons Anarchief : % ligne(s) au critère (0 ou % attendues)', v_n, v_attendues;
  END IF;

  IF v_n = 0 THEN
    RAISE NOTICE 'Doublons Anarchief : run 33 absent ou déjà traité, rien à faire';
    RETURN;
  END IF;

  -- 1. Les nouveautés
  UPDATE ingest.partner_catalog_staging_rows sr
     SET match_status = 'new_record',
         proposed_book_id = NULL,
         proposed_book_draft_id = NULL,
         confidence = 0,
         subtitle = coalesce(d.sous_titre, sr.subtitle),
         normalized_payload = CASE
           WHEN d.volume IS NULL THEN sr.normalized_payload
           ELSE coalesce(sr.normalized_payload, '{}'::jsonb) || jsonb_build_object('volume', d.volume)
         END,
         warnings = coalesce(sr.warnings, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'kind', 'doublon_tranche',
           'geste', 'nouveaute',
           'motif', CASE WHEN d.cle = '591'
                         THEN 'Rapprochée d''un brouillon d''une autre bibliothèque (5951) : notice propre d''Anarchief.Org (décision de la coordination du 19/10/2026).'
                         ELSE 'Page distincte d''après l''archiviste (réponse de J/M du 19/10/2026).' END,
           'avant', jsonb_build_object('match_status', sr.match_status,
                                       'proposed_book_draft_id', sr.proposed_book_draft_id,
                                       'confidence', sr.confidence),
           'le', '2026-10-19'))
    FROM _doublons_anarchief d
   WHERE d.ligne = sr.id AND d.cle = sr.external_key AND d.geste = 'nouveaute'
     AND sr.run_id = 33 AND sr.match_status = 'possible_duplicate'
     AND sr.editorial_decision = 'pending' AND sr.created_book_draft_id IS NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;

  -- 2. Les pages fondues
  UPDATE ingest.partner_catalog_staging_rows sr
     SET editorial_decision = 'reject',
         review_status = 'rejected',
         selected_for_draft = false,
         editorial_note = 'Fondue dans ANARCHIEF-' || d.dans || ' : même document, une seule notice (réponse de J/M du 19/10/2026). Son fichier rejoint cette notice.',
         editorial_decided_at = now(),
         warnings = coalesce(sr.warnings, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
           'kind', 'doublon_tranche',
           'geste', 'fondue',
           'dans', d.dans,
           'le', '2026-10-19'))
    FROM _doublons_anarchief d
   WHERE d.ligne = sr.id AND d.cle = sr.external_key AND d.geste = 'fondue'
     AND sr.run_id = 33 AND sr.match_status = 'possible_duplicate'
     AND sr.editorial_decision = 'pending' AND sr.created_book_draft_id IS NULL;
  GET DIAGNOSTICS v_m = ROW_COUNT;

  IF v_n <> 11 OR v_m <> 4 THEN
    RAISE EXCEPTION 'Doublons Anarchief : % nouveauté(s) (11 attendues), % fondue(s) (4 attendues)', v_n, v_m;
  END IF;

  PERFORM ingest.fn_refresh_partner_catalog_run_counters(33);

  RAISE NOTICE 'Doublons Anarchief : % nouveautés, % pages fondues ; Theorie en praktijk (322, 3027) en attente', v_n, v_m;
END
$doublons$;

COMMIT;

-- =========================================================================
-- Suite (hors de ce paquet) : la coordination accepte les onze nouveautés et
-- crée leurs brouillons à l'écran Importations ; cotes ANARCHIEF-<page>
-- posées ensuite par migration (jamais « Attribuer les cotes » : la
-- numérotation automatique de la bibliothèque donnerait d'autres numéros).
-- Retour : la trace « avant » de warnings rend match_status, la suggestion
-- de rapprochement et la confiance ; décision éditoriale à remettre en attente.
-- =========================================================================
