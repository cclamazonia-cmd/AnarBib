-- =========================================================================
-- H10 — relecture, fiche par fiche, des alignements FICEDL (26/09/2026)
-- =========================================================================
-- Réf. : backlog v34 H10 ; REGISTRE §30 THES-FIC4 ; CONV-EXEC-3 (jamais de
--        passe automatique) ; fiche de relecture
--        docs/journal/arbitrages/RELECTURE_alignements_ficedl_2026-09-26.md
--        (chaque ligne numérotée ci-dessous y porte sa raison).
--
-- Jusqu'au 07/09, match_type n'avait que exact/close : 54 liens étaient tassés
-- en `close`, qui dit « presque le même concept » — faux dès que le sujet local
-- est plus étroit ou plus large, et publié dans l'export SKOS. H9 (25/09) a
-- ouvert les cinq relations. Les 99 liens relevés le 26/09 ont été relus un par
-- un ; Xavier a validé la fiche en bloc le 26/09. Cette migration applique :
--   * 51 changements (45 `close`, 6 `exact` trop affirmés) ;
--   *  9 `close` confirmés, écrits ici pour que la vérification les tienne ;
--   * 11 alignements nouveaux : 8 vers la facette `dates` (les rubriques
--     historiques n'en avaient aucun), 3 vers de meilleures cibles.
-- Les 38 autres `exact` sont confirmés sans changement (fiche, § B).
--
-- Clé : (slug du sujet, mot_id), jamais l'id — le banc de la CI n'a pas ces
-- sujets, et un id y désignerait autre chose. Un lien n'est modifié que s'il
-- porte encore la relation relevée le 26/09 : si quelqu'un l'a changé entre
-- temps, la migration ne l'écrase pas, et la vérification le dit.
-- Sur une base sans ces sujets (banc), rien n'est touché et la vérification
-- le constate sans lever.
-- =========================================================================

BEGIN;

CREATE TEMP TABLE h10_decisions (num text, slug text, mot_id text, avant text, apres text) ON COMMIT DROP;
INSERT INTO h10_decisions VALUES
  -- A. Les 54 `close` — devenir « plus large » (le descripteur englobe le sujet)
  ('1',  'anarcofeminismo',            'mot122', 'close', 'broad'),
  ('2',  'anarchisme-social',          'mot8',   'close', 'broad'),
  ('3',  'anarco-punk',                'mot27',  'close', 'broad'),
  ('4',  'antifascismo',               'mot119', 'close', 'broad'),
  ('5',  'arte-e-militancia',          'mot17',  'close', 'broad'),
  ('6',  'cabanagem',                  'mot313', 'close', 'broad'),
  ('7',  'anarcocomunismo',            'mot8',   'close', 'broad'),
  ('8',  'contracultura',              'mot71',  'close', 'broad'),
  ('9',  'ecologia-social',            'mot87',  'close', 'broad'),
  ('10', 'educacao-libertaria',        'mot104', 'close', 'broad'),
  ('11', 'especifismo',                'mot199', 'close', 'broad'),
  ('12', 'mulheres-anarquistas',       'mot123', 'close', 'broad'),
  ('13', 'ficcao',                     'mot166', 'close', 'broad'),
  ('14', 'makhnovtchina',              'mot403', 'close', 'broad'),
  ('15', 'movimento-comunitario',      'mot192', 'close', 'broad'),
  ('16', 'revolucao-sexual',           'mot261', 'close', 'broad'),
  ('17', 'solidaires-amerique-du-nord','mot412', 'close', 'broad'),
  ('18', 'solidaires-homosexualites-lgbtqi', 'mot261', 'close', 'broad'),
  ('19', 'solidaires-mai-juin-1936',   'mot343', 'close', 'broad'),
  -- A. — devenir « plus étroit » (rubriques composites, plus larges que le descripteur)
  ('20', 'solidaires-anticolonialisme-antiracisme-migrations', 'mot48',  'close', 'narrow'),
  ('21', 'solidaires-anticolonialisme-antiracisme-migrations', 'mot247', 'close', 'narrow'),
  ('22', 'solidaires-anticolonialisme-antiracisme-migrations', 'mot107', 'close', 'narrow'),
  ('23', 'solidaires-antifascisme-extreme-droite',             'mot117', 'close', 'narrow'),
  ('24', 'solidaires-bandes-dessinees-affiches-photos',        'mot168', 'close', 'narrow'),
  ('25', 'solidaires-bandes-dessinees-affiches-photos',        'mot20',  'close', 'narrow'),
  ('26', 'solidaires-bandes-dessinees-affiches-photos',        'mot29',  'close', 'narrow'),
  ('27', 'solidaires-histoire-du-mouvement-ouvrier-syndicalisme', 'mot271', 'close', 'narrow'),
  ('28', 'solidaires-moyen-orient-proche-orient-palestine',    'mot354', 'close', 'narrow'),
  ('29', 'solidaires-moyen-orient-proche-orient-palestine',    'mot378', 'close', 'narrow'),
  ('30', 'solidaires-repression-justice-prison',               'mot235', 'close', 'narrow'),
  ('31', 'solidaires-repression-justice-prison',               'mot160', 'close', 'narrow'),
  ('32', 'solidaires-repression-justice-prison',               'mot250', 'close', 'narrow'),
  ('33', 'solidaires-revolution-espagnole-exil-antifranquisme','mot326', 'close', 'narrow'),
  ('34', 'solidaires-revolution-espagnole-exil-antifranquisme','mot327', 'close', 'narrow'),
  ('35', 'solidaires-romans-nouvelles-essais',                 'mot179', 'close', 'narrow'),
  ('36', 'solidaires-romans-nouvelles-essais',                 'mot175', 'close', 'narrow'),
  ('37', 'solidaires-romans-nouvelles-essais',                 'mot172', 'close', 'narrow'),
  ('38', 'solidaires-urss-pays-de-l-est-europen',              'mot492', 'close', 'narrow'),
  ('39', 'solidaires-urss-pays-de-l-est-europen',              'mot493', 'close', 'narrow'),
  ('40', 'solidaires-yiddishland-mouvements-juifs',            'mot159', 'close', 'narrow'),
  -- A. — devenir « associé » (lien réel, sans hiérarchie)
  ('41', 'abolicionismo-penal',        'mot235', 'close', 'related'),
  ('42', 'anticlericalismo',           'mot165', 'close', 'related'),
  ('43', 'questao-agraria',            'mot191', 'close', 'related'),
  ('44', 'reforma-urbana',             'mot281', 'close', 'related'),
  ('45', 'solidaires-revolution-allemande-conseillisme', 'mot299', 'close', 'related'),
  -- A. — rester « proche » (confirmés)
  ('46', 'anarquismo-individualista',  'mot153', 'close', 'close'),
  ('47', 'movimento-estudantil',       'mot115', 'close', 'close'),
  ('48', 'resistencia-ao-governo',     'mot75',  'close', 'close'),
  ('49', 'solidaires-ameriques-latine-et-centrale', 'mot307', 'close', 'close'),
  ('50', 'solidaires-antifascisme-extreme-droite',  'mot119', 'close', 'close'),
  ('51', 'solidaires-libertaires',     'mot8',   'close', 'close'),
  ('52', 'solidaires-mai-1968-annees-68', 'mot346', 'close', 'close'),
  ('53', 'solidaires-revolution-1789-revolution-juin-1848', 'mot335', 'close', 'close'),
  ('54', 'solidaires-yiddishland-mouvements-juifs', 'mot509', 'close', 'close'),
  -- B. Six `exact` trop affirmés
  ('55', 'antirracismo',               'mot247', 'exact', 'broad'),
  ('56', 'fascismo',                   'mot119', 'exact', 'broad'),
  ('57', 'mutualismo',                 'mot204', 'exact', 'broad'),
  ('58', 'revolucao-espanhola',        'mot326', 'exact', 'close'),
  ('59', 'revolucao-russa',            'mot494', 'exact', 'close'),
  ('60', 'solidaires-revolution-russe','mot494', 'exact', 'close'),
  -- C. Facette `dates` (nouveaux)
  ('C1a', 'solidaires-la-commune-1871', 'mot654', NULL, 'broad'),
  ('C1b', 'comuna-de-paris',            'mot654', NULL, 'broad'),
  ('C2',  'solidaires-mai-juin-1936',   'mot571', NULL, 'broad'),
  ('C3',  'solidaires-mai-1968-annees-68', 'mot603', NULL, 'related'),
  ('C4a', 'revolucao-russa',            'mot552', NULL, 'related'),
  ('C4b', 'solidaires-revolution-russe','mot552', NULL, 'related'),
  ('C5a', 'solidaires-revolution-allemande-conseillisme', 'mot553', NULL, 'related'),
  ('C5b', 'solidaires-revolution-allemande-conseillisme', 'mot554', NULL, 'related'),
  -- D. Meilleures cibles (nouveaux)
  ('D1',  'solidaires-moyen-orient-proche-orient-palestine', 'mot387', NULL, 'close'),
  ('D2',  'solidaires-revolution-allemande-conseillisme',    'mot300', NULL, 'close'),
  ('D3',  'solidaires-revolution-allemande-conseillisme',    'mot62',  NULL, 'narrow');

-- 1) Les relations relues — seulement là où le lien porte encore l'état relevé
UPDATE public.subject_ficedl_links l
   SET match_type = d.apres
  FROM h10_decisions d
  JOIN public.subjects s ON s.slug = d.slug
 WHERE d.avant IS NOT NULL
   AND d.avant <> d.apres
   AND l.subject_id = s.id
   AND l.mot_id = d.mot_id
   AND l.match_type = d.avant;

-- 2) Les alignements nouveaux (created_by nul : posés par migration, pas par une personne)
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type, created_by)
SELECT s.id, d.mot_id, d.apres, NULL
  FROM h10_decisions d
  JOIN public.subjects s ON s.slug = d.slug
  JOIN public.ficedl_thesaurus_terms t ON t.mot_id = d.mot_id
 WHERE d.avant IS NULL
ON CONFLICT (subject_id, mot_id) DO NOTHING;

-- 3) Vérification — chaque décision, une par une
DO $$
DECLARE
  v_total    int;
  v_presents int;
  v_ecarts   text;
  v_dates    int;
BEGIN
  SELECT count(*), count(s.id) INTO v_total, v_presents
    FROM h10_decisions d LEFT JOIN public.subjects s ON s.slug = d.slug;

  IF v_presents = 0 THEN
    RAISE NOTICE 'H10 : aucun des sujets relus dans cette base (banc) — rien à appliquer.';
    RETURN;
  END IF;
  IF v_presents <> v_total THEN
    RAISE EXCEPTION 'H10 : % sujets relus sur % présents — base partielle, on n''applique pas à moitié.', v_presents, v_total;
  END IF;

  SELECT string_agg(d.num || ' ' || d.slug || '→' || d.mot_id || ' = ' || coalesce(l.match_type, 'absent') || ' (voulu ' || d.apres || ')', ' ; ' ORDER BY d.num)
    INTO v_ecarts
    FROM h10_decisions d
    JOIN public.subjects s ON s.slug = d.slug
    LEFT JOIN public.subject_ficedl_links l ON l.subject_id = s.id AND l.mot_id = d.mot_id
   WHERE l.match_type IS DISTINCT FROM d.apres;
  IF v_ecarts IS NOT NULL THEN
    RAISE EXCEPTION 'H10 : décisions non tenues : %', v_ecarts;
  END IF;

  SELECT count(*) INTO v_dates
    FROM public.subject_ficedl_links l JOIN public.ficedl_thesaurus_terms t ON t.mot_id = l.mot_id
   WHERE 'dates' = ANY (t.facet);
  IF v_dates < 8 THEN
    RAISE EXCEPTION 'H10 : % alignement(s) vers la facette dates, 8 attendus au moins.', v_dates;
  END IF;

  RAISE NOTICE 'H10 : % décisions tenues, % alignements vers dates.', v_total, v_dates;
END $$;

COMMIT;
