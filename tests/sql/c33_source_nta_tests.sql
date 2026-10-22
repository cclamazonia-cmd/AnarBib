-- =====================================================================
-- AnarBib — Tests d'acceptation : le NTA (KB), troisième source de
-- private.fn_enrichir_autorites (C33)
-- Date    : 2026-10-22
-- Ref     : migration 20261022190340_c33_le_nta_troisieme_source_des_autorites
--
-- Données fictives (« Zzta… », NTA p99999990x, Q99999998x).
-- T1 une fiche dont la seule source est le NTA : dates, pays, VIAF, ISNI
--    remplis ; external_ids.nta posé ; trace nta_releve { nta, date, lot,
--    preuve, champs } ; aucune trace wikidata_releve
-- T2 NTA + Wikidata tiré de ses liens : le Wikidata est écrit, mais
--    attribué au NTA (champs de nta_releve), pas de wikidata_releve
-- T3 rejouable : un second passage n'enrichit rien
-- T4 conflit : un NTA déjà posé et différent → refus, rien écrit
-- T5 refus : NTA mal formé ; fiche sans aucune source (le message nomme le NTA)
-- T6 Wikidata seul : l'ancien chemin est intact (trace wikidata_releve)
--   Bilan OK : 'C33-SOURCE-NTA OK : N/N tests passés'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  c_lot  constant text := 'Essai · NTA';
  c_date constant date := date '2026-10-22';
  v_p1 bigint; v_p2 bigint; v_p3 bigint; v_p4 bigint;
  v_res jsonb; v_a public.authors%rowtype; v_maj timestamptz; v_err text;
BEGIN
  INSERT INTO public.authors (sort_name, preferred_name, authority_type) VALUES ('Zztaun, Jan', 'Jan Zztaun', 'person') RETURNING id INTO v_p1;
  INSERT INTO public.authors (sort_name, preferred_name, authority_type) VALUES ('Zztadeux, Piet', 'Piet Zztadeux', 'person') RETURNING id INTO v_p2;
  INSERT INTO public.authors (sort_name, preferred_name, authority_type, external_ids)
  VALUES ('Zztatrois, Kees', 'Kees Zztatrois', 'person', '{"nta": "p999999909"}'::jsonb) RETURNING id INTO v_p3;
  INSERT INTO public.authors (sort_name, preferred_name, authority_type) VALUES ('Zztaquatre, Ida', 'Ida Zztaquatre', 'person') RETURNING id INTO v_p4;

  v_t := 'T1 NTA seul';
  BEGIN
    v_res := private.fn_enrichir_autorites(jsonb_build_array(jsonb_build_object(
      'id', v_p1, 'nom', 'Jan Zztaun', 'decision', 'nta_deux_signaux', 'nta', 'p999999901',
      'preuve_nta', 'titre « Een boek »', 'naissance', 1900, 'mort', 1970, 'pays', 'NL',
      'viaf', '999999001', 'isni', '0000000099999901')), c_date, c_lot);
    SELECT * INTO v_a FROM public.authors WHERE id = v_p1;
    IF v_a.birth_year = 1900 AND v_a.death_year = 1970 AND v_a.country = 'NL' AND v_a.viaf_id = '999999001'
       AND v_a.isni = '0000000099999901' AND v_a.wikidata_id IS NULL
       AND v_a.external_ids->>'nta' = 'p999999901'
       AND v_a.external_ids->'nta_releve'->>'nta' = 'p999999901'
       AND v_a.external_ids->'nta_releve'->>'lot' = c_lot
       AND v_a.external_ids->'nta_releve'->>'preuve' = 'titre « Een boek »'
       AND v_a.external_ids->'nta_releve'->'champs' @> '["birth_year","death_year","country","viaf_id","isni"]'::jsonb
       AND NOT (v_a.external_ids ? 'wikidata_releve')
       AND (v_res->>'enrichies')::int = 1
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(to_jsonb(v_a)::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T2 NTA + Wikidata de ses liens';
  BEGIN
    PERFORM private.fn_enrichir_autorites(jsonb_build_array(jsonb_build_object(
      'id', v_p2, 'nom', 'Piet Zztadeux', 'decision', 'nta_deux_signaux', 'nta', 'p999999902',
      'preuve_nta', 'titre « Twee »', 'qid', 'Q999999981', 'naissance', 1910)), c_date, c_lot);
    SELECT * INTO v_a FROM public.authors WHERE id = v_p2;
    IF v_a.wikidata_id = 'Q999999981' AND v_a.birth_year = 1910
       AND v_a.external_ids->'nta_releve'->'champs' @> '["wikidata_id","birth_year"]'::jsonb
       AND NOT (v_a.external_ids ? 'wikidata_releve')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_a.external_ids::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T3 rejouable';
  BEGIN
    SELECT updated_at INTO v_maj FROM public.authors WHERE id = v_p1;
    v_res := private.fn_enrichir_autorites(jsonb_build_array(jsonb_build_object(
      'id', v_p1, 'nom', 'Jan Zztaun', 'decision', 'nta_deux_signaux', 'nta', 'p999999901',
      'preuve_nta', 'titre « Een boek »', 'naissance', 1900, 'mort', 1970, 'pays', 'NL',
      'viaf', '999999001', 'isni', '0000000099999901')), c_date, c_lot);
    IF (v_res->>'enrichies')::int = 0 AND (SELECT updated_at FROM public.authors WHERE id = v_p1) = v_maj
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T4 conflit de NTA';
  BEGIN
    v_err := NULL;
    BEGIN
      PERFORM private.fn_enrichir_autorites(jsonb_build_array(jsonb_build_object(
        'id', v_p3, 'nom', 'Kees Zztatrois', 'nta', 'p999999903', 'naissance', 1920)), c_date, c_lot);
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; END;
    IF v_err LIKE '%NTA p999999909 ≠ p999999903%' AND (SELECT birth_year FROM public.authors WHERE id = v_p3) IS NULL
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_err,'pas de refus')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T5 refus : NTA mal formé, fiche sans source';
  DECLARE v_e1 text; v_e2 text;
  BEGIN
    BEGIN
      PERFORM private.fn_enrichir_autorites(jsonb_build_array(jsonb_build_object('id', v_p4, 'nom', 'Ida Zztaquatre', 'nta', '68716184')), c_date, c_lot);
    EXCEPTION WHEN OTHERS THEN v_e1 := SQLERRM; END;
    BEGIN
      PERFORM private.fn_enrichir_autorites(jsonb_build_array(jsonb_build_object('id', v_p4, 'nom', 'Ida Zztaquatre', 'naissance', 1930)), c_date, c_lot);
    EXCEPTION WHEN OTHERS THEN v_e2 := SQLERRM; END;
    IF v_e1 LIKE '%mal formée%' AND v_e2 LIKE '%ni NTA%' AND (SELECT birth_year FROM public.authors WHERE id = v_p4) IS NULL
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_e1,'∅')||' / '||coalesce(v_e2,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  v_t := 'T6 Wikidata seul : chemin d''avant intact';
  BEGIN
    PERFORM private.fn_enrichir_autorites(jsonb_build_array(jsonb_build_object(
      'id', v_p4, 'nom', 'Ida Zztaquatre', 'decision', 'A', 'qid', 'Q999999982', 'naissance', 1930)), c_date, c_lot);
    SELECT * INTO v_a FROM public.authors WHERE id = v_p4;
    IF v_a.wikidata_id = 'Q999999982' AND v_a.external_ids->'wikidata_releve'->>'qid' = 'Q999999982'
       AND NOT (v_a.external_ids ? 'nta_releve')
    THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_a.external_ids::text,'∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'C33-SOURCE-NTA OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'C33-SOURCE-NTA ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
