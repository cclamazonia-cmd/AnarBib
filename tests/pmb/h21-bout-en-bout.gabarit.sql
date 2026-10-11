-- =====================================================================
-- AnarBib — Le réimport de bout en bout, sur des fichiers exportés par PMB
-- (H21 lot 8, REGISTRE IMP-26 à IMP-34)
-- Date    : 2026-10-11
--
-- GABARIT de tests/sql/h21_bout_en_bout_tests.sql : src/tests/h21-bout-en-bout.test.js
-- remplace chaque marque par ce que la VRAIE edge function d'import écrit pour
-- les fichiers que PMB 8.1 a exportés lui-même (tests/pmb/fixtures) :
--   v1  pmb-8.1.1.1_jeu-de-test.unimarc.iso           le premier export ;
--   v2  pmb-8.1.1.1_jeu-de-test-v2.unimarc.iso        le deuxième (tests/pmb/banc/h21-v2.sql) ;
--   v2s pmb-8.1.1.1_jeu-de-test-v2-seuil.unimarc.iso  sa variante au-dessus du seuil ;
--   v3  pmb-8.1.1.1_jeu-de-test-v3.unimarc.iso        le troisième (h21-v3.sql).
-- Chaque cas des fichiers est dit dans tests/pmb/h21-bout-en-bout-cas.json (avec
-- l'étape de cette suite qui le prouve). Aucune règle n'est posée ici : la suite
-- prouve que celles des lots 0 à 7 tiennent ensemble.
--
-- Les gestes sont ceux de l'écran, sous les rôles réels (SET LOCAL ROLE
-- authenticated, request.jwt.claims) : coordination de BLMF (1111…), lectrice
-- de BLMF passée librarian (3333…), coordination de la bibliothèque B (4444…),
-- administration du réseau (2222…). Ce que l'edge function écrit (lignes de
-- staging, rapprochement, compteurs, bilan du run) est rejoué tel quel, en
-- postgres, par pg_temp.l8_ef.
--
-- SÉCURITÉ. Le relais ingest.fn_dispatch_partner_catalog_import fait un
-- net.http_post vers les edge functions de l'instance (sur le banc local :
-- celles de la PRODUCTION). Il est remplacé, dès l'entrée, par un TÉMOIN qui
-- écrit le journal d'envoi comme lui, sans rien envoyer ; vérifié avant tout
-- appel (sinon la suite s'arrête), annulé avec le reste.
--
-- T01 premier import (v1) : déposé, envoyé, analysé ; 50 lignes nouvelles,
--     promues, révisées, publiées : 50 notices, 33 exemplaires, leurs bases.
-- T02 retouches dans AnarBib, par les gestes de l'écran : la librarian change
--     l'éditeur d'une notice (5) et la cote d'un exemplaire (5) ; la
--     coordination l'année d'une notice (8) et la note d'un exemplaire (6) ;
--     B prend un exemplaire sur deux notices (10, 11) ; l'administration
--     réattribue une notice à B (13) ; un exemplaire part en prêt (19).
-- T03 deuxième import (v2), sous le jeton de la coordination : déposé,
--     « export complet » coché, envoyé, analysé ; reconnaissance (49 notices
--     reconnues, 1 nouvelle, la notice 16 absente) ; « plus détenue » (13) ;
--     « Créer » refusé sur une ligne reconnue ; drapeau refusé après l'envoi.
-- T04 recalcul de la comparaison, par pages : verdicts de chaque cas (notices
--     et exemplaires), dans la liste et le détail de l'écran ; aucune écriture.
-- T05 divergences (notices partagées 10 et 11) : les deux coordinations les
--     voient (fn_divergences_a_traiter), ni la librarian ni la lectrice.
-- T06 « Rapprocher » (toutes les lignes reconnues) : l'exemplaire ajouté devient
--     un brouillon dans le lot du run ; déjà là : ligne rejetée d'office ; sans
--     code, réétiqueté, code repris, déplacé : signalés, rien d'écrit ; la notice
--     réattribuée (13) : son exemplaire « parti chez B » (IMP-35), rien de
--     recréé, la ligne rejetée d'office.
-- T07 « Préparer » : un brouillon de mise à jour (notice 4), deux d'exemplaires
--     (3 et 4) ; chaque autre ligne ignorée avec sa raison ; librarian refusée.
-- T08 la notice nouvelle promue dans le lot du run ; l'exemplaire déplacé vers
--     elle écarté (signalé) ; son exemplaire neuf seul.
-- T09 divergences : BLMF applique (notice 10, brouillon prérempli, publié) ;
--     B écarte (notice 11).
-- T10 retraits : constat (disparu 18, engagé 19 en prêt ; l'exemplaire de la
--     notice absente jamais disparu), seuil sous 10 %, « Proposer » : un
--     brouillon ; librarian refusée ; second geste : rien.
-- T11 révision : rapport de l'écran (mises à jour, exemplaires, retraits) ;
--     publication refusée avant l'approbation ; approbation ; publication.
-- T12 après la publication : chaque valeur du fichier appliquée là où elle
--     devait l'être, chaque valeur AnarBib intacte là où elle devait l'être,
--     bases avancées selon IMP-31 d, l'exemplaire retiré, rien d'écrit chez B,
--     circulation intacte.
-- T13 zéro doublon : notices (identifiant d'origine, ISBN), exemplaires
--     (code, expl_id), lignes jamais deux fois converties.
-- T14 l'export d'AnarBib après le deuxième import (H24) : exactement l'export
--     figé (tests/pmb/h21-bout-en-bout-export.json), que
--     src/tests/h21-bout-en-bout.test.js relit par l'analyse.
-- T15 seuil au-dessus (v2s, run annulé) : bloqué sans confirmation, rien
--     proposé ; confirmé : proposé.
-- T16 un exemplaire plus récent que le run (né du v3, dans un run archivé) :
--     jamais disparu pour le run 2 (annulé).
-- T17 troisième import, identique au deuxième : RIEN de nouveau — aucun
--     brouillon, aucune divergence neuve, aucun retrait à proposer ; les seuls
--     signaux sont ceux que le run 2 a laissés (répétés, pas nouveaux).
-- T18 import v3 : le retiré réapparu — levée proposée, révisée, publiée ;
--     l'exemplaire neuf rapproché ; zéro doublon ; circulation intacte.
-- T19 mesure : chaque appel de l'écran sur le fichier entier < 8 s (NOTICE
--     H21L8-MESURE).
-- T05b (revue du 11/10) « Proposer les retraits » seul, sans « Rapprocher »
--     avant : « Préparer » puis la promotion rejoignent son lot (annulé).
-- T20 (IMP-35, 11/10/2026) le constat d'un exemplaire réattribué, condition par
--     condition : par l'expl_id de même source (code changé aussi), par le code
--     d'un exemplaire de la source quand le fichier n'a pas d'expl_id ou que
--     l'exemplaire de B n'en a pas, jamais quand les deux expl_id diffèrent (le
--     code recyclé ailleurs ne bloque rien : nouveau), jamais par une autre
--     source, la bibliothèque importatrice d'abord, avant « déjà en
--     brouillon » ; l'exemplaire de B intact ; une notice que plus personne ne
--     détient n'est pas « préparable ».
-- T21 (revue du 11/10) mesure du constat : 5 000 codes neufs sur une source déjà
--     riche de 5 000 exemplaires, < 8 s (NOTICE H21L8-MESURE-CONSTAT ; sans les
--     index du lot 8 : ~5 s).
-- Les comptes sont des écarts depuis le début de la suite (revue du 11/10).
--     (T04 : « préparable » ne compte plus la partie notice d'une notice
--     partagée ou plus détenue.)
--
-- Captures (tests/pmb/capturer-h21-bout-en-bout.sh) : avec anarbib.h21l8_capture
-- = on, la suite émet l'export de T14 (NOTICE H21L8-EXPORT) et les réponses de
-- l'écran sur le run 2 (NOTICE H21L8-ECRAN).
-- Toutes les écritures sont annulées : la suite se termine par un RAISE.
--   Bilan OK : 'H21-BOUT-EN-BOUT OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord  uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_admin  uuid := '22222222-2222-2222-2222-222222222222';  -- compte sans rôle (seed) -> administration du réseau ici
  v_libr   uuid := '33333333-3333-3333-3333-333333333333';  -- lectrice BLMF (seed) -> librarian ici
  v_coordB uuid := '44444444-4444-4444-4444-444444444444';  -- devient coordination de B ici
  v_lib    uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_libB   uuid;
  v_l1 jsonb := /*@@LIGNES:v1@@*/;   v_f1 jsonb := /*@@FIN:v1@@*/;
  v_l2 jsonb := /*@@LIGNES:v2@@*/;   v_f2 jsonb := /*@@FIN:v2@@*/;
  v_ls jsonb := /*@@LIGNES:v2s@@*/;  v_fs jsonb := /*@@FIN:v2s@@*/;
  v_l3 jsonb := /*@@LIGNES:v3@@*/;   v_f3 jsonb := /*@@FIN:v3@@*/;
  v_export_fige jsonb := /*@@EXPORT@@*/;
  v_src bigint; v_run1 bigint; v_run2 bigint; v_run3 bigint; v_run4 bigint;
  v_lot1 bigint; v_lot2 bigint; v_lot4 bigint;
  v_res jsonb; v_x text; v_h text[]; v_n int;
  -- les notices et exemplaires des cas, par leur identifiant d'origine
  v_b jsonb := '{}'::jsonb;        -- 001 -> books.id
  v_e jsonb := '{}'::jsonb;        -- expl_id -> exemplares.id
  v_r2 jsonb := '{}'::jsonb;       -- 001 -> ligne du run 2
  v_ms numeric; v_mesures text[] := ARRAY[]::text[];
  v_empreinte_b text; v_empreinte_circ text; v_empreinte text; v_apres text;
  v_nb0 bigint; v_ne0 bigint;   -- notices et exemplaires du seed
  v_nlot0 bigint; v_nret0 bigint;   -- lots et brouillons de retrait au départ (comptes en écart)
  v_ecran_avant jsonb;
BEGIN
  -- ── Décor ───────────────────────────────────────────────────────────
  SELECT count(*) INTO v_nb0 FROM public.books;
  SELECT count(*) INTO v_ne0 FROM public.exemplares;
  SELECT count(*) INTO v_nlot0 FROM public.catalog_batches;
  SELECT count(*) INTO v_nret0 FROM public.exemplar_drafts WHERE import_retrait IS NOT NULL;
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  UPDATE public.libraries SET tombo_pattern = '{"prefix": "L8-", "year": false, "pad": 4}'::jsonb,
         bib_ref_auto = true, bib_ref_prefix = 'L8-REF-', bib_ref_pad = 4 WHERE id = v_lib;
  INSERT INTO public.libraries (id, slug, name, is_active, visibility_level, tombo_pattern)
  VALUES (gen_random_uuid(), 'essai-h21-l8-b', 'Essai H21 lot 8 — B', true, 'private',
          '{"prefix": "L8B-", "year": false, "pad": 4}'::jsonb)
  RETURNING id INTO v_libB;
  UPDATE public.user_library_memberships SET status = 'inactive', is_primary = false WHERE user_id = v_coordB;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
  VALUES (v_coordB, v_libB, 'coordenador', 'active', true);
  UPDATE public.user_library_memberships SET role = 'librarian' WHERE user_id = v_libr AND library_id = v_lib;

  -- Le témoin d'envoi (voir l'en-tête) : le journal comme le relais, aucun envoi.
  EXECUTE $f$CREATE OR REPLACE FUNCTION ingest.fn_dispatch_partner_catalog_import(p_run_id bigint, p_force_reparse boolean DEFAULT false)
    RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'ingest', 'public', 'auth'
    AS $b$ DECLARE v_log bigint; BEGIN
      INSERT INTO ingest.partner_catalog_import_dispatch_log (run_id, force_reparse, request_body, requested_by, dispatch_status)
      VALUES (p_run_id, p_force_reparse, jsonb_build_object('run_id', p_run_id, 'force_reparse', p_force_reparse), auth.uid(), 'sent')
      RETURNING id INTO v_log;
      RETURN jsonb_build_object('ok', true, 'temoin_h21l8', true, 'run_id', p_run_id, 'dispatch_log_id', v_log, 'force_reparse', p_force_reparse);
    END $b$ $f$;
  IF position('temoin_h21l8' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) = 0
     OR position('net.http_post' IN pg_get_functiondef('ingest.fn_dispatch_partner_catalog_import(bigint, boolean)'::regprocedure)) > 0 THEN
    RAISE EXCEPTION 'H21L8 : le témoin d''envoi n''est pas en place — arrêt avant tout appel';
  END IF;

  -- Ce que l'edge function écrit pour un fichier (src/tests/h21-bout-en-bout.test.js
  -- en capture les écritures) : le run « en cours », les lignes, le
  -- rapprochement et les compteurs (ses deux RPC), puis le bilan.
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_ef(p_run bigint, p_lignes jsonb, p_fin jsonb) RETURNS jsonb LANGUAGE plpgsql AS $b$
    DECLARE v_m jsonb; v_c jsonb; v_fichier bigint;
    BEGIN
      UPDATE ingest.partner_catalog_import_runs
         SET run_status = 'processing', started_at = now(), finished_at = NULL, parser_version = p_fin->>'parser_version'
       WHERE id = p_run;
      SELECT id INTO v_fichier FROM ingest.partner_catalog_import_files WHERE run_id = p_run AND file_role = 'uploaded' ORDER BY id DESC LIMIT 1;
      INSERT INTO ingest.partner_catalog_staging_rows (run_id, source_file_id, row_no, external_key, item_type, title, subtitle,
             responsibility_statement, authors, publisher, place_of_publication, publication_year, edition_statement, language,
             isbn, issn, subjects, raw_payload, normalized_payload, parse_status, match_status, review_status, confidence,
             warnings, editorial_decision, selected_for_draft)
      SELECT p_run, v_fichier, r.row_no, r.external_key, r.item_type, r.title, r.subtitle, r.responsibility_statement, r.authors,
             r.publisher, r.place_of_publication, r.publication_year, r.edition_statement, r.language, r.isbn, r.issn, r.subjects,
             r.raw_payload, r.normalized_payload, r.parse_status, r.match_status, r.review_status, r.confidence, r.warnings,
             r.editorial_decision, r.selected_for_draft
        FROM jsonb_to_recordset(p_lignes) AS r(row_no integer, external_key text, item_type text, title text, subtitle text,
             responsibility_statement text, authors jsonb, publisher text, place_of_publication text, publication_year text,
             edition_statement text, language text, isbn text, issn text, subjects jsonb, raw_payload jsonb,
             normalized_payload jsonb, parse_status text, match_status text, review_status text, confidence numeric,
             warnings jsonb, editorial_decision text, selected_for_draft boolean);
      v_m := to_jsonb(ingest.fn_match_partner_catalog_run(p_run, NULL));
      v_c := to_jsonb(ingest.fn_refresh_partner_catalog_run_counters(p_run));
      UPDATE ingest.partner_catalog_import_runs
         SET detected_format = p_fin->>'detected_format', run_status = 'ready_for_review',
             imported_rows = (p_fin->>'imported_rows')::int, parser_version = p_fin->>'parser_version',
             summary = (p_fin->'summary') || jsonb_build_object('parsed_at', now(), 'matched_at', now(),
                                                               'matching_result', v_m, 'counter_refresh_result', v_c),
             finished_at = now()
       WHERE id = p_run;
      UPDATE ingest.partner_catalog_import_files
         SET detected_format = p_fin->>'detected_format', parse_status = 'parsed'
       WHERE id = v_fichier;
      RETURN v_m;
    END $b$ $f$;

  -- Un dépôt par l'écran (ImportacoesPage.handleUploadAndProcess) : la
  -- source propre, le run, l'export complet s'il est coché, l'envoi.
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_deposer(p_nom text, p_export_complet boolean) RETURNS bigint LANGUAGE plpgsql AS $b$
    DECLARE v_src bigint; v_run bigint;
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_src := (public.fn_import_own_source()->>'source_id')::bigint;
      v_run := (public.fn_import_create(v_src, 'partner/manual/import/2026-10-11/' || p_nom, p_nom,
                                        'catalogos_parceiros_raw', 'application/octet-stream', 70000, NULL, 'marc_iso2709')->>'run_id')::bigint;
      IF p_export_complet THEN PERFORM public.fn_import_set_export_complet(v_run, true); END IF;
      PERFORM public.fn_import_dispatch(v_run);
      EXECUTE 'RESET ROLE';
      RETURN v_run;
    EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; RAISE;
    END $b$ $f$;

  -- L'empreinte du catalogue (« aucune écriture ») : notices, responsabilités,
  -- fonds, exemplaires, identifiants d'origine, brouillons, lots, bases — hors
  -- les comptes de disponibilité et les horodatages de mise à jour.
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_catalogue() RETURNS text LANGUAGE sql AS $b$
    SELECT md5(concat_ws('|',
      (SELECT string_agg(md5((to_jsonb(x) - ARRAY['available_count', 'updated_at'])::text), ',' ORDER BY x.id) FROM public.books x),
      (SELECT string_agg(md5((to_jsonb(x) - 'updated_at')::text), ',' ORDER BY x.id) FROM public.book_contributors x),
      (SELECT string_agg(md5((to_jsonb(x) - ARRAY['exemplares_total', 'available_count', 'updated_at'])::text), ',' ORDER BY x.id) FROM public.book_holdings x),
      (SELECT string_agg(md5((to_jsonb(x) - 'updated_at')::text), ',' ORDER BY x.id) FROM public.exemplares x),
      (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM public.book_external_ids x),
      (SELECT string_agg(md5((to_jsonb(x) - 'updated_at')::text), ',' ORDER BY x.id) FROM public.book_drafts x),
      (SELECT string_agg(md5((to_jsonb(x) - 'updated_at')::text), ',' ORDER BY x.id) FROM public.exemplar_drafts x),
      (SELECT string_agg(md5((to_jsonb(x) - 'updated_at')::text), ',' ORDER BY x.id) FROM public.catalog_batches x),
      (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM ingest.book_import_baselines x),
      (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM ingest.exemplar_import_baselines x)))
  $b$ $f$;

  -- Le catalogue PUBLIÉ seul (notices, responsabilités, fonds, exemplaires,
  -- identifiants d'origine, bases) : un geste qui ne fait que des brouillons
  -- ne le change pas.
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_publie() RETURNS text LANGUAGE sql AS $b$
    SELECT md5(concat_ws('|',
      (SELECT string_agg(md5((to_jsonb(x) - ARRAY['available_count', 'updated_at'])::text), ',' ORDER BY x.id) FROM public.books x),
      (SELECT string_agg(md5((to_jsonb(x) - 'updated_at')::text), ',' ORDER BY x.id) FROM public.book_contributors x),
      (SELECT string_agg(md5((to_jsonb(x) - ARRAY['exemplares_total', 'available_count', 'updated_at'])::text), ',' ORDER BY x.id) FROM public.book_holdings x),
      (SELECT string_agg(md5((to_jsonb(x) - 'updated_at')::text), ',' ORDER BY x.id) FROM public.exemplares x),
      (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM public.book_external_ids x),
      (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM ingest.book_import_baselines x),
      (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM ingest.exemplar_import_baselines x)))
  $b$ $f$;

  -- La base d'une notice importée par BLMF, par son identifiant d'origine.
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_base(p_lib uuid, p_src bigint, p_cle text) RETURNS bigint LANGUAGE sql AS $b$
    SELECT bl.id FROM ingest.book_import_baselines bl JOIN public.book_external_ids x ON x.id = bl.external_id_id
     WHERE x.library_id = p_lib AND x.scheme = 'import:' || p_src AND x.value = p_cle
  $b$ $f$;
  -- Un export sans ce qui dépend du banc (identifiants internes, cotes
  -- numérotées, tombos, schéma « import:<id> »).
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_sans_ids(p jsonb) RETURNS jsonb LANGUAGE plpgsql AS $b$
    BEGIN
      IF jsonb_typeof(p) = 'object' THEN
        RETURN coalesce((SELECT jsonb_object_agg(k, pg_temp.l8_sans_ids(v)) FROM jsonb_each(p) x(k, v)
                          WHERE k NOT IN ('id', 'bibRef', 'tombo', 'authorId', 'scheme', 'holdingId', 'bookId', 'workId', 'serialId')), '{}'::jsonb);
      ELSIF jsonb_typeof(p) = 'array' THEN
        RETURN coalesce((SELECT jsonb_agg(pg_temp.l8_sans_ids(v) ORDER BY n) FROM jsonb_array_elements(p) WITH ORDINALITY x(v, n)), '[]'::jsonb);
      END IF;
      RETURN p;
    END $b$ $f$;

  -- Les doublons, chez BLMF : une même valeur d'identifiant d'origine sur deux
  -- notices (ou deux fois), un même ISBN sur deux notices qu'elle détient, un
  -- même code ou un même expl_id de la source sur deux exemplaires, une ligne
  -- d'import convertie deux fois. Rend la liste des écarts (vide : aucun).
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_doublons(p_lib uuid, p_src bigint) RETURNS text[] LANGUAGE sql AS $b$
    SELECT coalesce(array_agg(e ORDER BY e), ARRAY[]::text[]) FROM (
      SELECT 'origine ' || value || ' x' || count(*) AS e FROM public.book_external_ids
       WHERE library_id = p_lib AND scheme = 'import:' || p_src GROUP BY value HAVING count(*) > 1
      UNION ALL
      SELECT 'isbn ' || k || ' x' || count(DISTINCT b.id) FROM public.books b
        JOIN public.book_holdings h ON h.book_id = b.id AND h.library_id = p_lib
        CROSS JOIN LATERAL (SELECT public.fn_isbn_coeur(b.isbn) AS k) c
       WHERE nullif(c.k, '') IS NOT NULL
         AND c.k IN (SELECT public.fn_isbn_coeur(b2.isbn) FROM public.books b2 JOIN public.book_external_ids x2 ON x2.book_id = b2.id
                      WHERE x2.library_id = p_lib AND x2.scheme = 'import:' || p_src)
       GROUP BY k HAVING count(DISTINCT b.id) > 1
      UNION ALL
      SELECT 'code ' || source_item_code || ' x' || count(*) FROM public.exemplares
       WHERE library_id = p_lib AND source_item_code IS NOT NULL GROUP BY source_item_code
      HAVING count(*) > 1 AND bool_or(import_source_id IS NOT DISTINCT FROM p_src)
      UNION ALL
      SELECT 'expl_id ' || source_item_id || ' x' || count(*) FROM public.exemplares
       WHERE library_id = p_lib AND import_source_id = p_src AND source_item_id IS NOT NULL GROUP BY source_item_id HAVING count(*) > 1
      UNION ALL
      SELECT 'ligne ' || staging_row_id || ' x' || count(*) FROM ingest.partner_catalog_row_to_draft
       WHERE run_id IN (SELECT r.id FROM ingest.partner_catalog_import_runs r WHERE r.source_id = p_src)
       GROUP BY staging_row_id HAVING count(*) > 1) d
  $b$ $f$;

  -- Ce que l'écran reçoit d'un run (capture), sous le jeton courant.
  EXECUTE $f$CREATE FUNCTION pg_temp.l8_ecran(p_run bigint, p_lignes jsonb) RETURNS jsonb LANGUAGE plpgsql AS $b$
    DECLARE v jsonb;
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      v := jsonb_build_object(
        'run', (SELECT to_jsonb(r) FROM public.fn_import_list_runs(NULL) r WHERE r.id = p_run),
        'lignes', (SELECT jsonb_agg(to_jsonb(r) ORDER BY r.row_no) FROM public.fn_import_list_run_rows(p_run) r),
        'comparaisons', (SELECT jsonb_object_agg(k, public.fn_import_row_comparison(p_run, (p_lignes->>k)::bigint))
                           FROM unnest(ARRAY['3', '4', '5', '6', '7', '8', '9', '10', '11', '13']) k),
        'retraits', public.fn_import_retraits(p_run, 200, 0),
        'divergences', public.fn_divergences_a_traiter(NULL, 50, 0));
      EXECUTE 'RESET ROLE';
      RETURN v;
    EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; RAISE;
    END $b$ $f$;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ── T01 ─────────────────────────────────────────────────────────────
  v_t := 'T01 premier import (v1) : 50 lignes nouvelles, promues, revisees, publiees : 50 notices, 33 exemplaires, leurs bases';
  DECLARE v_ids bigint[]; v_rev jsonb;
  BEGIN
    v_run1 := pg_temp.l8_deposer('pmb-8.1.1.1_jeu-de-test.unimarc.iso', false);
    v_src := (SELECT source_id FROM ingest.partner_catalog_import_runs WHERE id = v_run1);
    PERFORM pg_temp.l8_ef(v_run1, v_l1, v_f1);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT array_agg(id ORDER BY row_no) INTO v_ids FROM public.fn_import_list_run_rows(v_run1) WHERE match_status = 'new_record';
    PERFORM public.fn_import_set_editorial(v_run1, v_ids, 'accept_new', 'page import: validation individuelle');
    v_res := public.fn_import_promote(v_run1, p_row_ids := v_ids);
    v_lot1 := (v_res->>'batch_id')::bigint;
    PERFORM public.fn_batch_assign_bib_refs(v_lot1, true);
    v_rev := public.fn_batch_review_request(v_lot1, NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_review_verdict((v_rev->>'review_id')::bigint, 'approved', NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.publish_catalog_batch(v_lot1);
    EXECUTE 'RESET ROLE';
    SELECT jsonb_object_agg(x.value, x.book_id) INTO v_b
      FROM public.book_external_ids x WHERE x.library_id = v_lib AND x.scheme = 'import:' || v_src;
    SELECT jsonb_object_agg(x.source_item_id, x.id) INTO v_e
      FROM public.exemplares x WHERE x.library_id = v_lib AND x.import_source_id = v_src;
    IF cardinality(v_ids) = /*@@N:v1@@*/
       AND (SELECT count(*) FROM public.book_drafts WHERE batch_id = v_lot1 AND status = 'published') = /*@@N:v1@@*/
       AND (SELECT count(*) FROM jsonb_object_keys(v_b)) = /*@@N:v1@@*/
       AND (SELECT count(*) FROM jsonb_object_keys(v_e)) = /*@@NX:v1@@*/
       AND (SELECT count(*) FROM ingest.book_import_baselines bl JOIN public.book_external_ids x ON x.id = bl.external_id_id
             WHERE x.library_id = v_lib AND x.scheme = 'import:' || v_src) = /*@@N:v1@@*/
       AND (SELECT count(*) FROM ingest.exemplar_import_baselines bl JOIN public.exemplares x ON x.id = bl.exemplar_id
             WHERE x.import_source_id = v_src) = /*@@NX:v1@@*/
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce(v_res::text, 'NULL'), 300)
         ||' notices='||(SELECT count(*) FROM jsonb_object_keys(v_b))||' exemplaires='||(SELECT count(*) FROM jsonb_object_keys(v_e))); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T02 ─────────────────────────────────────────────────────────────
  -- Retouches dans AnarBib, par les gestes de l'écran : « Éditer » une notice
  -- (create_book_draft_from_book, le formulaire écrit le brouillon,
  -- publish_book_draft), « Modifier » un exemplaire publié
  -- (fn_exemplaire_modifier_et_publier), un exemplaire ajouté depuis la
  -- notice par une autre bibliothèque (ExemplaresPanel : brouillon, puis
  -- publish_exemplar_draft), la réattribution d'une notice par
  -- l'administration, un prêt (fn_v2_create_emprestimo_by_holdings).
  v_t := 'T02 retouches AnarBib par l''ecran : librarian (notice 5, exemplaire 5), coordination (notice 8, exemplaire 6), B (10, 11), administration (13), pret (19)';
  DECLARE v_d bigint; v_m text[] := ARRAY[]::text[]; v_pret record;
  BEGIN
    -- la librarian : l'éditeur de la notice 5, la cote de l'exemplaire 5
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libr, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_d := public.create_book_draft_from_book((v_b->>'5')::bigint, NULL);
    UPDATE public.book_drafts SET editora = 'Éditions retouchées (AnarBib)' WHERE id = v_d;
    PERFORM public.publish_book_draft(v_d);
    PERFORM public.fn_exemplaire_modifier_et_publier((v_e->>'5')::bigint, '{"shelf_location": "JR CAU 2"}'::jsonb);
    EXECUTE 'RESET ROLE';
    -- la coordination : l'année de la notice 8, la note de l'exemplaire 6
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_d := public.create_book_draft_from_book((v_b->>'8')::bigint, NULL);
    UPDATE public.book_drafts SET ano = '1995' WHERE id = v_d;
    PERFORM public.publish_book_draft(v_d);
    PERFORM public.fn_exemplaire_modifier_et_publier((v_e->>'6')::bigint, '{"notes": "Reliure reprise à la main, à surveiller."}'::jsonb);
    EXECUTE 'RESET ROLE';
    -- B : un exemplaire sur les notices 10 et 11, depuis la notice
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    FOR v_d IN
      INSERT INTO public.exemplar_drafts (action, status, target_bib_ref, target_library_id, tombo, circulation_policy, visibility, created_by, updated_by)
      SELECT 'create', 'draft', bk.bib_ref, v_libB, NULL, 'ambos', 'public', v_coordB, v_coordB
        FROM public.books bk WHERE bk.id IN ((v_b->>'10')::bigint, (v_b->>'11')::bigint)
      RETURNING id
    LOOP
      PERFORM public.publish_exemplar_draft(v_d);
    END LOOP;
    EXECUTE 'RESET ROLE';
    -- l'administration : la notice 13 réattribuée à B
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.network_admin_reassign_book_to_library((v_b->>'13')::bigint, v_libB);
    EXECUTE 'RESET ROLE';
    -- un prêt sur l'exemplaire 19 (notice 17), par la coordination, à la librarian
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT * INTO v_pret FROM public.fn_v2_create_emprestimo_by_holdings(v_libr,
      ARRAY(SELECT x.holding_id FROM public.exemplares x WHERE x.id = (v_e->>'19')::bigint), NULL, 'H21 lot 8');
    EXECUTE 'RESET ROLE';
    -- ce que la suite vérifiera intact jusqu'au bout : tout ce qui est à B,
    -- et la circulation
    v_empreinte_b := (SELECT md5(concat_ws('|',
        (SELECT string_agg(md5((to_jsonb(h) - ARRAY['updated_at', 'available_count'])::text), ',' ORDER BY h.id) FROM public.book_holdings h WHERE h.library_id = v_libB),
        (SELECT string_agg(md5((to_jsonb(x) - ARRAY['updated_at'])::text), ',' ORDER BY x.id) FROM public.exemplares x WHERE x.library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(d)::text), ',' ORDER BY d.id) FROM public.exemplar_drafts d WHERE d.target_library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(d)::text), ',' ORDER BY d.id) FROM public.book_drafts d WHERE d.owner_library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM public.book_external_ids x WHERE x.library_id = v_libB))));
    v_empreinte_circ := (SELECT md5(concat_ws('|',
        (SELECT string_agg(md5(to_jsonb(p)::text), ',' ORDER BY p.id) FROM public.emprestimos_v2 p),
        (SELECT string_agg(md5(to_jsonb(i)::text), ',' ORDER BY i.id) FROM public.emprestimo_itens_v2 i),
        (SELECT string_agg(md5(to_jsonb(r)::text), ',' ORDER BY r.id) FROM public.reserva_linhas_v2 r),
        (SELECT string_agg(md5(to_jsonb(c)::text), ',' ORDER BY c.id) FROM public.consulta_linhas_v2 c))));
    IF (SELECT editora FROM public.books WHERE id = (v_b->>'5')::bigint) = 'Éditions retouchées (AnarBib)'
       AND (SELECT shelf_location FROM public.exemplares WHERE id = (v_e->>'5')::bigint) = 'JR CAU 2'
       AND (SELECT ano::text FROM public.books WHERE id = (v_b->>'8')::bigint) = '1995'
       AND (SELECT notes FROM public.exemplares WHERE id = (v_e->>'6')::bigint) = 'Reliure reprise à la main, à surveiller.'
       AND (SELECT count(DISTINCT h.book_id) FROM public.book_holdings h JOIN public.exemplares x ON x.holding_id = h.id
             WHERE h.library_id = v_libB AND h.book_id IN ((v_b->>'10')::bigint, (v_b->>'11')::bigint)) = 2
       AND EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = (v_b->>'13')::bigint AND h.library_id = v_libB)
       AND NOT EXISTS (SELECT 1 FROM public.book_holdings h WHERE h.book_id = (v_b->>'13')::bigint AND h.library_id = v_lib)
       AND v_pret.ok
       AND EXISTS (SELECT 1 FROM public.emprestimo_itens_v2 i WHERE i.item_id = (v_e->>'19')::bigint AND i.returned_at IS NULL)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : pret='||coalesce(to_jsonb(v_pret)::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T03 ─────────────────────────────────────────────────────────────
  v_t := 'T03 deuxieme import (v2) : reconnaissance (49 reconnues, 1 nouvelle, 16 absente), plus detenue (13), Creer refuse sur reconnue, drapeau refuse apres l''envoi';
  DECLARE v_m text[] := ARRAY[]::text[]; v_rows jsonb;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_run2 := pg_temp.l8_deposer('pmb-8.1.1.1_jeu-de-test-v2.unimarc.iso', true);
    -- le drapeau, une fois le run envoyé : refusé
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.fn_import_set_export_complet(v_run2, false); v_x := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_x = PG_EXCEPTION_HINT; END;
    v_m := v_m || v_x;
    EXECUTE 'RESET ROLE';
    PERFORM pg_temp.l8_ef(v_run2, v_l2, v_f2);
    EXECUTE 'SET LOCAL ROLE authenticated';
    SELECT jsonb_object_agg(external_key, jsonb_build_object('id', id, 'm', match_status, 'p', proposed_book_id, 'h', proposed_book_held))
      INTO v_rows FROM public.fn_import_list_run_rows(v_run2);
    SELECT jsonb_object_agg(k, (v->>'id')::bigint) INTO v_r2 FROM jsonb_each(v_rows) x(k, v);
    -- « Créer » sur une ligne reconnue : refusé
    BEGIN PERFORM public.fn_import_set_editorial(v_run2, ARRAY[(v_r2->>'4')::bigint], 'accept_new', 'page import: validation individuelle'); v_x := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_x := 'refuse'; END;
    v_m := v_m || v_x;
    EXECUTE 'RESET ROLE';
    IF current_setting('anarbib.h21l8_debug', true) = 'on' THEN RAISE NOTICE 'H21L8-DEBUG T03 % %', v_m, v_rows; END IF;
    IF v_m = ARRAY['error.import.export_complet_after_dispatch', 'refuse']
       AND (SELECT export_complet FROM ingest.partner_catalog_import_runs WHERE id = v_run2)
       AND (SELECT count(*) FROM jsonb_each(v_rows) x(k, v) WHERE v->>'m' = 'known_record') = /*@@N:v2@@*/ - 1
       AND v_rows->'61'->>'m' = 'new_record'
       AND NOT v_rows ? '16'
       AND NOT EXISTS (SELECT 1 FROM jsonb_each(v_rows) x(k, v) WHERE v->>'m' = 'known_record' AND (v->>'p')::bigint IS DISTINCT FROM (v_b->>k)::bigint)
       AND (v_rows->'13'->>'h')::boolean = false
       AND (SELECT count(*) FROM jsonb_each(v_rows) x(k, v) WHERE (v->>'h')::boolean) = /*@@N:v2@@*/ - 2
       AND (SELECT editorial_decision FROM ingest.partner_catalog_staging_rows WHERE id = (v_r2->>'4')::bigint) = 'pending'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, '/')||' '||left(coalesce(v_rows::text, '∅'), 900)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T04 ─────────────────────────────────────────────────────────────
  -- Le recalcul tel que l'écran le lance (ImportacoesPage : les lignes
  -- reconnues, par pages de 200 — le fichier en tient une), puis ce que
  -- l'écran lit : la liste (comptes par ligne, exemplaires du fichier et leur
  -- verdict) et le détail d'une ligne (B, A, N par champ).
  v_t := 'T04 recalcul : verdicts de chaque cas (notices et exemplaires) dans la liste et le detail ; aucune ecriture au catalogue';
  DECLARE v_rc jsonb; v_sig jsonb; v_sigx jsonb; v_det jsonb; v_m text[] := ARRAY[]::text[]; v_t0 timestamptz;
  BEGIN
    v_empreinte := pg_temp.l8_catalogue();
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_t0 := clock_timestamp();
    v_rc := public.fn_import_recomparer(v_run2, ARRAY(SELECT id FROM public.fn_import_list_run_rows(v_run2)
                                                       WHERE match_status = 'known_record' ORDER BY row_no));
    v_mesures := v_mesures || ('recomparer ' || round(extract(epoch FROM clock_timestamp() - v_t0) * 1000) || ' ms');
    -- la liste : par ligne, les champs qui ne sont pas « inchangé », et chaque
    -- exemplaire du fichier (constat, verdicts cote/note)
    SELECT jsonb_object_agg(r.external_key, (SELECT jsonb_object_agg(k, n) FROM jsonb_each(r.comparison_counts) c(k, n)
                                              WHERE k <> 'inchange' AND n::text <> '0'))
             FILTER (WHERE EXISTS (SELECT 1 FROM jsonb_each(r.comparison_counts) c(k, n) WHERE k <> 'inchange' AND n::text <> '0')),
           jsonb_object_agg(r.external_key, (SELECT jsonb_agg(i->>'constat' || coalesce(':' || (i->'verdicts'->>'shelf_location') || '/' || (i->'verdicts'->>'notes'), '')
                                                                ORDER BY (i->>'n')::int)
                                               FROM jsonb_array_elements(r.exemplaires_maj->'items') i))
             FILTER (WHERE r.exemplaires_maj IS NOT NULL
                       AND EXISTS (SELECT 1 FROM jsonb_array_elements(r.exemplaires_maj->'items') i
                                    WHERE i->>'constat' <> 'deja_la' OR i->'verdicts'->>'shelf_location' <> 'inchange'
                                       OR i->'verdicts'->>'notes' <> 'inchange'))
      INTO v_sig, v_sigx
      FROM public.fn_import_list_run_rows(v_run2) r;
    -- le détail : B, A, N des champs qui ont bougé
    FOR v_x IN SELECT unnest(ARRAY['4', '5', '7', '8', '9']) LOOP
      v_det := public.fn_import_row_comparison(v_run2, (v_r2->>v_x)::bigint);
      v_m := v_m || (v_x || ' ' || (SELECT string_agg(c->>'champ' || ':' || (c->>'verdict') || ':' || coalesce(c->>'b', '∅') || '/'
                                                  || coalesce(c->>'a', '∅') || '/' || coalesce(c->>'n', '∅'), ' ')
                                     FROM jsonb_array_elements(v_det->'champs') c WHERE c->>'verdict' <> 'inchange'));
    END LOOP;
    EXECUTE 'RESET ROLE';
    v_apres := pg_temp.l8_catalogue();
    IF current_setting('anarbib.h21l8_debug', true) = 'on' THEN RAISE NOTICE 'H21L8-DEBUG T04 % | % | % | %', v_sig, v_sigx, v_m, v_rc - 'rows'; END IF;
    IF v_apres = v_empreinte
       AND (v_rc->>'compared_rows')::int = /*@@N:v2@@*/ - 1
       AND v_sig = '{"4": {"source_seule": 1}, "5": {"local_seul": 1}, "7": {"source_seule": 1}, "8": {"conflit": 1},
                    "9": {"source_seule": 1}, "10": {"source_seule": 1}, "11": {"source_seule": 1}, "13": {"source_seule": 1}}'::jsonb
       AND v_sigx = '{"2": ["deja_la:inchange/inchange", "deja_la:inchange/inchange", "nouveau"],
                     "3": ["deja_la:source_seule/inchange"], "4": ["deja_la:inchange/source_seule"],
                     "5": ["deja_la:local_seul/inchange"], "6": ["deja_la:inchange/conflit"],
                     "14": ["reetiquete"], "15": ["sans_code"], "19": ["code_repris"], "44": ["deplace", "deja_la:inchange/inchange"],
                     "13": ["reattribue"]}'::jsonb
       -- « préparable » (lot 8) : la partie notice seulement pour la notice 4 —
       -- ni les partagées (10, 11), ni la plus détenue (13) — ; les exemplaires
       -- 3 et 4 comptés à part
       AND (SELECT jsonb_object_agg(r.external_key, r.update_applicable) FILTER (WHERE r.update_applicable > 0)
              FROM public.fn_import_list_run_rows(v_run2) r) = '{"4": 1}'::jsonb
       AND (SELECT jsonb_object_agg(r.external_key, (r.exemplaires_maj->>'applicables')::int)
                     FILTER (WHERE (r.exemplaires_maj->>'applicables')::int > 0)
              FROM public.fn_import_list_run_rows(v_run2) r) = '{"3": 1, "4": 1}'::jsonb
       AND v_m = ARRAY['4 ano:source_seule:1998/1998/1999', '5 editora:local_seul:Syros jeunesse/Éditions retouchées (AnarBib)/Syros jeunesse',
                       '7 contributors:source_seule:[["Taylor, Mildred D.", "autor"], ["Vassallo-Villaneau, Rose-Marie", "outro"]]/[["Taylor, Mildred D.", "autor"], ["Vassallo-Villaneau, Rose-Marie", "outro"]]/[["Taylor, Mildred D.", "autor"]]',
                       '8 ano:conflit:1993/1995/1994', '9 paginas:source_seule:47/47/∅']
       AND (v_rc->'divergences'->>'posees')::int = 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : catalogue '||CASE WHEN v_apres = v_empreinte THEN 'intact' ELSE 'CHANGE' END
         ||' sig='||coalesce(v_sig::text, '∅')||' ex='||coalesce(v_sigx::text, '∅')||' det='||array_to_string(v_m, ' ; ')||' rc='||coalesce((v_rc - 'rows')::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T05 ─────────────────────────────────────────────────────────────
  v_t := 'T05 divergences des notices partagees (10, 11) : les deux coordinations les voient, la librarian non ; B ne lit pas le run de BLMF';
  DECLARE v_d1 jsonb; v_d2 jsonb; v_d3 jsonb; v_cles text; v_refusB text[] := ARRAY[]::text[];
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_d1 := public.fn_divergences_a_traiter(NULL, 50, 0);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_d2 := public.fn_divergences_a_traiter(NULL, 50, 0);
    -- … mais pas le run de BLMF : ni ses lignes, ni leur détail, ni ses retraits
    BEGIN PERFORM public.fn_import_list_run_rows(v_run2); v_refusB := v_refusB || 'accepte'::text;
    EXCEPTION WHEN OTHERS THEN v_refusB := v_refusB || left(SQLERRM, 3); END;
    BEGIN PERFORM public.fn_import_row_comparison(v_run2, (v_r2->>'10')::bigint); v_refusB := v_refusB || 'accepte'::text;
    EXCEPTION WHEN OTHERS THEN v_refusB := v_refusB || 'refus'::text; END;
    BEGIN PERFORM public.fn_import_retraits(v_run2, 200, 0); v_refusB := v_refusB || 'accepte'::text;
    EXCEPTION WHEN OTHERS THEN v_refusB := v_refusB || 'refus'::text; END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libr, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_d3 := public.fn_divergences_a_traiter(NULL, 50, 0);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_cles := (SELECT string_agg((n->>'book_id') || ':' || (c->>'champ') || ':' || (c->>'verdict'), ',' ORDER BY (n->>'book_id')::bigint)
                 FROM jsonb_array_elements(v_d1->'notices') n, jsonb_array_elements(n->'champs') c);
    IF (v_d1->>'total')::int = 2 AND (v_d2->>'total')::int = 2
       AND v_cles = (SELECT string_agg(x || ':ano:source_seule', ',' ORDER BY x::bigint)
                       FROM unnest(ARRAY[v_b->>'10', v_b->>'11']) x)
       AND v_cles = (SELECT string_agg((n->>'book_id') || ':' || (c->>'champ') || ':' || (c->>'verdict'), ',' ORDER BY (n->>'book_id')::bigint)
                       FROM jsonb_array_elements(v_d2->'notices') n, jsonb_array_elements(n->'champs') c)
       AND (v_d3->>'total')::int = 0
       AND v_refusB = ARRAY['Run', 'refus', 'refus']
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_cles, '∅')||' B='||left(coalesce(v_d2::text, '∅'), 300)||' librarian='||coalesce(v_d3::text, '∅')
         ||' refus B='||array_to_string(v_refusB, '/')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Capture (anarbib.h21l8_capture = on) : ce que l'écran Importations reçoit
  -- du run 2 une fois la comparaison recalculée, avant tout geste (« avant »),
  -- puis après « Rapprocher », « Préparer », la promotion et « Proposer les
  -- retraits » (« apres », T10) : la liste des runs, les lignes, le détail des
  -- lignes qui ont bougé, le panneau des retraits, le bandeau des divergences
  -- (src/tests/h21-lot8-ecran.test.jsx).
  IF current_setting('anarbib.h21l8_capture', true) = 'on' THEN
    v_ecran_avant := pg_temp.l8_ecran(v_run2, v_r2);
  END IF;

  -- ── T05b ────────────────────────────────────────────────────────────
  -- « Proposer les retraits » seul, avant tout « Rapprocher » : il ouvre le lot
  -- du run ; « Préparer » puis la promotion le rejoignent (IMP-27 d ; constat
  -- corrigé par la migration du lot). Essayé puis annulé.
  v_t := 'T05b Proposer les retraits seul ouvre le lot du run ; Preparer puis la promotion le rejoignent (annule)';
  DECLARE v_m text[] := ARRAY[]::text[]; v_p jsonb; v_q jsonb; v_pr jsonb;
  BEGIN
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_p := public.fn_import_proposer_retraits(v_run2);
      v_q := public.fn_import_preparer_mises_a_jour(v_run2, ARRAY[(v_r2->>'4')::bigint]);
      PERFORM public.fn_import_set_editorial(v_run2, ARRAY[(v_r2->>'61')::bigint], 'accept_new', 'page import: validation individuelle');
      v_pr := public.fn_import_promote(v_run2, p_row_ids := ARRAY[(v_r2->>'61')::bigint]);
      EXECUTE 'RESET ROLE';
      v_m := v_m || ((v_p->>'retraits') || '/' || ((v_p->>'batch_id') IS NOT NULL)::text
                     || '/' || ((v_q->>'batch_id') = (v_p->>'batch_id'))::text || '/' || (v_q->>'prepared')
                     || '/' || ((v_pr->>'batch_id') = (v_p->>'batch_id'))::text
                     || '/' || ((SELECT count(*) FROM public.catalog_batches) - v_nlot0));
      RAISE EXCEPTION 'sentinelle';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'sentinelle' THEN RAISE; END IF; END;
    IF v_m = ARRAY['1/true/true/1/true/2']
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, ' / ')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T06 ─────────────────────────────────────────────────────────────
  -- « Rapprocher » : la coordination sélectionne toutes les lignes reconnues,
  -- la notice réattribuée (13) comprise : son exemplaire est « parti chez B »
  -- (IMP-35), rien n'est recréé, la ligne n'apporte rien.
  v_t := 'T06 Rapprocher : l''ajoute en brouillon dans le lot du run ; deja la rejete d''office ; sans code, reetiquete, code repris, deplace signales sans ecriture ; 13 parti chez B, rejetee d''office';
  DECLARE v_rec jsonb; v_dec jsonb; v_t0 timestamptz;
  BEGIN
    v_empreinte := pg_temp.l8_publie();
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_t0 := clock_timestamp();
    v_rec := public.fn_import_reconcile_duplicates(v_run2, ARRAY(SELECT id FROM public.fn_import_list_run_rows(v_run2)
                                                                WHERE match_status = 'known_record' ORDER BY row_no));
    v_mesures := v_mesures || ('rapprocher ' || round(extract(epoch FROM clock_timestamp() - v_t0) * 1000) || ' ms');
    EXECUTE 'RESET ROLE';
    v_lot2 := (v_rec->>'batch_id')::bigint;
    v_apres := pg_temp.l8_publie();
    -- la promotion, venue juste après « Rapprocher », rejoint son lot (IMP-27 d ;
    -- constat corrigé par 20261011090153_h21_lot8_un_lot_ouvert_par_run) —
    -- essayée puis annulée : la suite la refait en T08, après « Préparer »
    BEGIN
      EXECUTE 'SET LOCAL ROLE authenticated';
      PERFORM public.fn_import_set_editorial(v_run2, ARRAY[(v_r2->>'61')::bigint], 'accept_new', 'page import: validation individuelle');
      v_x := (public.fn_import_promote(v_run2, p_row_ids := ARRAY[(v_r2->>'61')::bigint])->>'batch_id');
      EXECUTE 'RESET ROLE';
      RAISE EXCEPTION 'sentinelle';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'sentinelle' THEN RAISE; END IF; END;
    SELECT jsonb_object_agg(external_key, editorial_decision) FILTER (WHERE editorial_decision <> 'reject')
      INTO v_dec FROM ingest.partner_catalog_staging_rows WHERE run_id = v_run2;
    IF v_apres = v_empreinte
       AND v_rec->'verdicts' = '{"deja_la": 24, "deplace": 1, "nouveau": 1, "sans_code": 1, "reattribue": 1, "reetiquete": 1, "code_repris": 1, "deja_en_brouillon": 0}'::jsonb
       AND (v_rec->>'created_items')::int = 1 AND (v_rec->>'rows_signalled')::int = 4 AND (v_rec->>'skipped_rows')::int = 0
       AND (v_rec->>'rows_already_held')::int = /*@@N:v2@@*/ - 6
       -- 13 : parti chez B, rien de recréé, rejetée d'office (note que fn_h21_rejet_par_choix reconnaît)
       AND (SELECT sr.editorial_decision = 'reject' AND sr.created_exemplar_draft_id IS NULL
                   AND sr.editorial_note LIKE 'Todos os exemplares desta linha ja estao na biblioteca ou foram reatribuidos%'
                   AND NOT ingest.fn_h21_rejet_par_choix(sr.editorial_decision, sr.editorial_note, sr.discarded_draft_id)
                   AND sr.exemplaires_constat->'items'->0->>'verdict' = 'reattribue'
                   AND (sr.exemplaires_constat->'items'->0->>'library_id')::uuid = v_libB
                   AND (sr.exemplaires_constat->'items'->0->>'exemplar_id')::bigint = (v_e->>'14')::bigint
              FROM ingest.partner_catalog_staging_rows sr WHERE sr.id = (v_r2->>'13')::bigint)
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.source_item_code = '33700004243347' AND x.status <> 'published')
       -- les lignes qui ne sont pas rejetées : l'ajout (un brouillon) et les quatre signalées ; la nouvelle attend
       AND v_dec = '{"2": "accept_duplicate", "14": "accept_duplicate", "15": "accept_duplicate", "19": "accept_duplicate",
                    "44": "accept_duplicate", "61": "pending"}'::jsonb
       AND (SELECT count(*) FROM public.exemplar_drafts WHERE batch_id = v_lot2) = 1
       AND (SELECT d.source_item_code = 'H21L8-AJOUT-2' AND d.source_item_id = '35' AND d.import_source_id = v_src
                   AND d.import_run_id = v_run2 AND d.target_library_id = v_lib AND d.status = 'draft'
              FROM public.exemplar_drafts d WHERE d.batch_id = v_lot2)
       AND public.fn_batch_is_imported(v_lot2)
       AND ingest.fn_h21_lot_ouvert_du_run(v_run2, v_lib) = v_lot2
       AND v_x::bigint = v_lot2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : publie '||CASE WHEN v_apres = v_empreinte THEN 'intact' ELSE 'CHANGE' END
         ||' '||left(coalesce((v_rec - 'run')::text, '∅'), 600)||' dec='||coalesce(v_dec::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T07 ─────────────────────────────────────────────────────────────
  -- « Préparer la mise à jour » sur toutes les lignes reconnues (l'écran les
  -- offre, rapprochées ou non) : APRÈS « Rapprocher », il rejoint le lot que
  -- « Rapprocher » a ouvert (IMP-27 d — constat corrigé par la migration
  -- 20261011090153_h21_lot8_un_lot_ouvert_par_run : il en ouvrait un second).
  v_t := 'T07 Preparer : notice 4 (annee), exemplaires 3 (cote) et 4 (note), dans le lot du run ; chaque autre ligne ignoree avec sa raison ; librarian refusee';
  DECLARE v_p jsonb; v_refus text; v_t0 timestamptz; v_d record;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libr, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.fn_import_preparer_mises_a_jour(v_run2, ARRAY[(v_r2->>'4')::bigint]); v_refus := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_refus := SQLERRM; END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_empreinte := pg_temp.l8_publie();
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_t0 := clock_timestamp();
    v_p := public.fn_import_preparer_mises_a_jour(v_run2, ARRAY(SELECT id FROM public.fn_import_list_run_rows(v_run2)
                                                               WHERE match_status = 'known_record' ORDER BY row_no));
    v_mesures := v_mesures || ('preparer ' || round(extract(epoch FROM clock_timestamp() - v_t0) * 1000) || ' ms');
    EXECUTE 'RESET ROLE';
    v_apres := pg_temp.l8_publie();
    SELECT d.* INTO v_d FROM public.book_drafts d WHERE d.id = (v_p->'drafts'->0->>'draft_id')::bigint;
    IF v_refus LIKE 'Acesso restrito%'
       AND v_apres = v_empreinte
       AND (v_p->>'batch_id')::bigint = v_lot2
       AND (v_p->>'prepared')::int = 1
       AND v_p->'skipped' = '{"plus_detenue": 1, "partagee": 2, "rien_a_appliquer": 45}'::jsonb
       AND (v_p->'drafts'->0->>'book_id')::bigint = (v_b->>'4')::bigint AND v_p->'drafts'->0->'applied' = '["ano"]'::jsonb
       AND v_d.ano::text = '1999' AND v_d.published_book_id = (v_b->>'4')::bigint AND v_d.batch_id = v_lot2
       AND v_d.titulo = (SELECT titulo FROM public.books WHERE id = (v_b->>'4')::bigint)
       AND (v_p->'exemplaires'->>'prepared')::int = 2
       AND v_p->'exemplaires'->'skipped' = '{"signale": 4, "pas_au_catalogue": 1, "rien_a_appliquer": 22, "autre_bibliotheque": 1}'::jsonb
       AND (SELECT string_agg(x.published_exemplar_id::text || ':' || coalesce(x.shelf_location, '∅') || ':' || coalesce(x.notes, '∅'), ',' ORDER BY x.published_exemplar_id)
              FROM public.exemplar_drafts x WHERE x.batch_id = v_lot2 AND x.import_update IS NOT NULL)
           = (v_e->>'3') || ':ER OPP 2:∅,' || (v_e->>'4') || ':R ZIM:Envoyé en reliure en 2026'
       AND (SELECT count(*) FROM public.catalog_batches) = v_nlot0 + 2   -- le lot du premier import, celui du run 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_refus, '∅')||' lot2='||coalesce(v_lot2::text, '∅')||' '||left(coalesce(v_p::text, '∅'), 700)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T08 ─────────────────────────────────────────────────────────────
  v_t := 'T08 notice nouvelle promue dans le lot du run ; son exemplaire neuf seul, l''exemplaire deplace vers elle ecarte (signale)';
  DECLARE v_pr jsonb; v_ids bigint[] := ARRAY[(v_r2->>'61')::bigint]; v_dn bigint;
  BEGIN
    v_empreinte := pg_temp.l8_publie();
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_import_set_editorial(v_run2, v_ids, 'accept_new', 'page import: validation individuelle');
    v_pr := public.fn_import_promote(v_run2, p_row_ids := v_ids);
    EXECUTE 'RESET ROLE';
    v_apres := pg_temp.l8_publie();
    SELECT created_book_draft_id INTO v_dn FROM ingest.partner_catalog_staging_rows WHERE id = v_ids[1];
    IF v_apres = v_empreinte
       AND (v_pr->>'batch_id')::bigint = v_lot2 AND (v_pr->>'created_drafts')::int = 1 AND (v_pr->>'items_created')::int = 1
       AND (SELECT batch_id FROM public.book_drafts WHERE id = v_dn) = v_lot2
       AND (SELECT string_agg(coalesce(x.source_item_code, '∅') || ':' || coalesce(x.source_item_id, '∅'), ',')
              FROM public.exemplar_drafts x WHERE x.import_staging_row_id = v_ids[1]) = 'H21L8-NOUV-1:37'
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts x WHERE x.source_item_code = '3370000451300' AND x.status <> 'published')
       AND (SELECT count(*) FROM public.catalog_batches) = v_nlot0 + 2   -- le lot du premier import, celui du run 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||left(coalesce((v_pr - 'run')::text, '∅'), 500)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T09 ─────────────────────────────────────────────────────────────
  -- Le bandeau des divergences : BLMF « Appliquer » sur la notice 10 (brouillon
  -- prérempli, hors lot, publié par elle) ; B « Écarter » sur la notice 11.
  v_t := 'T09 divergences : BLMF applique (10, publie : annee du fichier) ; B ecarte (11, base avancee, notice intacte)';
  DECLARE v_a jsonb; v_ec jsonb; v_div10 bigint[]; v_div11 bigint[]; v_avant11 text;
  BEGIN
    SELECT array_agg(id) FILTER (WHERE book_id = (v_b->>'10')::bigint), array_agg(id) FILTER (WHERE book_id = (v_b->>'11')::bigint)
      INTO v_div10, v_div11 FROM ingest.book_import_divergences WHERE statut = 'ouverte';
    v_avant11 := (SELECT md5((to_jsonb(x) - ARRAY['available_count', 'updated_at'])::text) FROM public.books x WHERE x.id = (v_b->>'11')::bigint);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_a := public.fn_divergences_appliquer((v_b->>'10')::bigint, v_div10);
    PERFORM public.publish_book_draft((v_a->>'draft_id')::bigint);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordB, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_ec := public.fn_divergences_ecarter(v_div11);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF cardinality(v_div10) = 1 AND cardinality(v_div11) = 1
       AND v_a->'applied' = '["ano"]'::jsonb AND (v_a->>'library_id')::uuid = v_lib
       AND (SELECT d.batch_id IS NULL AND d.status = 'published' FROM public.book_drafts d WHERE d.id = (v_a->>'draft_id')::bigint)
       AND (SELECT ano::text FROM public.books WHERE id = (v_b->>'10')::bigint) = '1996'
       AND (SELECT statut FROM ingest.book_import_divergences WHERE id = v_div10[1]) = 'appliquee'
       AND (v_ec->>'ecartees')::int = 1
       AND (SELECT statut FROM ingest.book_import_divergences WHERE id = v_div11[1]) = 'ecartee'
       AND (SELECT md5((to_jsonb(x) - ARRAY['available_count', 'updated_at'])::text) FROM public.books x WHERE x.id = (v_b->>'11')::bigint) = v_avant11
       AND ingest.fn_h21_valeur_de_base((SELECT bl.id FROM ingest.book_import_baselines bl JOIN public.book_external_ids x ON x.id = bl.external_id_id
                                          WHERE x.library_id = v_lib AND x.scheme = 'import:' || v_src AND x.value = '11'), 'ano') #>> '{}' = '1997'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : appliquer='||coalesce(v_a::text, '∅')||' ecarter='||coalesce(v_ec::text, '∅')
         ||' statuts='||coalesce((SELECT string_agg(book_id || ':' || statut, ',') FROM ingest.book_import_divergences), '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T10 ─────────────────────────────────────────────────────────────
  v_t := 'T10 retraits : disparu (18), engage (19, pret), hors fichier (16) ; seuil sous 10 % ; Proposer : un brouillon dans le lot du run ; librarian refusee ; second geste : rien';
  DECLARE v_ret jsonb; v_prop jsonb; v_prop2 jsonb; v_refus text; v_v jsonb; v_t0 timestamptz;
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_libr, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN PERFORM public.fn_import_proposer_retraits(v_run2); v_refus := 'accepte';
    EXCEPTION WHEN OTHERS THEN v_refus := SQLERRM; END;
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_empreinte := pg_temp.l8_publie();
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_t0 := clock_timestamp();
    v_ret := public.fn_import_retraits(v_run2, 200, 0);
    v_mesures := v_mesures || ('retraits ' || round(extract(epoch FROM clock_timestamp() - v_t0) * 1000) || ' ms');
    v_t0 := clock_timestamp();
    v_prop := public.fn_import_proposer_retraits(v_run2);
    v_mesures := v_mesures || ('proposer ' || round(extract(epoch FROM clock_timestamp() - v_t0) * 1000) || ' ms');
    v_prop2 := public.fn_import_proposer_retraits(v_run2);
    EXECUTE 'RESET ROLE';
    v_apres := pg_temp.l8_publie();
    SELECT jsonb_object_agg(x->>'expl_id', x->>'verdict' || coalesce(':' || (x->>'motif'), '')) INTO v_v FROM jsonb_array_elements(v_ret->'items') x;
    IF v_refus LIKE 'Acesso restrito%' AND v_apres = v_empreinte
       AND v_ret->'counts' = '{"disparu": 1, "retires": 0, "hors_fichier": 1, "disparu_engage": 1, "retire_reapparu": 0, "disparu_brouillon": 0}'::jsonb
       AND v_v = '{"18": "disparu", "19": "disparu_engage:pret"}'::jsonb
       AND (v_ret->'seuil'->>'atteint')::boolean = false AND (v_ret->'seuil'->>'disparus')::int = 2 AND (v_ret->'seuil'->>'total')::int = 32
       AND (v_ret->>'export_complet')::boolean AND v_ret->>'bloque_retraits' IS NULL
       AND (v_prop->>'retraits')::int = 1 AND (v_prop->>'batch_id')::bigint = v_lot2 AND (v_prop->'ignores'->>'disparu_engage')::int = 1
       AND (v_prop2->>'retraits')::int = 0
       AND (SELECT count(*) FROM public.exemplar_drafts x WHERE x.import_retrait IS NOT NULL AND x.batch_id = v_lot2
              AND x.published_exemplar_id = (v_e->>'18')::bigint) = 1
       AND (SELECT count(*) FROM public.exemplar_drafts x WHERE x.import_retrait IS NOT NULL) = v_nret0 + 1
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_refus, '∅')||' '||left(coalesce((v_ret - 'items')::text, '∅'), 500)
         ||' v='||coalesce(v_v::text, '∅')||' prop='||coalesce(v_prop::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF current_setting('anarbib.h21l8_capture', true) = 'on' THEN
    RAISE NOTICE 'H21L8-ECRAN %', jsonb_build_object('avant', v_ecran_avant, 'apres', pg_temp.l8_ecran(v_run2, v_r2))::text;
  END IF;

  -- ── T11 ─────────────────────────────────────────────────────────────
  -- La révision du lot du run (un seul lot : l'ajout rapproché, la notice
  -- nouvelle, la mise à jour de la notice 4, celles des exemplaires 3 et 4, le
  -- retrait de l'exemplaire 18), telle que l'écran Révision la lit.
  v_t := 'T11 revision : rapport (mises a jour, exemplaires, ecartes, retraits) ; publication refusee avant l''approbation ; approbation ; publication';
  DECLARE v_rev jsonb; v_rap jsonb; v_refus text; v_pub jsonb;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_assign_bib_refs(v_lot2, true);
    BEGIN PERFORM public.publish_catalog_batch(v_lot2); v_refus := 'accepte';
    EXCEPTION WHEN OTHERS THEN GET STACKED DIAGNOSTICS v_refus = PG_EXCEPTION_HINT; END;
    v_rev := public.fn_batch_review_request(v_lot2, NULL);
    v_rap := public.fn_batch_review_report(v_lot2);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_review_verdict((v_rev->>'review_id')::bigint, 'approved', NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_pub := public.publish_catalog_batch(v_lot2);
    EXECUTE 'RESET ROLE';
    IF v_refus = 'error.publish.review_required'
       AND (v_rap->'batch'->>'imported')::boolean
       AND (v_rap->'prepared_updates'->>'count')::int = 1 AND (v_rap->'prepared_updates'->>'applied_fields')::int = 1
       AND v_rap->'prepared_updates'->'examples'->0->>'external_key' = '4'
       AND (v_rap->'prepared_item_updates'->>'count')::int = 2
       AND (SELECT string_agg(x->>'code' || ':' || (x->'applied'->0->>'champ'), ',' ORDER BY x->>'code')
              FROM jsonb_array_elements(v_rap->'prepared_item_updates'->'examples') x) = '33700003413727:shelf_location,33700003470461:notes'
       AND (v_rap->'items'->>'count')::int = 2 AND (v_rap->'items'->>'code_taken')::int = 0
       AND v_rap->'items_set_aside'->'counts' = '{"deja_la": 24, "deplace": 2, "sans_code": 1, "reattribue": 1, "reetiquete": 1, "code_repris": 1, "deja_en_brouillon": 0}'::jsonb
       AND (SELECT x->>'library_name' FROM jsonb_array_elements(v_rap->'items_set_aside'->'examples') x WHERE x->>'verdict' = 'reattribue') = 'Essai H21 lot 8 — B'
       AND (v_rap->'retraits'->>'retraits')::int = 1
       AND (v_rap->'retraits'->'runs'->0->'bilan'->'counts'->>'disparu_engage')::int = 1
       AND (v_rap->'retraits'->'runs'->0->'bilan'->'seuil'->>'atteint')::boolean = false
       AND (v_rap->'updates'->>'rows_with_changes')::int = 1
       AND NOT EXISTS (SELECT 1 FROM public.book_drafts WHERE batch_id = v_lot2 AND status <> 'published')
       AND NOT EXISTS (SELECT 1 FROM public.exemplar_drafts WHERE batch_id = v_lot2 AND status <> 'published')
       AND (SELECT status FROM public.catalog_batches WHERE id = v_lot2) = 'published'
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : refus='||coalesce(v_refus, '∅')||' pub='||left(coalesce(v_pub::text, '∅'), 300)
         ||' rap='||left(coalesce(jsonb_build_object('pu', v_rap->'prepared_updates'->'count', 'piu', v_rap->'prepared_item_updates'->'count',
                      'items', v_rap->'items', 'aside', v_rap->'items_set_aside'->'counts', 'retraits', v_rap->'retraits'->'retraits')::text, '∅'), 700)); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T12 ─────────────────────────────────────────────────────────────
  v_t := 'T12 apres publication : le fichier applique ou il devait l''etre, AnarBib intact ailleurs, bases selon IMP-31 d, retire, B intact, circulation intacte';
  DECLARE v_m text[] := ARRAY[]::text[]; v_x2 text; b61 bigint; v_aj bigint;
  BEGIN
    b61 := (SELECT x.book_id FROM public.book_external_ids x WHERE x.library_id = v_lib AND x.scheme = 'import:' || v_src AND x.value = '61');
    v_aj := (SELECT x.id FROM public.exemplares x WHERE x.library_id = v_lib AND x.source_item_code = 'H21L8-AJOUT-2');
    -- appliqué : notice 4, exemplaires 3 et 4, ajout sur 2, notice 61 et son exemplaire, divergence 10, retrait 18
    v_m := v_m || ((SELECT ano FROM public.books WHERE id = (v_b->>'4')::bigint)
                   || '|' || (SELECT shelf_location FROM public.exemplares WHERE id = (v_e->>'3')::bigint)
                   || '|' || (SELECT notes FROM public.exemplares WHERE id = (v_e->>'4')::bigint)
                   || '|' || (SELECT h.book_id = (v_b->>'2')::bigint AND x.source_item_id = '35' AND x.import_run_id = v_run2
                                FROM public.exemplares x JOIN public.book_holdings h ON h.id = x.holding_id WHERE x.id = v_aj)::text
                   || '|' || (SELECT string_agg(x.source_item_code || ':' || x.source_item_id, ',') FROM public.exemplares x
                                JOIN public.book_holdings h ON h.id = x.holding_id WHERE h.book_id = b61)
                   || '|' || (SELECT ano FROM public.books WHERE id = (v_b->>'10')::bigint)
                   || '|' || (SELECT (retire_at IS NOT NULL)::text FROM public.exemplares WHERE id = (v_e->>'18')::bigint));
    -- intact : notices 5, 8, 9, 7, 11, 13 ; exemplaires 5, 6, 19, 15, 16, 20, 23, 28
    v_m := v_m || ((SELECT editora FROM public.books WHERE id = (v_b->>'5')::bigint)
                   || '|' || (SELECT ano FROM public.books WHERE id = (v_b->>'8')::bigint)
                   || '|' || (SELECT paginas::text FROM public.books WHERE id = (v_b->>'9')::bigint)
                   || '|' || (SELECT count(*)::text FROM public.book_contributors WHERE book_id = (v_b->>'7')::bigint)
                   || '|' || (SELECT ano FROM public.books WHERE id = (v_b->>'11')::bigint)
                   || '|' || (SELECT ano FROM public.books WHERE id = (v_b->>'13')::bigint)
                   || '|' || (SELECT shelf_location FROM public.exemplares WHERE id = (v_e->>'5')::bigint)
                   || '|' || (SELECT notes FROM public.exemplares WHERE id = (v_e->>'6')::bigint)
                   || '|' || (SELECT (retire_at IS NULL)::text FROM public.exemplares WHERE id = (v_e->>'19')::bigint)
                   || '|' || (SELECT source_item_code FROM public.exemplares WHERE id = (v_e->>'15')::bigint)
                   || '|' || (SELECT source_item_code FROM public.exemplares WHERE id = (v_e->>'16')::bigint)
                   || '|' || (SELECT source_item_id FROM public.exemplares WHERE id = (v_e->>'20')::bigint)
                   || '|' || (SELECT (h.book_id = (v_b->>'42')::bigint)::text FROM public.exemplares x JOIN public.book_holdings h ON h.id = x.holding_id WHERE x.id = (v_e->>'23')::bigint)
                   || '|' || (SELECT (h.book_id = (v_b->>'50')::bigint)::text FROM public.exemplares x JOIN public.book_holdings h ON h.id = x.holding_id WHERE x.id = (v_e->>'28')::bigint));
    -- bases (IMP-31 d) : avancées à N pour ce qui est appliqué, B gardé ailleurs
    v_m := v_m || ((ingest.fn_h21_valeur_de_base(pg_temp.l8_base(v_lib, v_src, '4'), 'ano') #>> '{}')
                   || '|' || (ingest.fn_h21_valeur_de_base(pg_temp.l8_base(v_lib, v_src, '8'), 'ano') #>> '{}')
                   || '|' || (ingest.fn_h21_valeur_de_base(pg_temp.l8_base(v_lib, v_src, '9'), 'paginas') #>> '{}')
                   || '|' || (ingest.fn_h21_valeur_de_base(pg_temp.l8_base(v_lib, v_src, '5'), 'editora') #>> '{}')
                   || '|' || (ingest.fn_h21_valeur_de_base(pg_temp.l8_base(v_lib, v_src, '10'), 'ano') #>> '{}')
                   || '|' || jsonb_array_length(ingest.fn_h21_valeur_de_base(pg_temp.l8_base(v_lib, v_src, '7'), 'contributors'))
                   || '|' || (SELECT shelf_location FROM ingest.exemplar_import_baselines WHERE exemplar_id = (v_e->>'3')::bigint)
                   || '|' || (SELECT notes FROM ingest.exemplar_import_baselines WHERE exemplar_id = (v_e->>'4')::bigint)
                   || '|' || (SELECT shelf_location FROM ingest.exemplar_import_baselines WHERE exemplar_id = (v_e->>'5')::bigint)
                   || '|' || (SELECT left(notes, 20) FROM ingest.exemplar_import_baselines WHERE exemplar_id = (v_e->>'6')::bigint)
                   || '|' || (SELECT count(*) FROM ingest.exemplar_import_baselines WHERE exemplar_id = v_aj)
                   || '|' || (SELECT count(*) FROM ingest.book_import_baselines bl JOIN public.book_external_ids x ON x.id = bl.external_id_id WHERE x.book_id = b61));
    v_x2 := (SELECT md5(concat_ws('|',
        (SELECT string_agg(md5((to_jsonb(h) - ARRAY['updated_at', 'available_count'])::text), ',' ORDER BY h.id) FROM public.book_holdings h WHERE h.library_id = v_libB),
        (SELECT string_agg(md5((to_jsonb(x) - ARRAY['updated_at'])::text), ',' ORDER BY x.id) FROM public.exemplares x WHERE x.library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(d)::text), ',' ORDER BY d.id) FROM public.exemplar_drafts d WHERE d.target_library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(d)::text), ',' ORDER BY d.id) FROM public.book_drafts d WHERE d.owner_library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM public.book_external_ids x WHERE x.library_id = v_libB))));
    IF v_m = ARRAY['1999|ER OPP 2|Envoyé en reliure en 2026|true|H21L8-NOUV-1:37|1996|true',
                   'Éditions retouchées (AnarBib)|1995|47|2|1996|1998|JR CAU 2|Reliure reprise à la main, à surveiller.|true|33700003453202|33700004118010|20|true|true',
                   '1999|1993|47|Syros jeunesse|1996|2|ER OPP 2|Envoyé en reliure en 2026|JR CAU|Reliure bibliographi|1|1']
       AND v_x2 = v_empreinte_b
       AND (SELECT md5(concat_ws('|',
             (SELECT string_agg(md5(to_jsonb(p)::text), ',' ORDER BY p.id) FROM public.emprestimos_v2 p),
             (SELECT string_agg(md5(to_jsonb(i)::text), ',' ORDER BY i.id) FROM public.emprestimo_itens_v2 i),
             (SELECT string_agg(md5(to_jsonb(r)::text), ',' ORDER BY r.id) FROM public.reserva_linhas_v2 r),
             (SELECT string_agg(md5(to_jsonb(c)::text), ',' ORDER BY c.id) FROM public.consulta_linhas_v2 c)))) = v_empreinte_circ
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, ' ## ')||' B '||CASE WHEN v_x2 = v_empreinte_b THEN 'intact' ELSE 'CHANGE' END); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T13 ─────────────────────────────────────────────────────────────
  v_t := 'T13 zero doublon : notices (identifiant d''origine, ISBN), exemplaires (code, expl_id), lignes converties une fois';
  DECLARE v_m text[] := ARRAY[]::text[];
  BEGIN
    v_m := pg_temp.l8_doublons(v_lib, v_src);
    IF v_m = ARRAY[]::text[]
       AND (SELECT count(*) FROM public.books) = v_nb0 + /*@@N:v1@@*/ + 1
       AND (SELECT count(*) FROM public.exemplares) = v_ne0 + /*@@NX:v1@@*/ + 2 + 2
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, ' ; ')
         ||' notices='||(SELECT count(*) FROM public.books)||' exemplaires='||(SELECT count(*) FROM public.exemplares)); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T14 ─────────────────────────────────────────────────────────────
  -- L'export de l'écran (fn_export_catalog_lote) après le deuxième import,
  -- restreint aux notices importées de la source : figé dans
  -- tests/pmb/h21-bout-en-bout-export.json (comparé sans les identifiants du
  -- banc), relu par src/tests/h21-bout-en-bout.test.js.
  v_t := 'T14 l''export apres le deuxieme import est exactement l''export fige';
  DECLARE v_exp jsonb; v_proj jsonb;
  BEGIN
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_exp := public.fn_export_catalog_lote(v_lib);
    EXECUTE 'RESET ROLE';
    v_exp := jsonb_build_object('library', v_exp->'library',
               'records', (SELECT jsonb_agg(r ORDER BY (r->>'originId'))
                             FROM jsonb_array_elements(v_exp->'records') r
                            WHERE EXISTS (SELECT 1 FROM public.book_external_ids x
                                           WHERE x.book_id = (r->>'id')::bigint AND x.library_id = v_lib AND x.scheme = 'import:' || v_src)));
    IF current_setting('anarbib.h21l8_capture', true) = 'on' THEN
      RAISE NOTICE 'H21L8-EXPORT %', v_exp::text;
    END IF;
    v_proj := pg_temp.l8_sans_ids(v_exp);
    IF v_export_fige IS NULL THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : pas d''export fige (tests/pmb/capturer-h21-bout-en-bout.sh)');
    ELSIF v_proj = pg_temp.l8_sans_ids(v_export_fige) THEN
      v_passed := v_passed+1;
    ELSE
      v_failed := v_failed+1;
      v_failures := v_failures||(v_t||' : '||(SELECT string_agg(coalesce(p->>'originId', a->>'originId'), ',')
                                                FROM jsonb_array_elements(v_proj->'records') WITH ORDINALITY x(p, n)
                                                FULL JOIN jsonb_array_elements(pg_temp.l8_sans_ids(v_export_fige)->'records') WITH ORDINALITY y(a, m) ON m = n
                                               WHERE p IS DISTINCT FROM a));
    END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T15 ─────────────────────────────────────────────────────────────
  -- La variante au-dessus du seuil (v2s), déposée après le run 2 comme un
  -- export complet ; annulée ensuite (sentinelle) : le run 2 reste le fichier
  -- actuel de la source.
  v_t := 'T15 seuil au-dessus (v2s) : atteint, bloque sans confirmation, rien propose ; confirme : propose (annule)';
  DECLARE v_m text[] := ARRAY[]::text[]; v_runS bigint; v_r jsonb; v_p jsonb; v_p2 jsonb;
  BEGIN
    BEGIN
      v_runS := pg_temp.l8_deposer('pmb-8.1.1.1_jeu-de-test-v2-seuil.unimarc.iso', true);
      PERFORM pg_temp.l8_ef(v_runS, v_ls, v_fs);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_r := public.fn_import_retraits(v_runS, 200, 0);
      v_p := public.fn_import_proposer_retraits(v_runS);
      PERFORM public.fn_import_confirmer_export_complet(v_runS);
      v_p2 := public.fn_import_proposer_retraits(v_runS);
      EXECUTE 'RESET ROLE';
      v_m := v_m || ((v_r->'seuil'->>'disparus') || '/' || (v_r->'seuil'->>'total') || '/' || (v_r->'seuil'->>'atteint')
                     || '/' || coalesce(v_r->>'bloque_retraits', '∅') || '/' || (v_r->'counts'->>'hors_fichier')
                     || '/' || (v_p->>'retraits') || '/' || (v_p2->>'retraits') || '/' || (v_p2->'ignores'->>'disparu_engage')
                     || '/' || (SELECT count(*) FROM public.exemplar_drafts WHERE import_retrait->>'run_id' = v_runS::text));
      RAISE EXCEPTION 'sentinelle';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'sentinelle' THEN RAISE; END IF; END;
    IF v_m = ARRAY['20/33/true/seuil_non_confirme/3/0/19/1/19']
       AND NOT EXISTS (SELECT 1 FROM ingest.partner_catalog_import_runs WHERE id = v_runS)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, ' / ')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T16 ─────────────────────────────────────────────────────────────
  -- Un exemplaire entré dans PMB après le deuxième export (v3, H21L8-V3-53),
  -- importé par un run plus récent — rapproché, révisé, publié —, run archivé
  -- ensuite : le run 2 redevient le fichier actuel, et cet exemplaire, absent
  -- de son fichier, n'y est jamais « disparu » (annulé ensuite).
  v_t := 'T16 un exemplaire ne d''un run plus recent (archive) n''est jamais disparu pour le run 2 (annule)';
  DECLARE v_m text[] := ARRAY[]::text[]; v_runX bigint; v_rec jsonb; v_rev jsonb; v_lotX bigint; v_r jsonb; v_neuf bigint;
  BEGIN
    BEGIN
      v_runX := pg_temp.l8_deposer('pmb-8.1.1.1_jeu-de-test-v3.unimarc.iso', false);
      PERFORM pg_temp.l8_ef(v_runX, v_l3, v_f3);
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_rec := public.fn_import_reconcile_duplicates(v_runX, ARRAY(SELECT id FROM public.fn_import_list_run_rows(v_runX) WHERE external_key = '53'));
      v_lotX := (v_rec->>'batch_id')::bigint;
      v_rev := public.fn_batch_review_request(v_lotX, NULL);
      EXECUTE 'RESET ROLE';
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      PERFORM public.fn_batch_review_verdict((v_rev->>'review_id')::bigint, 'approved', NULL);
      EXECUTE 'RESET ROLE';
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      PERFORM public.publish_catalog_batch(v_lotX);
      v_r := public.fn_import_retraits(v_run2, 200, 0);
      v_m := v_m || coalesce(v_r->>'bloque_retraits', '∅');
      PERFORM public.fn_import_archive_run(v_runX, true);
      v_r := public.fn_import_retraits(v_run2, 200, 0);
      EXECUTE 'RESET ROLE';
      v_neuf := (SELECT id FROM public.exemplares WHERE library_id = v_lib AND source_item_code = 'H21L8-V3-53');
      v_m := v_m || ((v_neuf IS NOT NULL)::text || '/' || coalesce(v_r->>'bloque_retraits', '∅') || '/' || (v_r->'counts'->>'disparu')
                     || '/' || (v_r->'counts'->>'retires') || '/' || (v_r->'counts'->>'disparu_engage')
                     || '/' || EXISTS (SELECT 1 FROM jsonb_array_elements(v_r->'items') x WHERE (x->>'exemplar_id')::bigint = v_neuf)::text);
      RAISE EXCEPTION 'sentinelle';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'sentinelle' THEN RAISE; END IF; END;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    IF v_m = ARRAY['run_perime', 'true/∅/0/1/1/false']
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, ' / ')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T17 ─────────────────────────────────────────────────────────────
  -- Le même fichier v2, redéposé (run 3, export complet) : chaque geste de
  -- l'écran, sur toutes les lignes reconnues — rien de nouveau.
  v_t := 'T17 troisieme import identique : aucun brouillon, aucune divergence neuve, aucun retrait ; seuls les signaux laisses par le run 2, repetes';
  DECLARE v_rc jsonb; v_rec jsonb; v_p jsonb; v_prop jsonb; v_ret jsonb; v_div jsonb; v_sig jsonb; v_sigx jsonb;
          v_nbd bigint; v_ned bigint; v_nlot bigint; v_ndiv bigint; v_ids bigint[];
  BEGIN
    SELECT count(*) INTO v_nbd FROM public.book_drafts;
    SELECT count(*) INTO v_ned FROM public.exemplar_drafts;
    SELECT count(*) INTO v_nlot FROM public.catalog_batches;
    SELECT count(*) INTO v_ndiv FROM ingest.book_import_divergences;
    v_empreinte := pg_temp.l8_publie();
    v_run3 := pg_temp.l8_deposer('pmb-8.1.1.1_jeu-de-test-v2.unimarc.iso', true);
    PERFORM pg_temp.l8_ef(v_run3, v_l2, v_f2);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_ids := ARRAY(SELECT id FROM public.fn_import_list_run_rows(v_run3) WHERE match_status = 'known_record' ORDER BY row_no);
    v_rc := public.fn_import_recomparer(v_run3, v_ids);
    SELECT jsonb_object_agg(r.external_key, (SELECT jsonb_object_agg(k, n) FROM jsonb_each(r.comparison_counts) c(k, n)
                                              WHERE k <> 'inchange' AND n::text <> '0'))
             FILTER (WHERE EXISTS (SELECT 1 FROM jsonb_each(r.comparison_counts) c(k, n) WHERE k <> 'inchange' AND n::text <> '0')),
           jsonb_object_agg(r.external_key, (SELECT jsonb_agg(i->>'constat' || coalesce(':' || (i->'verdicts'->>'shelf_location') || '/' || (i->'verdicts'->>'notes'), '')
                                                                ORDER BY (i->>'n')::int)
                                               FROM jsonb_array_elements(r.exemplaires_maj->'items') i))
             FILTER (WHERE r.exemplaires_maj IS NOT NULL
                       AND EXISTS (SELECT 1 FROM jsonb_array_elements(r.exemplaires_maj->'items') i
                                    WHERE i->>'constat' <> 'deja_la' OR i->'verdicts'->>'shelf_location' <> 'inchange'
                                       OR i->'verdicts'->>'notes' <> 'inchange'))
      INTO v_sig, v_sigx
      FROM public.fn_import_list_run_rows(v_run3) r;
    v_p := public.fn_import_preparer_mises_a_jour(v_run3, v_ids);
    v_rec := public.fn_import_reconcile_duplicates(v_run3, ARRAY(SELECT id FROM public.fn_import_list_run_rows(v_run3)
                                                                WHERE match_status = 'known_record'));
    v_ret := public.fn_import_retraits(v_run3, 200, 0);
    v_prop := public.fn_import_proposer_retraits(v_run3);
    v_div := public.fn_divergences_a_traiter(NULL, 50, 0);
    EXECUTE 'RESET ROLE';
    v_apres := pg_temp.l8_publie();
    IF current_setting('anarbib.h21l8_debug', true) = 'on' THEN
      RAISE NOTICE 'H21L8-DEBUG T17 % | % | % | % | % | %', v_sig, v_sigx, v_p - 'drafts', v_rec - 'run', v_ret - 'items', v_prop;
    END IF;
    IF v_apres = v_empreinte
       AND (SELECT count(*) FROM public.book_drafts) = v_nbd AND (SELECT count(*) FROM public.exemplar_drafts) = v_ned
       AND (SELECT count(*) FROM public.catalog_batches) = v_nlot
       AND (SELECT count(*) FROM ingest.book_import_divergences) = v_ndiv
       AND (v_rc->'divergences'->>'posees')::int = 0 AND (v_div->>'total')::int = 0
       AND cardinality(v_ids) = /*@@N:v2@@*/
       -- les signaux répétés : local seul (5, et 11 dont B a écarté la
       -- divergence), conflit (8), responsabilités et effacement montrés (7, 9),
       -- la notice réattribuée (13)
       AND v_sig = '{"5": {"local_seul": 1}, "7": {"source_seule": 1}, "8": {"conflit": 1}, "9": {"source_seule": 1},
                    "11": {"local_seul": 1}, "13": {"source_seule": 1}}'::jsonb
       AND v_sigx = '{"5": ["deja_la:local_seul/inchange"], "6": ["deja_la:inchange/conflit"], "13": ["reattribue"],
                     "14": ["reetiquete"], "15": ["sans_code"], "19": ["code_repris"], "44": ["deplace", "deja_la:inchange/inchange"],
                     "61": ["deja_la:inchange/inchange", "deplace"]}'::jsonb
       AND (v_p->>'prepared')::int = 0 AND (v_p->'exemplaires'->>'prepared')::int = 0 AND v_p->>'batch_id' IS NULL
       AND (v_p->'skipped'->>'plus_detenue')::int = 1 AND (v_p->'skipped'->>'partagee')::int = 2
       AND (v_rec->>'created_items')::int = 0 AND v_rec->>'batch_id' IS NULL AND (v_rec->'verdicts'->>'reattribue')::int = 1
       AND (v_prop->>'retraits')::int = 0 AND (v_prop->>'levees')::int = 0 AND v_prop->>'batch_id' IS NULL
       AND v_ret->'counts' = '{"disparu": 0, "retires": 1, "hors_fichier": 1, "disparu_engage": 1, "retire_reapparu": 0, "disparu_brouillon": 0}'::jsonb
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : publie '||CASE WHEN v_apres = v_empreinte THEN 'intact' ELSE 'CHANGE' END
         ||' brouillons '||((SELECT count(*) FROM public.book_drafts) - v_nbd)||'/'||((SELECT count(*) FROM public.exemplar_drafts) - v_ned)
         ||' lots '||((SELECT count(*) FROM public.catalog_batches) - v_nlot)||' div '||((SELECT count(*) FROM ingest.book_import_divergences) - v_ndiv)
         ||' sig='||coalesce(v_sig::text, '∅')||' ex='||coalesce(v_sigx::text, '∅')||' prep='||left(coalesce((v_p - 'drafts')::text, '∅'), 300)
         ||' rec='||left(coalesce((v_rec - 'run')::text, '∅'), 300)||' ret='||coalesce((v_ret->'counts')::text, '∅')||' prop='||coalesce(v_prop::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T18 ─────────────────────────────────────────────────────────────
  v_t := 'T18 import v3 : le retire reapparu leve (propose, revise, publie), l''exemplaire neuf rapproche ; zero doublon ; B et circulation intacts';
  DECLARE v_m text[] := ARRAY[]::text[]; v_rec jsonb; v_ret jsonb; v_prop jsonb; v_rev jsonb; v_x2 text;
  BEGIN
    v_run4 := pg_temp.l8_deposer('pmb-8.1.1.1_jeu-de-test-v3.unimarc.iso', true);
    PERFORM pg_temp.l8_ef(v_run4, v_l3, v_f3);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_rec := public.fn_import_reconcile_duplicates(v_run4, ARRAY(SELECT id FROM public.fn_import_list_run_rows(v_run4)
                                                                WHERE match_status = 'known_record'));
    v_ret := public.fn_import_retraits(v_run4, 200, 0);
    v_prop := public.fn_import_proposer_retraits(v_run4);
    v_lot4 := (v_rec->>'batch_id')::bigint;
    v_rev := public.fn_batch_review_request(v_lot4, NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.fn_batch_review_verdict((v_rev->>'review_id')::bigint, 'approved', NULL);
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    PERFORM public.publish_catalog_batch(v_lot4);
    EXECUTE 'RESET ROLE';
    v_x2 := (SELECT md5(concat_ws('|',
        (SELECT string_agg(md5((to_jsonb(h) - ARRAY['updated_at', 'available_count'])::text), ',' ORDER BY h.id) FROM public.book_holdings h WHERE h.library_id = v_libB),
        (SELECT string_agg(md5((to_jsonb(x) - ARRAY['updated_at'])::text), ',' ORDER BY x.id) FROM public.exemplares x WHERE x.library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(d)::text), ',' ORDER BY d.id) FROM public.exemplar_drafts d WHERE d.target_library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(d)::text), ',' ORDER BY d.id) FROM public.book_drafts d WHERE d.owner_library_id = v_libB),
        (SELECT string_agg(md5(to_jsonb(x)::text), ',' ORDER BY x.id) FROM public.book_external_ids x WHERE x.library_id = v_libB))));
    v_m := v_m || ((v_rec->>'created_items') || '/' || (v_ret->'counts'->>'retire_reapparu') || '/' || (v_prop->>'levees')
                   || '/' || (v_prop->>'retraits') || '/' || ((v_prop->>'batch_id')::bigint = v_lot4)::text
                   || '/' || (SELECT (retire_at IS NULL)::text FROM public.exemplares WHERE id = (v_e->>'18')::bigint)
                   || '/' || (SELECT count(*) FROM public.exemplares x JOIN public.book_holdings h ON h.id = x.holding_id
                               WHERE x.source_item_code = 'H21L8-V3-53' AND h.book_id = (v_b->>'53')::bigint AND x.import_run_id = v_run4)
                   || '/' || (SELECT status FROM public.catalog_batches WHERE id = v_lot4));
    v_m := v_m || pg_temp.l8_doublons(v_lib, v_src);
    IF v_m = ARRAY['1/1/1/0/true/true/1/published']
       AND (SELECT count(*) FROM public.books) = v_nb0 + /*@@N:v1@@*/ + 1
       AND (SELECT count(*) FROM public.exemplares) = v_ne0 + /*@@NX:v1@@*/ + 2 + 2 + 1
       AND v_x2 = v_empreinte_b
       AND (SELECT md5(concat_ws('|',
             (SELECT string_agg(md5(to_jsonb(p)::text), ',' ORDER BY p.id) FROM public.emprestimos_v2 p),
             (SELECT string_agg(md5(to_jsonb(i)::text), ',' ORDER BY i.id) FROM public.emprestimo_itens_v2 i),
             (SELECT string_agg(md5(to_jsonb(r)::text), ',' ORDER BY r.id) FROM public.reserva_linhas_v2 r),
             (SELECT string_agg(md5(to_jsonb(c)::text), ',' ORDER BY c.id) FROM public.consulta_linhas_v2 c)))) = v_empreinte_circ
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, ' ; ')||' rec='||left(coalesce((v_rec - 'run')::text, '∅'), 300)
         ||' prop='||coalesce(v_prop::text, '∅')||' B '||CASE WHEN v_x2 = v_empreinte_b THEN 'intact' ELSE 'CHANGE' END); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T20 ─────────────────────────────────────────────────────────────
  -- IMP-35, condition par condition, sur l'exemplaire 14 (réattribué à B avec
  -- la notice 13 : code 33700004243347, expl_id 14, source du run) ; annulé.
  v_t := 'T20 IMP-35 : reattribue par l''expl_id, par le code de la source (fichier ou B sans expl_id) ; deux expl_id differents : nouveau ; jamais par une autre source ; chez soi d''abord ; avant deja en brouillon ; B intact';
  DECLARE v_m text[] := ARRAY[]::text[]; v_srcX bigint; v_eB14 bigint := (v_e->>'14')::bigint; v_avantB text; v_c jsonb;
  BEGIN
    v_avantB := (SELECT md5(to_jsonb(x)::text) FROM public.exemplares x WHERE x.id = v_eB14);
    BEGIN
      INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
      VALUES ('L8 autre source', v_lib, 'mapeada', 'own_catalog', true) RETURNING id INTO v_srcX;
      -- (a) l'expl_id de même source, le code changé dans PMB : reattribue, chez B
      v_c := ingest.fn_h21_constat_exemplaire(v_lib, v_src, NULL, 'L8-AUTRE-CODE', '14');
      v_m := v_m || (v_c->>'verdict' || ':' || ((v_c->>'exemplar_id')::bigint = v_eB14)::text || ':' || ((v_c->>'library_id')::uuid = v_libB)::text
                     || ':' || coalesce(v_c->>'library_name', '∅'));
      -- (b) le code d'un exemplaire de la source, sans expl_id : reattribue
      v_m := v_m || (ingest.fn_h21_constat_exemplaire(v_lib, v_src, NULL, '33700004243347', NULL)->>'verdict');
      -- (c) une autre source : jamais (nouveau), avec ou sans expl_id
      v_m := v_m || (ingest.fn_h21_constat_exemplaire(v_lib, v_srcX, NULL, '33700004243347', '14')->>'verdict');
      v_m := v_m || (ingest.fn_h21_constat_exemplaire(v_lib, v_srcX, NULL, '33700004243347', NULL)->>'verdict');
      -- (d) le code recyclé chez B : même code, expl_id NEUF dans le fichier (99), l'exemplaire de B a le
      --     sien (14) — ce n'est pas le même exemplaire, rien ne bloque sa création : nouveau
      v_m := v_m || (ingest.fn_h21_constat_exemplaire(v_lib, v_src, NULL, '33700004243347', '99')->>'verdict');
      -- (d') l'exemplaire de B sans expl_id, le fichier avec : par le code, reattribue
      INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
      SELECT x.bib_ref, 'L8B-SANS-XID', v_libB, x.holding_id, 'L8-B-SANS-XID', NULL, v_src, 'ambos'
        FROM public.exemplares x WHERE x.id = v_eB14;
      v_m := v_m || (ingest.fn_h21_constat_exemplaire(v_lib, v_src, NULL, 'L8-B-SANS-XID', '555')->>'verdict');
      -- (e) chez soi d'abord : un exemplaire de B de la même source porte aussi l'expl_id 9 ; celui de BLMF l'emporte
      INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
      SELECT x.bib_ref, 'L8B-X-9', v_libB, h.id, 'L8-B-9', '9', v_src, 'ambos'
        FROM public.exemplares x JOIN public.book_holdings h ON h.library_id = v_libB AND h.book_id = (v_b->>'13')::bigint
       WHERE x.id = v_eB14;
      v_m := v_m || (ingest.fn_h21_constat_exemplaire(v_lib, v_src, (v_b->>'8')::bigint, '33700003669468', '9')->>'verdict');
      -- (f) avant « déjà en brouillon » : un brouillon vivant chez BLMF au même code
      INSERT INTO public.exemplar_drafts (action, status, target_bib_ref, target_library_id, source_item_code, circulation_policy, visibility)
      SELECT 'create', 'draft', bk.bib_ref, v_lib, '33700004243347', 'ambos', 'public' FROM public.books bk WHERE bk.id = (v_b->>'13')::bigint;
      v_m := v_m || (ingest.fn_h21_constat_exemplaire(v_lib, v_src, NULL, '33700004243347', '14')->>'verdict');
      -- (g) « préparable » (lot 8) : une notice que plus personne ne détient (BLMF a perdu son fonds) ne compte plus
      DELETE FROM public.exemplares x USING public.book_holdings h WHERE h.id = x.holding_id AND h.book_id = (v_b->>'4')::bigint AND h.library_id = v_lib;
      DELETE FROM public.book_holdings h WHERE h.book_id = (v_b->>'4')::bigint;
      EXECUTE 'SET LOCAL ROLE authenticated';
      v_m := v_m || (SELECT coalesce(r.update_applicable::text, '∅') || '/' || coalesce(r.proposed_book_held::text, '∅') FROM public.fn_import_list_run_rows(v_run2) r WHERE r.external_key = '4');
      EXECUTE 'RESET ROLE';
      RAISE EXCEPTION 'sentinelle';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'sentinelle' THEN RAISE; END IF; END;
    IF v_m = ARRAY['reattribue:true:true:Essai H21 lot 8 — B', 'reattribue', 'nouveau', 'nouveau', 'nouveau', 'reattribue', 'deja_la', 'reattribue', '0/false']
       AND (SELECT md5(to_jsonb(x)::text) FROM public.exemplares x WHERE x.id = v_eB14) = v_avantB
       AND (SELECT x.library_id = v_libB AND x.source_item_code = '33700004243347' AND x.source_item_id = '14' AND x.import_source_id = v_src
              FROM public.exemplares x WHERE x.id = v_eB14)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_m, ' / ')); END IF;
  EXCEPTION WHEN OTHERS THEN EXECUTE 'RESET ROLE'; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T21 ─────────────────────────────────────────────────────────────
  -- La recherche « ailleurs » (IMP-35) à l'échelle : une source déjà riche de
  -- 5 000 exemplaires (chez B : la recherche les rencontre), 5 000 codes neufs
  -- constatés pour BLMF — tous « nouveau ». Annulé.
  v_t := 'T21 mesure : 5 000 constats de codes neufs sur une source de 5 000 exemplaires < 8 s';
  DECLARE v_n int; v_t0 timestamptz; v_ms numeric; v_hb bigint;
  BEGIN
    BEGIN
      SELECT h.id INTO v_hb FROM public.book_holdings h WHERE h.book_id = (v_b->>'13')::bigint AND h.library_id = v_libB;
      -- (le recalcul de disponibilité, par ligne, n'a rien à voir ici : coupé le temps du décor)
      ALTER TABLE public.exemplares DISABLE TRIGGER trg_exemplar_recompute_availability;
      INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, source_item_code, source_item_id, import_source_id, circulation_policy)
      SELECT bk.bib_ref, 'L8M-' || i, v_libB, v_hb, 'L8M-C-' || i, 'm' || i, v_src, 'ambos'
        FROM public.books bk, generate_series(1, 5000) i WHERE bk.id = (v_b->>'13')::bigint;
      ALTER TABLE public.exemplares ENABLE TRIGGER trg_exemplar_recompute_availability;
      ANALYZE public.exemplares;
      v_t0 := clock_timestamp();
      SELECT count(*) INTO v_n FROM generate_series(1, 5000) i,
             LATERAL ingest.fn_h21_constat_exemplaire(v_lib, v_src, (v_b->>'1')::bigint, 'L8N-' || i, 'n' || i) c
       WHERE c->>'verdict' = 'nouveau';
      v_ms := round(extract(epoch FROM clock_timestamp() - v_t0) * 1000);
      RAISE NOTICE 'H21L8-MESURE-CONSTAT 5000 codes neufs, source de 5000 exemplaires : % ms (nouveau : %)', v_ms, v_n;
      RAISE EXCEPTION 'sentinelle';
    EXCEPTION WHEN raise_exception THEN IF SQLERRM <> 'sentinelle' THEN RAISE; END IF; END;
    IF v_n = 5000 AND v_ms < 8000
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_ms::text, '∅')||' ms, nouveau '||coalesce(v_n::text, '∅')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ── T19 ─────────────────────────────────────────────────────────────
  v_t := 'T19 mesure : chaque appel de l''ecran sur le fichier entier < 8 s';
  BEGIN
    RAISE NOTICE 'H21L8-MESURE %', array_to_string(v_mesures, ' ; ');
    IF cardinality(v_mesures) = 5
       AND NOT EXISTS (SELECT 1 FROM unnest(v_mesures) m WHERE substring(m FROM ' ([0-9]+) ms$')::int >= 8000)
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||array_to_string(v_mesures, ' ; ')); END IF;
  END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'H21-BOUT-EN-BOUT OK : %/% tests passés', v_passed, v_passed;
  ELSE
    RAISE EXCEPTION 'H21-BOUT-EN-BOUT ECHEC : %/% — %', v_failed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
