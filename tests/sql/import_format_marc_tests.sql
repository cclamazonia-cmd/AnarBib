-- =====================================================================
-- AnarBib — Tests d'acceptation : un fichier MARC ISO 2709 s'importe (H28)
-- Date    : 2026-09-26  ·  Session : aller-retour PMB (G15, H14)
-- Ref     : migration 20260926184500_h28_le_format_iso2709_est_admis
--
-- Pourquoi cette suite existe : la CHECK detected_format n'admettait ni le
-- mot que l'EF ecrit pour un fichier ISO 2709 ('marc_iso2709') ni celui que
-- le front envoyait pour un .mrc/.marc ('marc21'). Aucun run MARC n'avait
-- jamais tourne : le defaut etait invisible.
--
-- T1 : la CHECK admet 'marc_iso2709' et 'marcxml', pas de vocabulaire
--      ('marc21', 'unimarc'). T2 : la coordination cree un run ISO 2709 sur
--      SON catalogue (fn_import_create, comme le front). T3 : l'UPDATE final
--      de l'EF (detected_format = 'marc_iso2709') passe. T4 : 'marc21' reste
--      refuse (23514) — le front ne doit plus l'envoyer.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-FORMAT-MARC OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_con text; v_res jsonb; v_src bigint; v_run bigint; v_fmt text; v_state text;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── T1 : la CHECK dit les formats, pas les vocabulaires ─────────────────
  v_t := 'T1 la CHECK admet marc_iso2709 et marcxml, pas marc21 ni unimarc';
  BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
     WHERE c.conname = 'partner_catalog_import_runs_detected_format_check'
       AND c.conrelid = 'ingest.partner_catalog_import_runs'::regclass;
    IF v_con IS NOT NULL
       AND position('''marc_iso2709''' in v_con) > 0
       AND position('''marcxml''' in v_con) > 0
       AND position('''marc21''' in v_con) = 0
       AND position('''unimarc''' in v_con) = 0 THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_con,'<contrainte absente>')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 : la coordination cree un run ISO 2709 sur son catalogue ─────────
  v_t := 'T2 fn_import_create accepte p_detected_format = marc_iso2709 (un export PMB .marc)';
  BEGIN
    v_res := public.fn_import_own_source();
    v_src := (v_res->>'source_id')::bigint;
    v_res := public.fn_import_create(v_src, 'essai/export-pmb.marc', 'export-pmb.marc',
                                     p_detected_format := 'marc_iso2709');
    v_run := (v_res->>'run_id')::bigint;
    SELECT r.detected_format INTO v_fmt FROM ingest.partner_catalog_import_runs r WHERE r.id = v_run;
    IF coalesce((v_res->>'ok')::boolean, false) AND v_fmt = 'marc_iso2709' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fmt='||coalesce(v_fmt,'NULL')||' res='||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 : l'UPDATE final de l'EF passe ───────────────────────────────────
  -- Forme de index.ts (fin du traitement) : le run est cree 'unknown' (fichier
  -- .iso ou .txt dont l'extension ne dit rien), l'EF reconnait l'ISO 2709.
  v_t := 'T3 un run cree unknown recoit detected_format = marc_iso2709 (UPDATE de l''EF)';
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
    VALUES (v_src, v_lib, 'essai/export.iso', 'export.iso', 'unknown', 'processing') RETURNING id INTO v_run;
    UPDATE ingest.partner_catalog_import_runs
       SET detected_format = 'marc_iso2709', run_status = 'ready_for_review'
     WHERE id = v_run;
    SELECT r.detected_format, r.run_status INTO v_fmt, v_state FROM ingest.partner_catalog_import_runs r WHERE r.id = v_run;
    IF v_fmt = 'marc_iso2709' AND v_state = 'ready_for_review' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fmt='||coalesce(v_fmt,'NULL')||' status='||coalesce(v_state,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 : un vocabulaire n'est pas un format ──────────────────────────────
  v_t := 'T4 detected_format = marc21 reste refuse (23514)';
  BEGIN
    UPDATE ingest.partner_catalog_import_runs SET detected_format = 'marc21' WHERE id = v_run;
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION
    WHEN check_violation THEN v_passed := v_passed+1;
    WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLSTATE||' '||SQLERRM);
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-FORMAT-MARC OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMPORT-FORMAT-MARC ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
