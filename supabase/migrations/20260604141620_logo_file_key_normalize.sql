-- =============================================================================
-- Normalisation de la convention logo_file_key (item 2 -- hygiene donnee)
-- -----------------------------------------------------------------------------
-- Cible unique = CHEMIN COMPLET dans le bucket public library-ui-assets.
-- Les slugs nus (ex. 'btl') sont expanses en 'themes/<slug>/logo-<slug>.png'
-- (nommage atteste : le fichier themes/btl/logo-btl.png existe et servait deja
-- via l'expansion cote front). 'blmf' est deja en chemin complet -> intact.
--
-- Iso-comportement visuel : l'URL produite est exactement celle que
-- resolveLibraryLogo(@/lib/theme) calculait deja pour le slug nu. Cette
-- migration ne fait qu'uniformiser la DONNEE ; le filet d'expansion reste
-- dans resolveLibraryLogo (donc un eventuel slug nu futur marcherait encore).
--
-- DML data-only (pas de schema, pas de RLS). Idempotent (une valeur deja en
-- chemin contient '/' -> exclue). Applique par Woodpecker (supabase db push
-- --linked). JAMAIS colle en SQL Editor.
-- =============================================================================

UPDATE public.library_commons
   SET logo_file_key = 'themes/' || logo_file_key || '/logo-' || logo_file_key || '.png'
 WHERE logo_file_key IS NOT NULL
   AND btrim(logo_file_key) <> ''
   AND logo_file_key NOT LIKE '%/%'
   AND logo_file_key !~* '^https?://';

-- Verif : plus aucun slug nu (toute valeur non vide = chemin complet ou URL).
DO $verif$
DECLARE n int;
BEGIN
  SELECT count(*) INTO n
    FROM public.library_commons
    WHERE logo_file_key IS NOT NULL
      AND btrim(logo_file_key) <> ''
      AND logo_file_key NOT LIKE '%/%'
      AND logo_file_key !~* '^https?://';
  IF n > 0 THEN
    RAISE EXCEPTION 'verif: % slug(s) nu(s) restant(s) dans logo_file_key', n;
  END IF;
  RAISE NOTICE 'verif: logo_file_key normalise (aucun slug nu restant)';
END;
$verif$;
