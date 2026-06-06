-- =========================================================================
-- Ajout de MLEG dans library_commons (donnees operationnelles)
-- =========================================================================
-- Date     : 2026-06-06 22:44 UTC (horodatage reel)
-- Session  : Catalogacao work completion
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- La table library_commons contient les donnees operationnelles de chaque
-- bibliotheque (logo, email, mode de livraison). MLEG n'y avait pas de
-- ligne => le logo ne s'affichait pas sur la page d'inscription.
-- =========================================================================

INSERT INTO public.library_commons (
  library_id,
  library_slug,
  display_name,
  short_name,
  logo_file_key,
  email_delivery_mode,
  is_test_mode,
  is_active
) VALUES (
  (SELECT id FROM public.libraries WHERE slug = 'mleg'),
  'mleg',
  'Maloca Libertária / Biblioteca Emma Goldman',
  'MLEG',
  'themes/maloca/logo_maloca.png',
  'test_only',
  true,
  true
);

NOTIFY pgrst, 'reload schema';
