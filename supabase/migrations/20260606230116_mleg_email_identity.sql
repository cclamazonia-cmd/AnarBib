-- =========================================================================
-- Ajout de MLEG dans library_email_identity
-- =========================================================================
-- Date     : 2026-06-06 23:01 UTC (horodatage reel)
-- Session  : Catalogacao work completion
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- L'Edge Function register verifie library_email_identity pour valider
-- la bibliotheque choisie lors de l'inscription. Sans cette ligne,
-- l'inscription echoue avec INVALID_LIBRARY (non-2xx non explicite).
-- La ligne a ete inseree directement via MCP SQL pour debloquer
-- l'inscription ; cette migration formalise le changement.
-- =========================================================================

INSERT INTO public.library_email_identity (
  library_slug,
  display_name,
  email_delivery_mode,
  is_test_mode,
  is_active
) VALUES (
  'mleg',
  'Maloca Libertária / Biblioteca Emma Goldman',
  'test_only',
  true,
  true
) ON CONFLICT (library_slug) DO NOTHING;
