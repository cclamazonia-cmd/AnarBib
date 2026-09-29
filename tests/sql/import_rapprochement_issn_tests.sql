-- =====================================================================
-- AnarBib — Tests d'acceptation : le rapprochement par ISSN ne prend pas un
-- article pour sa revue
-- Date    : 2026-09-29  ·  revue contradictoire de la fin de H27
-- Ref     : migration 20260929102719_le_rapprochement_distingue_le_fascicule_de_sa_revue
--
-- Un article porte l'ISSN de sa revue (H17). Depuis que l'ISSN d'un
-- périodique PMB est rangé en ISSN (et non plus en ISBN), la ligne d'une
-- revue trouvait par « issn_exact » la revue ET ses articles, au même score :
-- le candidat retenu dépendait de l'ordre physique des notices.
--
-- T1 l'article est entré AVANT sa revue : la ligne de la revue propose la revue.
-- T2 aucun candidat « issn_exact » n'est un article.
-- T3 la ligne d'un article (même ISSN) n'est pas rapprochée par ISSN.
-- T4 une monographie qui porte un ISSN par erreur reste candidate (seul
--    l'article est écarté).
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'IMPORT-RAPPROCHEMENT-ISSN OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_src bigint; v_run bigint; v_res jsonb;
  v_art bigint; v_per bigint; v_mono bigint;
  v_l_per bigint; v_l_art bigint; v_l_mono bigint;
BEGIN
  -- L'article d'abord : l'ordre physique qui faisait sortir l'article.
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, ano, issn)
  VALUES ('ESSAI-RI-1', 'Classer sans dominer', 'artigo', 'fr', '2025', '2555-0004') RETURNING id INTO v_art;
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, issn)
  VALUES ('ESSAI-RI-2', 'Le Rat des bibliothèques', 'periodico', 'fr', '2555-0004') RETURNING id INTO v_per;
  INSERT INTO public.books (bib_ref, titulo, tipo_material, idioma, ano, issn)
  VALUES ('ESSAI-RI-3', 'Annuaire des bibliothèques rebelles', 'livro', 'fr', '2024', '1111-2222') RETURNING id INTO v_mono;

  INSERT INTO ingest.partner_catalog_sources (partner_name, relation_status, source_kind, import_enabled)
  VALUES ('Essai rapprochement ISSN', 'mapeada', 'manual_upload', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, storage_path, original_filename)
  VALUES (v_src, 'essai/issn.iso', 'issn.iso') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, issn, normalized_payload)
  VALUES (v_run, 1, '72', 'Le Rat des bibliotheques (nouvelle serie)', '2555-0004', '{"material_type": "periodico"}'::jsonb)
  RETURNING id INTO v_l_per;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, issn, normalized_payload)
  VALUES (v_run, 2, '74', 'Un autre article de la meme revue', '2555-0004', '{"material_type": "artigo"}'::jsonb)
  RETURNING id INTO v_l_art;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, issn, normalized_payload)
  VALUES (v_run, 3, '75', 'Annuaire 2025', '1111-2222', '{"material_type": "livro"}'::jsonb)
  RETURNING id INTO v_l_mono;

  -- ── T1 ──────────────────────────────────────────────────────────────
  v_t := 'T1 la ligne de la revue propose la revue, pas son article';
  BEGIN
    v_res := ingest.fn_match_partner_catalog_row(v_l_per);
    IF (SELECT match_status = 'matched_book' AND proposed_book_id = v_per
          FROM ingest.partner_catalog_staging_rows WHERE id = v_l_per)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text||' (revue '||v_per||', article '||v_art||')'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T2 ──────────────────────────────────────────────────────────────
  v_t := 'T2 aucun candidat issn_exact n''est un article';
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_match_candidates mc
                    WHERE mc.staging_row_id = v_l_per AND mc.candidate_type = 'book' AND mc.candidate_id = v_art)
       AND EXISTS (SELECT 1 FROM ingest.partner_catalog_match_candidates mc
                    WHERE mc.staging_row_id = v_l_per AND mc.match_method = 'issn_exact' AND mc.candidate_id = v_per)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||(SELECT coalesce(string_agg(candidate_id::text||'/'||match_method, ', '), '∅')
           FROM ingest.partner_catalog_match_candidates WHERE staging_row_id = v_l_per)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T3 ──────────────────────────────────────────────────────────────
  v_t := 'T3 la ligne d''un article n''est pas rapprochée par ISSN';
  BEGIN
    v_res := ingest.fn_match_partner_catalog_row(v_l_art);
    IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_match_candidates mc
                    WHERE mc.staging_row_id = v_l_art AND mc.match_method = 'issn_exact')
       AND (SELECT match_status FROM ingest.partner_catalog_staging_rows WHERE id = v_l_art) = 'new_record'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T4 ──────────────────────────────────────────────────────────────
  v_t := 'T4 une notice qui n''est pas un article reste candidate';
  BEGIN
    v_res := ingest.fn_match_partner_catalog_row(v_l_mono);
    IF (SELECT match_status = 'matched_book' AND proposed_book_id = v_mono
          FROM ingest.partner_catalog_staging_rows WHERE id = v_l_mono)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-RAPPROCHEMENT-ISSN OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'IMPORT-RAPPROCHEMENT-ISSN ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
