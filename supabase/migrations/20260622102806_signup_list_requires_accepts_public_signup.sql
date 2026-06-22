-- =========================================================================
-- Paquet visibilité — le sélecteur d'inscription n'expose que les biblios ouvertes
-- =========================================================================
-- Date     : 2026-06-22
-- Chantier : visibilité des bibliothèques / onboarding
-- Auteur   : Claude (MCP Supabase) — appliquée d'abord sur staging, réintégrée au repo
--
-- Contexte : v_libraries_for_signup ne filtrait que sur is_active, donc toute
-- bibliothèque active (même privée / de test) apparaissait dans le sélecteur de
-- création de compte. On exige désormais aussi accepts_public_signup = true, ce
-- qui exclut les bibliothèques privées/test (ex. CIRA Marseille) du menu
-- d'inscription. Aucun impact sur les biblios existantes (toutes en
-- accepts_public_signup = true au moment de la migration).
--
-- Vue : security_invoker = true préservé. Les GRANT existants (anon + authenticated
-- SELECT) sont conservés par CREATE OR REPLACE VIEW.
-- =========================================================================

CREATE OR REPLACE VIEW public.v_libraries_for_signup
WITH (security_invoker = true) AS
  SELECT id,
         slug,
         name,
         short_name,
         city,
         reader_cards_enabled,
         reader_validation_mode
  FROM public.libraries l
  WHERE is_active = true
    AND accepts_public_signup = true
  ORDER BY name;

-- Recharger le cache de schéma PostgREST (vue exposée modifiée).
NOTIFY pgrst, 'reload schema';
