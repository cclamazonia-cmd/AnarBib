-- ═══════════════════════════════════════════════════════════════════════════
-- AnarBib — attacher un fichier reçu se décide AVANT la clé de service
-- (13/10/2026, migration 20261013182842).
--   T1  objets et droits : la garde existe, DEFINER, STABLE, search_path figé,
--       fermée à anon et à PUBLIC, ouverte à authenticated ; la RPC
--       d'écriture reste ouverte à authenticated et fermée à anon ;
--   T2  la garde, jouée SOUS authenticated : la coordination de la
--       bibliothèque du run, sur un livre que sa bibliothèque détient, passe ;
--       l'administration du réseau passe partout ;
--   T3  les refus, tous IDENTIQUES (message et HINT
--       error.edge.received_asset_not_found) : lecteur, adhésion inactive,
--       coordination d'une autre bibliothèque, livre non détenu, fichier
--       inconnu, livre inconnu — administration comprise depuis le 14/10
--       (migration 20261014190433) — et rien n'a été écrit ni verrouillé
--       (xmax du run inchangé) ;
--   T4  la garde et fn_attach_received_asset_record disent la même chose,
--       cas par cas (chaque attache réelle annulée dans une sous-transaction) ;
--   T5  l'oracle « déjà attaché » de la RPC d'écriture est fermé : un fichier
--       attaché n'est plus dit au lecteur ni à la coordination d'à côté ; la
--       coordination légitime obtient toujours la réponse idempotente.
-- Fixtures : deux bibliothèques, six comptes, deux livres, un run et un
-- fichier reçu par bibliothèque, créés ici. La suite lève toujours (OK ou
-- ECHEC) : rien ne reste.
-- Mutants éprouvés le 13/10 (replace sur pg_get_functiondef, banc local) :
-- garde sans la condition (a) (« true OR EXISTS ») → 3/5, T3 et T4 rougissent ;
-- sans la condition (b) → 3/5, T3 et T4 ; retour « déjà attaché » remis avant
-- les gardes de la RPC d'écriture → 4/5, T5 (le lecteur lit l'asset_id).
--   Bilan OK : 'ATTACH-RECU-GARDE OK : N/N tests passés'
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_suf text := to_char(clock_timestamp(), 'SSMS') || floor(random() * 1000)::int;
  v_libA uuid; v_libB uuid;
  v_coordA uuid := gen_random_uuid();   -- coordination de A
  v_lectA uuid := gen_random_uuid();    -- lecteur de A
  v_bibA uuid := gen_random_uuid();     -- bibliothécaire de A
  v_ancienA uuid := gen_random_uuid();  -- ancienne coordination de A (inactive)
  v_coordB uuid := gen_random_uuid();   -- coordination de B
  v_admin uuid := gen_random_uuid();    -- administration du réseau, sans adhésion
  v_bookA bigint; v_bookB bigint; v_srcA bigint; v_srcB bigint; v_runA bigint; v_runB bigint;
  v_raA bigint; v_raB bigint; v_ra_inconnu bigint; v_book_inconnu bigint;
  v_u uuid; v_rec record; v_state text; v_msg text; v_hint text; v_det text;
  v_g text; v_r text; v_res jsonb; v_x0 text; v_x1 text; v_b boolean; v_txt text;
BEGIN
  INSERT INTO public.catalog_ref_source_partners (code, label, sort_order, is_active)
  VALUES ('other_partner', 'Outro parceiro', 80, true) ON CONFLICT (code) DO NOTHING;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('attach-a-' || v_suf, 'Attache A (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libA;
  INSERT INTO public.libraries (slug, name, network_mode, circulation_mode, is_active, visibility_level, membership_enabled)
  VALUES ('attach-b-' || v_suf, 'Attache B (essai)', 'federated', 'full_sigb', true, 'public', false) RETURNING id INTO v_libB;
  FOREACH v_u IN ARRAY ARRAY[v_coordA, v_lectA, v_bibA, v_ancienA, v_coordB, v_admin] LOOP
    INSERT INTO auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    VALUES ('00000000-0000-0000-0000-000000000000', v_u, 'authenticated', 'authenticated', 'attach-' || v_u || '@anarbib.local', now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}');
    INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
    VALUES (v_u, 'attach-' || v_u || '@anarbib.local', 'Attache', left(v_u::text, 8), 'fr');
  END LOOP;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary) VALUES
    (v_coordA, v_libA, 'coordenador', 'active', true),
    (v_lectA, v_libA, 'reader', 'active', true),
    (v_bibA, v_libA, 'librarian', 'active', true),
    (v_ancienA, v_libA, 'coordenador', 'inactive', false),
    (v_coordB, v_libB, 'coordenador', 'active', true);
  INSERT INTO public.network_administrators (user_id, status) VALUES (v_admin, 'active');

  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Attache livre A', 'ATTACH-A-' || v_suf, 'livro', v_libA) RETURNING id INTO v_bookA;
  INSERT INTO public.books (titulo, bib_ref, tipo_material, owner_library_id)
  VALUES ('Attache livre B', 'ATTACH-B-' || v_suf, 'livro', v_libB) RETURNING id INTO v_bookB;
  INSERT INTO public.book_holdings (book_id, library_id) VALUES (v_bookA, v_libA), (v_bookB, v_libB);

  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Attache essai A', v_libA, 'mapeada', 'own_catalog', true) RETURNING id INTO v_srcA;
  INSERT INTO ingest.partner_catalog_sources (partner_name, library_id, relation_status, source_kind, import_enabled)
  VALUES ('Attache essai B', v_libB, 'mapeada', 'own_catalog', true) RETURNING id INTO v_srcB;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
  VALUES (v_srcA, v_libA, 'essai/attach-a.zip', 'attach-a.zip', 'zip', 'ready_for_review', 0) RETURNING id INTO v_runA;
  INSERT INTO ingest.partner_catalog_import_runs (source_id, library_id, storage_path, original_filename, detected_format, run_status, imported_rows)
  VALUES (v_srcB, v_libB, 'essai/attach-b.zip', 'attach-b.zip', 'zip', 'ready_for_review', 0) RETURNING id INTO v_runB;
  INSERT INTO ingest.partner_catalog_received_assets (run_id, staging_row_id, source_asset_id, asset_kind, title, mime_type, deposit_bucket, deposit_status, deposit_path, manifest_file)
  VALUES (v_runA, NULL, 901, 'pdf', 'Attache (PDF A)', 'application/pdf', 'partner-catalog-deposits', 'deposited', 'received/' || v_runA || '/901_a.pdf', 'files/901_a.pdf')
  RETURNING id INTO v_raA;
  INSERT INTO ingest.partner_catalog_received_assets (run_id, staging_row_id, source_asset_id, asset_kind, title, mime_type, deposit_bucket, deposit_status, deposit_path, manifest_file)
  VALUES (v_runB, NULL, 902, 'pdf', 'Attache (PDF B)', 'application/pdf', 'partner-catalog-deposits', 'deposited', 'received/' || v_runB || '/902_b.pdf', 'files/902_b.pdf')
  RETURNING id INTO v_raB;
  SELECT coalesce(max(id), 0) + 100000 INTO v_ra_inconnu FROM ingest.partner_catalog_received_assets;
  SELECT coalesce(max(id), 0) + 100000 INTO v_book_inconnu FROM public.books;

  -- garde jouée sous authenticated : 'passe' ou 'refus|<message>|<hint>'
  EXECUTE $f$CREATE FUNCTION pg_temp.attach_garde(p_sub uuid, p_ra bigint, p_book bigint) RETURNS text LANGUAGE plpgsql AS $b$
    DECLARE v boolean; v_m text; v_h text;
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_sub, 'role', 'authenticated')::text, true);
      EXECUTE 'SET LOCAL ROLE authenticated';
      BEGIN
        v := public.fn_attach_received_asset_garde(p_ra, p_book);
        EXECUTE 'RESET ROLE';
        RETURN CASE WHEN v IS TRUE THEN 'passe' ELSE 'rendu ' || coalesce(v::text, 'NULL') END;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_m = MESSAGE_TEXT, v_h = PG_EXCEPTION_HINT;
        EXECUTE 'RESET ROLE';
        RETURN 'refus|' || v_m || '|' || coalesce(v_h, '');
      END;
    END $b$ $f$;
  -- RPC d'écriture jouée sous authenticated, puis ANNULÉE : 'passe' ou 'refus|<message>'
  EXECUTE $f$CREATE FUNCTION pg_temp.attach_ecrit(p_sub uuid, p_ra bigint, p_book bigint) RETURNS text LANGUAGE plpgsql AS $b$
    DECLARE v_res jsonb; v_m text;
    BEGIN
      PERFORM set_config('request.jwt.claims', json_build_object('sub', p_sub, 'role', 'authenticated')::text, true);
      BEGIN
        EXECUTE 'SET LOCAL ROLE authenticated';
        v_res := public.fn_attach_received_asset_record(p_ra, p_book, 'pdf-restrito', 'attached/' || p_book || '/' || p_ra || '_essai.pdf', 'both');
        EXECUTE 'RESET ROLE';
        RAISE EXCEPTION 'attach-annule:%', v_res::text;
      EXCEPTION WHEN OTHERS THEN
        EXECUTE 'RESET ROLE';
        v_m := SQLERRM;
      END;
      RETURN CASE WHEN v_m LIKE 'attach-annule:%' AND (substr(v_m, 15)::jsonb ->> 'ok') = 'true' THEN 'passe' ELSE 'refus|' || v_m END;
    END $b$ $f$;

  -- 17/10/2026 (20261018211310) : la RPC d'écriture vérifie, après ses gardes,
  -- que l'objet déclaré existe — l'Edge Function l'a versé avant de l'appeler.
  INSERT INTO storage.objects (bucket_id, name)
  SELECT 'pdf-restrito', 'attached/' || b || '/' || r || '_essai.pdf'
    FROM unnest(ARRAY[v_bookA, v_bookB]) b, unnest(ARRAY[v_raA, v_raB]) r
  ON CONFLICT (bucket_id, name) DO NOTHING;

  -- ───────────────────────────────────────────────────────
  v_t := 'T1 objets et droits';
  BEGIN
    SELECT prosecdef, provolatile::text, array_to_string(proconfig, ',') INTO v_b, v_state, v_txt
      FROM pg_proc WHERE oid = 'public.fn_attach_received_asset_garde(bigint, bigint)'::regprocedure;
    IF NOT v_b THEN RAISE EXCEPTION 'garde INVOKER : elle ne lirait pas ingest'; END IF;
    IF v_state <> 's' THEN RAISE EXCEPTION 'garde non STABLE (%)', v_state; END IF;
    IF v_txt IS DISTINCT FROM 'search_path=""' THEN RAISE EXCEPTION 'search_path %', v_txt; END IF;
    IF has_function_privilege('anon', 'public.fn_attach_received_asset_garde(bigint, bigint)', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_garde(bigint, bigint)', 'EXECUTE') THEN
      RAISE EXCEPTION 'garde : fermée à anon, ouverte à authenticated';
    END IF;
    IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(p.proacl) a
                WHERE p.oid = 'public.fn_attach_received_asset_garde(bigint, bigint)'::regprocedure AND a.grantee = 0) THEN
      RAISE EXCEPTION 'garde ouverte à PUBLIC';
    END IF;
    IF has_function_privilege('anon', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE')
       OR NOT has_function_privilege('authenticated', 'public.fn_attach_received_asset_record(bigint, bigint, text, text, text)', 'EXECUTE') THEN
      RAISE EXCEPTION 'RPC d''écriture : fermée à anon, ouverte à authenticated';
    END IF;
    v_passed := v_passed + 1;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  v_t := 'T2 la coordination de la bibliotheque du run sur un livre detenu, et l''administration du reseau, passent';
  BEGIN
    v_det := '';
    FOR v_rec IN SELECT * FROM (VALUES
        ('coordA A/A', v_coordA, v_raA, v_bookA),
        ('coordB B/B', v_coordB, v_raB, v_bookB),
        ('admin A/B',  v_admin,  v_raA, v_bookB),
        ('admin B/A',  v_admin,  v_raB, v_bookA)) AS c(nom, sub, ra, book) LOOP
      v_g := pg_temp.attach_garde(v_rec.sub, v_rec.ra, v_rec.book);
      IF v_g <> 'passe' THEN v_det := v_det || ' ' || v_rec.nom || '=' || v_g; END IF;
    END LOOP;
    IF v_det = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' :' || v_det); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  v_t := 'T3 tous les refus sont identiques (introuvable, error.edge.received_asset_not_found) et ne touchent pas le run';
  BEGIN
    v_det := '';
    SELECT xmax::text INTO v_x0 FROM ingest.partner_catalog_import_runs WHERE id = v_runA;
    FOR v_rec IN SELECT * FROM (VALUES
        ('lecteur',               v_lectA,   v_raA,        v_bookA),
        ('bibliothecaire',        v_bibA,    v_raA,        v_bookA),
        ('adhesion inactive',     v_ancienA, v_raA,        v_bookA),
        ('coordB fichier de A',   v_coordB,  v_raA,        v_bookB),
        ('coordA livre de B',     v_coordA,  v_raA,        v_bookB),
        ('coordA fichier de B',   v_coordA,  v_raB,        v_bookA),
        ('fichier inconnu',       v_coordA,  v_ra_inconnu, v_bookA),
        ('livre inconnu',         v_coordA,  v_raA,        v_book_inconnu),
        ('admin fichier inconnu', v_admin,   v_ra_inconnu, v_bookA),
        ('admin livre inconnu',   v_admin,   v_raA,        v_book_inconnu),
        ('admin livre NULL',      v_admin,   v_raA,        NULL::bigint),
        ('fichier NULL',          v_coordA,  NULL::bigint, v_bookA),
        ('livre NULL',            v_coordA,  v_raA,        NULL::bigint)) AS c(nom, sub, ra, book) LOOP
      v_g := pg_temp.attach_garde(v_rec.sub, v_rec.ra, v_rec.book);
      IF v_g IS DISTINCT FROM 'refus|Recurso recebido introuvável.|error.edge.received_asset_not_found' THEN
        v_det := v_det || ' ' || v_rec.nom || '=' || coalesce(v_g, 'NULL');
      END IF;
    END LOOP;
    SELECT xmax::text INTO v_x1 FROM ingest.partner_catalog_import_runs WHERE id = v_runA;
    IF v_x1 IS DISTINCT FROM v_x0 THEN v_det := v_det || format(' xmax du run %s->%s', v_x0, v_x1); END IF;
    IF EXISTS (SELECT 1 FROM ingest.partner_catalog_received_assets WHERE id IN (v_raA, v_raB) AND deposit_status <> 'deposited') THEN
      v_det := v_det || ' fichier recu modifie';
    END IF;
    IF v_det = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' :' || v_det); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  v_t := 'T4 la garde et fn_attach_received_asset_record disent la meme chose, cas par cas';
  BEGIN
    v_det := '';
    FOR v_rec IN SELECT * FROM (VALUES
        ('coordA A/A',          v_coordA,  v_raA,        v_bookA),
        ('admin A/B',           v_admin,   v_raA,        v_bookB),
        ('lecteur',             v_lectA,   v_raA,        v_bookA),
        ('adhesion inactive',   v_ancienA, v_raA,        v_bookA),
        ('coordB fichier de A', v_coordB,  v_raA,        v_bookB),
        ('coordA livre de B',   v_coordA,  v_raA,        v_bookB),
        ('fichier inconnu',     v_coordA,  v_ra_inconnu, v_bookA),
        ('livre inconnu',       v_coordA,  v_raA,        v_book_inconnu),
        ('admin livre inconnu', v_admin,   v_raA,        v_book_inconnu)) AS c(nom, sub, ra, book) LOOP
      v_g := split_part(pg_temp.attach_garde(v_rec.sub, v_rec.ra, v_rec.book), '|', 1);
      v_r := pg_temp.attach_ecrit(v_rec.sub, v_rec.ra, v_rec.book);
      IF v_g IS DISTINCT FROM split_part(v_r, '|', 1)
         OR (v_g = 'refus' AND v_r IS DISTINCT FROM 'refus|Recurso recebido introuvável.') THEN
        v_det := v_det || format(' %s: garde=%s ecriture=%s', v_rec.nom, v_g, left(coalesce(v_r, 'NULL'), 80));
      END IF;
    END LOOP;
    -- les attaches acceptées ont bien été annulées
    IF EXISTS (SELECT 1 FROM ingest.partner_catalog_received_assets WHERE id IN (v_raA, v_raB) AND deposit_status <> 'deposited') THEN
      v_det := v_det || ' attache non annulee';
    END IF;
    IF v_det = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' :' || v_det); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  v_t := 'T5 un fichier deja attache n''est plus dit hors coordination ; la coordination garde la reponse idempotente';
  BEGIN
    v_det := '';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_attach_received_asset_record(v_raA, v_bookA, 'pdf-restrito', 'attached/' || v_bookA || '/' || v_raA || '_essai.pdf', 'both');
    EXECUTE 'RESET ROLE';
    IF NOT coalesce((v_res ->> 'created')::boolean, false) OR (v_res ->> 'asset_id') IS NULL THEN
      RAISE EXCEPTION 'decor : attache %', v_res;
    END IF;
    FOR v_rec IN SELECT * FROM (VALUES
        ('lecteur',             v_lectA,  v_bookA),
        ('coordB fichier de A', v_coordB, v_bookB),
        ('coordA livre de B',   v_coordA, v_bookB)) AS c(nom, sub, book) LOOP
      PERFORM set_config('request.jwt.claims', json_build_object('sub', v_rec.sub, 'role', 'authenticated')::text, true);
      BEGIN
        EXECUTE 'SET LOCAL ROLE authenticated';
        v_res := public.fn_attach_received_asset_record(v_raA, v_rec.book, 'pdf-restrito', 'attached/' || v_rec.book || '/' || v_raA || '_essai.pdf', 'both');
        EXECUTE 'RESET ROLE';
        v_msg := 'rendu ' || v_res::text;
      EXCEPTION WHEN OTHERS THEN
        EXECUTE 'RESET ROLE';
        v_msg := SQLERRM;
      END;
      IF v_msg IS DISTINCT FROM 'Recurso recebido introuvável.' THEN v_det := v_det || ' ' || v_rec.nom || '=' || left(v_msg, 100); END IF;
    END LOOP;
    -- la garde aussi refuse l'attaché à qui n'en a pas le droit (et laisse la coordination passer : l'Edge Function rend alors 409)
    IF pg_temp.attach_garde(v_lectA, v_raA, v_bookA) = 'passe' THEN v_det := v_det || ' garde: lecteur passe'; END IF;
    IF pg_temp.attach_garde(v_coordA, v_raA, v_bookA) <> 'passe' THEN v_det := v_det || ' garde: coordination refusee'; END IF;
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_coordA, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    v_res := public.fn_attach_received_asset_record(v_raA, v_bookA, 'pdf-restrito', 'attached/' || v_bookA || '/' || v_raA || '_essai.pdf', 'both');
    EXECUTE 'RESET ROLE';
    IF coalesce((v_res ->> 'created')::boolean, true) OR (v_res ->> 'ok') IS DISTINCT FROM 'true' OR (v_res ->> 'asset_id') IS NULL THEN
      v_det := v_det || ' coordination: ' || v_res::text;
    END IF;
    PERFORM set_config('request.jwt.claims', '', true);
    IF v_det = '' THEN v_passed := v_passed + 1;
    ELSE v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' :' || v_det); END IF;
  EXCEPTION WHEN OTHERS THEN
    EXECUTE 'RESET ROLE';
    v_failed := v_failed + 1; v_failures := v_failures || (v_t || ' : ' || SQLERRM); END;

  -- ───────────────────────────────────────────────────────
  IF v_failed = 0 THEN
    RAISE EXCEPTION 'ATTACH-RECU-GARDE OK : %/% tests passés', v_passed, v_passed + v_failed;
  ELSE
    RAISE EXCEPTION 'ATTACH-RECU-GARDE ECHEC : %/% tests passés — %', v_passed, v_passed + v_failed, array_to_string(v_failures, ' | ');
  END IF;
END $$;
