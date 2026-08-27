-- =====================================================================
-- AnarBib — Tests d'acceptation : import d'un candidat institutionnel
-- Date    : 2026-08-28  ·  Session : chantier importations
-- Ref     : migration 20260828140000_candidat_institutionnel_ingerable
--
-- Pourquoi cette suite existe : public.fn_import_ingest_candidate a ete
-- INEXECUTABLE depuis son ecriture (cinq ecarts entre ce qu'elle ecrit et ce
-- que les colonnes acceptent), et RIEN ne l'a signale — ni les migrations, ni
-- les advisors, ni le typage. Une CHECK et un NOT NULL ne se verifient qu'a
-- l'execution, donc seulement sur un chemin reellement emprunte. Ces tests
-- EMPRUNTENT le chemin : ils appellent la RPC pour de vrai, avec le JWT d'une
-- coordinatrice, et regardent les trois tables ecrites.
--
-- T5 est le test le moins evident et le plus utile : il ne compare pas le
-- statut a une liste recopiee ici (qui derivrait avec la contrainte), il le
-- confronte a la CHECK ELLE-MEME. C'est la forme generale du defaut repare.
--   Bilan OK : 'IMPORT-CANDIDAT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord   uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador (seed)
  v_outside uuid := '22222222-2222-2222-2222-222222222222';  -- sans adhesion (seed)
  v_lib     uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_other_lib uuid;
  v_other_src bigint;
  v_book    bigint;
  v_res     jsonb;
  v_res2    jsonb;
  v_row     ingest.partner_catalog_staging_rows%rowtype;
  v_src     ingest.partner_catalog_sources%rowtype;
  v_run     ingest.partner_catalog_import_runs%rowtype;
  v_con     text;
  v_n       int;
  v_ok      boolean;

  -- Candidat type rendu par l'EF catalog_metadata_lookup (mode Busca).
  v_cand jsonb := jsonb_build_object(
    'source_record_id', 'bn-0001',
    'title',            'A Conquista do Pao',
    'subtitle',         'edicao de teste',
    'responsibility_statement', 'Piotr Kropotkin',
    'contributors',     jsonb_build_array(jsonb_build_object('name', 'KROPOTKIN, Piotr')),
    'publisher',        'Editora Teste',
    'place',            'Sao Paulo',
    'year',             '1892',
    'language',         'pt',
    'isbn',             jsonb_build_array('9788575591234'),
    'subjects',         jsonb_build_array('anarquismo'),
    'source',           'biblioteca_nacional',
    'source_url',       'https://exemplo.invalid/bn-0001',
    'confidence',       87
  );
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la RPC s''execute et repond ok (elle etait inexecutable)';
  BEGIN
    v_res := public.fn_import_ingest_candidate(v_cand);
    IF coalesce((v_res->>'ok')::boolean, false)
       AND (v_res->>'run_id') IS NOT NULL AND (v_res->>'row_id') IS NOT NULL THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Sans T1 rien n'a de sens : on s'arrete la plutot que d'aligner des echecs.
  IF v_res IS NULL THEN
    RAISE EXCEPTION 'IMPORT-CANDIDAT ECHEC : 0/1 OK, la RPC ne s''execute pas | %',
      array_to_string(v_failures, ' || ');
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la source de repli est creee : institutional_lookup + relation_status mapeada';
  BEGIN
    SELECT * INTO v_src FROM ingest.partner_catalog_sources
     WHERE id = (v_res->>'source_id')::bigint;
    IF v_src.source_kind = 'institutional_lookup'
       AND v_src.relation_status = 'mapeada'
       AND v_src.library_id = v_lib
       AND v_src.import_enabled THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got kind='||coalesce(v_src.source_kind,'NULL')
      ||' rel='||coalesce(v_src.relation_status,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 le run porte detected_format=lookup et un storage_path (NOT NULL sans defaut)';
  BEGIN
    SELECT * INTO v_run FROM ingest.partner_catalog_import_runs
     WHERE id = (v_res->>'run_id')::bigint;
    IF v_run.detected_format = 'lookup'
       AND coalesce(v_run.storage_path, '') <> ''
       AND v_run.library_id = v_lib THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got fmt='||coalesce(v_run.detected_format,'NULL')
      ||' path='||coalesce(v_run.storage_path,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 la notice arrive dans la file de revision avec ses metadonnees';
  BEGIN
    SELECT * INTO v_row FROM ingest.partner_catalog_staging_rows
     WHERE id = (v_res->>'row_id')::bigint;
    IF v_row.title = 'A Conquista do Pao'
       AND v_row.isbn = '9788575591234'
       AND v_row.external_key = 'bn-0001'
       AND v_row.review_status = 'pending'
       AND v_row.raw_payload = v_cand THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got title='||coalesce(v_row.title,'NULL')
      ||' isbn='||coalesce(v_row.isbn,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le test qui garde la LECON : on confronte le statut ecrit a la CHECK
  -- elle-meme, pas a une liste recopiee ici. C'est exactement ce qui manquait :
  -- 'pre_matched' se relit tres bien, il ne se heurte qu'a la contrainte.
  v_t := 'T5 le match_status ecrit appartient au vocabulaire de la CHECK (introspection)';
  BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
     WHERE c.conname = 'partner_catalog_staging_rows_match_status_check';
    IF v_con IS NOT NULL AND v_row.match_status IS NOT NULL
       AND position('''' || v_row.match_status || '''' in v_con) > 0 THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : statut '
      ||coalesce(v_row.match_status,'NULL')||' absent de '||coalesce(v_con,'<contrainte absente>')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Un statut valide ne suffit pas : 'unreviewed' passerait la CHECK et
  -- resterait pourtant un cul-de-sac editorial. C'est ce que garde T6.
  v_t := 'T6 sans doublon au catalogue : new_record, donc PROMOUVABLE';
  BEGIN
    SELECT ingest.fn_is_editorial_decision_compatible(v_row.match_status, 'accept_new') INTO v_ok;
    IF v_row.match_status = 'new_record' AND v_ok THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_row.match_status,'NULL')
      ||' promouvable='||coalesce(v_ok::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 les compteurs du run sont rafraichis (imported_rows=1, ready_for_review)';
  BEGIN
    SELECT * INTO v_run FROM ingest.partner_catalog_import_runs
     WHERE id = (v_res->>'run_id')::bigint;
    IF v_run.imported_rows = 1 AND v_run.run_status = 'ready_for_review' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got rows='||v_run.imported_rows
      ||' status='||v_run.run_status); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Regression directe de la faute 2 : tant qu'aucune ligne ne pouvait porter
  -- 'institutional_lookup', le SELECT de repli ne trouvait JAMAIS rien et la
  -- branche INSERT etait rejouee a chaque appel. Elle doit maintenant etre
  -- empruntee une seule fois.
  v_t := 'T8 deuxieme candidat le meme jour : une seule source, un seul run, deux lignes';
  BEGIN
    v_res2 := public.fn_import_ingest_candidate(v_cand || jsonb_build_object(
      'source_record_id', 'bn-0002', 'title', 'Palavras de um Revoltado',
      'isbn', jsonb_build_array('9788575599999')));
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_sources
     WHERE library_id = v_lib AND source_kind = 'institutional_lookup';
    IF v_n = 1
       AND (v_res2->>'source_id')::bigint = (v_res->>'source_id')::bigint
       AND (v_res2->>'run_id')::bigint = (v_res->>'run_id')::bigint
       AND (SELECT count(*) FROM ingest.partner_catalog_staging_rows
             WHERE run_id = (v_res->>'run_id')::bigint) = 2 THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : sources='||v_n
      ||' run1='||(v_res->>'run_id')||' run2='||coalesce(v_res2->>'run_id','NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le rapprochement n'est pas decoratif : c'est lui qui empeche l'assistant
  -- d'auto-promouvoir un doublon. S'il n'etait pas appele, ce test verrait
  -- 'new_record' sur une notice DEJA au catalogue.
  v_t := 'T9 un candidat portant l''ISBN d''un livre du catalogue est marque doublon';
  BEGIN
    INSERT INTO public.books (titulo, autor, ano, isbn)
    VALUES ('A Conquista do Pao', 'KROPOTKIN, Piotr', '1892', '9788575591111')
    RETURNING id INTO v_book;

    v_res2 := public.fn_import_ingest_candidate(v_cand || jsonb_build_object(
      'source_record_id', 'bn-0003', 'isbn', jsonb_build_array('9788575591111')));
    SELECT * INTO v_row FROM ingest.partner_catalog_staging_rows
     WHERE id = (v_res2->>'row_id')::bigint;
    IF v_row.match_status = 'matched_book' AND v_row.proposed_book_id = v_book
       AND NOT ingest.fn_is_editorial_decision_compatible(v_row.match_status, 'accept_new') THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_row.match_status,'NULL')
      ||' propose='||coalesce(v_row.proposed_book_id::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 une source d''une AUTRE bibliotheque est refusee';
  BEGIN
    INSERT INTO public.libraries (slug, name) VALUES ('autre-test', 'Autre biblio (test)')
    RETURNING id INTO v_other_lib;
    INSERT INTO ingest.partner_catalog_sources
      (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('Ailleurs', v_other_lib, 'mapeada', 'manual_upload', true)
    RETURNING id INTO v_other_src;

    BEGIN
      PERFORM public.fn_import_ingest_candidate(v_cand, v_other_src);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      IF position('nao pertence' in SQLERRM) > 0 THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' (fixture) : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 une personne sans adhesion staff est refusee';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_outside, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_import_ingest_candidate(v_cand);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      IF position('Acesso' in SQLERRM) > 0 THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
    END;
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T12 la RPC n''est ouverte ni a anon ni a PUBLIC';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public' AND routine_name = 'fn_import_ingest_candidate'
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' droit(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-CANDIDAT OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-CANDIDAT ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
