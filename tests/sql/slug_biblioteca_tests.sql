-- =====================================================================
-- AnarBib — Tests : le slug d'une bibliothèque garde ses lettres
-- Date    : 2026-08-30  ·  Item B16
-- Ref     : 20260830202631 (fn_library_slug_from_name)
--
-- Le défaut corrigé ne se voyait pas en relisant le code : il fallait
-- exécuter la fabrication. `lower()` était appliqué APRÈS le filtre
-- `[^a-z0-9]`, donc toute majuscule devenait un tiret avant d'avoir été
-- minusculée — « Biblioteca Terra Livre » donnait « iblioteca-erra-ivre ».
-- Et le `translate()` censé replier les accents était un no-op : ses deux
-- arguments étaient la même chaîne.
--
-- T1 et T2 sont les deux cas qui ont motivé l'item. T5 est le garde-fou qui
-- compte sur la durée : il refuse qu'on réinsère le calcul dans le corps de
-- `fn_provision_preactive_library`. Sortir le calcul dans une fonction nommée
-- n'a d'intérêt que si personne ne le remet en ligne ensuite.
--   Bilan OK : 'SLUG-BIBLIO OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_got text; v_n int;
BEGIN
  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 les majuscules sont minusculees, pas mangees';
  BEGIN
    v_got := public.fn_library_slug_from_name('Biblioteca Terra Livre');
    IF v_got = 'biblioteca-terra-livre' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_got,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 les accents sont replies, pas remplaces par des tirets';
  BEGIN
    v_got := public.fn_library_slug_from_name('Associação Cultural Ñandú');
    IF v_got = 'associacao-cultural-nandu' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_got,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Le catalan et le francais passent par le meme chemin que le portugais.
  v_t := 'T2b meme chose hors portugais';
  BEGIN
    v_got := public.fn_library_slug_from_name('Ateneu Llibertari de Gràcia');
    IF v_got = 'ateneu-llibertari-de-gracia' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_got,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Ponctuation, parentheses, tirets cadratins : tout devient un seul tiret,
  -- et il n'en reste ni au debut ni a la fin.
  v_t := 'T3 la ponctuation se replie en un seul tiret, sans bord';
  BEGIN
    v_got := public.fn_library_slug_from_name('CIRA – Centre de Recherches (Marseille)');
    IF v_got = 'cira-centre-de-recherches-marseille' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_got,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Un nom vide ou fait de seule ponctuation ne doit pas rendre NULL : c'est
  -- l'appelante qui decide quoi faire d'un slug vide (elle leve 23514).
  v_t := 'T4 un nom vide rend le repli, un nom de ponctuation rend le vide';
  BEGIN
    IF public.fn_library_slug_from_name('   ') = 'biblioteca'
       AND public.fn_library_slug_from_name(NULL) = 'biblioteca'
       AND public.fn_library_slug_from_name(' --- ') = ''
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : vide='||coalesce(public.fn_library_slug_from_name('   '),'NULL')
        ||' null='||coalesce(public.fn_library_slug_from_name(NULL),'NULL')
        ||' ponct='||coalesce(public.fn_library_slug_from_name(' --- '),'NULL'));
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le test qui compte sur la duree : le provisionnement doit APPELER la
  -- fonction, pas refabriquer le calcul dans son corps. Sans ce garde-fou,
  -- une reecriture distraite reintroduirait le defaut sans que rien ne rougisse.
  v_t := 'T5 fn_provision_preactive_library appelle la fonction au lieu de refaire le calcul';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'fn_provision_preactive_library'
       AND p.prosrc LIKE '%fn_library_slug_from_name%'
       AND p.prosrc NOT LIKE '%[^a-z0-9]+%';
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : le corps refabrique le slug ou n''appelle pas la fonction'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 la fonction de slug n''est pas ouverte aux roles de session';
  BEGIN
    IF has_function_privilege('anon', 'public.fn_library_slug_from_name(text)', 'EXECUTE')
       OR has_function_privilege('authenticated', 'public.fn_library_slug_from_name(text)', 'EXECUTE')
    THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : accordee a anon ou authenticated');
    ELSE v_passed := v_passed+1; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'SLUG-BIBLIO OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'SLUG-BIBLIO ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
