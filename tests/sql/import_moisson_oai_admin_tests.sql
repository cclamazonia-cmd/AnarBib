-- =====================================================================
-- AnarBib — Tests d'acceptation : moissonner un entrepot OAI-PMH est un
-- geste de reseau (admin), comme deposer un catalogue compagnon
-- Date    : 2026-09-04  ·  Session : importations / qui fait entrer quoi
-- Ref     : migration 20260904133000_moisson_oai_reservee_a_l_administration
--
-- Pourquoi cette suite existe : le chemin OAI etait bancal — enregistrer
-- l'entrepot etait admin, mais declencher la moisson et promouvoir le lot
-- restaient a la coordination de la biblio rattachee. La doctrine du matin
-- (20260904121500) dit que la provenance decide, pas le volume : un entrepot
-- moissonne est un fonds tiers.
--
-- T1 a T3 sont des tests de NON-ACTION : le refus ne cree ni run, ni verrou
-- de moisson, ni brouillon. T4 tient l'autre bord : l'admin reseau passe les
-- gardes, sinon le circuit serait mort pour tout le monde (la suite
-- import_oai_pmh_tests, qui moissonne en admin, le garde aussi). Les refus
-- sont confrontes au HINT REEL (PG_EXCEPTION_HINT).
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-MOISSON-OAI-ADMIN OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_hint_attendu constant text := 'error.import.deposit_admin_only';
  v_src  bigint;
  v_run  bigint;
  v_hint text;
  v_n    int;
  v_status text;
  v_res  jsonb;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── Jeu d'essai : un entrepot OAI rattache a BLMF, son etat de moisson au
  --    repos, un run deja moissonne avec une ligne prete a promouvoir. ──
  INSERT INTO ingest.partner_catalog_sources
    (partner_name, library_id, relation_status, source_kind, import_enabled, oai_endpoint_url, oai_metadata_prefix)
  VALUES ('Entrepot essai', v_lib, 'mapeada', 'oai_pmh', true, 'https://entrepot.invalid/oai', 'marcxml')
  RETURNING id INTO v_src;

  INSERT INTO ingest.oai_harvest_state (source_id, harvest_status, lots_per_cycle)
  VALUES (v_src, 'idle', 2);

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status, detected_format)
  VALUES (v_src, v_lib, 'oai/essai', 'oai-harvest-essai', 'ready_for_review', 'oai_pmh') RETURNING id INTO v_run;

  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
  VALUES (v_run, 1, 'oai-1', 'Dieu et l''Etat', 'new_record', 'accept_new');

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la coordination ne declenche plus de moisson, et rien n''est ecrit (ni run, ni verrou)';
  BEGIN
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_import_runs WHERE source_id = v_src;
    BEGIN
      PERFORM public.fn_import_harvest_oai(v_src);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      SELECT harvest_status INTO v_status FROM ingest.oai_harvest_state WHERE source_id = v_src;
      IF v_hint <> v_hint_attendu THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')||' / '||SQLERRM);
      ELSIF (SELECT count(*) FROM ingest.partner_catalog_import_runs WHERE source_id = v_src) <> v_n OR v_status <> 'idle' THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ecriture malgre le refus (status='||v_status||')');
      ELSE v_passed := v_passed+1; END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 deposer un fichier sur une source OAI est refuse a la coordination';
  BEGIN
    PERFORM public.fn_import_create(v_src, 'oai/essai2', 'oai-essai2');
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
    IF v_hint = v_hint_attendu THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')||' / '||SQLERRM); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 promouvoir un lot moissonne est refuse a la coordination, sans brouillon cree';
  BEGIN
    BEGIN
      PERFORM public.fn_import_promote(v_run);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint <> v_hint_attendu THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')||' / '||SQLERRM);
      ELSIF (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run) <> 0 THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : des brouillons ont ete crees malgre le refus');
      ELSE v_passed := v_passed+1; END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 l''admin reseau passe les trois gardes (le chemin OAI n''est pas mort)';
  BEGIN
    INSERT INTO public.network_administrators (user_id, status) VALUES (v_coord, 'active');

    -- create : la garde doit etre passee
    v_res := public.fn_import_create(v_src, 'oai/essai3', 'oai-essai3');
    IF NOT coalesce((v_res->>'ok')::boolean, false) THEN
      RAISE EXCEPTION 'create : %', coalesce(v_res::text, 'NULL');
    END IF;

    -- promote et harvest : un echec plus loin (dispatch pg_net, corps du lot)
    -- n'est pas le sujet ; ce qui compte est que le HINT du refus n'apparaisse pas.
    BEGIN
      PERFORM public.fn_import_promote(v_run);
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = v_hint_attendu THEN RAISE EXCEPTION 'promote refuse a l''admin : %', SQLERRM; END IF;
    END;
    BEGIN
      PERFORM public.fn_import_harvest_oai(v_src);
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = v_hint_attendu THEN RAISE EXCEPTION 'harvest refuse a l''admin : %', SQLERRM; END IF;
    END;
    v_passed := v_passed+1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 les droits n''ont pas bouge : executables par authenticated, fermees a anon et PUBLIC';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public'
       AND routine_name IN ('fn_import_harvest_oai', 'fn_import_create', 'fn_import_promote')
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n <> 0 THEN RAISE EXCEPTION '% droit(s) anon/PUBLIC de trop', v_n; END IF;
    SELECT count(DISTINCT routine_name) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public'
       AND routine_name IN ('fn_import_harvest_oai', 'fn_import_create', 'fn_import_promote')
       AND grantee = 'authenticated' AND privilege_type = 'EXECUTE';
    IF v_n = 3 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/3 executables par authenticated'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-MOISSON-OAI-ADMIN OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-MOISSON-OAI-ADMIN ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
