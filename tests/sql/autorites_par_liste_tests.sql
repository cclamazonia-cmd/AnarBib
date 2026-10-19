-- =====================================================================
-- AnarBib — Tests d'acceptation : une liste fermée lie les contributeurs
-- d'une bibliothèque à leurs autorités
-- Date    : 2026-10-19  ·  Session : Anarchief — autorités et liens vers le wiki
-- Ref     : migration 20261019160041_les_auteurs_d_anarchief_rejoignent_leurs_autorites (private.fn_autorites_par_liste)
--
-- Données fictives : une bibliothèque d'essai, une autre bibliothèque, des
-- notices aux noms d'essai (« Zzaut… »).
--
-- T1  renommage + suppression : le débris « Zzautcoll (Koor » + « Orkest) »
--     devient une seule ligne « Zzautcoll (Koor, Orkest) », liée au collectif
--     créé
-- T2  éclatement : « Zzautexist  Zzautneuf  Zzautseul » devient trois lignes
--     (positions 1, 2, 3 ; seule la 1re principale) ; la 1re liée à
--     l'autorité existante, la 2e à l'autorité créée, la 3e laissée en texte
-- T3  autorité créée : forme retenue, forme de tri, type (colonne ET
--     structured_meta), étiquette, note ; formes variantes en alias
--     (alias_norm = f_normalize_search) ; book_authors suit le lien ;
--     book_contributors.nature = type
-- T4  périmètre : la même graphie sur une notice d'une autre bibliothèque,
--     ou déjà liée à une autre autorité, n'est pas touchée ; l'autorité
--     existante n'a reçu aucun alias ; books.autor inchangé
-- T5  rejouable : un second passage ne crée rien, ne lie rien, n'ajoute
--     aucune ligne
-- T6  refus : autorité existante absente, clé sans autorité, liste non
--     objet, étiquette vide, type inconnu
-- T7  la fonction est INVOKER, fermée à anon et authenticated
--
--   Bilan OK : 'AUTORITES-PAR-LISTE OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text; v_ok boolean;
  c_lib   constant uuid := 'a1e50000-0000-4000-8000-000000000011';
  c_autre constant uuid := 'a1e50000-0000-4000-8000-000000000012';
  c_label constant text := 'Essai · liste fermée';
  v_exist bigint; v_autre_aut bigint;
  v_b1 bigint; v_b2 bigint; v_b3 bigint; v_b4 bigint;
  v_liste jsonb; v_res jsonb; v_res2 jsonb;
  v_coll bigint; v_neuf bigint;
  v_n int; v_txt text;
  v_a public.authors%rowtype;
  v_row record;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.libraries (id, slug, name, short_name, visibility_level, network_mode, catalog_mode, accepts_public_signup, is_active)
  VALUES (c_lib,   'autliste-essai', 'Essai liste (test autorités)', 'AutListe', 'private', 'observer', 'network_published', false, true),
         (c_autre, 'autliste-autre', 'Autre liste (test autorités)', 'AutAutre', 'private', 'federated', 'network_published', false, true);
  INSERT INTO public.library_service_state (library_id) VALUES (c_lib), (c_autre) ON CONFLICT (library_id) DO NOTHING;

  INSERT INTO public.authors (preferred_name, sort_name, authority_type) VALUES ('Zzautexist Essai', 'Essai, Zzautexist', 'person') RETURNING id INTO v_exist;
  INSERT INTO public.authors (preferred_name, sort_name) VALUES ('Zzautautre Essai', 'Essai, Zzautautre') RETURNING id INTO v_autre_aut;

  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material) VALUES ('Zzautliste un', 'Zzautcoll (Koor | Orkest)', 'AUTL-1', 'livro') RETURNING id INTO v_b1;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material) VALUES ('Zzautliste deux', 'Zzautexist  Zzautneuf  Zzautseul', 'AUTL-2', 'livro') RETURNING id INTO v_b2;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material) VALUES ('Zzautliste autre', 'Zzautneuf', 'AUTL-3', 'livro') RETURNING id INTO v_b3;
  INSERT INTO public.books (titulo, autor, bib_ref, tipo_material) VALUES ('Zzautliste déjà liée', 'Zzautneuf', 'AUTL-4', 'livro') RETURNING id INTO v_b4;
  INSERT INTO public.book_holdings (book_id, library_id, local_bib_ref, exemplares_total, available_count)
  VALUES (v_b1, c_lib, 'AUTL-1', 0, 0), (v_b2, c_lib, 'AUTL-2', 0, 0), (v_b3, c_autre, 'AUTL-3', 0, 0), (v_b4, c_lib, 'AUTL-4', 0, 0);
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id)
  VALUES (v_b1, 1, 'Zzautcoll (Koor', 'autor', true, NULL), (v_b1, 2, 'Orkest)', 'autor', false, NULL),
         (v_b2, 1, 'Zzautexist  Zzautneuf  Zzautseul', 'autor', true, NULL),
         (v_b3, 1, 'Zzautneuf', 'autor', true, NULL),
         (v_b4, 1, 'Zzautneuf', 'autor', true, v_autre_aut);

  v_liste := jsonb_build_object(
    'renommages',  jsonb_build_array(jsonb_build_object('nom', 'Zzautcoll (Koor', 'en', 'Zzautcoll (Koor, Orkest)')),
    'suppressions', jsonb_build_array('Orkest)'),
    'eclatements', jsonb_build_array(jsonb_build_object('nom', 'Zzautexist  Zzautneuf  Zzautseul',
                                                        'parts', jsonb_build_array('Zzautexist', 'Zzautneuf', 'Zzautseul'))),
    'autorites', jsonb_build_array(
       jsonb_build_object('cle', 'coll', 'preferred', 'Zzautcoll', 'sort', 'Zzautcoll', 'type', 'collective',
                          'alias', jsonb_build_array('Zzautcoll (Koor, Orkest)')),
       jsonb_build_object('cle', 'neuf', 'preferred', 'Zzautneuf Essai', 'sort', 'Essai, Zzautneuf', 'type', 'person',
                          'alias', jsonb_build_array('Zzautneuf', 'ZZAUTNEUF'))),
    'liens', jsonb_build_array(
       jsonb_build_object('nom', 'Zzautcoll (Koor, Orkest)', 'cle', 'coll'),
       jsonb_build_object('nom', 'Zzautexist', 'autorite', v_exist),
       jsonb_build_object('nom', 'Zzautneuf', 'cle', 'neuf')),
    'texte', jsonb_build_array('Zzautseul'));

  v_res := private.fn_autorites_par_liste(c_lib, v_liste, c_label, 'Note d''essai.');
  SELECT id INTO v_coll FROM public.authors WHERE preferred_name = 'Zzautcoll' AND source_label = c_label;
  SELECT id INTO v_neuf FROM public.authors WHERE preferred_name = 'Zzautneuf Essai' AND source_label = c_label;

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 renommage + suppression du débris';
  BEGIN
    SELECT count(*), string_agg(name || '→' || coalesce(author_id::text, '∅'), ',') INTO v_n, v_txt
      FROM public.book_contributors WHERE book_id = v_b1;
    IF v_n = 1 AND v_txt = 'Zzautcoll (Koor, Orkest)→' || v_coll THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 éclatement en trois lignes, liées selon la liste';
  BEGIN
    SELECT string_agg(position || ':' || name || ':' || coalesce(author_id::text, '∅') || ':' || is_primary, ' ; ' ORDER BY position)
      INTO v_txt FROM public.book_contributors WHERE book_id = v_b2;
    IF v_txt = '1:Zzautexist:' || v_exist || ':true ; 2:Zzautneuf:' || v_neuf || ':false ; 3:Zzautseul:∅:false'
    THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_txt, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 autorité créée complète, alias normalisés, book_authors et nature suivent';
  BEGIN
    SELECT * INTO v_a FROM public.authors WHERE id = v_neuf;
    v_ok := v_a.sort_name = 'Essai, Zzautneuf' AND v_a.authority_type = 'person'
      AND v_a.structured_meta->>'authorityType' = 'person' AND v_a.source_label = c_label
      AND v_a.notes = 'Note d''essai.';
    SELECT count(*) INTO v_n FROM public.author_name_aliases
     WHERE author_id = v_neuf AND is_active AND match_kind = 'variant'
       AND alias_norm = public.f_normalize_search(alias_text);
    v_ok := v_ok AND v_n = 1;   -- « Zzautneuf » et « ZZAUTNEUF » : une seule forme normalisée
    SELECT count(*) INTO v_n FROM public.book_authors WHERE book_id = v_b2 AND author_id IN (v_exist, v_neuf);
    v_ok := v_ok AND v_n = 2;
    SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_b2 AND author_id = v_neuf AND nature = 'person';
    v_ok := v_ok AND v_n = 1;
    SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_b1 AND nature = 'collective';
    v_ok := v_ok AND v_n = 1;
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : tri=' || coalesce(v_a.sort_name, '∅') || ' alias=' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 hors périmètre intact : autre bibliothèque, ligne déjà liée, autorité existante, transcription';
  BEGIN
    SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_b3 AND author_id IS NULL;
    v_ok := v_n = 1;
    SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id = v_b4 AND author_id = v_autre_aut;
    v_ok := v_ok AND v_n = 1;
    SELECT count(*) INTO v_n FROM public.author_name_aliases WHERE author_id IN (v_exist, v_autre_aut);
    v_ok := v_ok AND v_n = 0;
    SELECT count(*) INTO v_n FROM public.books WHERE id = v_b2 AND autor = 'Zzautexist  Zzautneuf  Zzautseul';
    v_ok := v_ok AND v_n = 1;
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 rejouable';
  BEGIN
    SELECT count(*) INTO v_n FROM public.book_contributors WHERE book_id IN (v_b1, v_b2, v_b3, v_b4);
    v_res2 := private.fn_autorites_par_liste(c_lib, v_liste, c_label, 'Note d''essai.');
    v_ok := (v_res2->>'autorites_creees')::int = 0 AND (v_res2->>'liens')::int = 0 AND (v_res2->>'eclatements')::int = 0
        AND (v_res2->>'renommages')::int = 0 AND (v_res2->>'suppressions')::int = 0 AND (v_res2->>'alias')::int = 0;
    v_ok := v_ok AND (SELECT count(*) FROM public.book_contributors WHERE book_id IN (v_b1, v_b2, v_b3, v_b4)) = v_n;
    SELECT count(*) INTO v_n FROM public.authors WHERE source_label = c_label;
    v_ok := v_ok AND v_n = 2;
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res2::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T6 ────────────────────────────────────────────────────────────
  v_t := 'T6 refus : autorité absente, clé orpheline, liste non objet, étiquette vide, type inconnu';
  v_txt := NULL;
  FOR v_row IN SELECT * FROM (VALUES
      ('autorité absente', jsonb_build_object('liens', jsonb_build_array(jsonb_build_object('nom', 'X', 'autorite', -1))), c_label),
      ('clé orpheline',    jsonb_build_object('liens', jsonb_build_array(jsonb_build_object('nom', 'X', 'cle', 'rien'))), c_label),
      ('liste tableau',    '[]'::jsonb, c_label),
      ('étiquette vide',   '{}'::jsonb, ' '),
      ('type inconnu',     jsonb_build_object('autorites', jsonb_build_array(jsonb_build_object('cle', 'k', 'preferred', 'Zzautx', 'type', 'meeting'))), c_label)
    ) x(cas, liste, label) LOOP
    BEGIN
      PERFORM private.fn_autorites_par_liste(c_lib, v_row.liste, v_row.label, NULL);
      v_txt := concat_ws(' ; ', v_txt, 'accepté : ' || v_row.cas);
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
  END LOOP;
  IF v_txt IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  -- ── T7 ────────────────────────────────────────────────────────────
  v_t := 'T7 INVOKER, fermée à anon et authenticated';
  BEGIN
    SELECT NOT p.prosecdef INTO v_ok FROM pg_proc p
     WHERE p.oid = 'private.fn_autorites_par_liste(uuid, jsonb, text, text)'::regprocedure;
    v_ok := v_ok
      AND NOT has_function_privilege('anon', 'private.fn_autorites_par_liste(uuid, jsonb, text, text)', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'private.fn_autorites_par_liste(uuid, jsonb, text, text)', 'EXECUTE');
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'AUTORITES-PAR-LISTE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'AUTORITES-PAR-LISTE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
