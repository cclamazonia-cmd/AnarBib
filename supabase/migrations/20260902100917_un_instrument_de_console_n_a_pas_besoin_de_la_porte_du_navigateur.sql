-- B20, lot conventions : les deux contrôles qualité redeviennent ce qu'ils
-- sont — des instruments de console.
--
-- ============================================================================
-- LE TRI (02/09/2026)
-- ============================================================================
-- `conv_controle_qualite(p_regra, p_limite)` et `conv_controle_resumo()` sont
-- des diagnostics EN LECTURE SEULE (STABLE) sur les vues
-- `private.v_conv_controle_*`, écrits pour piloter la campagne des conventions
-- depuis la console. Aucun appelant nulle part (GLB v17 ch. 6, contre-vérifié
-- le 02/09 : grep dépôt 0, base 0), aucune spec ne leur promet d'écran — la
-- file de vérification, elle, a le sien (`conv_revue_*`, câblées).
--
-- Or la console travaille en `postgres` : le grant `authenticated` ne sert
-- qu'à la porte PostgREST, où personne ne frappe. On le retire ; la recette
-- console est INTACTE (`select * from api.conv_controle_resumo();` en SQL
-- direct fonctionne comme avant), et le jour où l'atelier des conventions
-- veut son panneau de contrôle qualité, la restauration est un GRANT.
--
-- La migration `20260901082124` les citait comme bon exemple (garde de corps
-- qui refuse bruyamment) : le corps ne change pas d'un mot, seul le droit
-- d'entrée bouge. ACL lue avant d'écrire : {postgres=X, authenticated=X},
-- pas d'entrée PUBLIC héritée — les trois cibles nommées par ceinture.

REVOKE EXECUTE ON FUNCTION api.conv_controle_qualite(text, integer) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION api.conv_controle_resumo() FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_reste text;
BEGIN
  SELECT string_agg(p.proname, ', ') INTO v_reste
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'api'
    AND p.proname IN ('conv_controle_qualite','conv_controle_resumo')
    AND (has_function_privilege('authenticated', p.oid, 'EXECUTE')
      OR has_function_privilege('anon', p.oid, 'EXECUTE'));
  IF v_reste IS NOT NULL THEN
    RAISE EXCEPTION 'révocation sans effet sur : % — rollback', v_reste;
  END IF;

  -- L'instrument lui-même reste entier : les deux vues qu'il lit existent,
  -- et postgres garde son EXECUTE — c'est la moitié « console » du contrat.
  IF to_regclass('private.v_conv_controle_qualite') IS NULL
     OR to_regclass('private.v_conv_controle_resumo') IS NULL THEN
    RAISE EXCEPTION 'vues private.v_conv_controle_* introuvables — l''instrument serait cassé — rollback';
  END IF;
  IF NOT has_function_privilege('postgres', 'api.conv_controle_resumo()', 'EXECUTE') THEN
    RAISE EXCEPTION 'postgres a perdu EXECUTE — la console serait muette — rollback';
  END IF;
END $$;
