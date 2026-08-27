-- Sujets « Bibliotheque Solidaires » + alignement sur le thesaurus FICEDL
-- Lot d'essai. Les libelles sont ceux du collectif, non retraduits.
-- Statut 'proposto' : rien n'est publie, rien n'est active.
BEGIN;

-- 1. Les 35 rubriques deviennent des sujets, en francais uniquement :
--    ce sont leurs mots, nous n'inventons pas de traductions.
INSERT INTO public.subjects (slug, label_i18n, status, scope_note)
VALUES
  ('solidaires-histoire-du-mouvement-ouvrier-syndicalisme', jsonb_build_object('fr', 'Histoire du mouvement ouvrier, syndicalisme'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-ecologie', jsonb_build_object('fr', 'Ecologie'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-feminisme', jsonb_build_object('fr', 'Féminisme'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-economie', jsonb_build_object('fr', 'Economie'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-homosexualites-lgbtqi', jsonb_build_object('fr', 'Homosexualités, LGBTQI'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-anticolonialisme-antiracisme-migrations', jsonb_build_object('fr', 'Anticolonialisme, antiracisme, migrations'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-antifascisme-extreme-droite', jsonb_build_object('fr', 'Antifascisme, extrême droite'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-antimilitarisme', jsonb_build_object('fr', 'Antimilitarisme'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-repression-justice-prison', jsonb_build_object('fr', 'Répression - Justice - Prison'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-education', jsonb_build_object('fr', 'Education'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-bandes-dessinees-affiches-photos', jsonb_build_object('fr', 'Bandes dessinées, affiches, photos'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-jeunesse', jsonb_build_object('fr', 'Jeunesse'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-afrique', jsonb_build_object('fr', 'Afrique'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-amerique-du-nord', jsonb_build_object('fr', 'Amérique du nord'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-ameriques-latine-et-centrale', jsonb_build_object('fr', 'Amériques latine et centrale'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-asie', jsonb_build_object('fr', 'Asie'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-europe', jsonb_build_object('fr', 'Europe'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-moyen-orient-proche-orient-palestine', jsonb_build_object('fr', 'Moyen-Orient, Proche-Orient, Palestine'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-urss-pays-de-l-est-europen', jsonb_build_object('fr', 'URSS - Pays de l''Est europen'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-yiddishland-mouvements-juifs', jsonb_build_object('fr', 'Yiddishland - Mouvements juifs'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-revolution-1789-revolution-juin-1848', jsonb_build_object('fr', 'Révolution 1789 - Révolution Juin 1848'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-la-commune-1871', jsonb_build_object('fr', 'La Commune 1871'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-revolution-russe', jsonb_build_object('fr', 'Révolution russe'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-revolution-allemande-conseillisme', jsonb_build_object('fr', 'Révolution allemande - Conseillisme'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-mai-juin-1936', jsonb_build_object('fr', 'Mai-Juin 1936'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-revolution-espagnole-exil-antifranquisme', jsonb_build_object('fr', 'Révolution espagnole, exil, antifranquisme'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-deuxieme-guerre-mondiale', jsonb_build_object('fr', 'Deuxième guerre mondiale'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-mai-1968-annees-68', jsonb_build_object('fr', 'Mai 1968, années 68'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-marxisme', jsonb_build_object('fr', 'Marxisme'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-libertaires', jsonb_build_object('fr', 'Libertaires'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-religions', jsonb_build_object('fr', 'Religions'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-sociologie', jsonb_build_object('fr', 'Sociologie'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-sport', jsonb_build_object('fr', 'Sport'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-romans-nouvelles-essais', jsonb_build_object('fr', 'Romans, nouvelles, essais'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.'),
  ('solidaires-divers', jsonb_build_object('fr', 'Divers'), 'proposto', 'Rubrique du listing de la Bibliotheque Solidaires (lot d''essai 2026). Libelle d''origine conserve.')
ON CONFLICT (slug) DO NOTHING;

-- 2. Alignement sur les descripteurs FICEDL (skos:exactMatch / skos:closeMatch).
--    Les correspondances larges passent en 'close' : la contrainte n'admet
--    que 'exact' et 'close'.

-- Histoire du mouvement ouvrier, syndicalisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot271', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-histoire-du-mouvement-ouvrier-syndicalisme'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- syndicalisme

-- Ecologie
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot87', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-ecologie'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- écologie

-- Féminisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot122', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-feminisme'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- féminisme

-- Economie
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot88', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-economie'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- économie (généralités)

-- Homosexualités, LGBTQI
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot261', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-homosexualites-lgbtqi'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- sexualité et genre

-- Anticolonialisme, antiracisme, migrations
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot48', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-anticolonialisme-antiracisme-migrations'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- colonialisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot247', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-anticolonialisme-antiracisme-migrations'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- racisme et antiracisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot107', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-anticolonialisme-antiracisme-migrations'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- émigration et immigration

-- Antifascisme, extrême droite
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot119', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-antifascisme-extreme-droite'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- fascisme et antifascisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot117', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-antifascisme-extreme-droite'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- extrême-droite

-- Antimilitarisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot11', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-antimilitarisme'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- antimilitarisme

-- Répression - Justice - Prison
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot250', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-repression-justice-prison'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- répression
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot160', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-repression-justice-prison'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- justice
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot235', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-repression-justice-prison'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- prison

-- Education
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot104', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-education'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- éducation

-- Bandes dessinées, affiches, photos
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot168', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-bandes-dessinees-affiches-photos'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- littérature : bande dessinée
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot20', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-bandes-dessinees-affiches-photos'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- art : affiches
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot29', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-bandes-dessinees-affiches-photos'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- art : photographie

-- Jeunesse
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot158', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-jeunesse'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- jeunes et jeunesse

-- Afrique
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot290', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-afrique'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Afrique

-- Amérique du nord
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot412', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-amerique-du-nord'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Amérique

-- Amériques latine et centrale
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot307', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-ameriques-latine-et-centrale'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Amérique Latine

-- Asie
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot417', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-asie'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Asie

-- Europe
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot332', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-europe'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Europe

-- Moyen-Orient, Proche-Orient, Palestine
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot378', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-moyen-orient-proche-orient-palestine'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Palestine
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot354', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-moyen-orient-proche-orient-palestine'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Israël

-- URSS - Pays de l'Est europen
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot492', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-urss-pays-de-l-est-europen'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- URSS
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot493', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-urss-pays-de-l-est-europen'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- URSS : histoire

-- Yiddishland - Mouvements juifs
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot509', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-yiddishland-mouvements-juifs'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Juifs
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot159', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-yiddishland-mouvements-juifs'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Juifs : juifs anarchistes

-- Révolution russe
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot494', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-revolution-russe'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Russie : histoire : 1917-1921

-- Révolution allemande - Conseillisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot299', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-revolution-allemande-conseillisme'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Allemagne : histoire : 1914-1918

-- Mai-Juin 1936
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot343', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-mai-juin-1936'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- France : histoire : 1919-1939

-- Révolution espagnole, exil, antifranquisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot326', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-revolution-espagnole-exil-antifranquisme'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Espagne : histoire : 1936-1939
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot327', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-revolution-espagnole-exil-antifranquisme'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- Espagne : histoire : 1939-1975

-- Deuxième guerre mondiale
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot508', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-deuxieme-guerre-mondiale'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- guerres : Guerre mondiale , 2 (1939-1945)

-- Marxisme
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot194', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-marxisme'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- marxisme

-- Libertaires
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot8', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-libertaires'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- anarchisme

-- Religions
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot249', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-religions'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- religion et spiritualité (en général)

-- Sociologie
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot264', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-sociologie'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- sociologie

-- Sport
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot268', 'exact' FROM public.subjects s WHERE s.slug = 'solidaires-sport'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- sport

-- Romans, nouvelles, essais
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot179', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-romans-nouvelles-essais'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- littérature : romans
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot175', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-romans-nouvelles-essais'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- littérature : nouvelles
INSERT INTO public.subject_ficedl_links (subject_id, mot_id, match_type)
SELECT s.id, 'mot172', 'close' FROM public.subjects s WHERE s.slug = 'solidaires-romans-nouvelles-essais'
ON CONFLICT (subject_id, mot_id) DO NOTHING;   -- littérature : essais

COMMIT;

-- Controle :
--   SELECT count(*) FROM public.subjects WHERE slug LIKE 'solidaires-%';             -- attendu 35
--   SELECT count(*) FROM public.subject_ficedl_links l
--     JOIN public.subjects s ON s.id=l.subject_id WHERE s.slug LIKE 'solidaires-%';  -- attendu 44