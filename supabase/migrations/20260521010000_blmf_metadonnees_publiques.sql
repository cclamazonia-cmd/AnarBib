-- =====================================================================
-- Migration : métadonnées publiques de la BLMF pour la galerie (#K2)
-- Date de conception : 2026-05-20
--
-- Renseigne affiliation_label et website_url de la Biblioteca Libertária
-- Maxwell Ferreira, exposés sur sa carte dans la galerie /explorar.
-- Données fournies par le coordinateur du projet.
--
-- Idempotent : le WHERE cible la BLMF par slug ; rejouer la migration
-- réécrit les mêmes valeurs sans effet de bord.
-- =====================================================================

BEGIN;

UPDATE public.library_commons
SET affiliation_label = 'Centro de Cultura Libertária da Amazônia — CCLA',
    website_url       = 'https://cclamazonia.noblogs.org/'
WHERE library_id = (SELECT id FROM public.libraries WHERE slug = 'blmf');

-- Vérification : la BLMF a bien reçu ses deux champs.
DO $$
DECLARE
  v_aff text;
  v_url text;
BEGIN
  SELECT lc.affiliation_label, lc.website_url
    INTO v_aff, v_url
  FROM public.library_commons lc
  JOIN public.libraries l ON l.id = lc.library_id
  WHERE l.slug = 'blmf';

  IF v_aff IS NULL OR v_url IS NULL THEN
    RAISE EXCEPTION
      'BLMF : affiliation_label ou website_url non renseigne apres UPDATE';
  END IF;

  RAISE NOTICE 'OK BLMF : affiliation=%, site=%', v_aff, v_url;
END $$;

COMMIT;
