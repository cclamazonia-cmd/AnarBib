-- =========================================================================
-- Paquet visibilité — inscription publique réservée aux bibliothèques PUBLIQUES
-- =========================================================================
-- Date     : 2026-06-22
-- Chantier : visibilité des bibliothèques / onboarding
-- Auteur   : Claude (MCP Supabase) — appliquée sur staging puis réintégrée au repo
--
-- Contexte : suite à 20260622102806 (filtre accepts_public_signup), une biblio à
-- visibilité 'network' (cas BTL / Biblioteca Terra Livre) apparaissait encore dans
-- le sélecteur d'inscription PUBLIC (/criar-conta) alors que son catalogue est
-- réservé aux usager·es connecté·es — une page anonyme ne doit pas exposer une
-- biblio non-publique. On exige désormais AUSSI visibility_level = 'public'.
-- Effet : seules les biblios actives, publiques et acceptant l'inscription publique
-- figurent au sélecteur (blmf, mleg conservées ; btl, cira-marseille exclues).
--
-- Vue : security_invoker = true préservé ; GRANT existants (anon + authenticated
-- SELECT) conservés par CREATE OR REPLACE VIEW.
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
    AND visibility_level = 'public'
  ORDER BY name;

-- Recharger le cache de schéma PostgREST (vue exposée modifiée).
NOTIFY pgrst, 'reload schema';
