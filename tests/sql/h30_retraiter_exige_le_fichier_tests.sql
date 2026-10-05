-- =====================================================================
-- AnarBib — Tests d'acceptation : « Retraiter » exige le fichier (H30)
-- Date    : 2026-10-04
-- Ref     : migration 20261005064758_retraiter_exige_le_fichier
--           (fn_import_dispatch(p_run_id, force_reparse => true) refuse,
--           HINT error.import.reparse_no_file, un run dont l'objet n'est pas
--           dans storage.objects : seau du run, sinon catalogos_parceiros_raw ;
--           nom = btrim(storage_path) ; garde APRÈS reparse_after_promotion,
--           AVANT profile_missing)
--
-- Gestes : la coordination de BLMF (seed), par l'API (SET LOCAL ROLE
-- authenticated, request.jwt.claims), comme ImportacoesPage.handleReprocess.
-- Décor (runs, lignes, objets du seau, profil) écrit en postgres : le bouchon
-- storage de la CI (_ci_setup_storage_stub.sql) a une table storage.objects
-- VIDE, chaque cas y dépose ce qu'il lui faut.
--
-- SÉCURITÉ. Le relais d'envoi ingest.fn_dispatch_partner_catalog_import fait
-- un net.http_post vers les edge functions de l'instance avec le secret du
-- coffre — sur le banc local, celles de la PRODUCTION. Il est remplacé, dès
-- l'entrée, par un TÉMOIN (rend run_id et force_reparse), vérifié AVANT tout
-- appel (sinon la suite s'arrête) ; tous les cas se jouent dans une
-- sous-transaction que la suite lève elle-même, et qui emporte le témoin.
--
-- H1  run CSV analysé (2 lignes), aucun objet : refus reparse_no_file ; run
--     (statut, compteurs) et lignes (ids, décisions) intacts, aucun envoi
--     journalisé.
-- H2  chemins de CONVENTION que rien ne lit : moisson OAI (oai/<source>/<date>),
--     candidat institutionnel (lookup/<biblio>/<date>), dépôt direct de fonds
--     (seau partner-catalog-deposits, direct/<source>/<cible>, des fichiers
--     reçus SOUS ce préfixe) : trois refus reparse_no_file, runs et lignes
--     intacts — un « dossier » n'est pas le fichier.
-- H3  objet présent (seau par défaut, nom = storage_path) : accepté jusqu'au
--     témoin (run_id, force_reparse vrai), run intact.
-- H4  storage_path entouré d'espaces, objet au nom nu : accepté (btrim).
-- H5  bucket_id vide ('') et blanc ('   ') : le seau par défaut est lu,
--     accepté ; bucket_id NULL — impossible en vrai (colonne NOT NULL, vérifié)
--     — accepté de même, la contrainte levée le temps du cas.
-- H6  le seau compte : run au seau par défaut, objet du même nom dans
--     partner-catalog-deposits seulement : refus ; run au seau
--     partner-catalog-deposits, objet dans le seau par défaut seulement :
--     refus ; run et objet dans partner-catalog-deposits : accepté.
-- H7  ordre des gardes : run PROMU, sans fichier : c'est
--     reparse_after_promotion qui parle.
-- H8  ordre des gardes : profil supprimé depuis l'import, fichier présent :
--     profile_missing ; profil supprimé ET pas de fichier : reparse_no_file
--     (la garde H30 passe avant celle du profil).
-- H9  premier envoi (force_reparse faux, puis NULL), sans fichier : la garde
--     H30 ne s'en mêle pas, accepté jusqu'au témoin.
-- H10 aucune requête pg_net (net.http_request_queue inchangée, mesurée DANS la
--     sous-transaction), aucun envoi journalisé pour les runs de la suite, et
--     l'envoi réel revenu après la sous-transaction (net.http_post dans la
--     définition du relais).
--
-- Contre-épreuves (04/10/2026, banc privé anarbib_h30, mutants hors dépôt :
-- définition vivante de fn_import_dispatch, ancre comptée, CREATE OR REPLACE,
-- dans une transaction annulée) :
--   sans la garde H30                     : H1 H2 H6 H8 tombent ;
--   sans btrim sur storage_path           : H4 tombe ;
--   seau du run lu tel quel (sans repli)  : H5 tombe ;
--   seau par défaut toujours (run ignoré) : H6 tombe ;
--   garde H30 AVANT celle de la promotion : H7 tombe ;
--   garde H30 APRÈS celle du profil       : H8 tombe ;
--   garde H30 aussi au premier envoi      : H9 tombe.
--   H3 : témoin (ne tombe avec aucune) ; H10 : garde de sécurité de la suite.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE (en CI,
-- run-sql-suites.sh la joue par psql -f, sans transaction englobante).
--   Bilan OK : 'H30-RETRAITER-FICHIER OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lib   uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  c_def   constant text := 'catalogos_parceiros_raw';
  c_dep   constant text := 'partner-catalog-deposits';
  v_src bigint; v_src_dep bigint; v_runs bigint[] := ARRAY[]::bigint[];
  v_r1 bigint; v_r2 bigint; v_r3 bigint; v_r4 bigint;
  v_h1 text; v_h2 text; v_h3 text; v_h4 text;
  v_res1 jsonb; v_res2 jsonb; v_res3 jsonb; v_res4 jsonb;
  v_e0 text; v_e1 text; v_res jsonb; v_prof bigint; v_nn boolean;
  v_q0 bigint; v_q1 bigint; v_log bigint; v_temoin boolean; v_reel boolean;
BEGIN
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H30 Essai retraiter', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H30 Essai depot direct', v_lib, 'mutualizacao_autorizada', 'partner_deposit', true) RETURNING id INTO v_src_dep;
  -- état d'un run : statut, compteurs, seau, chemin ; ses lignes (id, décision)
  EXECUTE $f$CREATE FUNCTION pg_temp.h30_etat(p_run bigint) RETURNS text LANGUAGE sql AS $b$
    SELECT r.run_status || '/' || r.imported_rows || '/' || r.bucket_id || '/' || r.storage_path || '['
           || coalesce((SELECT string_agg(sr.id || ':' || sr.editorial_decision || ':' || sr.match_status, ',' ORDER BY sr.id)
                          FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = r.id), '') || ']'
      FROM ingest.partner_catalog_import_runs r WHERE r.id = p_run $b$ $f$;

  BEGIN  -- sous-transaction LEVÉE à la fin : emporte le témoin et tout le décor
    EXECUTE $f$CREATE OR REPLACE FUNCTION ingest.fn_dispatch_partner_catalog_import(p_run_id bigint, p_force_reparse boolean DEFAULT false)
      RETURNS jsonb LANGUAGE sql
      AS $b$ SELECT jsonb_build_object('temoin_h30', true, 'run_id', p_run_id, 'force_reparse', p_force_reparse) $b$ $f$;
    IF position('temoin_h30' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) = 0
       OR position('net.http_post' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0 THEN
      RAISE EXCEPTION 'H30 : le témoin d''envoi n''est pas en place — arrêt avant tout appel';
    END IF;
    SELECT count(*) INTO v_q0 FROM net.http_request_queue;

    -- ── H1 ──────────────────────────────────────────────────────────────
    v_t := 'H1 run CSV sans objet dans le seau : refus reparse_no_file, run et lignes intacts';
    BEGIN
      v_h1 := NULL; v_res1 := NULL;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src, v_lib, 'essai/h30-h1.csv', 'h30-h1.csv', 'csv', 'ready_for_review', 2) RETURNING id INTO v_r1;
      v_runs := v_runs || v_r1;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
      VALUES (v_r1, 1, 'H30-H1-1', 'H30 ligne 1', 'new_record', 'accept_new'),
             (v_r1, 2, 'H30-H1-2', 'H30 ligne 2', 'new_record', 'pending');
      v_e0 := pg_temp.h30_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN v_res1 := public.fn_import_dispatch(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h30_etat(v_r1);
      IF v_h1 = 'error.import.reparse_no_file'
         AND v_e0 LIKE 'ready_for_review/2/%' AND v_e0 LIKE '%,%' AND v_e1 = v_e0
         AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_dispatch_log WHERE run_id = v_r1)
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1,'NULL')||' '||left(coalesce(v_res1::text,''), 80)
           ||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H2 ──────────────────────────────────────────────────────────────
    v_t := 'H2 chemins de convention (oai/, lookup/, direct/ avec fichiers recus sous le prefixe) : trois refus reparse_no_file, runs intacts';
    BEGIN
      v_h1 := NULL; v_h2 := NULL; v_h3 := NULL;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src, v_lib, 'oai/' || v_src || '/' || current_date, 'oai-harvest-' || current_date, 'oai_pmh', 'ready_for_review', 1)
      RETURNING id INTO v_r1;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src, v_lib, 'lookup/' || v_lib || '/' || current_date, 'lookup-' || current_date, 'lookup', 'ready_for_review', 1)
      RETURNING id INTO v_r2;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, bucket_id, storage_path, original_filename, run_status, parser_version, imported_rows)
      VALUES (v_src_dep, v_lib, c_dep, 'direct/' || v_lib || '/' || v_lib, 'fonds-direct-H30', 'ready_for_review', 'fonds_direct_v1', 1)
      RETURNING id INTO v_r3;
      v_runs := v_runs || v_r1 || v_r2 || v_r3;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
      VALUES (v_r1, 1, 'H30-H2-OAI', 'H30 moisson', 'new_record', 'pending'),
             (v_r2, 1, 'H30-H2-LKP', 'H30 candidat', 'new_record', 'pending'),
             (v_r3, 1, 'H30-H2-DIR', 'H30 depot direct', 'new_record', 'pending');
      -- le dépôt direct a bien reçu des fichiers, SOUS son chemin de convention
      INSERT INTO storage.objects (bucket_id, name)
      VALUES (c_dep, 'direct/' || v_lib || '/' || v_lib || '/fonds.zip'),
             (c_dep, 'direct/' || v_lib || '/' || v_lib || '/notices.mrc');
      v_e0 := pg_temp.h30_etat(v_r1) || ' ' || pg_temp.h30_etat(v_r2) || ' ' || pg_temp.h30_etat(v_r3);
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN PERFORM public.fn_import_dispatch(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      BEGIN PERFORM public.fn_import_dispatch(v_r2, true); v_h2 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      BEGIN PERFORM public.fn_import_dispatch(v_r3, true); v_h3 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h3 = PG_EXCEPTION_HINT; v_h3 := coalesce(nullif(v_h3, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h30_etat(v_r1) || ' ' || pg_temp.h30_etat(v_r2) || ' ' || pg_temp.h30_etat(v_r3);
      IF v_h1 = 'error.import.reparse_no_file' AND v_h2 = 'error.import.reparse_no_file' AND v_h3 = 'error.import.reparse_no_file'
         AND v_e0 IS NOT NULL AND v_e1 = v_e0
         AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_dispatch_log WHERE run_id IN (v_r1, v_r2, v_r3))
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : oai='||coalesce(v_h1,'NULL')||' lookup='||coalesce(v_h2,'NULL')
           ||' direct='||coalesce(v_h3,'NULL')||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H3 ──────────────────────────────────────────────────────────────
    v_t := 'H3 objet present (seau par defaut, nom = storage_path) : accepte jusqu''au temoin, run intact';
    BEGIN
      v_h1 := NULL; v_res1 := NULL;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src, v_lib, 'essai/h30-h3.csv', 'h30-h3.csv', 'csv', 'ready_for_review', 1) RETURNING id INTO v_r1;
      v_runs := v_runs || v_r1;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
      VALUES (v_r1, 1, 'H30-H3-1', 'H30 ligne', 'new_record', 'pending');
      INSERT INTO storage.objects (bucket_id, name) VALUES (c_def, 'essai/h30-h3.csv');
      v_e0 := pg_temp.h30_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN v_res1 := public.fn_import_dispatch(v_r1, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h30_etat(v_r1);
      IF v_h1 IS NULL AND coalesce((v_res1->>'temoin_h30')::boolean, false)
         AND (v_res1->>'run_id')::bigint = v_r1 AND coalesce((v_res1->>'force_reparse')::boolean, false)
         AND v_e1 = v_e0
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1, left(coalesce(v_res1::text,'NULL'), 120))); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H4 ──────────────────────────────────────────────────────────────
    v_t := 'H4 storage_path entoure d''espaces, objet au nom nu : accepte (btrim)';
    BEGIN
      v_h1 := NULL; v_res1 := NULL;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, '  essai/h30-h4.csv  ', 'h30-h4.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r1;
      v_runs := v_runs || v_r1;
      INSERT INTO storage.objects (bucket_id, name) VALUES (c_def, 'essai/h30-h4.csv');
      IF EXISTS (SELECT 1 FROM storage.objects o JOIN ingest.partner_catalog_import_runs r ON o.name = r.storage_path WHERE r.id = v_r1) THEN
        RAISE EXCEPTION 'decor : un objet porte le chemin non nettoye';
      END IF;
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN v_res1 := public.fn_import_dispatch(v_r1, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      IF v_h1 IS NULL AND coalesce((v_res1->>'temoin_h30')::boolean, false) AND (v_res1->>'run_id')::bigint = v_r1
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1, left(coalesce(v_res1::text,'NULL'), 120))); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H5 ──────────────────────────────────────────────────────────────
    v_t := 'H5 bucket_id vide, blanc ou NULL : le seau par defaut est lu, accepte (NULL : colonne NOT NULL en vrai, contrainte levee le temps du cas)';
    BEGIN
      v_h1 := NULL; v_h2 := NULL; v_h3 := NULL; v_res1 := NULL; v_res2 := NULL; v_res3 := NULL;
      SELECT a.attnotnull INTO v_nn FROM pg_attribute a
       WHERE a.attrelid = 'ingest.partner_catalog_import_runs'::regclass AND a.attname = 'bucket_id';
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, bucket_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, '', 'essai/h30-h5a.csv', 'h30-h5a.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r1;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, bucket_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, '   ', 'essai/h30-h5b.csv', 'h30-h5b.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r2;
      v_runs := v_runs || v_r1 || v_r2;
      INSERT INTO storage.objects (bucket_id, name)
      VALUES (c_def, 'essai/h30-h5a.csv'), (c_def, 'essai/h30-h5b.csv'), (c_def, 'essai/h30-h5c.csv');
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN v_res1 := public.fn_import_dispatch(v_r1, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      BEGIN v_res2 := public.fn_import_dispatch(v_r2, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      -- NULL : décor impossible en vrai, joué dans une sous-transaction annulée
      BEGIN
        ALTER TABLE ingest.partner_catalog_import_runs ALTER COLUMN bucket_id DROP NOT NULL;
        INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, bucket_id, storage_path, original_filename, detected_format, run_status)
        VALUES (v_src, v_lib, NULL, 'essai/h30-h5c.csv', 'h30-h5c.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r3;
        EXECUTE 'SET LOCAL ROLE authenticated';
        BEGIN v_res3 := public.fn_import_dispatch(v_r3, true);
        EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h3 = PG_EXCEPTION_HINT; v_h3 := coalesce(nullif(v_h3, ''), SQLERRM); END;
        EXECUTE 'RESET ROLE';
        RAISE EXCEPTION 'h30-h5-annule';
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM IS DISTINCT FROM 'h30-h5-annule' THEN RAISE; END IF;
      END;
      IF v_nn
         AND (SELECT attnotnull FROM pg_attribute WHERE attrelid = 'ingest.partner_catalog_import_runs'::regclass AND attname = 'bucket_id')
         AND v_h1 IS NULL AND (v_res1->>'run_id')::bigint = v_r1 AND coalesce((v_res1->>'temoin_h30')::boolean, false)
         AND v_h2 IS NULL AND (v_res2->>'run_id')::bigint = v_r2 AND coalesce((v_res2->>'temoin_h30')::boolean, false)
         AND v_h3 IS NULL AND v_r3 IS NOT NULL AND (v_res3->>'run_id')::bigint = v_r3 AND coalesce((v_res3->>'temoin_h30')::boolean, false)
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : not null='||coalesce(v_nn::text,'NULL')
           ||' vide='||coalesce(v_h1, left(coalesce(v_res1::text,'NULL'), 60))
           ||' blanc='||coalesce(v_h2, left(coalesce(v_res2::text,'NULL'), 60))
           ||' null='||coalesce(v_h3, left(coalesce(v_res3::text,'NULL'), 60))); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H6 ──────────────────────────────────────────────────────────────
    v_t := 'H6 le seau compte : objet dans un AUTRE seau que celui du run, refus (dans les deux sens) ; run et objet dans partner-catalog-deposits, accepte';
    BEGIN
      v_h1 := NULL; v_h2 := NULL; v_h3 := NULL; v_res3 := NULL;
      -- run au seau par défaut, objet du même nom dans l'autre seau seulement
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h30-h6a.csv', 'h30-h6a.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r1;
      -- run à l'autre seau, objet du même nom dans le seau par défaut seulement
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, bucket_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, c_dep, 'essai/h30-h6b.csv', 'h30-h6b.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r2;
      -- témoin : run et objet dans l'autre seau
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, bucket_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, c_dep, 'essai/h30-h6c.csv', 'h30-h6c.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r3;
      v_runs := v_runs || v_r1 || v_r2 || v_r3;
      INSERT INTO storage.objects (bucket_id, name)
      VALUES (c_dep, 'essai/h30-h6a.csv'), (c_def, 'essai/h30-h6b.csv'), (c_dep, 'essai/h30-h6c.csv');
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN PERFORM public.fn_import_dispatch(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      BEGIN PERFORM public.fn_import_dispatch(v_r2, true); v_h2 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      BEGIN v_res3 := public.fn_import_dispatch(v_r3, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h3 = PG_EXCEPTION_HINT; v_h3 := coalesce(nullif(v_h3, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      IF v_h1 = 'error.import.reparse_no_file' AND v_h2 = 'error.import.reparse_no_file'
         AND v_h3 IS NULL AND (v_res3->>'run_id')::bigint = v_r3 AND coalesce((v_res3->>'temoin_h30')::boolean, false)
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : objet dans l''autre seau='||coalesce(v_h1,'NULL')
           ||' objet dans le seau par defaut seulement='||coalesce(v_h2,'NULL')
           ||' temoin='||coalesce(v_h3, left(coalesce(v_res3::text,'NULL'), 80))); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H7 ──────────────────────────────────────────────────────────────
    v_t := 'H7 ordre des gardes : run promu, sans fichier : reparse_after_promotion parle (pas reparse_no_file), run et lien intacts';
    BEGIN
      v_h1 := NULL;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h30-h7.csv', 'h30-h7.csv', 'csv', 'ready_for_review') RETURNING id INTO v_r1;
      v_runs := v_runs || v_r1;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
      VALUES (v_r1, 1, 'H30-H7-1', 'H30 promue', 'new_record', 'accept_new');
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_import_promote(v_r1, ARRAY['new_record'], ARRAY['accept_new']);
      EXECUTE 'RESET ROLE';
      IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = v_r1)
         OR EXISTS (SELECT 1 FROM storage.objects o JOIN ingest.partner_catalog_import_runs r
                      ON o.name = btrim(r.storage_path) WHERE r.id = v_r1) THEN
        RAISE EXCEPTION 'decor : promotion=% ', left(coalesce(v_res::text, 'NULL'), 160);
      END IF;
      v_e0 := pg_temp.h30_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN PERFORM public.fn_import_dispatch(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h30_etat(v_r1);
      IF v_h1 = 'error.import.reparse_after_promotion' AND v_e1 = v_e0
         AND EXISTS (SELECT 1 FROM ingest.partner_catalog_row_to_draft l WHERE l.run_id = v_r1)
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H8 ──────────────────────────────────────────────────────────────
    v_t := 'H8 ordre des gardes : profil supprime + fichier present : profile_missing ; profil supprime sans fichier : reparse_no_file';
    BEGIN
      v_h1 := NULL; v_h2 := NULL;
      v_res := public.fn_import_profile_create(v_lib, 'Profil ephemere (H30)', '{}'::jsonb, '{}'::jsonb, '{"code": "b"}'::jsonb);
      v_prof := (v_res->>'id')::bigint;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, adapter_overrides)
      VALUES (v_src, v_lib, 'essai/h30-h8a.marc', 'h30-h8a.marc', 'marc_iso2709', 'ready_for_review', jsonb_build_object('profile_id', v_prof))
      RETURNING id INTO v_r1;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, adapter_overrides)
      VALUES (v_src, v_lib, 'essai/h30-h8b.marc', 'h30-h8b.marc', 'marc_iso2709', 'ready_for_review', jsonb_build_object('profile_id', v_prof))
      RETURNING id INTO v_r2;
      v_runs := v_runs || v_r1 || v_r2;
      INSERT INTO storage.objects (bucket_id, name) VALUES (c_def, 'essai/h30-h8a.marc');
      DELETE FROM ingest.import_profiles WHERE id = v_prof;
      IF v_prof IS NULL OR EXISTS (SELECT 1 FROM ingest.import_profiles WHERE id = v_prof) THEN
        RAISE EXCEPTION 'decor : profil=% ', left(coalesce(v_res::text, 'NULL'), 160);
      END IF;
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN PERFORM public.fn_import_dispatch(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      BEGIN PERFORM public.fn_import_dispatch(v_r2, true); v_h2 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      IF v_h1 = 'error.import.profile_missing' AND v_h2 = 'error.import.reparse_no_file'
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : fichier present='||coalesce(v_h1,'NULL')
           ||' sans fichier='||coalesce(v_h2,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── H9 ──────────────────────────────────────────────────────────────
    v_t := 'H9 premier envoi (force_reparse faux, puis NULL) sans fichier : pas refuse par H30, accepte jusqu''au temoin';
    BEGIN
      v_h1 := NULL; v_h2 := NULL; v_res1 := NULL; v_res2 := NULL;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h30-h9a.csv', 'h30-h9a.csv', 'csv', 'uploaded') RETURNING id INTO v_r1;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status)
      VALUES (v_src, v_lib, 'essai/h30-h9b.csv', 'h30-h9b.csv', 'csv', 'uploaded') RETURNING id INTO v_r2;
      v_runs := v_runs || v_r1 || v_r2;
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN v_res1 := public.fn_import_dispatch(v_r1, false);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      BEGIN v_res2 := public.fn_import_dispatch(v_r2, NULL);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      IF v_h1 IS NULL AND coalesce((v_res1->>'temoin_h30')::boolean, false) AND (v_res1->>'run_id')::bigint = v_r1
         AND (v_res1->>'force_reparse')::boolean IS FALSE
         AND v_h2 IS NULL AND coalesce((v_res2->>'temoin_h30')::boolean, false) AND (v_res2->>'run_id')::bigint = v_r2
         AND NOT coalesce((v_res2->>'force_reparse')::boolean, false)
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : faux='||coalesce(v_h1, left(coalesce(v_res1::text,'NULL'), 80))
           ||' NULL='||coalesce(v_h2, left(coalesce(v_res2::text,'NULL'), 80))); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- mesures de H10, DANS la sous-transaction (elle emporte la file avec elle)
    SELECT count(*) INTO v_q1 FROM net.http_request_queue;
    SELECT count(*) INTO v_log FROM ingest.partner_catalog_import_dispatch_log WHERE run_id = ANY (v_runs);
    v_temoin := position('temoin_h30' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0;
    RAISE EXCEPTION 'h30-annule';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM IS DISTINCT FROM 'h30-annule' THEN RAISE; END IF;
  END;

  -- ── H10 ─────────────────────────────────────────────────────────────
  v_t := 'H10 aucune requete pg_net, aucun envoi journalise, l''envoi reel revenu apres la sous-transaction';
  v_reel := position('net.http_post' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0
            AND position('temoin_h30' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) = 0;
  IF v_q0 IS NOT NULL AND v_q1 = v_q0 AND v_log = 0 AND coalesce(array_length(v_runs, 1), 0) > 0
     AND v_temoin AND v_reel
     AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = ANY (v_runs))
  THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : file pg_net='||coalesce(v_q0::text,'NULL')||'->'||coalesce(v_q1::text,'NULL')
       ||' envois journalises='||coalesce(v_log::text,'NULL')||' runs='||coalesce(array_length(v_runs, 1), 0)
       ||' temoin en place pendant='||coalesce(v_temoin::text,'NULL')||' envoi reel revenu='||coalesce(v_reel::text,'NULL')); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H30-RETRAITER-FICHIER OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'H30-RETRAITER-FICHIER ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
