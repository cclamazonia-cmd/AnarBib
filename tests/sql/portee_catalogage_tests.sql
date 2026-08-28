-- =====================================================================
-- AnarBib — Tests : biblio de destination a la publication, et suppression
--                   definitive reservee a la coordination
-- Date    : 2026-08-29  ·  Session : chantier catalogage (portee des gestes)
-- Ref     : migrations 20260829100000 et 20260829120000
--
-- Pourquoi cette suite existe. Deux defauts de la MEME famille : quelque chose
-- decidait a la place des gens.
--   * la bibliotheque ou un livre atterrit venait, quand owner_library_id etait
--     nul, d'un `order by ulm.role desc limit 1` — un tri ALPHABETIQUE sur le
--     nom du role, qui met `reader` devant `librarian`, sans filtrer `status`.
--     Une adhesion revoquee pouvait designer la destination ;
--   * et le garde-fou « seule une admin reseau cible une biblio » etait pose sur
--     initial_copies_library_id, pas sur owner_library_id qui est lu AVANT lui
--     et se modifie librement.
--
-- T2 est le test qui compte, et c'est un test de NON-ACTION : une adhesion
-- REVOQUEE, et de surcroit `reader` (celle que l'ancien tri preferait), ne doit
-- PAS designer la bibliotheque. C'est exactement le cas que l'ancien code se
-- serait fait un plaisir de choisir.
--
-- T6 tient l'autre piege, cote suppression : une policy qui refuse un DELETE ne
-- leve pas d'erreur, elle supprime ZERO ligne. Un test qui verifierait seulement
-- « ca n'a pas plante » passerait alors que le refus fonctionne — ou pas.
--
-- Toutes les ecritures sont annulees : la suite se termine par un RAISE.
--   Bilan OK : 'PORTEE-CATALOGAGE OK : N/N'
-- =====================================================================
DO $$
DECLARE
  v_passed int := 0; v_failed int := 0; v_failures text[] := ARRAY[]::text[]; v_t text;
  v_coord uuid := '11111111-1111-1111-1111-111111111111';  -- coordenador BLMF (seed)
  v_biblio uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';  -- BLMF (seed)
  v_autre  uuid := '22222222-2222-2222-2222-222222222222';  -- sans adhesion (seed)
  v_btl    uuid;
  v_draft  bigint;
  v_book   bigint;
  v_lot    bigint;
  v_lib    uuid;
  v_n      int;
  v_def    text;
BEGIN
  -- Le seed de CI ne porte qu'UNE bibliotheque : la suite fabrique la seconde
  -- plutot que d'exiger du seed ce qu'il n'a pas (elle est annulee comme le
  -- reste). Si un jour le seed en porte deux, on prend la sienne.
  SELECT id INTO v_btl FROM public.libraries WHERE id <> v_biblio AND is_active
   ORDER BY slug LIMIT 1;
  IF v_btl IS NULL THEN
    INSERT INTO public.libraries (slug, name)
    VALUES ('portee-test', 'Bibliotheque de test — portee') RETURNING id INTO v_btl;
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);

  -- ═══ A. La bibliotheque de destination ═══════════════════════════

  -- Le piege que l'ancien tri adorait : une adhesion REVOQUEE, role `reader`
  -- (qui passe avant `librarian` et `coordenador` en tri alphabetique inverse),
  -- dans une AUTRE bibliotheque.
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_coord, v_btl, 'reader', 'removed');

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T1 sans owner_library_id, la destination est l''adhesion ACTIVE du createur';
  BEGIN
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, status, created_by)
    VALUES ('Le talon de fer', 'TEST-PORTEE-001', 'livro', 'draft', v_coord)
    RETURNING id INTO v_draft;
    -- publish_book_draft rend un BIGINT (l'id du livre), pas du jsonb.
    v_book := public.publish_book_draft(v_draft);
    SELECT library_id INTO v_lib FROM public.book_holdings WHERE book_id = v_book LIMIT 1;
    IF v_lib = v_biblio THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : holding sur '||coalesce(v_lib::text,'AUCUN')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T2 une adhesion REVOQUEE ne designe pas la bibliotheque (non-action)';
  BEGIN
    IF v_lib IS DISTINCT FROM v_btl THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : le livre a atterri dans la biblio revoquee'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T3 publier un rascunho rattache a une biblio dont on n''est pas membre est refuse';
  BEGIN
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, status, created_by, owner_library_id)
    VALUES ('Germinal', 'TEST-PORTEE-002', 'livro', 'draft', v_coord, v_btl)
    RETURNING id INTO v_draft;
    PERFORM public.publish_book_draft(v_draft);
    v_failed := v_failed+1; v_failures := v_failures||(v_t||' : aucun refus');
  EXCEPTION WHEN OTHERS THEN
    IF position('n''etes pas membre' in SQLERRM) > 0 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : mauvaise erreur '||SQLERRM); END IF;
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T4 ... mais publier dans SA propre bibliotheque marche toujours';
  BEGIN
    INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, status, created_by, owner_library_id)
    VALUES ('La conquete du pain', 'TEST-PORTEE-003', 'livro', 'draft', v_coord, v_biblio)
    RETURNING id INTO v_draft;
    v_book := public.publish_book_draft(v_draft);
    SELECT library_id INTO v_lib FROM public.book_holdings WHERE book_id = v_book LIMIT 1;
    IF v_lib = v_biblio THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : holding sur '||coalesce(v_lib::text,'AUCUN')); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T5 le tri alphabetique de role a disparu du corps (structurel)';
  BEGIN
    SELECT pg_get_functiondef(p.oid) INTO v_def
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.proname = 'publish_book_draft';
    IF v_def NOT LIKE '%order by ulm.role desc%'
       AND v_def LIKE '%ulm.is_primary desc, ulm.created_at, ulm.library_id%' THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : corps inattendu'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ═══ B. La suppression definitive ════════════════════════════════

  -- Une bibliothecaire (pas coordenador, pas admin reseau).
  INSERT INTO public.user_library_memberships (user_id, library_id, role, status)
  VALUES (v_autre, v_biblio, 'librarian', 'active');

  INSERT INTO public.book_drafts (titulo, bib_ref, tipo_material, status, created_by)
  VALUES ('A supprimer', 'TEST-PORTEE-004', 'livro', 'cancelled', v_coord)
  RETURNING id INTO v_draft;
  INSERT INTO public.catalog_batches (name, status) VALUES ('Lot de test portee', 'closed')
  RETURNING id INTO v_lot;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T6 une bibliothecaire ne supprime plus : ZERO ligne, et la ligne est toujours la';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    DELETE FROM public.book_drafts WHERE id = v_draft;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RESET ROLE;
    IF v_n = 0 AND EXISTS (SELECT 1 FROM public.book_drafts WHERE id = v_draft) THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) supprimee(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T7 ... mais elle peut toujours CREER et EDITER (rien d''autre ne bouge)';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    UPDATE public.book_drafts SET notas = 'edite par la bibliothecaire' WHERE id = v_draft;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RESET ROLE;
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : UPDATE a touche '||v_n||' ligne(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T8 une coordinatrice supprime';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_coord, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    DELETE FROM public.book_drafts WHERE id = v_draft;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RESET ROLE;
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T9 le lot suit la meme regle (le supprimer emporte sa corbeille)';
  BEGIN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_autre, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    DELETE FROM public.catalog_batches WHERE id = v_lot;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RESET ROLE;
    IF v_n = 0 AND EXISTS (SELECT 1 FROM public.catalog_batches WHERE id = v_lot) THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) supprimee(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE; v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM);
  END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T10 la suppression journalisee du levier 2 fonctionne toujours';
  BEGIN
    SELECT count(*) INTO v_n FROM public.catalog_audit_log
     WHERE action = 'delete' AND entity_type = 'book' AND entity_id = v_draft;
    IF v_n = 1 THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' ligne(s) de journal'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  -- ─────────────────────────────────────────────────────────────────
  v_t := 'T11 les 4 policies restrictives sont en place et les permissives intactes';
  BEGIN
    SELECT count(*) INTO v_n FROM pg_policies
     WHERE schemaname = 'public' AND policyname LIKE '%_suppression_definitive_coordination'
       AND cmd = 'DELETE' AND permissive = 'RESTRICTIVE';
    IF v_n = 4 AND EXISTS (SELECT 1 FROM pg_policies
                            WHERE schemaname='public' AND tablename='book_drafts'
                              AND policyname='book_drafts_catalogacao_librarian_all')
    THEN v_passed := v_passed+1;
    ELSE v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||v_n||' restrictive(s)'); END IF;
  EXCEPTION WHEN OTHERS THEN v_failed := v_failed+1; v_failures := v_failures||(v_t||' : '||SQLERRM); END;

  IF v_failed = 0 THEN
    RAISE EXCEPTION 'PORTEE-CATALOGAGE OK : %/% tests passés', v_passed, (v_passed+v_failed);
  ELSE
    RAISE EXCEPTION 'PORTEE-CATALOGAGE ECHEC : %/% OK, % échec(s) | %',
      v_passed, (v_passed+v_failed), v_failed, array_to_string(v_failures, ' || ');
  END IF;
END $$;
