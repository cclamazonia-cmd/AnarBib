-- =====================================================================
-- AnarBib — Tests d'acceptation : un lieu retiré des copies d'import
-- (19/10/2026)
-- Ref     : migration 20261019191959_un_lieu_retire_des_copies_d_import
--
-- Le lieu de ce banc est FICTIF (« Bancheville ») : aucun vrai lieu ne doit
-- figurer dans le dépôt. Une notice `ANARCHIEF-21161` miniature, son
-- brouillon publié, sa ligne et sa référence d'import sont fabriqués dans la
-- transaction ; la migration est jouée deux fois (\ir) ; tout est annulé.
-- T1 fn_jsonb_sans_lieu : champ égal → null, texte qui contient → sans lui
--    (« (lieu, 2024) » → « (2024) »), url_page → l'adresse donnée, le reste
--    intact ; lieu vide ou document nul → inchangé.
-- T2 la notice : plus de lieu nulle part, adresse neutre, les autres clés
--    de la charge brute intactes.
-- T3 le brouillon publié (charge brute, racine du marc_json, éditeur ; un
--    brouillon sans copie d'import garde son marc_json), la ligne d'import
--    (charge brute, normalisée, éditeur) et la référence (brute, projetée).
-- T4 une autre notice qui porte le même mot ailleurs ne bouge pas.
-- T5 idempotence : le second passage ne change rien.
-- =====================================================================
BEGIN;

DO $$
DECLARE v_lib uuid; v_src bigint; v_run bigint; v_sr bigint; v_book bigint; v_autre bigint; v_ext bigint;
  v_raw jsonb := jsonb_build_object(
    'cle', '21161', 'titre', 'Livre de banc',
    'titre_wiki', 'Auteur - Livre de banc (Bancheville, 2024)',
    'url_page', 'https://anarchief.org/wiki/Auteur_-_Livre_de_banc_(Bancheville,_2024)',
    'editeur', 'Bancheville', 'lieu', '', 'fichiers', 'https://anarchief.org/w/images/x.pdf');
BEGIN
  IF EXISTS (SELECT 1 FROM public.books WHERE bib_ref = 'ANARCHIEF-21161') THEN
    RAISE EXCEPTION 'LIEU-RETIRE ECHEC : 0/1 — une notice ANARCHIEF-21161 existe déjà sur ce banc';
  END IF;
  SELECT id INTO v_lib FROM public.libraries ORDER BY created_at LIMIT 1;
  INSERT INTO public.books (titulo, bib_ref, marc_json)
  VALUES ('Livre de banc', 'ANARCHIEF-21161', jsonb_build_object('ingest', jsonb_build_object('raw_payload', v_raw)))
  RETURNING id INTO v_book;
  INSERT INTO public.books (titulo, bib_ref, editora) VALUES ('Guide de Bancheville', 'LIEU-AUTRE-1', 'Office de Bancheville')
  RETURNING id INTO v_autre;
  INSERT INTO public.book_drafts (titulo, status, tipo_material, editora, published_book_id, marc_json)
  VALUES ('Livre de banc', 'draft', 'livro', 'Bancheville', v_book,
          jsonb_build_object('publisher', 'Bancheville', 'titre', 'Livre de banc', 'ingest', jsonb_build_object('raw_payload', v_raw)));
  -- un autre brouillon de la même notice, SANS copie d'import : son marc_json ne doit jamais devenir NULL
  INSERT INTO public.book_drafts (titulo, status, tipo_material, published_book_id, marc_json)
  VALUES ('Livre de banc, reprise', 'draft', 'livro', v_book, jsonb_build_object('note', 'sans import'));
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Lieu banc', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/lieu.csv', 'lieu.csv', 'csv', 'ready_for_review') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, item_type, title, publisher, raw_payload, normalized_payload, match_status, editorial_decision)
  VALUES (v_run, 1, '21161', 'am', 'Livre de banc', 'Bancheville', v_raw, jsonb_build_object('publisher', 'Bancheville', 'title', 'Livre de banc'), 'known_record', 'pending')
  RETURNING id INTO v_sr;
  INSERT INTO public.book_external_ids (book_id, library_id, scheme, value, source_id)
  VALUES (v_book, v_lib, 'import:' || v_src, '21161', v_src) RETURNING id INTO v_ext;
  INSERT INTO ingest.book_import_baselines (external_id_id, run_id, staging_row_id, mapped, contributors, subjects, raw_payload, mapping_version, payload_hash, origine, confirmed_at)
  VALUES (v_ext, v_run, v_sr, jsonb_build_object('editora', 'Bancheville', 'titulo', 'Livre de banc'), '[]'::jsonb, '[]'::jsonb, v_raw, 'v1', 'h', 'import', now());
END $$;

\ir ../../supabase/migrations/20261019191959_un_lieu_retire_des_copies_d_import.sql
\ir ../../supabase/migrations/20261019191959_un_lieu_retire_des_copies_d_import.sql

DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := '{}'; v_t text;
  v_book bigint; j jsonb;
BEGIN
  SELECT id INTO v_book FROM public.books WHERE bib_ref = 'ANARCHIEF-21161';

  v_t := 'T1 fn_jsonb_sans_lieu';
  j := private.fn_jsonb_sans_lieu('{"a":"Bancheville","b":"X (Bancheville, 2024)","url_page":"https://w/X_(Bancheville,_2024)","c":"rien","n":3}'::jsonb, 'Bancheville', 'https://w/?curid=1');
  IF j->>'a' IS NULL AND j ? 'a' AND j->>'b' = 'X (2024)' AND j->>'url_page' = 'https://w/?curid=1' AND j->>'c' = 'rien' AND (j->>'n')::int = 3
     AND private.fn_jsonb_sans_lieu('{"a":"Bancheville"}'::jsonb, '', NULL) = '{"a":"Bancheville"}'::jsonb
     AND private.fn_jsonb_sans_lieu(NULL, 'Bancheville', NULL) IS NULL
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(j::text,'∅')); END IF;

  v_t := 'T2 la notice';
  SELECT marc_json->'ingest'->'raw_payload' INTO j FROM public.books WHERE id = v_book;
  IF (SELECT to_jsonb(b)::text !~* 'bancheville' FROM public.books b WHERE b.id = v_book)
     AND j->>'url_page' = 'https://anarchief.org/w/index.php?curid=21161'
     AND j->>'titre_wiki' = 'Auteur - Livre de banc (2024)'
     AND j->>'fichiers' = 'https://anarchief.org/w/images/x.pdf' AND j->>'cle' = '21161' AND j->>'titre' = 'Livre de banc'
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(j::text,'∅')); END IF;

  v_t := 'T3 brouillon, ligne et référence d''import';
  IF NOT EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.published_book_id = v_book AND to_jsonb(d)::text ~* 'bancheville')
     AND EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.published_book_id = v_book AND d.editora IS NULL)
     AND EXISTS (SELECT 1 FROM public.book_drafts d WHERE d.published_book_id = v_book AND d.marc_json ? 'publisher' AND d.marc_json->>'publisher' IS NULL AND d.marc_json->>'titre' = 'Livre de banc')
     AND (SELECT marc_json FROM public.book_drafts WHERE titulo = 'Livre de banc, reprise') = '{"note": "sans import"}'::jsonb
     AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows s WHERE s.external_key = '21161' AND to_jsonb(s)::text ~* 'bancheville')
     AND EXISTS (SELECT 1 FROM ingest.partner_catalog_staging_rows s WHERE s.external_key = '21161' AND s.publisher IS NULL AND s.normalized_payload->>'title' = 'Livre de banc')
     AND NOT EXISTS (SELECT 1 FROM ingest.book_import_baselines r WHERE r.raw_payload->>'cle' = '21161' AND to_jsonb(r)::text ~* 'bancheville')
     AND EXISTS (SELECT 1 FROM ingest.book_import_baselines r WHERE r.raw_payload->>'cle' = '21161' AND r.mapped->>'titulo' = 'Livre de banc')
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  v_t := 'T4 une autre notice ne bouge pas';
  IF (SELECT editora = 'Office de Bancheville' AND titulo = 'Guide de Bancheville' FROM public.books WHERE bib_ref = 'LIEU-AUTRE-1')
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  v_t := 'T5 idempotence';
  IF (SELECT count(*) FROM public.books WHERE bib_ref = 'ANARCHIEF-21161') = 1
     AND (SELECT marc_json->'ingest'->'raw_payload'->>'titre_wiki' FROM public.books WHERE id = v_book) = 'Auteur - Livre de banc (2024)'
  THEN v_passed := v_passed+1; ELSE v_failed := v_failed+1; v_failures := v_failures||v_t; END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'LIEU-RETIRE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'LIEU-RETIRE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;

ROLLBACK;
