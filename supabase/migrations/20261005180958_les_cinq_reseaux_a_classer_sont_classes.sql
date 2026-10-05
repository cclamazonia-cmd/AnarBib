-- =====================================================================
-- G13 suite (05/10/2026) — les cinq réseaux laissés « à classer » par
-- 20261005173015 sont classés, sur recherche documentée et décision de Xavier.
--
--   ABABA  — Amicale des Bibliothèques Autonomes de Bruxelles et Alentours :
--            bibliothèques autonomes qui mettent leurs inventaires en commun
--            (Inventaire.io) → documentation ;
--   FAO    — Federacija za anarhistično organiziranje (Slovénie, Istrie
--            croate), membre de l'IFA → organisation_politique ;
--   AFI    — Anarho-feministična iniciativa (Ljubljana), collectif
--            anarcha-féministe ; pas l'Internationale (IFA). Une seule source
--            (Culture.si, fiche de l'Infoshop Metelkova) → organisation_politique ;
--   UK Social Centre Network — réseau des centres sociaux autogérés
--            britanniques → autre ;
--   Radical Routes — réseau britannique de coopératives, surtout d'habitat
--            → autre.
-- Les sites officiels connus sont posés (FAO, Radical Routes, FAI, RebAL ;
-- NORLA par sa page chez MayDay Rooms).
--
-- Effet sur le catalogue public : aucun aujourd'hui — aucun de ces réseaux
-- n'est déclaré par une fiche de carte rattachée à une bibliothèque AnarBib.
-- La lecture `reseaux` des fiches ne dépend pas de la nature : rien à
-- recalculer. Suite : tests/sql/g13_reseaux_constitues_tests.sql (T1).
-- =====================================================================

DO $mig$
DECLARE v_n int;
BEGIN
  UPDATE public.networks n
     SET kind = v.kind, site_url = coalesce(v.site_url, n.site_url)
    FROM (VALUES
      ('ababa',                    'documentation',          'https://inventaire.io/groups/ababa--amicale-des-biblioth%C3%A8ques-autonomes-de-bruxelles-et-alentours'),
      ('fao',                      'organisation_politique', 'https://www.a-federacija.org/'),
      ('afi',                      'organisation_politique', NULL),
      ('uk-social-centre-network', 'autre',                  NULL),
      ('radical-routes',           'autre',                  'https://www.radicalroutes.org.uk/'),
      ('fai',                      'organisation_politique', 'https://federazioneanarchica.org/'),
      ('rebal',                    'documentation',          'https://www.rebal.info/'),
      ('norla',                    'documentation',          'https://maydayrooms.org/project/network-of-radical-libraries-and-archives/')
    ) AS v(slug, kind, site_url)
   WHERE n.slug = v.slug;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  IF v_n <> 8 THEN
    RAISE EXCEPTION 'G13 : % réseaux mis à jour (8 attendus)', v_n;
  END IF;
  IF EXISTS (SELECT 1 FROM public.networks WHERE kind IS NULL) THEN
    RAISE EXCEPTION 'G13 : un réseau reste à classer';
  END IF;
END
$mig$;
