-- ============================================================
-- Tests — un Wikidata, une seule fiche d'autorité
-- ============================================================
-- Migration couverte : 20261020174755_un_wikidata_une_seule_fiche.sql
--
-- Le cas d'origine (20/10/2026) : Q51862284 posé sur 10907 par
-- l'enrichissement du 26/09, puis sur 11572 par une proposition C4 de
-- l'Atelier appliquée le 18/10. Rien ne regardait si l'identifiant était pris.
--
-- 10 tests :
--   1. publish_author_draft (fiche NEUVE) refuse un Wikidata porté ailleurs :
--      hint i18n, DETAIL {qid, author_id, name} qui nomme l'autre fiche, rien
--      n'est créé.
--   2. La comparaison ignore casse et espaces (« q… » saisi à la main).
--   3. publish_author_draft (fiche EXISTANTE, branche UPDATE) refuse aussi, et
--      la fiche garde sa valeur.
--   4. Pas de faux refus : republier la fiche qui porte déjà le Wikidata passe ;
--      un Wikidata libre est posé, normalisé (« Q… », sans espaces).
--   5. api.fn_authority_propose refuse dès la proposition (edition d'autorité).
--   6. api.fn_authority_apply refuse une proposition faite AVANT la garde (le
--      cas bebb7a02) : la proposition reste à appliquer, la fiche intacte.
--   7. api.fn_authority_apply pose un Wikidata libre (pas de faux refus).
--   8. L'index unique tient même sans le déclencheur (23505).
--   9. merge_author_with_fields reprend le Wikidata du doublon (sans heurter
--      l'index que le doublon occupe encore).
--  10. Aucune paire au même Wikidata dans la base reconstruite.
--
-- Mutants rejoués le 20/10 sur la base reconstruite : sans déclencheur ni
-- index (l'état d'avant), T1 rougit ; sans l'index seul, T8 ; sans la garde de
-- fn_authority_propose, T5 ; merge_author_with_fields d'avant, T9.
-- Fixtures fabriquées ici (identifiants Q99999980x, inventés), tout est annulé
-- par l'exception de bilan.
-- ============================================================

DO $$
DECLARE
  v_coord uuid := gen_random_uuid();
  v_lib   uuid;
  v_a bigint; v_c bigint; v_d bigint; v_e bigint;
  v_draft bigint; v_new bigint; v_prop uuid; v_n int;
  v_refus boolean; v_hint text; v_detail text; v_state text; v_txt text;
  v_ok int := 0;
BEGIN
  -- ── Fixtures ───────────────────────────────────────────────────────
  INSERT INTO auth.users (id, instance_id, aud, role, email, created_at, updated_at)
  VALUES (v_coord, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
          'wdunique-' || v_coord || '@example.invalid', now(), now());
  INSERT INTO public.profiles (id, first_name, last_name) VALUES (v_coord, 'Coordination', 'WDUNIQUE');
  INSERT INTO public.libraries (slug, name)
  VALUES ('essai-wdunique-' || substr(gen_random_uuid()::text, 1, 8), 'Essai Wikidata unique')
  RETURNING id INTO v_lib;
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_coord, v_lib, 'coordenador', 'active');

  INSERT INTO public.authors (preferred_name, sort_name, wikidata_id)
  VALUES ('Zzwd Alpha', 'Alpha, Zzwd', 'Q999999801') RETURNING id INTO v_a;
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Zzwd Charlie', 'Charlie, Zzwd') RETURNING id INTO v_c;
  INSERT INTO public.authors (preferred_name, sort_name, wikidata_id)
  VALUES ('Zzwd Delta', 'Delta, Zzwd', 'Q999999804') RETURNING id INTO v_d;
  INSERT INTO public.authors (preferred_name, sort_name)
  VALUES ('Zzwd Echo', 'Echo, Zzwd') RETURNING id INTO v_e;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- 1 ---------------------------------------------------------------
  INSERT INTO public.author_drafts (preferred_name, sort_name, wikidata_id, status, created_by)
  VALUES ('Zzwd Bravo', 'Bravo, Zzwd', 'Q999999801', 'draft', v_coord) RETURNING id INTO v_draft;
  v_refus := false; v_hint := NULL; v_detail := NULL;
  BEGIN
    PERFORM public.publish_author_draft(v_draft);
  EXCEPTION WHEN OTHERS THEN
    v_refus := true;
    GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT, v_detail = PG_EXCEPTION_DETAIL, v_state = RETURNED_SQLSTATE;
  END;
  IF NOT v_refus THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T1 — publish_author_draft a créé une 2e fiche au Wikidata Q999999801.';
  END IF;
  IF v_hint IS DISTINCT FROM 'error.catalog.wikidata_already_used' OR v_state <> 'P0001'
     OR (v_detail::jsonb ->> 'author_id')::bigint IS DISTINCT FROM v_a
     OR v_detail::jsonb ->> 'qid' IS DISTINCT FROM 'Q999999801'
     OR v_detail::jsonb ->> 'name' IS DISTINCT FROM 'Zzwd Alpha' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T1 — refus mal formé (état %, hint %, detail %).', v_state, v_hint, v_detail;
  END IF;
  IF EXISTS (SELECT 1 FROM public.authors WHERE preferred_name = 'Zzwd Bravo') THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T1 — la fiche refusée existe quand même.';
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T1 OK — fiche neuve au Wikidata déjà pris : refusée, l''autre fiche nommée (%).', v_detail;

  -- 2 ---------------------------------------------------------------
  UPDATE public.author_drafts SET wikidata_id = ' q999999801 ' WHERE id = v_draft;
  v_refus := false; v_hint := NULL;
  BEGIN
    PERFORM public.publish_author_draft(v_draft);
  EXCEPTION WHEN OTHERS THEN
    v_refus := true; GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
  END;
  IF NOT v_refus OR v_hint IS DISTINCT FROM 'error.catalog.wikidata_already_used' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T2 — « q999999801 » (casse, espaces) passe à côté de la garde (hint %).', v_hint;
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T2 OK — casse et espaces ne contournent pas la garde.';

  -- 3 ---------------------------------------------------------------
  INSERT INTO public.author_drafts (preferred_name, sort_name, wikidata_id, status, created_by, published_author_id)
  VALUES ('Zzwd Charlie', 'Charlie, Zzwd', 'Q999999801', 'draft', v_coord, v_c) RETURNING id INTO v_draft;
  v_refus := false; v_hint := NULL;
  BEGIN
    PERFORM public.publish_author_draft(v_draft);
  EXCEPTION WHEN OTHERS THEN
    v_refus := true; GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
  END;
  IF NOT v_refus OR v_hint IS DISTINCT FROM 'error.catalog.wikidata_already_used' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T3 — republier une fiche existante avec le Wikidata d''une autre passe (hint %).', v_hint;
  END IF;
  IF (SELECT wikidata_id FROM public.authors WHERE id = v_c) IS NOT NULL THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T3 — la fiche a reçu le Wikidata malgré le refus.';
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T3 OK — branche UPDATE de publish_author_draft : refusée, fiche intacte.';

  -- 4 ---------------------------------------------------------------
  INSERT INTO public.author_drafts (preferred_name, sort_name, wikidata_id, status, created_by, published_author_id)
  VALUES ('Zzwd Alpha', 'Alpha, Zzwd', 'Q999999801', 'draft', v_coord, v_a) RETURNING id INTO v_draft;
  PERFORM public.publish_author_draft(v_draft);   -- sa propre valeur : pas de refus
  INSERT INTO public.author_drafts (preferred_name, sort_name, wikidata_id, status, created_by)
  VALUES ('Zzwd Foxtrot', 'Foxtrot, Zzwd', '  q999999802 ', 'draft', v_coord) RETURNING id INTO v_draft;
  v_new := public.publish_author_draft(v_draft);
  SELECT wikidata_id INTO v_txt FROM public.authors WHERE id = v_new;
  IF v_txt IS DISTINCT FROM 'Q999999802' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T4 — Wikidata libre posé sous la forme « % » (attendu Q999999802).', v_txt;
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T4 OK — pas de faux refus ; la valeur posée est normalisée.';

  -- 5 ---------------------------------------------------------------
  SELECT count(*) INTO v_n FROM public.authority_proposals WHERE target_kind = 'author' AND target_id = v_c;
  v_refus := false; v_hint := NULL;
  BEGIN
    PERFORM api.fn_authority_propose('edition', 'author', v_c, NULL,
      jsonb_build_object('fields', jsonb_build_object('wikidata_id', 'Q999999801')), 'essai : Wikidata pris');
  EXCEPTION WHEN OTHERS THEN
    v_refus := true; GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT;
  END;
  IF NOT v_refus OR v_hint IS DISTINCT FROM 'error.catalog.wikidata_already_used' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T5 — fn_authority_propose accepte un Wikidata déjà porté (hint %).', v_hint;
  END IF;
  IF (SELECT count(*) FROM public.authority_proposals WHERE target_kind = 'author' AND target_id = v_c) <> v_n THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T5 — une proposition a été enregistrée malgré le refus.';
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T5 OK — l''Atelier refuse dès la proposition.';

  -- 6 ---------------------------------------------------------------
  -- Une proposition enregistrée avant la garde, consentie (le cas bebb7a02).
  INSERT INTO public.authority_proposals (kind, target_kind, target_id, payload, rationale, status, deadline, proposed_by)
  VALUES ('edition', 'author', v_c,
          jsonb_build_object('fields', jsonb_build_object('wikidata_id', 'Q999999801', 'country', 'ES')),
          'essai : proposée avant la garde', 'resolved_consent', now() - interval '1 day', v_coord)
  RETURNING id INTO v_prop;
  v_refus := false; v_hint := NULL; v_detail := NULL;
  BEGIN
    PERFORM api.fn_authority_apply(v_prop);
  EXCEPTION WHEN OTHERS THEN
    v_refus := true; GET STACKED DIAGNOSTICS v_hint = PG_EXCEPTION_HINT, v_detail = PG_EXCEPTION_DETAIL;
  END;
  IF NOT v_refus OR v_hint IS DISTINCT FROM 'error.catalog.wikidata_already_used'
     OR (v_detail::jsonb ->> 'author_id')::bigint IS DISTINCT FROM v_a THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T6 — fn_authority_apply pose un Wikidata déjà porté (hint %, detail %).', v_hint, v_detail;
  END IF;
  IF (SELECT status FROM public.authority_proposals WHERE id = v_prop) <> 'resolved_consent'
     OR (SELECT wikidata_id IS NOT NULL OR country IS NOT NULL FROM public.authors WHERE id = v_c) THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T6 — refus partiel : proposition ou fiche modifiée.';
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T6 OK — l''application refuse une proposition antérieure à la garde ; rien ne bouge.';

  -- 7 ---------------------------------------------------------------
  INSERT INTO public.authority_proposals (kind, target_kind, target_id, payload, rationale, status, deadline, proposed_by)
  VALUES ('edition', 'author', v_c,
          jsonb_build_object('fields', jsonb_build_object('wikidata_id', 'Q999999803')),
          'essai : Wikidata libre', 'resolved_consent', now() - interval '1 day', v_coord)
  RETURNING id INTO v_prop;
  -- L'appel d'abord, la lecture ensuite : dans une même expression, la
  -- sous-requête lirait l'instantané d'AVANT l'application.
  v_txt := api.fn_authority_apply(v_prop);
  IF v_txt IS DISTINCT FROM 'applied'
     OR (SELECT wikidata_id FROM public.authors WHERE id = v_c) IS DISTINCT FROM 'Q999999803' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T7 — un Wikidata libre n''est pas appliqué.';
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T7 OK — l''application pose un Wikidata libre.';

  -- 8 ---------------------------------------------------------------
  ALTER TABLE public.authors DISABLE TRIGGER trg_authors_wikidata_une_fiche;
  v_state := NULL;
  BEGIN
    UPDATE public.authors SET wikidata_id = 'Q999999801' WHERE id = v_e;
  EXCEPTION WHEN unique_violation THEN
    v_state := '23505';
  END;
  ALTER TABLE public.authors ENABLE TRIGGER trg_authors_wikidata_une_fiche;
  IF v_state IS DISTINCT FROM '23505' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T8 — sans le déclencheur, deux fiches portent Q999999801 (aucun index unique).';
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T8 OK — l''index unique tient même sans le déclencheur.';

  -- 9 ---------------------------------------------------------------
  PERFORM public.merge_author_with_fields(v_e, v_d, ARRAY['wikidata_id']);
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = v_d)
     OR (SELECT wikidata_id FROM public.authors WHERE id = v_e) IS DISTINCT FROM 'Q999999804' THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T9 — la fusion n''a pas repris le Wikidata du doublon.';
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T9 OK — merge_author_with_fields reprend le Wikidata du doublon.';

  -- 10 --------------------------------------------------------------
  SELECT count(*) INTO v_n FROM (
    SELECT wikidata_id FROM public.authors WHERE wikidata_id IS NOT NULL GROUP BY 1 HAVING count(*) > 1) d;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'WIKIDATA-UNIQUE ECHEC : T10 — % Wikidata portés par plusieurs fiches.', v_n;
  END IF;
  v_ok := v_ok + 1;
  RAISE NOTICE 'T10 OK — aucune paire au même Wikidata.';

  RAISE EXCEPTION 'WIKIDATA-UNIQUE OK : %/10 tests passés (fixtures annulées)', v_ok;
END $$;
