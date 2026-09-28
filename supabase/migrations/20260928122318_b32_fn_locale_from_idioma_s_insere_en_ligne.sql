-- =========================================================================
-- B32 (levier c) — fn_locale_from_idioma s'insère en ligne
-- =========================================================================
-- Date     : 2026-09-28
-- Chantier : B32
--
-- LE CONSTAT. public.fn_locale_from_idioma(text) est une fonction SQL
-- IMMUTABLE munie d'un SET search_path : un SET interdit l'insertion en ligne,
-- PostgreSQL l'appelle donc pour chaque ligne, en posant et reposant le GUC à
-- chaque appel. api.catalog_works_v1 l'évalue jusqu'à trois fois par notice
-- (titres_livres : WHERE, DISTINCT ON, ORDER BY) sur toutes les notices
-- rattachées à une œuvre ; fn_work_titles_reseed — le déclencheur AFTER de
-- books — la rappelle à chaque notice écrite.
--
-- LE GESTE. Même table de correspondance, même résultat pour toute entrée
-- (vérifié ci-dessous contre la définition en place, sur toutes les valeurs
-- distinctes de books.idioma plus les cas limites), mais un corps réduit à une
-- expression, sans SET : toutes les références sont qualifiées pg_catalog, le
-- search_path n'a plus d'effet sur elle. Le planificateur l'insère en ligne :
-- une expression par ligne au lieu d'un appel.
-- =========================================================================

BEGIN;

-- La version en place, gardée le temps de la comparaison
DO $garde$
DECLARE v_def text;
BEGIN
  SELECT pg_get_functiondef(p.oid) INTO v_def FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_locale_from_idioma';
  IF v_def IS NULL THEN RAISE EXCEPTION 'B32 : fn_locale_from_idioma introuvable'; END IF;
  EXECUTE replace(v_def, 'FUNCTION public.fn_locale_from_idioma(', 'FUNCTION pg_temp.b32_locale_avant(');
END
$garde$;

CREATE OR REPLACE FUNCTION public.fn_locale_from_idioma(p_idioma text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT CASE
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{pt-br,pt,pt-pt,por}'::text[])            THEN 'pt-BR'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{fr,fra,fre,fr-fr,fr-be,fr-ca}'::text[])  THEN 'fr'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{es,spa,es-es,es-ar,es-mx}'::text[])     THEN 'es'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{it,ita,it-it}'::text[])                 THEN 'it'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{en,eng,en-us,en-gb}'::text[])           THEN 'en'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{de,ger,deu,de-de}'::text[])             THEN 'de'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{ca,cat}'::text[])                       THEN 'ca'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{eo,epo}'::text[])                       THEN 'eo'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{nl,nld,dut}'::text[])                   THEN 'nl'
    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{el,ell,gre}'::text[])                   THEN 'el'
    ELSE NULL END
$function$;

COMMENT ON FUNCTION public.fn_locale_from_idioma(text) IS
  'Locale d''affichage (pt-BR, fr, es, it, en, de, ca, eo, nl, el) déduite du code de langue d''une notice ; NULL sinon. Sans SET search_path, exprès (B32) : références qualifiées pg_catalog, corps réduit à une expression pour que PostgreSQL l''insère en ligne.';

-- Même résultat pour toute entrée : toutes les valeurs distinctes de books.idioma,
-- plus les cas limites (NULL, vide, blancs, casse, inconnu).
DO $equiv$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n
    FROM (SELECT DISTINCT idioma AS v FROM public.books
          UNION ALL SELECT unnest(ARRAY[NULL, '', '  ', 'PT-BR', ' Fr ', 'xx', 'por', 'EN-us', 'gre', 'esperanto'])) x
   WHERE public.fn_locale_from_idioma(x.v) IS DISTINCT FROM pg_temp.b32_locale_avant(x.v);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'B32 : fn_locale_from_idioma diverge de la version en place sur % valeur(s)', v_n;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE n.nspname = 'public' AND p.proname = 'fn_locale_from_idioma' AND p.proconfig IS NOT NULL) THEN
    RAISE EXCEPTION 'B32 : fn_locale_from_idioma porte encore un SET';
  END IF;
END
$equiv$;

DROP FUNCTION pg_temp.b32_locale_avant(text);

COMMIT;
