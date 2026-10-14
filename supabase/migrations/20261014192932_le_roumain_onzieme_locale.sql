-- =====================================================================
-- AnarBib — le roumain, onzième locale (lot 3 du chantier « locale ro »)
-- Date    : 2026-10-14  ·  Backlog E39 · REGISTRE DOC-I18N-4, DOC-I18N-5
-- Banc    : tests/sql/locales_source_unique_tests.sql
--
-- CE QUE FAIT CETTE MIGRATION
--  1. public.fn_supported_locales() rend 'ro' en onzième position (D1) : les
--     huit contraintes CHECK et les huit fonctions qui la lisent (migration
--     20261013194812) acceptent le roumain sans autre retouche.
--  2. public.fn_locale_from_idioma : une notice en roumain (ro, ron, rum) a
--     désormais la locale ro — work_titles peut donc recevoir son titre
--     d'édition roumain. Reporté du lot 2 : avant le 1, la contrainte de
--     work_titles l'aurait refusé.
--  3. La casse de phrase s'applique aux titres roumains (fn_conv_casse_titre),
--     avec les mots-outils roumains (private.conv_mots_outils) — les mêmes
--     que src/lib/titleCase.js côté front.
--  4. fn_notify_fonds_deposit_received : le titre de la tâche existe en roumain.
--
-- MÉTHODE. Les trois dernières fonctions sont longues : elles sont réécrites
-- à partir de leur définition RÉELLE (pg_get_functiondef), en remplaçant un
-- seul fragment, et la migration échoue si ce fragment n'est pas trouvé
-- exactement une fois (« repartir de la définition réelle »). CREATE OR
-- REPLACE garde propriétaire, droits et options.
--
-- Rien d'autre ne change : le roumain reste hors des sélecteurs de l'app
-- (listed: false) jusqu'à sa relecture (D5).
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_supported_locales()
 RETURNS text[]
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
 SET search_path TO 'pg_catalog'
AS $function$
  SELECT ARRAY['pt-BR','fr','es','en','it','de','ca','eo','nl','el','ro']::text[]
$function$;

DO $$
DECLARE
  d text;
  -- Remplace UNE occurrence exacte dans la définition de f, et la rejoue.
  -- (procédure locale : une fonction par cible, écrite en clair)
BEGIN
  -- 2. fn_locale_from_idioma
  d := pg_get_functiondef('public.fn_locale_from_idioma(text)'::regprocedure);
  IF (length(d) - length(replace(d, '    ELSE NULL END', ''))) / length('    ELSE NULL END') <> 1 THEN
    RAISE EXCEPTION 'fn_locale_from_idioma : fragment « ELSE NULL END » attendu une fois';
  END IF;
  EXECUTE replace(d, '    ELSE NULL END',
    $r$    WHEN pg_catalog.lower(pg_catalog.btrim(COALESCE(p_idioma, ''))) = ANY ('{ro,ron,rum,ro-ro}'::text[])            THEN 'ro'
    ELSE NULL END$r$);

  -- 3a. mots-outils roumains
  d := pg_get_functiondef('private.conv_mots_outils(text)'::regprocedure);
  IF (length(d) - length(replace(d, '    else null', ''))) / length('    else null') <> 1 THEN
    RAISE EXCEPTION 'conv_mots_outils : fragment « else null » attendu une fois';
  END IF;
  EXECUTE replace(d, '    else null',
    $r$    when p_lang like 'ro%' then array['a','al','ale','ai','ce','că','cu','de','despre','din','după','fără','în','între','la','o','pe','pentru','prin','sau','spre','sub','și','un','unei','unui','către']
    else null$r$);

  -- 3b. casse de phrase pour le roumain
  d := pg_get_functiondef('public.fn_conv_casse_titre(text,text,boolean)'::regprocedure);
  IF (length(d) - length(replace(d, $f$'^(pt|es|fr|it|ca|eo|nl|el)'$f$, ''))) / length($f$'^(pt|es|fr|it|ca|eo|nl|el)'$f$) <> 1 THEN
    RAISE EXCEPTION 'fn_conv_casse_titre : expression des langues en casse de phrase attendue une fois';
  END IF;
  EXECUTE replace(d, $f$'^(pt|es|fr|it|ca|eo|nl|el)'$f$, $f$'^(pt|es|fr|it|ca|eo|nl|el|ro)'$f$);

  -- 4. titre roumain de la tâche « lot de fonds reçu »
  d := pg_get_functiondef('public.fn_notify_fonds_deposit_received(bigint)'::regprocedure);
  IF (length(d) - length(replace(d, $f$'el',    'Ελήφθη παρτίδα αρχείων — έλεγχος και επισύναψη'$f$, ''))) / length($f$'el',    'Ελήφθη παρτίδα αρχείων — έλεγχος και επισύναψη'$f$) <> 1 THEN
    RAISE EXCEPTION 'fn_notify_fonds_deposit_received : ligne el attendue une fois';
  END IF;
  EXECUTE replace(d, $f$'el',    'Ελήφθη παρτίδα αρχείων — έλεγχος και επισύναψη'$f$,
    $f$'el',    'Ελήφθη παρτίδα αρχείων — έλεγχος και επισύναψη',
    'ro',    'Lot de fonduri primit — de verificat și de atașat'$f$);
END $$;

-- ── Vérification ────────────────────────────────────────────────────
DO $$
BEGIN
  IF public.fn_supported_locales() <> ARRAY['pt-BR','fr','es','en','it','de','ca','eo','nl','el','ro']::text[] THEN
    RAISE EXCEPTION 'fn_supported_locales : liste inattendue';
  END IF;
  IF public.fn_locale_from_idioma('rum') IS DISTINCT FROM 'ro' OR public.fn_locale_from_idioma(' RO ') IS DISTINCT FROM 'ro'
     OR public.fn_locale_from_idioma('fre') IS DISTINCT FROM 'fr' THEN
    RAISE EXCEPTION 'fn_locale_from_idioma : correspondance roumaine absente ou autre correspondance cassée';
  END IF;
  IF NOT ('și' = ANY (private.conv_mots_outils('ro'))) THEN
    RAISE EXCEPTION 'conv_mots_outils : mots-outils roumains absents';
  END IF;
  IF public.fn_conv_casse_titre('ISTORIA ANARHISMULUI ÎN ROMÂNIA', 'ro') = 'ISTORIA ANARHISMULUI ÎN ROMÂNIA' THEN
    RAISE EXCEPTION 'fn_conv_casse_titre : le roumain n''est pas traité';
  END IF;
  IF has_function_privilege('anon', 'public.fn_supported_locales()', 'EXECUTE')
     OR NOT has_function_privilege('authenticated', 'public.fn_supported_locales()', 'EXECUTE') THEN
    RAISE EXCEPTION 'fn_supported_locales : droits changés';
  END IF;
END $$;
