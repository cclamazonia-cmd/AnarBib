-- =====================================================================
-- AnarBib — Tests d'acceptation : supprimer un run sans abandonner son lot
-- Date    : 2026-08-29  ·  Session : chantier catalogage / importations
-- Ref     : migration 20260829060000_supprimer_un_run_ne_laisse_pas_son_lot
--
-- Pourquoi cette suite existe : `fn_import_delete_run` supprimait le run et
-- ses lignes `ingest` en CASCADE, mais laissait derriere elle le LOT de
-- catalogage et ses brouillons, qui vivent dans `public`. Rien ne le
-- signalait — la fonction repondait ok. Le 28/08/2026 les runs #13 et #14
-- (CIRA Marseille) ont ete supprimes ainsi : 237 brouillons sont restes sans
-- aucun ecran ou lire leur provenance, et la provenance etait irrecuperable.
--
-- Le test qui compte est T2, et c'est un test de NON-ACTION : le refus ne
-- doit RIEN detruire. Un refus qui aurait deja supprime le fichier de storage
-- ou une partie des lignes serait pire que l'absence de garde.
--
-- T3 tient l'autre moitie de la decision : la CORBEILLE du lot ne bloque pas.
-- Refuser sur elle recreerait l'impasse levee le meme jour cote ecran (un lot
-- dont tous les brouillons sont jetes doit rester supprimable).
--
-- T5 confronte le HINT a ce que la fonction leve REELLEMENT
-- (PG_EXCEPTION_HINT), pas a une chaine recopiee ici qui deriverait avec elle.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE, qui
-- defait la transaction. Rien ne subsiste.
--   Bilan OK : 'IMPORT-SUPPRESSION-RUN OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_src   bigint;
  v_run   bigint;
  v_run_nu bigint;
  v_lot   bigint;
  v_row   bigint;
  v_draft bigint;
  v_res   jsonb;
  v_hint  text;
  v_n     int;
BEGIN
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── Jeu d'essai : une source, un run rattache a la biblio, un lot, un
  --    brouillon actif, et le lien run -> lot que pose la creation reelle. ──
  INSERT INTO ingest.partner_catalog_sources (partner_name, relation_status, source_kind, import_enabled)
  VALUES ('Essai suppression run', 'mapeada', 'manual_upload', true)
  RETURNING id INTO v_src;

  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename)
  VALUES (v_src, v_lib, 'essai/run.csv', 'run.csv') RETURNING id INTO v_run;

  INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status)
  VALUES (v_run, 1, 'k-1', 'Le talon de fer', 'new_record') RETURNING id INTO v_row;

  INSERT INTO public.catalog_batches (name, notes, status)
  VALUES ('Essai — lot du run', 'lot de test', 'open') RETURNING id INTO v_lot;

  INSERT INTO public.book_drafts (titulo, batch_id, status)
  VALUES ('Le talon de fer', v_lot, 'draft') RETURNING id INTO v_draft;

  INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id)
  VALUES (v_row, v_run, v_draft, v_lot);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 le run n''est pas supprimable tant que son lot retient du travail';
  BEGIN
    PERFORM public.fn_import_delete_run(v_run);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    IF position('retient encore' in SQLERRM) > 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 le refus n''a RIEN detruit (run, lot, brouillon, lien)';
  BEGIN
    SELECT (SELECT count(*) FROM ingest.partner_catalog_import_runs WHERE id = v_run)
         + (SELECT count(*) FROM public.catalog_batches WHERE id = v_lot)
         + (SELECT count(*) FROM public.book_drafts WHERE id = v_draft)
         + (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run)
      INTO v_n;
    IF v_n = 4 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/4 survivants'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 la CORBEILLE du lot ne bloque pas la suppression du run';
  BEGIN
    UPDATE public.book_drafts SET status = 'cancelled' WHERE id = v_draft;
    v_res := public.fn_import_delete_run(v_run);
    IF coalesce((v_res->>'ok')::boolean, false) THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 le lot et son brouillon jete survivent au run supprime';
  -- Ils ne sont pas emportes : l'onglet « Lots » sait desormais les retirer
  -- d'un geste, et rien ne doit disparaitre sans decision humaine.
  BEGIN
    SELECT (SELECT count(*) FROM public.catalog_batches WHERE id = v_lot)
         + (SELECT count(*) FROM public.book_drafts WHERE id = v_draft)
      INTO v_n;
    IF v_n = 2 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||'/2 survivants'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 le refus porte le HINT i18n que l''ecran sait traduire';
  BEGIN
    -- On refabrique la situation bloquante sur un run neuf.
    INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename)
    VALUES (v_src, v_lib, 'essai/run2.csv', 'run2.csv') RETURNING id INTO v_run_nu;
    INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status)
    VALUES (v_run_nu, 1, 'k-2', 'Germinal', 'new_record') RETURNING id INTO v_row;
    UPDATE public.book_drafts SET status = 'draft' WHERE id = v_draft;
    INSERT INTO ingest.partner_catalog_row_to_draft (staging_row_id, run_id, draft_id, batch_id)
    VALUES (v_row, v_run_nu, v_draft, v_lot);

    BEGIN
      PERFORM public.fn_import_delete_run(v_run_nu);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
      IF v_hint = 'error.import.run_has_drafts' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : hint = '||coalesce(v_hint,'NULL')); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 un run SANS lot reste supprimable (non-regression)';
  BEGIN
    DELETE FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_run_nu;
    v_res := public.fn_import_delete_run(v_run_nu);
    IF coalesce((v_res->>'ok')::boolean, false)
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_run_nu)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 la RPC n''est ouverte ni a anon ni a PUBLIC';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public' AND routine_name = 'fn_import_delete_run'
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' droit(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-SUPPRESSION-RUN OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-SUPPRESSION-RUN ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
