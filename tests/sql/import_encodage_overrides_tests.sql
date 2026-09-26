-- =====================================================================
-- AnarBib — Tests d'acceptation : l'encodage d'un import se regle, et un
-- import deja promu ne se retraite pas (H15)
-- Date    : 2026-09-26  ·  Session : aller-retour PMB (G15, H14)
-- Ref     : migration 20260926191500_h15_encodage_de_l_import
--
-- T1 : forced_encoding pose sur un run de sa biblio. T2 : la FUSION garde
-- profile_id et les autres axes (l'ancienne fonction remplacait tout).
-- T3 : un encodage hors liste fermee est refuse. T4 : un run d'une autre
-- biblio repond 'Run introuvável.' (meme message que l'inexistant). T5 : les
-- droits (anon non, ancienne signature partie). T6 : retraiter un run deja
-- promu en brouillons est refuse avec le HINT reel.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-ENCODAGE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_lib2  uuid;
  v_src bigint; v_src2 bigint; v_run bigint; v_run2 bigint; v_run3 bigint;
  v_res jsonb; v_ov jsonb; v_hint text; v_msg text;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level)
  VALUES (gen_random_uuid(), 'essai-encodage-autre', 'Essai — Autre biblio', false, 'private')
  RETURNING id INTO v_lib2;
  -- Donnee de reference absente du banc (voir lot_importe_bibliotheque_de_destination_tests).
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Essai encodage', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
  VALUES (v_src, v_lib, 'essai/pmb.marc', 'pmb.marc', 'marc_iso2709', 'ready_for_review') RETURNING id INTO v_run;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 forced_encoding windows-1252 pose sur un run de sa biblio';
  BEGIN
    v_res := public.fn_import_set_adapter_overrides(v_run, NULL, NULL, 'Windows-1252');
    SELECT r.adapter_overrides INTO v_ov FROM ingest.partner_catalog_import_runs r WHERE r.id = v_run;
    IF coalesce((v_res->>'ok')::boolean, false) AND v_ov = '{"forced_encoding": "windows-1252"}'::jsonb THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ov='||coalesce(v_ov::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 : fusion ─────────────────────────────────────────────────────
  v_t := 'T2 FUSION : profile_id et une cle etrangere survivent ; un axe remis a auto disparait';
  BEGIN
    UPDATE ingest.partner_catalog_import_runs
       SET adapter_overrides = adapter_overrides || '{"profile_id": 42, "autre": "garde"}'::jsonb
     WHERE id = v_run;
    PERFORM public.fn_import_set_adapter_overrides(v_run, 'marc', 'unimarc', NULL);
    SELECT r.adapter_overrides INTO v_ov FROM ingest.partner_catalog_import_runs r WHERE r.id = v_run;
    IF v_ov = '{"profile_id": 42, "autre": "garde", "forced_format": "marc", "forced_vocabulary": "unimarc"}'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : ov='||coalesce(v_ov::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 : liste fermee ───────────────────────────────────────────────
  v_t := 'T3 un encodage hors liste (macintosh) est refuse, rien n''est ecrit';
  BEGIN
    SELECT r.adapter_overrides INTO v_ov FROM ingest.partner_catalog_import_runs r WHERE r.id = v_run;
    BEGIN
      PERFORM public.fn_import_set_adapter_overrides(v_run, NULL, NULL, 'macintosh');
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM LIKE 'forced_encoding inválido%'
         AND (SELECT r.adapter_overrides FROM ingest.partner_catalog_import_runs r WHERE r.id = v_run) = v_ov
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 : oracle d'existence ─────────────────────────────────────────
  v_t := 'T4 le run d''une autre biblio repond comme un run inexistant';
  BEGIN
    INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
    VALUES ('Essai encodage ailleurs', v_lib2, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src2;
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status)
    VALUES (v_src2, v_lib2, 'essai/ailleurs.marc', 'ailleurs.marc', 'ready_for_review') RETURNING id INTO v_run2;
    BEGIN
      PERFORM public.fn_import_set_adapter_overrides(v_run2, NULL, NULL, 'utf-8');
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      v_msg := SQLERRM;
      IF v_msg = 'Run introuvável.' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_msg); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T5 : droits ─────────────────────────────────────────────────────
  v_t := 'T5 anon n''execute pas la nouvelle signature ; l''ancienne (3 args) n''existe plus';
  BEGIN
    IF NOT has_function_privilege('anon', 'public.fn_import_set_adapter_overrides(bigint,text,text,text)', 'EXECUTE')
       AND has_function_privilege('authenticated', 'public.fn_import_set_adapter_overrides(bigint,text,text,text)', 'EXECUTE')
       AND to_regprocedure('public.fn_import_set_adapter_overrides(bigint,text,text)') IS NULL
       AND NOT has_function_privilege('anon', 'public.fn_import_dispatch(bigint,boolean)', 'EXECUTE')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : droits inattendus'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T6 : pas de retraitement apres promotion ────────────────────────
  v_t := 'T6 retraiter un run deja promu en brouillons est refuse (HINT error.import.reparse_after_promotion)';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, run_status)
    VALUES (v_src, v_lib, 'essai/promu.csv', 'promu.csv', 'drafts_created') RETURNING id INTO v_run3;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
    VALUES (v_run3, 1, 'enc-1', 'Deja vu', 'new_record', 'accept_new');
    v_res := public.fn_import_promote(v_run3, ARRAY['new_record'], ARRAY['accept_new']);
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = v_run3) THEN
      RAISE EXCEPTION 'la promotion n''a pas cree de lien ligne → brouillon : %', left(v_res::text, 200);
    END IF;
    BEGIN
      PERFORM public.fn_import_dispatch(v_run3, true);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.import.reparse_after_promotion'
         AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = v_run3)
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint='||coalesce(v_hint,'NULL')||' / '||SQLERRM); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-ENCODAGE OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMPORT-ENCODAGE ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
