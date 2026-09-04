-- =====================================================================
-- AnarBib — Tests d'acceptation : le depot d'un catalogue compagnon est un
-- geste d'administration, le catalogue propre reste a la coordination
-- Date    : 2026-09-04  ·  Session : importations / qui fait entrer quoi
-- Ref     : migration 20260904121500_depot_partenaire_reserve_a_l_administration
--
-- Pourquoi cette suite existe : jusqu'ici la SEULE voie de fichier d'une
-- coordination passait par une source partner_deposit — le catalogue d'une
-- bibliotheque compagne, dont elle ne detient pas les livres, et qui a la
-- publication recoit quand meme une bibliotheque de destination. Fermer ce
-- depot sans ouvrir le catalogue propre aurait retire l'import de fichier aux
-- coordinations : la suite tient donc les DEUX bords.
--
-- T2 et T5 sont des tests de NON-ACTION : le refus ne doit RIEN creer (ni
-- run, ni brouillon). T3 et T4 tiennent l'autre moitie de la decision — la
-- coordination importe toujours SON catalogue. T6 verifie que l'admin reseau
-- passe bien les trois gardes, sinon le circuit compagnon serait mort pour
-- tout le monde. T1/T2/T5 confrontent le HINT a ce que la fonction leve
-- REELLEMENT (PG_EXCEPTION_HINT), pas a une chaine recopiee.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-DEPOT-ADMIN OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_hint_attendu constant text := 'error.import.deposit_admin_only';
  v_src_depot bigint;
  v_src_own   bigint;
  v_run_depot bigint;
  v_res  jsonb;
  v_res2 jsonb;
  v_hint text;
  v_n    int;
  v_kind text;
  v_runlib uuid;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── Jeu d'essai : une source de depot compagnon sous BLMF, un run deja
  --    recu dessus, une ligne prete a promouvoir. ──
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai depot compagnon', v_lib, 'mapeada', 'partner_deposit', true)
  RETURNING id INTO v_src_depot;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status)
  VALUES (v_src_depot, v_lib, 'essai/depot.csv', 'depot.csv', 'ready_for_review') RETURNING id INTO v_run_depot;

  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
  VALUES (v_run_depot, 1, 'k-depot-1', 'La conquete du pain', 'new_record', 'accept_new');

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la coordination ne peut plus enregistrer une source de depot compagnon';
  BEGIN
    PERFORM public.fn_import_register_deposit_source('Compagnon refuse');
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = v_hint_attendu THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')||' / '||SQLERRM); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 deposer un fichier sur une source compagnon est refuse, et ne cree aucun run';
  BEGIN
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_import_runs WHERE source_id = v_src_depot;
    BEGIN
      PERFORM public.fn_import_create(v_src_depot, 'essai/depot2.csv', 'depot2.csv');
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> v_hint_attendu THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')||' / '||SQLERRM);
      ELSIF (SELECT count(*) FROM ingest.partner_catalog_import_runs WHERE source_id = v_src_depot) <> v_n THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : un run a ete cree malgre le refus');
      ELSE v_passed := v_passed+1; END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 la coordination obtient SA source own_catalog, une seule, idempotente';
  BEGIN
    v_res  := public.fn_import_own_source();
    v_res2 := public.fn_import_own_source();
    v_src_own := (v_res->>'source_id')::bigint;
    SELECT source_kind INTO v_kind FROM ingest.partner_catalog_sources WHERE id = v_src_own AND library_id = v_lib;
    IF coalesce((v_res->>'created')::boolean, false)
       AND NOT coalesce((v_res2->>'created')::boolean, true)
       AND (v_res2->>'source_id')::bigint = v_src_own
       AND v_kind = 'own_catalog'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')||' puis '||coalesce(v_res2::text,'NULL')||' kind='||coalesce(v_kind,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 la coordination depose toujours un fichier de SON catalogue';
  BEGIN
    v_res := public.fn_import_create(v_src_own, 'essai/propre.csv', 'propre.csv');
    SELECT library_id INTO v_runlib FROM ingest.partner_catalog_import_runs WHERE id = (v_res->>'run_id')::bigint;
    IF coalesce((v_res->>'ok')::boolean, false) AND v_runlib = v_lib THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 promouvoir un lot compagnon est refuse a la coordination, et ne cree aucun brouillon';
  BEGIN
    BEGIN
      PERFORM public.fn_import_promote(v_run_depot);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> v_hint_attendu THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')||' / '||SQLERRM);
      ELSIF (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run_depot) <> 0 THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : des brouillons ont ete crees malgre le refus');
      ELSE v_passed := v_passed+1; END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 l''admin reseau passe les trois gardes (le circuit compagnon n''est pas mort)';
  -- La meme personne devient admin reseau : c'est le seul bit qui change.
  BEGIN
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_coord, 'active');

    v_res := public.fn_import_register_deposit_source('Compagnon admis');
    SELECT source_kind INTO v_kind FROM ingest.partner_catalog_sources WHERE id = (v_res->>'source_id')::bigint;
    IF NOT coalesce((v_res->>'created')::boolean, false) OR v_kind <> 'partner_deposit' THEN
      RAISE EXCEPTION 'register : %', coalesce(v_res::text, 'NULL');
    END IF;

    v_res := public.fn_import_create(v_src_depot, 'essai/depot3.csv', 'depot3.csv');
    IF NOT coalesce((v_res->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'create : %', coalesce(v_res::text, 'NULL');
    END IF;

    -- promote : la garde doit etre passee. Un echec plus loin dans
    -- fn_bulk_create_book_drafts_from_run ne serait pas le sujet de cette
    -- suite ; ce qui compte est que le HINT du refus n'apparaisse pas.
    BEGIN
      PERFORM public.fn_import_promote(v_run_depot);
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = v_hint_attendu THEN RAISE EXCEPTION 'promote refuse a l''admin : %', SQLERRM; END IF;
    END;
    v_passed := v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 les quatre RPC restent executables par authenticated, fermees a anon et PUBLIC';
  -- Fermer a authenticated donnerait un ecran mort : la garde vit dans le corps.
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public'
       AND routine_name IN ('fn_import_own_source', 'fn_import_register_deposit_source', 'fn_import_create', 'fn_import_promote')
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n <> 0 THEN RAISE EXCEPTION '% droit(s) anon/PUBLIC de trop', v_n; END IF;
    SELECT count(DISTINCT routine_name) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public'
       AND routine_name IN ('fn_import_own_source', 'fn_import_register_deposit_source', 'fn_import_create', 'fn_import_promote')
       AND grantee = 'authenticated' AND privilege_type = 'EXECUTE';
    IF v_n = 4 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/4 executables par authenticated'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-DEPOT-ADMIN OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-DEPOT-ADMIN ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
