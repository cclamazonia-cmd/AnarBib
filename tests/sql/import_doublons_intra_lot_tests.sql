-- =====================================================================
-- AnarBib — Tests d'acceptation : doublons internes a un lot d'import
-- Date    : 2026-08-28  ·  Session : chantier importations
-- Ref     : migration 20260828210000_doublons_intra_lot_import
--
-- Pourquoi cette suite existe : le rapprochement d'import compare chaque
-- ligne AU CATALOGUE, jamais les lignes du lot ENTRE ELLES. Le listing de
-- la Bibliotheque Solidaires portait neuf paires du meme ouvrage ; les neuf
-- sont sorties 'new_record', et n'ont ete trouvees qu'a la main. La
-- promotion en aurait fait dix-huit livres.
--
-- Les deux tests qui comptent sont T2 et T4, et ce sont des tests de
-- NON-ACTION. T2 tient la lecon de « La cassure » : deux fois le meme
-- titre, deux auteurs differents, deux livres — signaler la aurait appris
-- aux gens a ignorer un signalement. T4 garde qu'un appariement au
-- catalogue, qui en dit plus que le notre, n'est jamais ecrase.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE,
-- qui defait la transaction. Rien ne subsiste.
--   Bilan OK : 'IMPORT-DOUBLONS-INTRA OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_src   bigint;
  v_run   bigint;
  v_run2  bigint;
  v_res   jsonb;
  v_res2  jsonb;
  v_n     int;
  v_txt   text;
  v_a bigint; v_b bigint; v_c bigint; v_d bigint; v_e bigint; v_f bigint;
  v_g bigint; v_h bigint; v_i bigint; v_j bigint;
BEGIN
  -- ── Jeu d'essai : une source, deux lots ──────────────────────────
  INSERT INTO ingest.partner_catalog_sources (partner_name, relation_status, source_kind, import_enabled)
  VALUES ('Essai doublons intra-lot', 'mapeada', 'manual_upload', true)
  RETURNING id INTO v_src;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, storage_path, original_filename)
  VALUES (v_src, 'essai/a.csv', 'a.csv') RETURNING id INTO v_run;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, storage_path, original_filename)
  VALUES (v_src, 'essai/b.csv', 'b.csv') RETURNING id INTO v_run2;

  -- Paire franche : meme titre, meme auteur.
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status, editorial_decision)
  VALUES (v_run, 1, 'k-a', 'Le talon de fer', 'Jack London', 'new_record', 'accept_new') RETURNING id INTO v_a;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status, editorial_decision)
  VALUES (v_run, 2, 'k-b', 'Le talon de fer', 'Jack London', 'new_record', 'accept_new') RETURNING id INTO v_b;

  -- Homonymes : meme titre, auteurs differents (cas « La cassure »).
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run, 3, 'k-c', 'La cassure', 'Martina Cole', 'new_record') RETURNING id INTO v_c;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run, 4, 'k-d', 'La cassure', 'Collectif', 'new_record') RETURNING id INTO v_d;

  -- Deja appariee au catalogue : ne doit pas etre touchee, malgre sa jumelle.
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run, 5, 'k-e', 'Germinal', 'Emile Zola', 'matched_book') RETURNING id INTO v_e;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run, 6, 'k-f', 'Germinal', 'Emile Zola', 'new_record') RETURNING id INTO v_f;

  -- Casse et ponctuation differentes : c'est la meme saisie.
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run, 7, 'k-g', 'L''An 01 : mode d''emploi', 'Gebe', 'new_record') RETURNING id INTO v_g;
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run, 8, 'k-h', 'l an 01  --  MODE D EMPLOI', 'gebe', 'new_record') RETURNING id INTO v_h;

  -- Titre vide des deux cotes : ne doit rien regrouper.
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run, 9, 'k-i', NULL, 'Anonyme', 'new_record') RETURNING id INTO v_i;

  -- Meme ouvrage, mais dans un AUTRE lot : hors sujet.
  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status)
  VALUES (v_run2, 1, 'k-j', 'Le talon de fer', 'Jack London', 'new_record') RETURNING id INTO v_j;

  v_res := ingest.fn_flag_intra_run_duplicates(v_run);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 la paire franche est signalee des deux cotes';
  BEGIN
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_staging_rows
     WHERE id IN (v_a, v_b) AND match_status = 'possible_duplicate';
    IF v_n = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/2'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 meme titre + auteurs differents n''est PAS signale (lecon « La cassure »)';
  BEGIN
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_staging_rows
     WHERE id IN (v_c, v_d) AND match_status = 'possible_duplicate';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' signalee(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 une ligne appariee au catalogue garde son statut';
  BEGIN
    SELECT match_status INTO v_txt FROM ingest.partner_catalog_staging_rows WHERE id = v_e;
    IF v_txt = 'matched_book' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 sa jumelle non appariee ne se signale pas toute seule';
  BEGIN
    SELECT match_status INTO v_txt FROM ingest.partner_catalog_staging_rows WHERE id = v_f;
    IF v_txt = 'new_record' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 la normalisation ignore casse et ponctuation';
  BEGIN
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_staging_rows
     WHERE id IN (v_g, v_h) AND match_status = 'possible_duplicate';
    IF v_n = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/2'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 un titre vide ne regroupe rien';
  BEGIN
    SELECT match_status INTO v_txt FROM ingest.partner_catalog_staging_rows WHERE id = v_i;
    IF v_txt = 'new_record' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 le meme ouvrage dans un AUTRE lot n''est pas concerne';
  BEGIN
    SELECT match_status INTO v_txt FROM ingest.partner_catalog_staging_rows WHERE id = v_j;
    IF v_txt = 'new_record' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 le warning nomme la jumelle, et pas soi-meme';
  BEGIN
    SELECT w->'jumelles' #>> '{0}' INTO v_txt
      FROM ingest.partner_catalog_staging_rows sr,
           jsonb_array_elements(sr.warnings) w
     WHERE sr.id = v_a AND w->>'kind' = 'intra_run_duplicate';
    IF v_txt = 'k-b' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_txt,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 la decision editoriale n''est PAS touchee (signaler n''est pas decider)';
  BEGIN
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_staging_rows
     WHERE id IN (v_a, v_b) AND editorial_decision = 'accept_new';
    IF v_n = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/2'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 le retour compte les groupes et les lignes';
  BEGIN
    IF (v_res->>'groupes')::int = 2 AND (v_res->>'lignes_signalees')::int = 4 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 rejouable : le second passage ne double pas le warning';
  BEGIN
    v_res2 := ingest.fn_flag_intra_run_duplicates(v_run);
    SELECT count(*) INTO v_n
      FROM ingest.partner_catalog_staging_rows sr,
           jsonb_array_elements(sr.warnings) w
     WHERE sr.id = v_a AND w->>'kind' = 'intra_run_duplicate';
    IF v_n = 1 AND v_res2->>'lignes_signalees' = v_res->>'lignes_signalees' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' warning(s), '||v_res2::text); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T12 une ligne corrigee perd son signalement au rejeu';
  BEGIN
    UPDATE ingest.partner_catalog_staging_rows SET title = 'Le talon de fer (tome 2)' WHERE id = v_b;
    PERFORM ingest.fn_flag_intra_run_duplicates(v_run);
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_staging_rows
     WHERE id IN (v_a, v_b) AND match_status = 'possible_duplicate';
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' encore signalee(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T13 le rapprochement APPELLE la detection (sinon elle ne sert a rien)';
  BEGIN
    IF pg_get_functiondef(to_regprocedure('ingest.fn_match_partner_catalog_run(bigint, bigint[])'))
         LIKE '%fn_flag_intra_run_duplicates%' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : appel absent'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T14 la fonction n''est ouverte ni a anon ni a PUBLIC';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'ingest' AND routine_name = 'fn_flag_intra_run_duplicates'
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' droit(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T15 un lot inconnu leve une erreur explicite';
  BEGIN
    BEGIN
      PERFORM ingest.fn_flag_intra_run_duplicates(-1);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucune erreur levee');
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM LIKE '%introuvable%' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ═════════════════════════════════════════════════════════════════
  -- 29/09/2026 (migration 20260929102719_le_rapprochement_distingue_le_fascicule_de_sa_revue) : un fichier MARC porte des notices de
  -- même titre qui ne sont pas la même notice — une revue et ses fascicules,
  -- un ensemble et ses tomes. La clé prend le numéro et la date du fascicule.
  -- Un troisième lot, pour ne rien changer aux comptes de T1 à T15.
  DECLARE
    v_run3 bigint; v_res3 jsonb;
    v_revue bigint; v_f12 bigint; v_f13 bigint; v_f1a bigint; v_f1b bigint; v_d1 bigint; v_d2 bigint;
    v_ens bigint; v_t1 bigint; v_t2 bigint;
  BEGIN
    INSERT INTO ingest.partner_catalog_import_runs (source_id, storage_path, original_filename)
    VALUES (v_src, 'essai/c.iso', 'c.iso') RETURNING id INTO v_run3;
    -- une revue, et deux de ses fascicules (notices de bulletin PMB : le titre est celui de la revue)
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, normalized_payload)
    VALUES (v_run3, 1, '24', 'Géo', 'new_record', '{"material_type": "periodico"}') RETURNING id INTO v_revue;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, normalized_payload)
    VALUES (v_run3, 2, '1-bull', 'Géo', 'new_record', '{"material_type": "periodico", "volume": "277", "issue": {"number": "277", "date": "2004-08-04"}}') RETURNING id INTO v_f12;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, normalized_payload)
    VALUES (v_run3, 3, '2-bull', 'Géo', 'new_record', '{"material_type": "periodico", "volume": "278", "issue": {"number": "278", "date": "2004-09-01"}}') RETURNING id INTO v_f13;
    -- une revue qui renumérote chaque année : même numéro, dates différentes
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, normalized_payload)
    VALUES (v_run3, 4, 'r-1', 'Le Monde libertaire', 'new_record', '{"issue": {"number": "1", "date": "2024-01-01"}}') RETURNING id INTO v_f1a;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, normalized_payload)
    VALUES (v_run3, 5, 'r-2', 'Le Monde libertaire', 'new_record', '{"issue": {"number": "1", "date": "2025-01-01"}}') RETURNING id INTO v_f1b;
    -- le même fascicule saisi deux fois
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, normalized_payload)
    VALUES (v_run3, 6, 'd-1', 'Réfractions', 'new_record', '{"issue": {"number": "N° 12", "date": "2004-05-01"}}') RETURNING id INTO v_d1;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, normalized_payload)
    VALUES (v_run3, 7, 'd-2', 'Réfractions', 'new_record', '{"issue": {"number": "n°12", "date": "2004-05-01"}}') RETURNING id INTO v_d2;
    -- un ensemble et ses deux tomes, même titre, même responsabilité
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status, normalized_payload)
    VALUES (v_run3, 8, '68', 'Chroniques de l''entraide ouvrière', 'Zdeňka Černá', 'new_record', '{}') RETURNING id INTO v_ens;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status, normalized_payload)
    VALUES (v_run3, 9, '69', 'Chroniques de l''entraide ouvrière', 'Zdeňka Černá', 'new_record', '{"volume": "1"}') RETURNING id INTO v_t1;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, responsibility_statement, match_status, normalized_payload)
    VALUES (v_run3, 10, '70', 'Chroniques de l''entraide ouvrière', 'Zdeňka Černá', 'new_record', '{"volume": "Tome 2"}') RETURNING id INTO v_t2;

    v_res3 := ingest.fn_flag_intra_run_duplicates(v_run3);

    v_t := 'T16 une revue et deux de ses fascicules ne sont pas des doublons';
    BEGIN
      IF (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE id IN (v_revue, v_f12, v_f13) AND match_status = 'new_record') = 3
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res3::text); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    v_t := 'T17 deux fascicules de même numéro et de dates différentes ne sont pas des doublons';
    BEGIN
      IF (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE id IN (v_f1a, v_f1b) AND match_status = 'new_record') = 2
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res3::text); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    v_t := 'T18 le même fascicule saisi deux fois reste signalé, et la clé se nomme';
    BEGIN
      IF (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE id IN (v_d1, v_d2) AND match_status = 'possible_duplicate') = 2
         AND (v_res3->>'groupes')::int = 1 AND (v_res3->>'lignes_signalees')::int = 2
         AND (SELECT w->>'cle' FROM ingest.partner_catalog_staging_rows sr, jsonb_array_elements(sr.warnings) w
               WHERE sr.id = v_d1 AND w->>'kind' = 'intra_run_duplicate') = 'titre+responsabilite+numero'
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res3::text); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    v_t := 'T19 un ensemble et ses tomes ne sont pas des doublons';
    BEGIN
      IF (SELECT count(*) FROM ingest.partner_catalog_staging_rows WHERE id IN (v_ens, v_t1, v_t2) AND match_status = 'new_record') = 3
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_res3::text); END IF;
    EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||('T16-T19 : '||SQLERRM);
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-DOUBLONS-INTRA OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-DOUBLONS-INTRA ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
