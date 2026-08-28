-- =====================================================================
-- AnarBib — Tests d'acceptation : le chemin OAI-PMH s'exécute
-- Date    : 2026-08-28  ·  Session : chantier importations
-- Ref     : migration 20260828170000_chemin_oai_pmh_executable
--
-- Pourquoi cette suite existe : les DEUX RPC du circuit OAI-PMH ont été
-- inexecutables depuis leur ecriture (quatre ecarts entre ce qu'elles ecrivent
-- et ce que les colonnes acceptent, plus une colonne NOT NULL sans defaut non
-- fournie), et RIEN ne l'a signale — ni les migrations, ni les advisors, ni le
-- typage, ni la CI. Une CHECK et un NOT NULL ne se verifient qu'a l'execution,
-- donc seulement sur un chemin reellement emprunte. Ces tests EMPRUNTENT le
-- chemin : ils appellent les deux RPC pour de vrai, avec le JWT d'une admin
-- reseau (register_oai_source est admin-only), et regardent les trois tables
-- ecrites — sources, oai_harvest_state, import_runs.
--
-- Les tests les moins evidents et les plus utiles :
--   T4  ne compare pas les statuts a une liste recopiee ici (qui deriverait
--       avec les contraintes) : il les confronte aux CHECK ELLES-MEMES. C'est
--       la forme generale du defaut repare, la meme que T5 de la suite
--       import_candidat_institutionnel_tests.
--   T6  garde la branche de MISE A JOUR de register_oai_source, qui n'avait
--       elle non plus jamais tourne : aucune ligne ne pouvant porter oai_pmh,
--       son SELECT ne trouvait jamais rien.
--   T10 confronte le run au sens que la vue de politique lui donne
--       elle-meme : un run que rien ne traite ne doit pas s'annoncer revisable.
--   T11 garde le VERROU : deux moissonnages concurrents sur la meme source se
--       partageraient run et jeton de reprise. Depuis le Lot 3b ce n'est plus
--       un cul-de-sac mais une vraie garde — l'EF relache le verrou.
--   T15 a T17 gardent le Lot 3b cote SQL : l'EF est REELLEMENT appelee (journal
--       de dispatch), un verrou perime est repris au lieu de bloquer la source
--       a jamais, et la RPC ne s'excuse plus d'une EF absente.
--
-- Ce que cette suite NE couvre pas, et ou ca se joue : le comportement de l'EF
-- elle-meme (lecture de l'enveloppe OAI, reprise par jeton, relachement du
-- verrou sur CHAQUE sortie) est exerce par src/tests/harvest-oai-pmh.test.js,
-- qui evalue le VRAI index.ts avec un fetch stube.
--   Bilan OK : 'IMPORT-OAI OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord   uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador (seed)
  v_outside uuid := '22222222-2222-2222-2222-222222222222';  -- sans adhesion (seed)
  v_lib     uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF de test (seed)
  v_plain   uuid := gen_random_uuid();   -- coordenadora, PAS admin reseau
  v_plainlib uuid;
  v_res     jsonb;
  v_res2    jsonb;
  v_res3    jsonb;
  v_disp    ingest.partner_catalog_import_dispatch_log%rowtype;
  v_src     ingest.partner_catalog_sources%rowtype;
  v_run     ingest.partner_catalog_import_runs%rowtype;
  v_state   ingest.oai_harvest_state%rowtype;
  v_con     text;
  v_stage   text;
  v_review  boolean;
  v_n       int;
  v_endpoint text := 'https://entrepot.invalid/oai  ';  -- espaces : la fonction trim
BEGIN
  -- ── Fixtures ────────────────────────────────────────────────────────
  -- La coordinatrice du seed devient AUSSI admin reseau : register_oai_source
  -- exige l'admin, harvest_oai exige en plus une adhesion staff avec acces au
  -- painel. Un seul acteur porte donc les deux qualites.
  INSERT INTO public.network_administrators(user_id, status) VALUES (v_coord, 'active');

  -- Une seconde coordinatrice, staff mais PAS admin reseau : elle sert a
  -- prouver que la porte de register_oai_source est bien sur l'admin reseau et
  -- non sur le simple fait d'etre staff (T11).
  INSERT INTO public.libraries (slug, name) VALUES ('oai-autre-test', 'Autre biblio (test OAI)')
    RETURNING id INTO v_plainlib;
  INSERT INTO auth.users(id, email) VALUES (v_plain, 'coord.oai@ex.invalid');
  INSERT INTO public.profiles(id, email, first_name) VALUES (v_plain, 'coord.oai@ex.invalid', 'Coord2');
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
    VALUES (v_plain, v_plainlib, 'coordenador', 'active', true);

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 fn_import_register_oai_source s''execute et cree (elle etait inexecutable)';
  BEGIN
    v_res := public.fn_import_register_oai_source(
      'Entrepot de test', v_endpoint, v_lib, 'oai_dc', 'colecao:anarquismo', 7, 'note de test');
    IF coalesce((v_res->>'ok')::boolean, false)
       AND coalesce((v_res->>'created')::boolean, false)
       AND (v_res->>'source_id') IS NOT NULL
       AND (v_res->>'state_id') IS NOT NULL THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- Sans T1 rien n'a de sens : on s'arrete la plutot que d'aligner des echecs.
  IF v_res IS NULL THEN
    RAISE EXCEPTION 'IMPORT-OAI ECHEC : 0/1 OK, register_oai_source ne s''execute pas | %',
      array_to_string(v_failures, ' || ');
  END IF;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 la source porte source_kind=oai_pmh, relation_status=mapeada, endpoint trime';
  BEGIN
    SELECT * INTO v_src FROM ingest.partner_catalog_sources
     WHERE id = (v_res->>'source_id')::bigint;
    IF v_src.source_kind = 'oai_pmh'
       AND v_src.relation_status = 'mapeada'
       AND v_src.library_id = v_lib
       AND v_src.oai_endpoint_url = 'https://entrepot.invalid/oai'
       AND v_src.oai_metadata_prefix = 'oai_dc'
       AND v_src.oai_set = 'colecao:anarquismo'
       AND v_src.import_enabled THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got kind='||coalesce(v_src.source_kind,'NULL')
      ||' rel='||coalesce(v_src.relation_status,'NULL')
      ||' url='||coalesce(v_src.oai_endpoint_url,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- L'etat de moissonnage est insere APRES la source, dans la meme fonction.
  -- Sa presence prouve que la fonction est allee jusqu'au bout, pas seulement
  -- que le premier INSERT est passe. En production le 28/08/2026, cette table
  -- comptait 0 ligne : c'etait la trace la plus nette de l'echec.
  v_t := 'T3 l''etat de moissonnage est cree, idle, avec lots_per_cycle transmis';
  BEGIN
    SELECT * INTO v_state FROM ingest.oai_harvest_state
     WHERE source_id = (v_res->>'source_id')::bigint;
    IF v_state.id IS NOT NULL
       AND v_state.harvest_status = 'idle'
       AND v_state.lots_per_cycle = 7
       AND v_state.total_records_harvested = 0 THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got status='||coalesce(v_state.harvest_status,'<aucune ligne>')
      ||' lots='||coalesce(v_state.lots_per_cycle::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le test qui garde la LECON : on confronte les mots ecrits aux CHECK
  -- elles-memes, pas a des listes recopiees ici. C'est exactement ce qui
  -- manquait : 'active' et 'oai_pmh' se relisent tres bien, ils ne se
  -- heurtaient qu'aux contraintes.
  v_t := 'T4 relation_status ET source_kind ecrits appartiennent a leurs CHECK (introspection)';
  BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
     WHERE c.conname = 'partner_catalog_sources_relation_status_check';
    IF v_con IS NULL OR v_src.relation_status IS NULL
       OR position('''' || v_src.relation_status || '''' in v_con) = 0 THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : relation_status '
        ||coalesce(v_src.relation_status,'NULL')||' absent de '||coalesce(v_con,'<contrainte absente>'));
    ELSE
      SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
       WHERE c.conname = 'partner_catalog_sources_source_kind_check';
      IF v_con IS NULL OR v_src.source_kind IS NULL
         OR position('''' || v_src.source_kind || '''' in v_con) = 0 THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : source_kind '
          ||coalesce(v_src.source_kind,'NULL')||' absent de '||coalesce(v_con,'<contrainte absente>'));
      ELSE v_passed := v_passed+1; END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Elargir un vocabulaire ne doit rien lui retirer. Le paquet voisin du meme
  -- jour a ajoute institutional_lookup ; celui-ci reecrit la meme contrainte.
  v_t := 'T5 elargir source_kind n''a pas fait tomber institutional_lookup';
  BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
     WHERE c.conname = 'partner_catalog_sources_source_kind_check';
    IF v_con IS NOT NULL
       AND position('''institutional_lookup''' in v_con) > 0
       AND position('''partner_deposit''' in v_con) > 0
       AND position('''manual_upload''' in v_con) > 0 THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||coalesce(v_con,'<absente>')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Regression directe : tant qu'aucune ligne ne pouvait porter oai_pmh, le
  -- SELECT de tete de register_oai_source ne trouvait JAMAIS rien et la branche
  -- INSERT etait rejouee. Elle ne doit desormais etre empruntee qu'une fois.
  v_t := 'T6 re-enregistrer le meme endpoint MET A JOUR au lieu de recreer';
  BEGIN
    v_res2 := public.fn_import_register_oai_source(
      'Entrepot de test (renomme)', 'https://entrepot.invalid/oai', v_lib,
      'marcxml', NULL, 3, 'note revisee');
    SELECT * INTO v_src FROM ingest.partner_catalog_sources
     WHERE id = (v_res->>'source_id')::bigint;
    SELECT * INTO v_state FROM ingest.oai_harvest_state
     WHERE source_id = (v_res->>'source_id')::bigint;
    SELECT count(*) INTO v_n FROM ingest.partner_catalog_sources
     WHERE library_id = v_lib AND source_kind = 'oai_pmh';
    IF v_n = 1
       AND (v_res2->>'source_id')::bigint = (v_res->>'source_id')::bigint
       AND coalesce((v_res2->>'created')::boolean, true) = false
       AND v_src.partner_name = 'Entrepot de test (renomme)'
       AND v_src.oai_metadata_prefix = 'marcxml'
       AND v_src.oai_set IS NULL
       AND v_state.lots_per_cycle = 3 THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : sources='||v_n
      ||' created='||coalesce(v_res2->>'created','NULL')
      ||' nom='||coalesce(v_src.partner_name,'NULL')
      ||' lots='||coalesce(v_state.lots_per_cycle::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 fn_import_harvest_oai s''execute et rend un run (elle etait inexecutable)';
  BEGIN
    v_res2 := public.fn_import_harvest_oai((v_res->>'source_id')::bigint);
    IF coalesce((v_res2->>'ok')::boolean, false)
       AND (v_res2->>'run_id') IS NOT NULL
       AND (v_res2->>'max_lots')::int = 3 THEN   -- lots_per_cycle mis a jour en T6
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res2::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Les trois fautes de harvest_oai, prises une par une. storage_path est la
  -- plus sournoise : NOT NULL SANS defaut, donc 23502 muet a la relecture.
  v_t := 'T8 le run porte detected_format=oai_pmh, un storage_path, run_status=queued';
  BEGIN
    SELECT * INTO v_run FROM ingest.partner_catalog_import_runs
     WHERE id = (v_res2->>'run_id')::bigint;
    IF v_run.detected_format = 'oai_pmh'
       AND coalesce(v_run.storage_path, '') <> ''
       AND v_run.run_status = 'queued'
       AND v_run.library_id = v_lib
       AND v_run.imported_rows = 0 THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got fmt='||coalesce(v_run.detected_format,'NULL')
      ||' path='||coalesce(v_run.storage_path,'<NULL>')
      ||' status='||coalesce(v_run.run_status,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Meme forme que T4, sur les deux colonnes de l'autre table.
  v_t := 'T9 detected_format ET run_status ecrits appartiennent a leurs CHECK (introspection)';
  BEGIN
    SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
     WHERE c.conname = 'partner_catalog_import_runs_detected_format_check';
    IF v_con IS NULL OR v_run.detected_format IS NULL
       OR position('''' || v_run.detected_format || '''' in v_con) = 0 THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : detected_format '
        ||coalesce(v_run.detected_format,'NULL')||' absent de '||coalesce(v_con,'<contrainte absente>'));
    ELSE
      SELECT pg_get_constraintdef(c.oid) INTO v_con FROM pg_constraint c
       WHERE c.conname = 'partner_catalog_import_runs_run_status_check';
      IF v_con IS NULL OR v_run.run_status IS NULL
         OR position('''' || v_run.run_status || '''' in v_con) = 0 THEN
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : run_status '
          ||coalesce(v_run.run_status,'NULL')||' absent de '||coalesce(v_con,'<contrainte absente>'));
      ELSE v_passed := v_passed+1; END IF;
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Un statut valide ne suffit pas : il doit dire la VERITE. Au moment ou la RPC
  -- rend la main, rien n'a encore traite ce run — l'EF harvest-oai-pmh travaille
  -- en asynchrone, appelee par pg_net. (Ce commentaire disait « l'EF n'existe
  -- pas » : vrai au Lot 3a, faux depuis le Lot 3b. Un commentaire perime est
  -- exactement ce qui a fait vivre les defauts de ce chantier.)
  -- On demande son sens a la vue de
  -- politique elle-meme plutot qu'a une liste recopiee : elle doit le classer
  -- « a lancer », et surtout PAS l'annoncer revisable — sinon l'ecran ouvrirait
  -- une file de revision vide en pretendant que le moissonnage est fini.
  v_t := 'T10 la vue de politique classe le run en dispatch_pending, non revisable';
  BEGIN
    SELECT policy_stage, can_open_review INTO v_stage, v_review
      FROM api.partner_catalog_import_run_policy_ui
     WHERE import_run_id = (v_res2->>'run_id')::bigint;
    IF v_stage = 'dispatch_pending' AND v_review IS FALSE THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got stage='||coalesce(v_stage,'<aucune ligne>')
      ||' can_open_review='||coalesce(v_review::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le verrou, cote garde : deux moissonnages concurrents sur la meme source
  -- partageraient run et jeton de reprise. Ce test garde les DEUX moities — le
  -- verrou est pose, et il mord. Ce qui a change au Lot 3b n'est pas ce geste
  -- mais sa SORTIE : l'EF le relache (src/tests/harvest-oai-pmh.test.js), et un
  -- verrou perime est repris (T16 plus bas).
  v_t := 'T11 le verrou in_progress est pose et refuse un second moissonnage FRAIS';
  BEGIN
    SELECT * INTO v_state FROM ingest.oai_harvest_state
     WHERE source_id = (v_res->>'source_id')::bigint;
    IF v_state.harvest_status IS DISTINCT FROM 'in_progress'
       OR v_state.last_run_id IS DISTINCT FROM (v_res2->>'run_id')::bigint THEN
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : verrou non pose, status='
        ||coalesce(v_state.harvest_status,'NULL'));
    ELSE
      BEGIN
        PERFORM public.fn_import_harvest_oai((v_res->>'source_id')::bigint);
        v_failed := v_failed+1; v_failures := v_failures||(v_t||' : second moissonnage accepte');
      EXCEPTION WHEN OTHERS THEN
        IF position('deja en cours' in SQLERRM) > 0 THEN v_passed := v_passed+1;
        ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
      END;
    END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- La porte de register_oai_source est sur l'ADMIN RESEAU, pas sur le fait
  -- d'etre staff : une coordinatrice de bibliotheque ne doit pas pouvoir
  -- declarer un entrepot a moissonner.
  v_t := 'T12 une coordenadora NON admin reseau ne peut pas enregistrer de source';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_plain, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_import_register_oai_source(
        'Entrepot pirate', 'https://pirate.invalid/oai', v_plainlib);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      IF position('administradores de rede' in SQLERRM) > 0 THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
    END;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T13 une personne sans adhesion staff ne peut pas declencher de moissonnage';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_outside, 'role', 'authenticated')::text, true);
    BEGIN
      PERFORM public.fn_import_harvest_oai((v_res->>'source_id')::bigint);
      v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
    EXCEPTION WHEN OTHERS THEN
      IF position('Acesso' in SQLERRM) > 0 THEN v_passed := v_passed+1;
      ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
    END;
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T14 les deux RPC ne sont ouvertes ni a anon ni a PUBLIC';
  BEGIN
    SELECT count(*) INTO v_n FROM information_schema.routine_privileges
     WHERE routine_schema = 'public'
       AND routine_name IN ('fn_import_register_oai_source', 'fn_import_harvest_oai')
       AND grantee IN ('anon', 'PUBLIC');
    IF v_n = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' droit(s) de trop'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Lot 3b. Sans cette trace, « le moissonnage est lance » n'engage rien : c'est
  -- exactement l'etat du Lot 3a, ou la RPC repondait ok en n'appelant personne.
  -- On regarde donc le journal de dispatch, pas la reponse de la fonction.
  v_t := 'T15 l''EF harvest-oai-pmh est REELLEMENT appelee (journal de dispatch)';
  BEGIN
    SELECT * INTO v_disp FROM ingest.partner_catalog_import_dispatch_log
     WHERE run_id = (v_res2->>'run_id')::bigint
     ORDER BY id DESC LIMIT 1;
    IF v_disp.id IS NOT NULL
       AND v_disp.dispatch_status = 'sent'
       AND v_disp.request_id IS NOT NULL
       AND (v_disp.request_body->>'run_id')::bigint = (v_res2->>'run_id')::bigint THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got statut='
      ||coalesce(v_disp.dispatch_status,'<aucune ligne>')
      ||' request_id='||coalesce(v_disp.request_id::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- LE test du Lot 3b. Un verrou que personne ne relache est pire que pas de
  -- verrou : c'est ce qui rendait la source inmoissonnable a jamais. L'EF le
  -- relache sur tous ses chemins, mais elle peut n'etre JAMAIS atteinte — et
  -- alors personne n'execute son finally. On vieillit donc le verrou et on
  -- verifie que la RPC le REPREND au lieu de l'opposer.
  --
  -- Le trigger trg_oai_harvest_state_updated reecrit updated_at a CHAQUE update :
  -- sans le desactiver le temps de la fixture, on ne peut pas vieillir une ligne
  -- — et le test passerait pour une mauvaise raison (verrou frais refuse, donc
  -- exception, donc echec... ou pire, verrou vieilli qu'on croit avoir pose).
  v_t := 'T16 un verrou in_progress perime est REPRIS, pas oppose';
  BEGIN
    ALTER TABLE ingest.oai_harvest_state DISABLE TRIGGER trg_oai_harvest_state_updated;
    UPDATE ingest.oai_harvest_state
       SET harvest_status = 'in_progress', updated_at = now() - interval '2 hours'
     WHERE source_id = (v_res->>'source_id')::bigint;
    ALTER TABLE ingest.oai_harvest_state ENABLE TRIGGER trg_oai_harvest_state_updated;

    v_res3 := public.fn_import_harvest_oai((v_res->>'source_id')::bigint);
    SELECT * INTO v_state FROM ingest.oai_harvest_state
     WHERE source_id = (v_res->>'source_id')::bigint;
    IF coalesce((v_res3->>'ok')::boolean, false)
       AND coalesce((v_res3->>'reclaimed_stale_lock')::boolean, false)
       AND v_state.harvest_status = 'in_progress'
       AND v_state.last_run_id = (v_res3->>'run_id')::bigint THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '
      ||coalesce(v_res3::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le champ 'note' du Lot 3a portait « Edge Function pas encore deployee ».
  -- L'ecran l'affiche A LA PLACE du message localise « Moissonnage lance » :
  -- tant qu'il est la, l'interface annonce a la coordination que rien n'existe.
  v_t := 'T17 la reponse ne s''excuse plus d''une EF absente (plus de champ note)';
  BEGIN
    IF v_res3 IS NOT NULL AND NOT (v_res3 ? 'note') AND (v_res3 ? 'dispatch') THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '
      ||coalesce(v_res3::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le cron. L'ecran promet un moissonnage « automatique hebdomadaire » dans les
  -- 10 locales ; jusqu'au 28/08/2026 aucun cron ne moissonnait, et la promesse
  -- tenait a un clic. Ces tests gardent les trois garanties qui rendent
  -- l'automatisme acceptable : il vise les bonnes sources, il ne double pas un
  -- cycle en cours, et il appelle vraiment l'EF.
  --
  -- On repart d'un etat propre : les tests precedents ont laisse la source en
  -- in_progress (T16 a repris le verrou), ce qui la rendrait invisible au cron.
  v_t := 'T18 le cron lance un moissonnage sur une source eligible';
  BEGIN
    UPDATE ingest.oai_harvest_state SET harvest_status = 'idle', last_error = NULL
     WHERE source_id = (v_res->>'source_id')::bigint;

    v_res3 := ingest.fn_cron_import_harvest_oai();
    IF coalesce((v_res3->>'ok')::boolean, false)
       AND (v_res3->>'lances')::int = 1
       AND (v_res3->'details'->0->>'source_id')::bigint = (v_res->>'source_id')::bigint THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res3::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le run du cron n'est l'oeuvre de PERSONNE : requested_by NULL. Emprunter
  -- l'identite d'une coordination pour contourner le controle d'acces aurait
  -- fait porter a quelqu'un un geste qu'il n'a pas pose, un mardi a 4 h.
  v_t := 'T19 le run du cron ne porte le nom de personne (requested_by NULL)';
  BEGIN
    SELECT * INTO v_run FROM ingest.partner_catalog_import_runs
     WHERE id = (v_res3->'details'->0->>'run_id')::bigint;
    IF v_run.requested_by IS NULL
       AND v_run.detected_format = 'oai_pmh'
       AND v_run.run_status = 'queued'
       AND coalesce(v_run.storage_path, '') <> '' THEN
      v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got requested_by='
      ||coalesce(v_run.requested_by::text,'NULL')||' status='||coalesce(v_run.run_status,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- Le verrou vaut aussi pour la machine : le cron vient de poser in_progress,
  -- un second passage ne doit rien relancer. Sans ca, deux cycles se
  -- partageraient le meme jeton de reprise.
  v_t := 'T20 un second passage du cron ne double pas un cycle en cours';
  BEGIN
    v_res3 := ingest.fn_cron_import_harvest_oai();
    IF (v_res3->>'lances')::int = 0 AND (v_res3->>'ignorees')::int >= 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' got '||coalesce(v_res3::text,'NULL')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  -- import_enabled existait, etait mise a true a l'enregistrement, et n'etait
  -- LUE PAR PERSONNE. Si le cron l'ignorait aussi, decocher une source
  -- n'aurait aucun effet — et on moissonnerait un partenaire qui a demande
  -- qu'on arrete.
  v_t := 'T21 une source import_enabled=false est ecartee du moissonnage automatique';
  BEGIN
    UPDATE ingest.oai_harvest_state SET harvest_status = 'idle'
     WHERE source_id = (v_res->>'source_id')::bigint;
    UPDATE ingest.partner_catalog_sources SET import_enabled = false
     WHERE id = (v_res->>'source_id')::bigint;

    v_res3 := ingest.fn_cron_import_harvest_oai();
    IF (v_res3->>'lances')::int = 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : source desactivee quand meme moissonnee : '
      ||coalesce(v_res3::text,'NULL')); END IF;

    UPDATE ingest.partner_catalog_sources SET import_enabled = true
     WHERE id = (v_res->>'source_id')::bigint;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'IMPORT-OAI OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'IMPORT-OAI ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
