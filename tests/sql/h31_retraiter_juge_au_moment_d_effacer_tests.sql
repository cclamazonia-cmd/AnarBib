-- =====================================================================
-- AnarBib — Tests d'acceptation : « Retraiter » juge le run au moment
-- d'effacer (H31)
-- Date    : 2026-10-05
-- Ref     : migration 20261005124652_h31_retraiter_juge_au_moment_d_effacer
--           (ingest.fn_h31_retraitement_refuse : la garde, une seule ;
--           ingest.fn_h31_effacer_lignes_pour_retraitement : l'effacement des
--           edge functions, sous verrou du run, qui rejoue la garde ;
--           fn_import_dispatch appelle la garde ; fn_import_promote,
--           fn_import_reconcile_duplicates, fn_import_set_editorial
--           verrouillent le run, FOR NO KEY UPDATE, après leurs contrôles
--           d'accès et avant de lire les lignes)
--
-- Gestes : la coordination de BLMF (seed) par l'API (SET LOCAL ROLE
-- authenticated, request.jwt.claims) pour l'envoi, les conversions et
-- l'attache ; l'effacement comme les edge functions l'appellent (SET LOCAL
-- ROLE service_role). Décor (runs, lignes, fichiers reçus, notice, objets du
-- seau) écrit en postgres.
--
-- SÉCURITÉ. Le relais d'envoi ingest.fn_dispatch_partner_catalog_import fait
-- un net.http_post vers les edge functions de l'instance avec le secret du
-- coffre — sur le banc local, celles de la PRODUCTION. Il est remplacé, dès
-- l'entrée, par un TÉMOIN, vérifié AVANT tout appel (sinon la suite
-- s'arrête) ; tous les cas se jouent dans une sous-transaction que la suite
-- lève elle-même, et qui emporte le témoin (T16 le vérifie).
--
-- La concurrence elle-même (deux sessions) ne se joue pas dans une suite :
-- preuve à deux sessions psql au banc privé (05/10/2026, notée dans le
-- rapport de livraison). Ici : la garde, l'effacement, les droits, et le
-- verrou des conversions prouvé dans la session (pg_locks, xmax).
--
-- T1  verrou des conversions, dans la session : fn_import_promote,
--     fn_import_reconcile_duplicates, fn_import_set_editorial, appelées sur un
--     run sans ligne retenue (chemin sans écriture), tiennent ensuite un
--     RowShareLock sur partner_catalog_import_runs et ont posé un verrou de
--     ligne (xmax) sur le run, que rien d'autre n'a touché ; aucun verrou
--     avant l'appel, ni après la sous-transaction levée.
-- T2  le verrou vient APRÈS les contrôles d'accès : un lecteur (rôle reader)
--     refusé aux trois, un dépôt compagnon refusé à la coordination
--     (promotion), « accept_duplicate » refusé (décision) : aucun verrou —
--     l'appel refusé rend ses verrous en levant, le témoin est donc le xmax
--     de la ligne du run (un verrou posé puis annulé l'y laisse), inchangé.
-- T3  structure : dans les trois conversions, le verrou du run (FOR NO KEY
--     UPDATE) vient après « Run % introuvable » et avant la lecture des lignes
--     (fn_bulk_create_book_drafts_from_run / FROM … staging_rows sr) ;
--     fn_import_dispatch appelle la garde et n'a plus de copie de ses
--     conditions ; l'effacement : verrou FOR UPDATE, puis garde, puis DELETE.
-- T4  ligne PROMUE (lien ligne → brouillon) : l'effacement refuse, HINT
--     error.import.reparse_after_promotion ; lignes, liens, run intacts.
-- T5  exemplaire RAPPROCHÉ vivant (fn_import_reconcile_duplicates) : refus,
--     HINT de la garde (pas celle du déclencheur, rows_held_by_items) ; intact.
-- T6  exemplaire rapproché À LA CORBEILLE (cancelled, sans notice) : refus de
--     la garde ; intact.
-- T7  ligne ÉCARTÉE (discarded_draft_id, IMP-27 e) : refus ; intact.
-- T8  fichier reçu ATTACHÉ par l'API (fn_attach_received_asset_record, mode
--     « both » : attached_digital_asset_id posé) : refus, que les fichiers
--     reçus soient demandés ou non ; lignes et fichier reçu intacts.
-- T9  fichier reçu attaché en mode « read » (deposit_status = 'attached',
--     attached_digital_asset_id NULL) : refus aussi — la colonne seule ne
--     suffit pas.
-- T10 effacement accepté sans fichiers reçus : rend le nombre de lignes,
--     efface celles du run et elles seules ; ses fichiers reçus (non
--     attachés) restent, détachés de leur ligne ; le run lui-même intact.
-- T11 effacement accepté AVEC les fichiers reçus : lignes et fichiers reçus du
--     run effacés ensemble ; ceux d'un autre run intacts.
-- T12 run inexistant : refus « introuvable », rien d'effacé.
-- T13 droits : l'effacement est SECURITY DEFINER, search_path figé,
--     exécutable par service_role seul (refus 42501 sous authenticated) ; la
--     garde n'est exécutable par aucun des trois rôles.
-- T14 fn_import_dispatch (« Retraiter », témoin) : refuse tout de suite un run
--     dont un fichier reçu est attaché (both, read) ; accepte le même paquet
--     dont les fichiers reçus ne sont pas attachés (non-régression).
-- T15 retraitement LÉGITIME de bout en bout : envoi accepté jusqu'au témoin,
--     effacement par la RPC, nouvelles lignes insérées comme l'edge function
--     le fait, promotion des nouvelles lignes ensuite (aucune ancienne).
-- T16 sécurité : aucune requête pg_net, aucun envoi journalisé, l'envoi réel
--     revenu après la sous-transaction.
-- T17 fn_attach_received_asset_record verrouille le run (FOR SHARE) APRÈS ses
--     gardes d'accès : un lecteur refusé ne touche pas la ligne du run (xmax
--     inchangé) ; l'attache acceptée change le xmax du run sans l'écrire ;
--     structure : gardes, verrou du run, relecture du fichier reçu sous verrou
--     de ligne, puis seulement les écritures. (Le fichier effacé entre-temps,
--     refusé « introuvable », et la double attache, rendue idempotente : preuve
--     à deux sessions, attache.sh.)
-- T18 fn_import_delete_run verrouille le run (FOR UPDATE, relu) APRÈS ses
--     contrôles d'accès (un lecteur refusé laisse le xmax du run inchangé) et
--     AVANT ses gardes (refusée par une garde — rapproché en attente,
--     error.import.run_has_drafts —, elle a quand même touché la ligne du
--     run : xmax changé, run intact) ; structure : accès, verrou, gardes,
--     DELETE ; les trois conversions refusent « introuvable » un run supprimé
--     pendant qu'elles attendaient leur verrou. (La course elle-même :
--     preuve à deux sessions, suppression.sh.)
--
-- Contre-épreuves (05/10/2026, banc privé anarbib_h31, mutants hors dépôt,
-- définitions vivantes, ancre comptée, transaction annulée), 26 mutants, tous
-- attrapés :
--   effacement sans la garde                 : T3 T4 T5 T6 T7 T8 T9 T14 ;
--   envoi sans la garde                      : T3 T14 ;
--   effacement sans FOR UPDATE               : T3 (la course elle-même : preuve
--                                              à deux sessions) ;
--   promotion / rapprochement / décision sans verrou (trois mutants) : T1 T3 ;
--   verrou AVANT les contrôles d'accès (promotion, décision) : T2 T3 ;
--   sans la condition « attaché »            : T8 T9 T14 ;
--   « attaché » = attached_digital_asset_id seul : T9 T14 ;
--   fichiers reçus jamais effacés            : T11 ; toujours effacés : T10 ;
--   fichiers reçus d'autres runs effacés     : T11 T14 ;
--   effacement ouvert à authenticated        : T13 ;
--   garde sans les liens : T4 ; sans les exemplaires : T5 T6 ; corbeille
--   oubliée : T6 ; sans les lignes écartées : T7 ;
--   conversions en FOR SHARE                 : T3 (l'interblocage lui-même :
--                                              preuve à deux sessions) ;
--   effacement SECURITY INVOKER              : T4 à T11, T13, T15 ;
--   attache sans verrou du run               : T17 (xmax inchangé, structure) ;
--   attache sans relecture sous verrou       : T17 (structure ; la course :
--                                              attache.sh, AT2) ;
--   attache : verrou avant les gardes d'accès : T17 (le lecteur refusé a
--                                              touché le run) ;
--   suppression sans verrou                  : T18 (xmax inchangé, structure) ;
--   suppression : verrou avant l'accès       : T18 (le lecteur refusé a
--                                              touché le run) ;
--   promotion sans contrôle du run disparu   : T18 (structure ; la course :
--                                              suppression.sh, SU3).
--   Les trois mutants « conversion sans verrou » font aussi tomber T18.
--
-- Toutes les écritures sont annulées : la suite se termine par un RAISE (en CI,
-- run-sql-suites.sh la joue par psql -f, sans transaction englobante).
--   Bilan OK : 'H31-RETRAITER-EFFACEMENT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord  uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_lecteur uuid := '33333333-3333-3333-3333-333333333333'; -- reader BLMF (seed)
  v_lib    uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  c_def    constant text := 'catalogos_parceiros_raw';
  v_src bigint; v_src_dep bigint; v_book bigint; v_runs bigint[] := ARRAY[]::bigint[];
  v_r1 bigint; v_r2 bigint; v_r3 bigint; v_ra bigint; v_ra2 bigint;
  v_h1 text; v_h2 text; v_h3 text; v_n int; v_n2 int; v_res jsonb; v_res2 jsonb;
  v_e0 text; v_e1 text; v_e2 text; v_e3 text;
  v_l0 int; v_l1 int; v_l2 int; v_x0 text; v_x1 text; v_ok boolean; v_det text;
  v_sig text; v_def text; v_i int; v_j int; v_k int; v_ids bigint[];
  v_q0 bigint; v_q1 bigint; v_log bigint; v_temoin boolean; v_reel boolean;
BEGIN
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H31 Essai retraiter', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_src;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('H31 Essai depot', v_lib, 'mutualizacao_autorizada', 'partner_deposit', true) RETURNING id INTO v_src_dep;
  -- état d'un run : statut, compteurs ; ses lignes (id, décision, écartée) ; ses
  -- liens ; ses fichiers reçus (id, ligne, statut, attache)
  EXECUTE $f$CREATE FUNCTION pg_temp.h31_etat(p_run bigint) RETURNS text LANGUAGE sql AS $b$
    SELECT r.run_status || '/' || r.imported_rows || ' L['
           || coalesce((SELECT string_agg(sr.id || ':' || sr.editorial_decision || ':' || coalesce(sr.discarded_draft_id::text, '-'), ',' ORDER BY sr.id)
                          FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = r.id), '')
           || '] T[' || (SELECT count(*) FROM ingest.partner_catalog_row_to_draft m WHERE m.run_id = r.id)
           || '] F[' || coalesce((SELECT string_agg(ra.id || ':' || coalesce(ra.staging_row_id::text, '-') || ':' || ra.deposit_status
                                                 || ':' || coalesce(ra.attached_digital_asset_id::text, '-'), ',' ORDER BY ra.id)
                                    FROM ingest.partner_catalog_received_assets ra WHERE ra.run_id = r.id), '') || ']'
      FROM ingest.partner_catalog_import_runs r WHERE r.id = p_run $b$ $f$;
  -- verrou tenu par cette session sur la table des runs (verrou de table posé
  -- par tout SELECT … FOR UPDATE / NO KEY UPDATE / SHARE / KEY SHARE)
  EXECUTE $f$CREATE FUNCTION pg_temp.h31_verrous() RETURNS int LANGUAGE sql AS $b$
    SELECT count(*)::int FROM pg_locks
     WHERE pid = pg_backend_pid() AND locktype = 'relation' AND granted
       AND relation = 'ingest.partner_catalog_import_runs'::regclass AND mode = 'RowShareLock' $b$ $f$;
  -- un run de n lignes (décision, statut de rapprochement, notice proposée)
  EXECUTE $f$CREATE FUNCTION pg_temp.h31_run(p_src bigint, p_lib uuid, p_nom text, p_n int, p_match text, p_dec text, p_book bigint, p_format text)
    RETURNS bigint LANGUAGE plpgsql AS $b$
    DECLARE v bigint;
    BEGIN
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (p_src, p_lib, 'essai/' || p_nom, p_nom, p_format, 'ready_for_review', p_n) RETURNING id INTO v;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision, proposed_book_id)
      SELECT v, g, 'H31-' || p_nom || '-' || g, 'H31 ' || p_nom || ' ' || g, p_match, p_dec, p_book FROM generate_series(1, p_n) g;
      RETURN v;
    END $b$ $f$;
  -- un fichier reçu (déposé) sur la ligne row_no du run
  EXECUTE $f$CREATE FUNCTION pg_temp.h31_recu(p_run bigint, p_row_no int, p_asset bigint) RETURNS bigint LANGUAGE sql AS $b$
    INSERT INTO ingest.partner_catalog_received_assets (run_id, staging_row_id, source_asset_id, asset_kind, title, mime_type, deposit_bucket, deposit_status, deposit_path, manifest_file)
    SELECT p_run, sr.id, p_asset, 'pdf', 'H31 (PDF ' || p_asset || ')', 'application/pdf', 'partner-catalog-deposits', 'deposited',
           'received/' || p_run || '/' || p_asset || '_h31.pdf', 'files/' || p_asset || '_h31.pdf'
      FROM ingest.partner_catalog_staging_rows sr WHERE sr.run_id = p_run AND sr.row_no = p_row_no
    RETURNING id $b$ $f$;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('H31 Notice existante', 'H31-NOTICE-EXISTANTE', 'livro', v_lib) RETURNING id INTO v_book;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_book, v_lib);

  BEGIN  -- sous-transaction LEVÉE à la fin : emporte le témoin et tout le décor
    EXECUTE $f$CREATE OR REPLACE FUNCTION ingest.fn_dispatch_partner_catalog_import(p_run_id bigint, p_force_reparse boolean DEFAULT false)
      RETURNS jsonb LANGUAGE sql
      AS $b$ SELECT jsonb_build_object('temoin_h31', true, 'run_id', p_run_id, 'force_reparse', p_force_reparse) $b$ $f$;
    IF position('temoin_h31' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) = 0
       OR position('net.http_post' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0 THEN
      RAISE EXCEPTION 'H31 : le témoin d''envoi n''est pas en place — arrêt avant tout appel';
    END IF;
    SELECT count(*) INTO v_q0 FROM net.http_request_queue;

    -- ── T1 ──────────────────────────────────────────────────────────────
    -- (en premier : aucune ligne de staging n'a encore été écrite dans cette
    -- transaction — leur clé étrangère vers le run pose aussi un RowShareLock)
    v_t := 'T1 les trois conversions verrouillent le run dans la session (RowShareLock sur la table des runs, xmax sur la ligne du run), rien avant, rien apres';
    BEGIN
      v_det := '';
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src, v_lib, 'essai/h31-t1.csv', 'h31-t1.csv', 'csv', 'ready_for_review', 0) RETURNING id INTO v_r1;
      v_runs := v_runs || v_r1;
      v_ok := pg_temp.h31_verrous() = 0;
      IF NOT v_ok THEN v_det := v_det || ' verrou deja tenu avant=' || pg_temp.h31_verrous(); END IF;
      FOREACH v_sig IN ARRAY ARRAY['promote', 'reconcile', 'editorial'] LOOP
        v_l1 := NULL; v_x0 := NULL; v_x1 := NULL; v_e0 := NULL; v_e1 := NULL; v_h1 := NULL;
        BEGIN
          SELECT xmax::text INTO v_x0 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
          v_e0 := pg_temp.h31_etat(v_r1);
          PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
          EXECUTE 'SET LOCAL ROLE authenticated';
          CASE v_sig
            WHEN 'promote'   THEN v_res := public.fn_import_promote(v_r1, NULL, ARRAY['accept_new'], NULL, NULL, ARRAY[-1]::bigint[]);
            WHEN 'reconcile' THEN v_res := public.fn_import_reconcile_duplicates(v_r1, ARRAY[-1]::bigint[]);
            ELSE                  v_res := public.fn_import_set_editorial(v_r1, ARRAY[-1]::bigint[], 'pending', NULL);
          END CASE;
          EXECUTE 'RESET ROLE';
          v_l1 := pg_temp.h31_verrous();
          SELECT xmax::text INTO v_x1 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
          v_e1 := pg_temp.h31_etat(v_r1);
          RAISE EXCEPTION 'h31-t1-annule';
        EXCEPTION WHEN OTHERS THEN
          EXECUTE 'RESET ROLE';
          IF SQLERRM IS DISTINCT FROM 'h31-t1-annule' THEN v_h1 := SQLERRM; END IF;
        END;
        v_l2 := pg_temp.h31_verrous();
        IF v_h1 IS NULL AND v_l1 = 1 AND v_x0 IS NOT NULL AND v_x1 IS DISTINCT FROM v_x0 AND v_x1 IS DISTINCT FROM '0' AND v_e1 = v_e0 AND v_l2 = 0 THEN
          NULL;
        ELSE
          v_ok := false;
          v_det := v_det || format(' %s: erreur=%s verrou=%s xmax %s->%s etat %s->%s apres=%s rendu=%s',
                                   v_sig, coalesce(v_h1, '-'), coalesce(v_l1::text, 'NULL'), coalesce(v_x0, 'NULL'), coalesce(v_x1, 'NULL'),
                                   coalesce(v_e0, 'NULL'), coalesce(v_e1, 'NULL'), v_l2, left(coalesce(v_res::text, 'NULL'), 80));
        END IF;
      END LOOP;
      IF v_ok THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_det); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T2 ──────────────────────────────────────────────────────────────
    -- Un appel refusé lève : sa sous-transaction est annulée et ses verrous
    -- rendus (pg_locks ne dit plus rien). Le témoin est la ligne du run :
    -- un verrou posé puis annulé y laisse son xmax (transaction avortée) ;
    -- aucun verrou, xmax inchangé.
    v_t := 'T2 le verrou vient apres les controles d''acces : lecteur refuse aux trois, depot compagnon (promotion) et accept_duplicate (decision) refuses, xmax du run inchange';
    BEGIN
      v_det := ''; v_ok := true;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src_dep, v_lib, 'essai/h31-t2-depot.csv', 'h31-t2-depot.csv', 'csv', 'ready_for_review', 0) RETURNING id INTO v_r2;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src, v_lib, 'essai/h31-t2.csv', 'h31-t2.csv', 'csv', 'ready_for_review', 0) RETURNING id INTO v_r1;
      v_runs := v_runs || v_r1 || v_r2;
      FOREACH v_sig IN ARRAY ARRAY['lecteur:promote', 'lecteur:reconcile', 'lecteur:editorial', 'coord:promote-depot', 'coord:accept_duplicate'] LOOP
        v_h1 := NULL; v_l1 := NULL;
        SELECT xmax::text INTO v_x0 FROM ingest.partner_catalog_import_runs WHERE id = CASE WHEN v_sig = 'coord:promote-depot' THEN v_r2 ELSE v_r1 END;
        BEGIN
          PERFORM set_config('request.jwt.claims',
                             json_build_object('sub', CASE WHEN v_sig LIKE 'lecteur:%' THEN v_lecteur ELSE v_coord END, 'role', 'authenticated')::text, true);
          EXECUTE 'SET LOCAL ROLE authenticated';
          CASE v_sig
            WHEN 'lecteur:promote'        THEN v_res := public.fn_import_promote(v_r1, NULL, ARRAY['accept_new'], NULL, NULL, ARRAY[-1]::bigint[]);
            WHEN 'lecteur:reconcile'      THEN v_res := public.fn_import_reconcile_duplicates(v_r1, ARRAY[-1]::bigint[]);
            WHEN 'lecteur:editorial'      THEN v_res := public.fn_import_set_editorial(v_r1, ARRAY[-1]::bigint[], 'pending', NULL);
            WHEN 'coord:promote-depot'    THEN v_res := public.fn_import_promote(v_r2, NULL, ARRAY['accept_new'], NULL, NULL, ARRAY[-1]::bigint[]);
            ELSE                               v_res := public.fn_import_set_editorial(v_r1, ARRAY[-1]::bigint[], 'accept_duplicate', NULL);
          END CASE;
          v_h1 := 'accepte';
          EXECUTE 'RESET ROLE';
        EXCEPTION WHEN OTHERS THEN
          EXECUTE 'RESET ROLE';
          v_h1 := coalesce(SQLERRM, '?');
        END;
        SELECT xmax::text INTO v_x1 FROM ingest.partner_catalog_import_runs WHERE id = CASE WHEN v_sig = 'coord:promote-depot' THEN v_r2 ELSE v_r1 END;
        IF v_h1 = 'accepte' OR v_x1 IS DISTINCT FROM v_x0 OR v_x0 IS DISTINCT FROM '0' THEN
          v_ok := false; v_det := v_det || format(' %s: %s xmax %s->%s', v_sig, left(v_h1, 60), v_x0, v_x1);
        END IF;
      END LOOP;
      IF v_ok THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_det); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T3 ──────────────────────────────────────────────────────────────
    v_t := 'T3 structure : verrou apres « Run % introuvable » et avant les lignes (trois conversions) ; envoi = appel de la garde ; effacement = verrou, garde, DELETE';
    BEGIN
      v_det := '';
      FOREACH v_sig IN ARRAY ARRAY['public.fn_import_promote(bigint, text[], text[], text, text, bigint[])|ingest.fn_bulk_create_book_drafts_from_run(',
                                   'public.fn_import_reconcile_duplicates(bigint, bigint[])|from ingest.partner_catalog_staging_rows sr',
                                   'public.fn_import_set_editorial(bigint, bigint[], text, text)|from ingest.partner_catalog_staging_rows sr'] LOOP
        v_def := lower(pg_get_functiondef(split_part(v_sig, '|', 1)::regprocedure));
        v_i := position('run % introuvable' IN v_def);
        v_j := position('from ingest.partner_catalog_import_runs where id = p_run_id for no key update' IN v_def);
        v_k := position(split_part(v_sig, '|', 2) IN v_def);
        IF NOT (v_i > 0 AND v_j > v_i AND v_k > v_j) THEN
          v_det := v_det || format(' %s: introuvable@%s verrou@%s lignes@%s', split_part(split_part(v_sig, '|', 1), '(', 1), v_i, v_j, v_k);
        END IF;
      END LOOP;
      v_def := pg_get_functiondef('public.fn_import_dispatch(bigint, boolean)'::regprocedure);
      IF position('AND ingest.fn_h31_retraitement_refuse(p_run_id) THEN' IN v_def) = 0
         OR position('partner_catalog_row_to_draft' IN v_def) > 0
         OR position('discarded_draft_id' IN v_def) > 0 THEN
        v_det := v_det || ' dispatch: garde non appelee ou copie restante';
      END IF;
      v_def := pg_get_functiondef('ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)'::regprocedure);
      v_i := position('WHERE r.id = p_run_id FOR UPDATE' IN v_def);
      v_j := position('IF ingest.fn_h31_retraitement_refuse(p_run_id) THEN' IN v_def);
      v_k := position('DELETE FROM ingest.partner_catalog_staging_rows' IN v_def);
      IF NOT (v_i > 0 AND v_j > v_i AND v_k > v_j) THEN
        v_det := v_det || format(' effacement: verrou@%s garde@%s delete@%s', v_i, v_j, v_k);
      END IF;
      IF v_det = '' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_det); END IF;
    EXCEPTION WHEN OTHERS THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T4 ──────────────────────────────────────────────────────────────
    v_t := 'T4 ligne promue (lien ligne -> brouillon) : l''effacement refuse (reparse_after_promotion), tout intact';
    BEGIN
      v_h1 := NULL; v_n := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t4.csv', 2, 'new_record', 'accept_new', NULL, 'csv');
      v_runs := v_runs || v_r1;
      v_ids := (SELECT array_agg(id) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r1 AND row_no = 1);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_import_promote(v_r1, NULL, ARRAY['accept_new'], NULL, NULL, v_ids);
      EXECUTE 'RESET ROLE';
      IF (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_r1) <> 1 THEN
        RAISE EXCEPTION 'decor : promotion=%', left(coalesce(v_res::text, 'NULL'), 160);
      END IF;
      v_e0 := pg_temp.h31_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN v_n := ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, false); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r1);
      IF v_h1 = 'error.import.reparse_after_promotion' AND v_e1 = v_e0 AND v_e0 LIKE '% T[1] %'
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1,'NULL')||' n='||coalesce(v_n::text,'NULL')
           ||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T5 / T6 ─────────────────────────────────────────────────────────
    v_t := 'T5 exemplaire rapproche vivant : refus de la garde (pas du declencheur), tout intact';
    BEGIN
      v_h1 := NULL; v_h2 := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t5.csv', 2, 'matched_book', 'pending', v_book, 'csv');
      v_runs := v_runs || v_r1;
      v_ids := (SELECT array_agg(id) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r1 AND row_no = 1);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_import_reconcile_duplicates(v_r1, v_ids);
      EXECUTE 'RESET ROLE';
      IF NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
                      WHERE sr.run_id = v_r1 AND x.book_draft_id IS NULL AND x.status <> 'cancelled') THEN
        RAISE EXCEPTION 'decor : rapprochement=%', left(coalesce(v_res::text, 'NULL'), 160);
      END IF;
      v_e0 := pg_temp.h31_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, false); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r1);
      IF v_h1 = 'error.import.reparse_after_promotion' AND v_e1 = v_e0
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1,'NULL')||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')); END IF;

      v_t := 'T6 exemplaire rapproche a la corbeille (cancelled, sans notice) : refus de la garde, tout intact';
      UPDATE public.exemplar_drafts x SET status = 'cancelled'
        FROM ingest.partner_catalog_staging_rows sr
       WHERE sr.id = x.import_staging_row_id AND sr.run_id = v_r1;
      v_e0 := pg_temp.h31_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, false); v_h2 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r1);
      IF v_h2 = 'error.import.reparse_after_promotion' AND v_e1 = v_e0
         AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
                          WHERE sr.run_id = v_r1 AND x.status <> 'cancelled')
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h2,'NULL')||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T7 ──────────────────────────────────────────────────────────────
    v_t := 'T7 ligne ecartee (discarded_draft_id) : refus, tout intact';
    BEGIN
      v_h1 := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t7.csv', 2, 'new_record', 'reject', NULL, 'csv');
      v_runs := v_runs || v_r1;
      UPDATE ingest.partner_catalog_staging_rows SET discarded_draft_id = 987654321 WHERE run_id = v_r1 AND row_no = 2;
      v_e0 := pg_temp.h31_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r1);
      IF v_h1 = 'error.import.reparse_after_promotion' AND v_e1 = v_e0 AND v_e0 LIKE '%:987654321%'
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1,'NULL')||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T8 / T9 ─────────────────────────────────────────────────────────
    v_t := 'T8 fichier recu attache (mode both, attached_digital_asset_id) : refus avec ou sans les fichiers recus, lignes et fichier intacts';
    BEGIN
      v_h1 := NULL; v_h2 := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t8.zip', 2, 'new_record', 'pending', NULL, 'zip');
      v_runs := v_runs || v_r1;
      v_ra := pg_temp.h31_recu(v_r1, 1, 71);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_attach_received_asset_record(v_ra, v_book, 'pdf-restrito', 'attached/' || v_book || '/' || v_ra || '_h31.pdf', 'both');
      EXECUTE 'RESET ROLE';
      IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_received_assets WHERE id = v_ra AND attached_digital_asset_id IS NOT NULL) THEN
        RAISE EXCEPTION 'decor : attache=%', left(coalesce(v_res::text, 'NULL'), 160);
      END IF;
      v_e0 := pg_temp.h31_etat(v_r1);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      BEGIN PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, false); v_h2 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r1);
      IF v_h1 = 'error.import.reparse_after_promotion' AND v_h2 = 'error.import.reparse_after_promotion'
         AND v_e1 = v_e0 AND v_e0 LIKE '%:attached:%' AND v_e0 NOT LIKE '%:attached:-]%'
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : avec fichiers='||coalesce(v_h1,'NULL')||' sans='||coalesce(v_h2,'NULL')
           ||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')); END IF;

      v_t := 'T9 fichier recu attache en mode read (deposit_status attached, attached_digital_asset_id NULL) : refus aussi';
      v_r2 := pg_temp.h31_run(v_src, v_lib, 'h31-t9.zip', 2, 'new_record', 'pending', NULL, 'zip');
      v_runs := v_runs || v_r2;
      v_ra2 := pg_temp.h31_recu(v_r2, 2, 72);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_attach_received_asset_record(v_ra2, v_book, 'pdf-restrito', 'attached/' || v_book || '/' || v_ra2 || '_h31.pdf', 'read');
      EXECUTE 'RESET ROLE';
      IF NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_received_assets WHERE id = v_ra2 AND attached_digital_asset_id IS NULL AND deposit_status = 'attached') THEN
        RAISE EXCEPTION 'decor : attache en lecture=%', left(coalesce(v_res::text, 'NULL'), 160);
      END IF;
      v_e2 := pg_temp.h31_etat(v_r2);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(v_r2, true); v_h3 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h3 = PG_EXCEPTION_HINT; v_h3 := coalesce(nullif(v_h3, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e3 := pg_temp.h31_etat(v_r2);
      IF v_h3 = 'error.import.reparse_after_promotion' AND v_e3 = v_e2 AND v_e2 LIKE '%:attached:-]%'
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h3,'NULL')||' avant='||coalesce(v_e2,'NULL')||' apres='||coalesce(v_e3,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T10 / T11 ───────────────────────────────────────────────────────
    v_t := 'T10 effacement accepte sans les fichiers recus : rend 2, lignes du run seules effacees, fichiers recus restes (detaches), run intact';
    BEGIN
      v_n := NULL; v_n2 := NULL; v_h1 := NULL; v_h2 := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t10.zip', 2, 'new_record', 'pending', NULL, 'zip');
      v_r2 := pg_temp.h31_run(v_src, v_lib, 'h31-t10-voisin.zip', 2, 'new_record', 'pending', NULL, 'zip');
      v_r3 := pg_temp.h31_run(v_src, v_lib, 'h31-t11.zip', 3, 'new_record', 'accept_new', NULL, 'zip');
      v_runs := v_runs || v_r1 || v_r2 || v_r3;
      PERFORM pg_temp.h31_recu(v_r1, 1, 81); PERFORM pg_temp.h31_recu(v_r1, 2, 82);
      PERFORM pg_temp.h31_recu(v_r2, 1, 83);
      PERFORM pg_temp.h31_recu(v_r3, 1, 84); PERFORM pg_temp.h31_recu(v_r3, 3, 85);
      v_e0 := pg_temp.h31_etat(v_r1); v_e2 := pg_temp.h31_etat(v_r2);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN v_n := ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, false);
      EXCEPTION WHEN OTHERS THEN v_h1 := SQLERRM; END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r1);
      IF v_h1 IS NULL AND v_n = 2
         AND v_e1 = 'ready_for_review/2 L[] T[0] F[' || (SELECT string_agg(ra.id || ':-:deposited:-', ',' ORDER BY ra.id)
                                                         FROM ingest.partner_catalog_received_assets ra WHERE ra.run_id = v_r1) || ']'
         AND (SELECT count(*) FROM ingest.partner_catalog_received_assets WHERE run_id = v_r1) = 2
         AND pg_temp.h31_etat(v_r2) = v_e2
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1, 'n='||coalesce(v_n::text,'NULL'))
           ||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')||' voisin='||coalesce(pg_temp.h31_etat(v_r2),'NULL')); END IF;

      v_t := 'T11 effacement accepte avec les fichiers recus : lignes et fichiers recus du run effaces ensemble, le voisin intact';
      v_e0 := pg_temp.h31_etat(v_r3);
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN v_n2 := ingest.fn_h31_effacer_lignes_pour_retraitement(v_r3, true);
      EXCEPTION WHEN OTHERS THEN v_h2 := SQLERRM; END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r3);
      IF v_h2 IS NULL AND v_n2 = 3 AND v_e0 LIKE '%:deposited:-,%' AND v_e1 = 'ready_for_review/3 L[] T[0] F[]'
         AND pg_temp.h31_etat(v_r2) = v_e2
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h2, 'n='||coalesce(v_n2::text,'NULL'))
           ||' avant='||coalesce(v_e0,'NULL')||' apres='||coalesce(v_e1,'NULL')||' voisin='||coalesce(pg_temp.h31_etat(v_r2),'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T12 ─────────────────────────────────────────────────────────────
    v_t := 'T12 run inexistant : refus introuvable';
    BEGIN
      v_h1 := NULL;
      EXECUTE 'SET LOCAL ROLE service_role';
      BEGIN PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(-42, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN v_h1 := SQLERRM; END;
      EXECUTE 'RESET ROLE';
      IF v_h1 = 'Run -42 introuvable'
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_h1,'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T13 ─────────────────────────────────────────────────────────────
    v_t := 'T13 droits : effacement DEFINER, search_path fige, service_role seul (42501 sous authenticated) ; garde fermee aux trois roles';
    BEGIN
      v_h1 := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t13.csv', 1, 'new_record', 'pending', NULL, 'csv');
      v_runs := v_runs || v_r1;
      v_e0 := pg_temp.h31_etat(v_r1);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      BEGIN
        EXECUTE 'SET LOCAL ROLE authenticated';
        PERFORM ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, false);
        v_h1 := 'accepte';
        EXECUTE 'RESET ROLE';
      EXCEPTION WHEN insufficient_privilege THEN
        EXECUTE 'RESET ROLE';
        v_h1 := '42501';
      END;
      IF v_h1 = '42501' AND pg_temp.h31_etat(v_r1) = v_e0
         AND (SELECT p.prosecdef AND p.proconfig::text LIKE '%search_path=ingest, public, pg_temp%'
                FROM pg_proc p WHERE p.oid = 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)'::regprocedure)
         AND NOT has_function_privilege('anon', 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)', 'EXECUTE')
         AND NOT has_function_privilege('authenticated', 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)', 'EXECUTE')
         AND has_function_privilege('service_role', 'ingest.fn_h31_effacer_lignes_pour_retraitement(bigint, boolean)', 'EXECUTE')
         AND NOT has_function_privilege('anon', 'ingest.fn_h31_retraitement_refuse(bigint)', 'EXECUTE')
         AND NOT has_function_privilege('authenticated', 'ingest.fn_h31_retraitement_refuse(bigint)', 'EXECUTE')
         AND NOT has_function_privilege('service_role', 'ingest.fn_h31_retraitement_refuse(bigint)', 'EXECUTE')
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : authenticated='||coalesce(v_h1,'NULL')
           ||' etat='||coalesce(pg_temp.h31_etat(v_r1),'NULL')); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T14 ─────────────────────────────────────────────────────────────
    v_t := 'T14 fn_import_dispatch refuse un paquet a fichier recu attache (both, read) et accepte le meme paquet non attache';
    BEGIN
      v_h1 := NULL; v_h2 := NULL; v_h3 := NULL; v_res := NULL;
      -- les deux runs de T8/T9 (fichier attaché both, read), et un paquet neuf,
      -- chacun avec son objet au seau (H30)
      SELECT r.id INTO v_r1 FROM ingest.partner_catalog_import_runs r WHERE r.id = ANY (v_runs) AND r.original_filename = 'h31-t8.zip';
      SELECT r.id INTO v_r2 FROM ingest.partner_catalog_import_runs r WHERE r.id = ANY (v_runs) AND r.original_filename = 'h31-t9.zip';
      v_r3 := pg_temp.h31_run(v_src, v_lib, 'h31-t14.zip', 2, 'new_record', 'pending', NULL, 'zip');
      v_runs := v_runs || v_r3;
      PERFORM pg_temp.h31_recu(v_r3, 1, 91);
      INSERT INTO storage.objects (bucket_id, name) VALUES (c_def, 'essai/h31-t8.zip'), (c_def, 'essai/h31-t9.zip'), (c_def, 'essai/h31-t14.zip');
      v_e0 := pg_temp.h31_etat(v_r1) || ' ' || pg_temp.h31_etat(v_r2);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN PERFORM public.fn_import_dispatch(v_r1, true); v_h1 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h1 = PG_EXCEPTION_HINT; v_h1 := coalesce(nullif(v_h1, ''), SQLERRM); END;
      BEGIN PERFORM public.fn_import_dispatch(v_r2, true); v_h2 := 'accepte';
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM); END;
      BEGIN v_res := public.fn_import_dispatch(v_r3, true);
      EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_h3 = PG_EXCEPTION_HINT; v_h3 := coalesce(nullif(v_h3, ''), SQLERRM); END;
      EXECUTE 'RESET ROLE';
      v_e1 := pg_temp.h31_etat(v_r1) || ' ' || pg_temp.h31_etat(v_r2);
      IF v_h1 = 'error.import.reparse_after_promotion' AND v_h2 = 'error.import.reparse_after_promotion' AND v_e1 = v_e0
         AND v_h3 IS NULL AND coalesce((v_res->>'temoin_h31')::boolean, false) AND (v_res->>'run_id')::bigint = v_r3
         AND coalesce((v_res->>'force_reparse')::boolean, false)
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : both='||coalesce(v_h1,'NULL')||' read='||coalesce(v_h2,'NULL')
           ||' non attache='||coalesce(v_h3, left(coalesce(v_res::text,'NULL'), 80))); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T15 ─────────────────────────────────────────────────────────────
    v_t := 'T15 retraitement legitime de bout en bout : envoi accepte, effacement par la RPC, nouvelles lignes, promotion des nouvelles seules';
    BEGIN
      v_h1 := NULL; v_res := NULL; v_res2 := NULL; v_n := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t15.csv', 2, 'new_record', 'accept_new', NULL, 'csv');
      v_runs := v_runs || v_r1;
      INSERT INTO storage.objects (bucket_id, name) VALUES (c_def, 'essai/h31-t15.csv');
      v_e0 := (SELECT string_agg(id::text, ',' ORDER BY id) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r1);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_import_dispatch(v_r1, true);
      EXECUTE 'RESET ROLE';
      -- l'edge function : effacement par la RPC, puis les lignes relues
      EXECUTE 'SET LOCAL ROLE service_role';
      v_n := ingest.fn_h31_effacer_lignes_pour_retraitement(v_r1, false);
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, row_no, external_key, title, match_status, editorial_decision)
      SELECT v_r1, g, 'H31-T15-bis-' || g, 'H31 relue ' || g, 'new_record', 'accept_new' FROM generate_series(1, 2) g;
      EXECUTE 'RESET ROLE';
      v_e1 := (SELECT string_agg(id::text, ',' ORDER BY id) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r1);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res2 := public.fn_import_promote(v_r1, NULL, ARRAY['accept_new'], NULL, NULL,
                  (SELECT array_agg(x::bigint) FROM unnest(string_to_array(v_e0 || ',' || v_e1, ',')) x));
      EXECUTE 'RESET ROLE';
      IF coalesce((v_res->>'temoin_h31')::boolean, false) AND v_n = 2 AND v_e1 IS NOT NULL
         AND NOT (string_to_array(v_e1, ',') && string_to_array(v_e0, ','))
         AND (v_res2->>'selected_count')::int = 2
         AND (SELECT array_agg(x::text ORDER BY x::bigint) FROM jsonb_array_elements_text(v_res2->'selected_row_ids') x) = string_to_array(v_e1, ',')
         AND (SELECT count(*) FROM ingest.partner_catalog_row_to_draft WHERE run_id = v_r1) = 2
      THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : envoi='||left(coalesce(v_res::text,'NULL'), 80)||' efface='||coalesce(v_n::text,'NULL')
           ||' anciennes='||coalesce(v_e0,'NULL')||' nouvelles='||coalesce(v_e1,'NULL')||' promotion='||left(coalesce(v_res2::text,'NULL'), 160)); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T17 ─────────────────────────────────────────────────────────────
    -- Le décor (le fichier reçu, clé étrangère vers le run) pose déjà un FOR
    -- KEY SHARE sur la ligne du run : pg_locks ne départage rien ici. Le
    -- témoin est le xmax de la ligne du run : l'attache n'écrit pas le run,
    -- seul son verrou peut le changer.
    v_t := 'T17 l''attache d''un fichier recu verrouille le run (xmax change, run intact) apres ses gardes d''acces (lecteur refuse : xmax inchange) ; verrou puis relecture sous verrou avant toute ecriture';
    BEGIN
      v_det := ''; v_h1 := NULL; v_h2 := NULL;
      INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
      VALUES (v_src, v_lib, 'essai/h31-t17.zip', 'h31-t17.zip', 'zip', 'ready_for_review', 0) RETURNING id INTO v_r1;
      v_runs := v_runs || v_r1;
      INSERT INTO ingest.partner_catalog_received_assets (run_id, staging_row_id, source_asset_id, asset_kind, title, mime_type, deposit_bucket, deposit_status, deposit_path, manifest_file)
      VALUES (v_r1, NULL, 171, 'pdf', 'H31 (PDF 171)', 'application/pdf', 'partner-catalog-deposits', 'deposited', 'received/' || v_r1 || '/171_h31.pdf', 'files/171_h31.pdf')
      RETURNING id INTO v_ra;
      -- (a) le lecteur : refusé par la garde d'accès, aucun verrou
      SELECT xmax::text INTO v_x0 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
      BEGIN
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lecteur, 'role', 'authenticated')::text, true);
        EXECUTE 'SET LOCAL ROLE authenticated';
        v_res := public.fn_attach_received_asset_record(v_ra, v_book, 'pdf-restrito', 'attached/' || v_book || '/' || v_ra || '_h31.pdf', 'both');
        v_h1 := 'accepte';
        EXECUTE 'RESET ROLE';
      EXCEPTION WHEN OTHERS THEN
        EXECUTE 'RESET ROLE';
        v_h1 := SQLERRM;
      END;
      SELECT xmax::text INTO v_x1 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
      IF v_h1 IS DISTINCT FROM 'Recurso recebido introuvável.' OR v_x1 IS DISTINCT FROM v_x0 THEN
        v_det := v_det || format(' lecteur: %s xmax %s->%s', left(coalesce(v_h1, 'NULL'), 60), v_x0, v_x1);
      END IF;
      -- (b) la coordination : attache acceptée, le run verrouillé, rien d'autre
      v_e0 := pg_temp.h31_etat(v_r1); v_e1 := NULL; v_res := NULL; v_x1 := NULL;
      SELECT xmax::text INTO v_x0 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
      BEGIN
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
        EXECUTE 'SET LOCAL ROLE authenticated';
        v_res := public.fn_attach_received_asset_record(v_ra, v_book, 'pdf-restrito', 'attached/' || v_book || '/' || v_ra || '_h31.pdf', 'both');
        EXECUTE 'RESET ROLE';
        SELECT xmax::text INTO v_x1 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
        v_e1 := pg_temp.h31_etat(v_r1);
        RAISE EXCEPTION 'h31-t17-annule';
      EXCEPTION WHEN OTHERS THEN
        EXECUTE 'RESET ROLE';
        IF SQLERRM IS DISTINCT FROM 'h31-t17-annule' THEN v_h2 := SQLERRM; END IF;
      END;
      IF v_h2 IS NOT NULL OR NOT coalesce((v_res->>'created')::boolean, false) OR v_x1 IS NOT DISTINCT FROM v_x0
         OR split_part(v_e1, ' F[', 1) IS DISTINCT FROM split_part(v_e0, ' F[', 1) OR v_e1 NOT LIKE '%:attached:%' THEN
        v_det := v_det || format(' coordination: erreur=%s rendu=%s xmax %s->%s etat %s->%s', coalesce(v_h2, '-'),
                                 left(coalesce(v_res::text, 'NULL'), 80), v_x0, v_x1, v_e0, coalesce(v_e1, 'NULL'));
      END IF;
      -- (c) structure : gardes d'accès, verrou du run, relecture sous verrou, écritures
      v_def := pg_get_functiondef('public.fn_attach_received_asset_record(bigint, bigint, text, text, text)'::regprocedure);
      v_i := position('IF NOT v_authorized THEN' IN v_def);
      v_j := position('WHERE run.id = ra.run_id FOR SHARE' IN v_def);
      v_k := position('WHERE id = p_received_asset_id FOR UPDATE' IN v_def);
      IF NOT (v_i > 0 AND v_j > v_i AND v_k > v_j AND position('INSERT INTO public.digital_assets' IN v_def) > v_k) THEN
        v_det := v_det || format(' structure: gardes@%s verrou@%s relecture@%s', v_i, v_j, v_k);
      END IF;
      IF v_det = '' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_det); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- ── T18 ─────────────────────────────────────────────────────────────
    -- Une suppression ACCEPTÉE efface la ligne du run (son xmax ne dit plus
    -- rien) : le témoin est une suppression refusée par une GARDE (rapproché
    -- en attente, run_has_drafts). Le refus lève et rend ses verrous, mais le
    -- verrou posé avant la garde laisse son xmax sur la ligne du run.
    v_t := 'T18 fn_import_delete_run verrouille le run apres ses controles d''acces (lecteur refuse : xmax inchange) et AVANT ses gardes (refus run_has_drafts : xmax change, run intact) ; les trois conversions refusent un run disparu apres leur verrou';
    BEGIN
      v_det := ''; v_h1 := NULL; v_h2 := NULL;
      v_r1 := pg_temp.h31_run(v_src, v_lib, 'h31-t18.csv', 1, 'matched_book', 'pending', v_book, 'csv');
      v_runs := v_runs || v_r1;
      v_ids := (SELECT array_agg(id) FROM ingest.partner_catalog_staging_rows WHERE run_id = v_r1);
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_res := public.fn_import_reconcile_duplicates(v_r1, v_ids);
      EXECUTE 'RESET ROLE';
      IF NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x JOIN ingest.partner_catalog_staging_rows sr ON sr.id = x.import_staging_row_id
                      WHERE sr.run_id = v_r1 AND x.book_draft_id IS NULL AND x.status IN ('draft', 'ready')) THEN
        RAISE EXCEPTION 'decor : rapprochement=%', left(coalesce(v_res::text, 'NULL'), 160);
      END IF;
      -- (a) le lecteur : refusé par le contrôle d'accès, aucun verrou
      SELECT xmax::text INTO v_x0 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
      BEGIN
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_lecteur, 'role', 'authenticated')::text, true);
        EXECUTE 'SET LOCAL ROLE authenticated';
        v_res := public.fn_import_delete_run(v_r1);
        v_h1 := 'accepte';
        EXECUTE 'RESET ROLE';
      EXCEPTION WHEN OTHERS THEN
        EXECUTE 'RESET ROLE';
        v_h1 := SQLERRM;
      END;
      SELECT xmax::text INTO v_x1 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
      IF v_h1 = 'accepte' OR v_x1 IS DISTINCT FROM v_x0 THEN
        v_det := v_det || format(' lecteur: %s xmax %s->%s', left(coalesce(v_h1, 'NULL'), 60), v_x0, v_x1);
      END IF;
      -- (b) la coordination : refusée par une GARDE, après le verrou
      v_e0 := pg_temp.h31_etat(v_r1);
      SELECT xmax::text INTO v_x0 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
      BEGIN
        PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
        EXECUTE 'SET LOCAL ROLE authenticated';
        v_res := public.fn_import_delete_run(v_r1);
        v_h2 := 'accepte';
        EXECUTE 'RESET ROLE';
      EXCEPTION WHEN OTHERS THEN
        EXECUTE 'RESET ROLE';
        GET STACKED DIAGNOSTICS v_h2 = PG_EXCEPTION_HINT; v_h2 := coalesce(nullif(v_h2, ''), SQLERRM);
      END;
      SELECT xmax::text INTO v_x1 FROM ingest.partner_catalog_import_runs WHERE id = v_r1;
      IF v_h2 IS DISTINCT FROM 'error.import.run_has_drafts' OR v_x1 IS NOT DISTINCT FROM v_x0
         OR pg_temp.h31_etat(v_r1) IS DISTINCT FROM v_e0 THEN
        v_det := v_det || format(' coordination: %s xmax %s->%s etat %s->%s', left(coalesce(v_h2, 'NULL'), 60), v_x0, v_x1,
                                 v_e0, coalesce(pg_temp.h31_etat(v_r1), 'NULL'));
      END IF;
      -- (c) structure : contrôle d'accès, verrou + relecture, gardes, DELETE
      v_def := pg_get_functiondef('public.fn_import_delete_run(bigint)'::regprocedure);
      v_i := position('AND NOT public.fn_caller_is_network_admin() THEN' IN v_def);
      v_j := position('WHERE id = p_run_id FOR UPDATE' IN v_def);
      v_k := position('SELECT array_agg(DISTINCT m.batch_id)' IN v_def);
      IF NOT (v_i > 0 AND v_j > v_i AND v_k > v_j AND position('DELETE FROM ingest.partner_catalog_import_runs' IN v_def) > v_k) THEN
        v_det := v_det || format(' structure suppression: acces@%s verrou@%s gardes@%s', v_i, v_j, v_k);
      END IF;
      -- (d) structure : les conversions vérifient que le run est encore là
      FOREACH v_sig IN ARRAY ARRAY['public.fn_import_promote(bigint, text[], text[], text, text, bigint[])',
                                   'public.fn_import_reconcile_duplicates(bigint, bigint[])',
                                   'public.fn_import_set_editorial(bigint, bigint[], text, text)'] LOOP
        IF lower(pg_get_functiondef(v_sig::regprocedure)) !~ 'for no key update;\s*if not found then\s*--[^\n]*\n\s*raise exception ''run % introuvable''' THEN
          v_det := v_det || ' ' || split_part(v_sig, '(', 1) || ': run disparu non verifie';
        END IF;
      END LOOP;
      IF v_det = '' THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' :'||v_det); END IF;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE 'RESET ROLE';
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

    -- mesures de T16, DANS la sous-transaction (elle emporte la file avec elle)
    SELECT count(*) INTO v_q1 FROM net.http_request_queue;
    SELECT count(*) INTO v_log FROM ingest.partner_catalog_import_dispatch_log WHERE run_id = ANY (v_runs);
    v_temoin := position('temoin_h31' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0;
    RAISE EXCEPTION 'h31-annule';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM IS DISTINCT FROM 'h31-annule' THEN RAISE; END IF;
  END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  v_t := 'T16 aucune requete pg_net, aucun envoi journalise, l''envoi reel revenu apres la sous-transaction';
  v_reel := position('net.http_post' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0
            AND position('temoin_h31' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) = 0;
  IF v_q0 IS NOT NULL AND v_q1 = v_q0 AND v_log = 0 AND coalesce(array_length(v_runs, 1), 0) > 0
     AND v_temoin AND v_reel
     AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = ANY (v_runs))
  THEN v_passed := v_passed+1;
  ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : file pg_net='||coalesce(v_q0::text,'NULL')||'->'||coalesce(v_q1::text,'NULL')
       ||' envois journalises='||coalesce(v_log::text,'NULL')||' runs='||coalesce(array_length(v_runs, 1), 0)
       ||' temoin en place pendant='||coalesce(v_temoin::text,'NULL')||' envoi reel revenu='||coalesce(v_reel::text,'NULL')); END IF;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H31-RETRAITER-EFFACEMENT OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'H31-RETRAITER-EFFACEMENT ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
