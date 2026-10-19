-- =====================================================================
-- AnarBib — Tests d'acceptation : enrichir des autorités par liste fermée
-- (dates, pays, langue, Wikidata, VIAF, ISNI, IdRef — le vide seulement)
-- Date    : 2026-10-19  ·  Session : Anarchief — enrichissement des autorités (D7)
-- Ref     : migration 20261019192349_les_autorites_d_anarchief_recoivent_dates_pays_et_identifiants
--           (private.fn_enrichir_autorites)
--
-- Données fictives : des autorités d'essai (« Zzenrich… »), des
-- identifiants inventés (Q99999990x, PPN 99999990x).
--
-- T1  le vide seulement : une fiche vierge reçoit tout ; une fiche qui a
--     déjà sa naissance et son pays les garde ; une mort antérieure à la
--     naissance connue n'est pas écrite ; noms, alias, type, note intacts
-- T2  trace : wikidata_releve { qid, date, lot, decision, champs } et
--     idref_releve { ppn, date, lot, preuve, champs }, chaque champ à sa
--     source (champs_idref) ; external_ids.idref posé ; les autres clés de
--     external_ids gardées
-- T3  collectif : Wikidata, VIAF, pays ; type inchangé
-- T4  rejouable : un second passage n'enrichit rien, ne touche ni
--     updated_at ni les traces
-- T5  une trace d'un autre lot est gardée ; la nouvelle va sous une clé datée
-- T6  tout ou rien : une fiche renommée depuis le relevé → refus, rien écrit ;
--     aucune fiche présente (banc) → « presentes 0 », rien écrit
-- T7  conflits : Wikidata déjà posé et différent, Wikidata porté par une
--     autre fiche → refus, rien écrit
-- T8  refus : valeurs mal formées, doublon dans la liste, champs IdRef sans
--     IdRef, fiche sans source, lot vide, liste non tableau, date future
-- T9  la fonction est INVOKER, fermée à anon et authenticated
--
--   Bilan OK : 'ENRICHIR-AUTORITES OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text; v_ok boolean;
  c_lot  constant text := 'Essai · enrichissement';
  c_date constant date := date '2026-10-19';
  v_p1 bigint; v_p2 bigint; v_p3 bigint; v_c1 bigint; v_autre bigint;
  v_liste jsonb; v_res jsonb; v_res2 jsonb;
  v_a public.authors%rowtype; v_b public.authors%rowtype;
  v_maj timestamptz; v_ext jsonb;
  v_n int; v_txt text;
  v_row record;
BEGIN
  -- ── monde ─────────────────────────────────────────────────────────
  INSERT INTO public.authors (preferred_name, sort_name, authority_type, notes, external_ids)
  VALUES ('Zzenrich Vierge', 'Vierge, Zzenrich', 'person', 'note d''essai', '{"autre_cle": "garde"}'::jsonb)
  RETURNING id INTO v_p1;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type, birth_year, country)
  VALUES ('Zzenrich Datee', 'Datee, Zzenrich', 'person', 1900, 'BE')
  RETURNING id INTO v_p2;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type, birth_year)
  VALUES ('Zzenrich Mortavant', 'Mortavant, Zzenrich', 'person', 1950)
  RETURNING id INTO v_p3;
  INSERT INTO public.authors (preferred_name, sort_name, authority_type)
  VALUES ('Zzenrich Kollektief', 'Zzenrich Kollektief', 'collective')
  RETURNING id INTO v_c1;
  INSERT INTO public.author_name_aliases (alias_text, alias_norm, author_id)
  VALUES ('Z. Vierge', 'z vierge', v_p1);

  v_liste := jsonb_build_array(
    jsonb_build_object('id', v_p1, 'nom', 'Zzenrich Vierge', 'decision', 'A', 'qid', 'Q999999901',
                       'naissance', 1880, 'mort', 1940, 'pays', 'NL', 'langue', 'nl',
                       'viaf', '999999901', 'isni', '000000009999990X',
                       'idref', '99999990X', 'preuve_idref', 'titre « essai »', 'champs_idref', jsonb_build_array('langue')),
    jsonb_build_object('id', v_p2, 'nom', 'Zzenrich Datee', 'decision', 'B', 'qid', 'Q999999902',
                       'naissance', 1899, 'mort', 1970, 'pays', 'FR'),
    jsonb_build_object('id', v_p3, 'nom', 'Zzenrich Mortavant', 'decision', 'C', 'qid', 'Q999999903',
                       'mort', 1940),
    jsonb_build_object('id', v_c1, 'nom', 'Zzenrich Kollektief', 'decision', 'K', 'qid', 'Q999999904',
                       'viaf', '999999904', 'pays', 'BE'));

  v_res := private.fn_enrichir_autorites(v_liste, c_date, c_lot);

  -- ── T1 ────────────────────────────────────────────────────────────
  v_t := 'T1 le vide seulement';
  BEGIN
    SELECT * INTO v_a FROM public.authors WHERE id = v_p1;
    v_ok := v_a.birth_year = 1880 AND v_a.death_year = 1940 AND v_a.country = 'NL' AND v_a.writing_language = 'nl'
        AND v_a.wikidata_id = 'Q999999901' AND v_a.viaf_id = '999999901' AND v_a.isni = '000000009999990X'
        AND v_a.preferred_name = 'Zzenrich Vierge' AND v_a.sort_name = 'Vierge, Zzenrich'
        AND v_a.authority_type = 'person' AND v_a.notes = 'note d''essai'
        AND (SELECT count(*) FROM public.author_name_aliases WHERE author_id = v_p1) = 1;
    SELECT * INTO v_b FROM public.authors WHERE id = v_p2;
    v_ok := v_ok AND v_b.birth_year = 1900 AND v_b.country = 'BE' AND v_b.death_year = 1970
        AND v_b.wikidata_id = 'Q999999902';
    SELECT * INTO v_b FROM public.authors WHERE id = v_p3;
    v_ok := v_ok AND v_b.birth_year = 1950 AND v_b.death_year IS NULL AND v_b.wikidata_id = 'Q999999903';
    v_ok := v_ok AND (v_res->>'presentes')::int = 4 AND (v_res->>'enrichies')::int = 4;
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T2 ────────────────────────────────────────────────────────────
  v_t := 'T2 trace par source';
  BEGIN
    SELECT external_ids INTO v_ext FROM public.authors WHERE id = v_p1;
    v_ok := v_ext->>'autre_cle' = 'garde'
        AND v_ext->>'idref' = '99999990X'
        AND v_ext->'wikidata_releve'->>'qid' = 'Q999999901'
        AND v_ext->'wikidata_releve'->>'date' = '2026-10-19'
        AND v_ext->'wikidata_releve'->>'lot' = c_lot
        AND v_ext->'wikidata_releve'->>'decision' = 'A'
        AND v_ext->'wikidata_releve'->'champs' @> '["birth_year","death_year","country","wikidata_id","viaf_id","isni"]'::jsonb
        AND NOT (v_ext->'wikidata_releve'->'champs' ? 'writing_language')
        AND v_ext->'idref_releve'->>'ppn' = '99999990X'
        AND v_ext->'idref_releve'->>'preuve' = 'titre « essai »'
        AND v_ext->'idref_releve'->'champs' = '["writing_language","idref"]'::jsonb;
    SELECT external_ids INTO v_ext FROM public.authors WHERE id = v_p2;
    v_ok := v_ok AND v_ext->'wikidata_releve'->'champs' = '["death_year","wikidata_id"]'::jsonb
        AND NOT (v_ext ? 'idref_releve') AND NOT (v_ext ? 'idref');
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || coalesce(v_ext::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T3 ────────────────────────────────────────────────────────────
  v_t := 'T3 collectif';
  BEGIN
    SELECT * INTO v_a FROM public.authors WHERE id = v_c1;
    v_ok := v_a.authority_type = 'collective' AND v_a.wikidata_id = 'Q999999904' AND v_a.viaf_id = '999999904'
        AND v_a.country = 'BE' AND v_a.birth_year IS NULL AND v_a.preferred_name = 'Zzenrich Kollektief';
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T4 ────────────────────────────────────────────────────────────
  v_t := 'T4 rejouable';
  BEGIN
    UPDATE public.authors SET updated_at = timestamptz '2000-01-01' WHERE id IN (v_p1, v_p2, v_p3, v_c1);
    SELECT external_ids INTO v_ext FROM public.authors WHERE id = v_p1;
    v_res2 := private.fn_enrichir_autorites(v_liste, c_date, c_lot);
    SELECT count(*) INTO v_n FROM public.authors
     WHERE id IN (v_p1, v_p2, v_p3, v_c1) AND updated_at <> timestamptz '2000-01-01';
    v_ok := (v_res2->>'enrichies')::int = 0 AND v_n = 0
        AND (SELECT external_ids FROM public.authors WHERE id = v_p1) = v_ext;
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_res2::text || ' maj=' || v_n); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T5 ────────────────────────────────────────────────────────────
  v_t := 'T5 trace d''un autre lot gardée';
  BEGIN
    v_res2 := private.fn_enrichir_autorites(
      jsonb_build_array(jsonb_build_object('id', v_p2, 'nom', 'Zzenrich Datee', 'decision', 'A', 'qid', 'Q999999902',
                                           'langue', 'fr', 'idref', '999999920')),
      date '2026-10-18', 'Essai · autre lot');
    SELECT * INTO v_a FROM public.authors WHERE id = v_p2;
    v_ok := v_a.writing_language = 'fr'
        AND v_a.external_ids->'wikidata_releve'->>'lot' = c_lot
        AND v_a.external_ids->'wikidata_releve_20261018'->>'lot' = 'Essai · autre lot'
        AND v_a.external_ids->'wikidata_releve_20261018'->'champs' = '["writing_language"]'::jsonb
        AND v_a.external_ids->'idref_releve'->'champs' = '["idref"]'::jsonb;
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_a.external_ids::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T6 ────────────────────────────────────────────────────────────
  v_t := 'T6 tout ou rien';
  BEGIN
    INSERT INTO public.authors (preferred_name, sort_name, authority_type) VALUES ('Zzenrich Neuve', 'Neuve, Zzenrich', 'person')
    RETURNING id INTO v_autre;
    v_ok := false;
    BEGIN
      PERFORM private.fn_enrichir_autorites(jsonb_build_array(
        jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905', 'naissance', 1910),
        jsonb_build_object('id', v_p1, 'nom', 'Zzenrich Renommee', 'qid', 'Q999999901')), c_date, c_lot);
    EXCEPTION WHEN raise_exception THEN v_ok := SQLERRM LIKE '%1 fiche(s) sur 2%';
    END;
    v_ok := v_ok AND (SELECT birth_year IS NULL AND wikidata_id IS NULL FROM public.authors WHERE id = v_autre);
    v_res2 := private.fn_enrichir_autorites(jsonb_build_array(
      jsonb_build_object('id', -1, 'nom', 'Zzenrich Absente', 'qid', 'Q999999906')), c_date, c_lot);
    v_ok := v_ok AND (v_res2->>'presentes')::int = 0 AND (v_res2->>'enrichies')::int = 0;
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ── T7 ────────────────────────────────────────────────────────────
  v_t := 'T7 conflits';
  v_txt := NULL;
  FOR v_row IN
    SELECT * FROM (VALUES
      ('Wikidata différent', jsonb_build_array(
         jsonb_build_object('id', v_p1, 'nom', 'Zzenrich Vierge', 'qid', 'Q999999999'),
         jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905', 'naissance', 1910))),
      ('Wikidata d''une autre fiche', jsonb_build_array(
         jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999901', 'naissance', 1910))),
      ('IdRef différent', jsonb_build_array(
         jsonb_build_object('id', v_p1, 'nom', 'Zzenrich Vierge', 'qid', 'Q999999901', 'idref', '999999999')))
    ) x(cas, liste) LOOP
    BEGIN
      PERFORM private.fn_enrichir_autorites(v_row.liste, c_date, c_lot);
      v_txt := concat_ws(' ; ', v_txt, 'accepté : ' || v_row.cas);
    EXCEPTION WHEN raise_exception THEN
      IF SQLERRM NOT LIKE '%conflit%' THEN v_txt := concat_ws(' ; ', v_txt, v_row.cas || ' : ' || SQLERRM); END IF;
    END;
  END LOOP;
  IF (SELECT birth_year IS NOT NULL OR wikidata_id IS NOT NULL FROM public.authors WHERE id = v_autre) THEN
    v_txt := concat_ws(' ; ', v_txt, 'Zzenrich Neuve écrite');
  END IF;
  IF v_txt IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  -- ── T8 ────────────────────────────────────────────────────────────
  v_t := 'T8 refus';
  v_txt := NULL;
  FOR v_row IN
    SELECT * FROM (VALUES
      ('pays',          jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905', 'pays', 'nl')), c_lot, c_date),
      ('isni',          jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905', 'isni', '0000 0001')), c_lot, c_date),
      ('qid',           jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', '999999905')), c_lot, c_date),
      ('idref',         jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'idref', '12')), c_lot, c_date),
      ('mort < naiss.', jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905', 'naissance', 1950, 'mort', 1900)), c_lot, c_date),
      ('année future',  jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905', 'naissance', 2999)), c_lot, c_date),
      ('doublon',       jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905'),
                                          jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905')), c_lot, c_date),
      ('champs IdRef',  jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'qid', 'Q999999905', 'champs_idref', '["pays"]'::jsonb)), c_lot, c_date),
      ('champ inconnu', jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'idref', '99999990X', 'champs_idref', '["nom"]'::jsonb)), c_lot, c_date),
      ('sans source',   jsonb_build_array(jsonb_build_object('id', v_autre, 'nom', 'Zzenrich Neuve', 'naissance', 1910)), c_lot, c_date),
      ('lot vide',      '[]'::jsonb, ' ', c_date),
      ('pas tableau',   '{}'::jsonb, c_lot, c_date),
      ('date future',   '[]'::jsonb, c_lot, current_date + 1)
    ) x(cas, liste, lot, d) LOOP
    BEGIN
      PERFORM private.fn_enrichir_autorites(v_row.liste, v_row.d, v_row.lot);
      v_txt := concat_ws(' ; ', v_txt, 'accepté : ' || v_row.cas);
    EXCEPTION WHEN raise_exception THEN NULL;
    END;
  END LOOP;
  IF (SELECT wikidata_id IS NOT NULL OR birth_year IS NOT NULL OR country IS NOT NULL FROM public.authors WHERE id = v_autre) THEN
    v_txt := concat_ws(' ; ', v_txt, 'Zzenrich Neuve écrite');
  END IF;
  IF v_txt IS NULL THEN v_passed := v_passed + 1;
  ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || v_txt); END IF;

  -- ── T9 ────────────────────────────────────────────────────────────
  v_t := 'T9 INVOKER, fermée à anon et authenticated';
  BEGIN
    SELECT NOT p.prosecdef INTO v_ok FROM pg_proc p
     WHERE p.oid = 'private.fn_enrichir_autorites(jsonb, date, text)'::regprocedure;
    v_ok := v_ok
      AND NOT has_function_privilege('anon', 'private.fn_enrichir_autorites(jsonb, date, text)', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'private.fn_enrichir_autorites(jsonb, date, text)', 'EXECUTE');
    IF v_ok THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || v_t; END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ENRICHIR-AUTORITES OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'ENRICHIR-AUTORITES ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
