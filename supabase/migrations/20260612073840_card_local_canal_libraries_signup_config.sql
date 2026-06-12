-- ════════════════════════════════════════════════════════════════════════════
-- CARD-LOCAL-CANAL — Wizard L1 : config d'identité dans v_libraries_for_signup
-- Auteur  : Xavier + Claude
-- Session : Identité lecteur·rice locale (CARD-LOCAL §27) — volet canaux/welcome
-- Date    : 2026-06-12 (UTC)
--
-- Le wizard de création (écran de confirmation/bienvenue) doit conditionner le
-- message « comment marche ta biblio » sur reader_cards_enabled (carte ?) et
-- reader_validation_mode (identité plus tard : par e-mail si remote, au 1er
-- passage si presential, accès direct si none — CARD-LOCAL-3) ainsi que le
-- « tu es en attente » (validation requise si mode ≠ none).
--
-- v_libraries_for_signup n'exposait que id/slug/name/short_name/city. On y ajoute
-- les 2 colonnes de config (déjà anon-lisibles sur libraries — ce sont des
-- réglages publics, comme reader_cards_enabled l'est déjà via libraries). La vue
-- reste security_invoker=true (doctrine BLOC C) et anon/authenticated SELECT.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE VIEW public.v_libraries_for_signup
WITH (security_invoker = true)
AS
  SELECT
    l.id,
    l.slug,
    l.name,
    l.short_name,
    l.city,
    l.reader_cards_enabled,
    l.reader_validation_mode
  FROM public.libraries l
  WHERE l.is_active = true
  ORDER BY l.name;

GRANT SELECT ON public.v_libraries_for_signup TO anon, authenticated;

COMMENT ON VIEW public.v_libraries_for_signup IS
  'Bibliothèques actives proposées au signup. + reader_cards_enabled / '
  'reader_validation_mode (CARD-LOCAL-CANAL : conditionne le message de bienvenue). '
  'security_invoker=true. MàJ wizard L1 du 12/06/2026.';

DO $$
DECLARE
  v_cols int;
BEGIN
  SELECT count(*) INTO v_cols
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'v_libraries_for_signup'
     AND column_name IN ('reader_cards_enabled', 'reader_validation_mode');
  IF v_cols <> 2 THEN
    RAISE EXCEPTION 'Vérification échouée : v_libraries_for_signup n''expose pas les 2 colonnes de config (% trouvée(s)).', v_cols;
  END IF;
  RAISE NOTICE 'CARD-LOCAL-CANAL L1 : v_libraries_for_signup étendue OK.';
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════════════════════
-- Rollback : recréer la vue avec les 5 colonnes d'origine (id, slug, name,
-- short_name, city) — cf. version pré-12/06.
-- ════════════════════════════════════════════════════════════════════════════
