-- ============================================================
-- Tests d'acceptation paquet A1 — Note obligatoire annulation biblio
-- ============================================================
-- 4 tests :
-- 1. Annulation sans note (NULL) → raise cancel_note_required
-- 2. Annulation avec note vide ('') → raise
-- 3. Annulation avec note trop courte (< 5 chars) → raise
-- 4. Annulation avec note valide (>= 5 chars) → succes
--
-- A executer apres application de la migration via Woodpecker.
-- Les tests utilisent une consulta de test creee specifiquement,
-- supprimee a la fin via ROLLBACK.
-- ============================================================

BEGIN;

-- Setup : creer une consulta de test
DO $$
DECLARE
  v_blmf_id uuid;
  v_test_user_id uuid;
  v_test_holding_id bigint;
  v_test_item_id bigint;
  v_consulta_id bigint;
BEGIN
  -- Recuperer BLMF
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf-test';
  IF v_blmf_id IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : BLMF introuvable';
  END IF;
  
  -- Recuperer le premier holding disponible sur BLMF
  SELECT id INTO v_test_holding_id 
  FROM public.book_holdings 
  WHERE library_id = v_blmf_id 
  LIMIT 1;
  
  IF v_test_holding_id IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : aucun holding disponible sur BLMF pour les tests';
  END IF;

  SELECT id INTO v_test_item_id
    FROM public.exemplares
   WHERE holding_id = v_test_holding_id
   LIMIT 1;

  IF v_test_item_id IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : aucun exemplaire sur le holding BLMF (etoffer supabase/seed.sql)';
  END IF;
  
  -- Recuperer un user lecteur (le premier reader actif sur BLMF)
  SELECT user_id INTO v_test_user_id
  FROM public.user_library_memberships
  WHERE library_id = v_blmf_id 
    AND role = 'reader'
    AND status = 'active'
  LIMIT 1;
  
  IF v_test_user_id IS NULL THEN
    RAISE EXCEPTION 'SETUP FAILED : aucun reader actif sur BLMF pour les tests';
  END IF;
  
  -- Creer une consulta de test directement en DB (bypass auth pour les tests SQL)
  INSERT INTO public.consultas_locais_v2 (user_id, library_id, status_global, notes)
  VALUES (v_test_user_id, v_blmf_id, 'ativa', 'TEST B6 - sera rollback')
  RETURNING id INTO v_consulta_id;
  
  -- Creer une ligne consulta (item ativa)
  INSERT INTO public.consulta_linhas_v2 (
    -- `sub_id` retire le 29/08/2026 : c'est une colonne GENERATED ALWAYS
    -- (consulta_id || '.' || line_no). Postgres refuse toute valeur explicite.
    -- `item_id` ajoute le meme jour : NOT NULL depuis le passage au grain item
    -- (#MODEL-item-grain), FK vers exemplares. La consulta porte l'EXEMPLAIRE
    -- consulte, pas seulement la notice -- c'est tout l'objet de ce modele.
    consulta_id, line_no, book_id, holding_id, item_id, 
    bib_ref, titulo_cache, autor_cache, item_status, expires_at
  )
  SELECT 
    v_consulta_id, 1, bh.book_id, v_test_holding_id, v_test_item_id,
    'TEST-B6', 'Test Title', 'Test Author', 'ativa', now() + interval '30 days'
  FROM public.book_holdings bh
  WHERE bh.id = v_test_holding_id;
  
  -- Creer le workflow stage initial em_preparacao (pour pouvoir transitionner vers cancelada_biblioteca)
  INSERT INTO public.consulta_item_workflow_v2 (
    consulta_id, line_no, workflow_stage, workflow_note
  ) VALUES (
    v_consulta_id, 1, 'em_preparacao', 'Setup test B6'
  );
  
  -- Stocker l'id dans une table temp pour les tests suivants
  CREATE TEMP TABLE IF NOT EXISTS test_consulta_id (id bigint);
  INSERT INTO test_consulta_id (id) VALUES (v_consulta_id);
  
  RAISE NOTICE 'SETUP OK : consulta test % creee en stage em_preparacao', v_consulta_id;
END $$;

-- ============================================================
-- TEST 1 — Annulation sans note (NULL) → raise cancel_note_required
-- ============================================================
-- Note : on doit simuler un appel api.advance_consulta. Mais api.advance_consulta
-- est SECURITY INVOKER avec auth.uid() requis. En SQL Editor (role postgres),
-- auth.uid() retourne NULL et la fonction raise not_authenticated en premier.
--
-- Solution : on teste la garde directement via SET LOCAL ROLE simule.
-- ============================================================

DO $$
DECLARE
  v_consulta_id bigint;
  v_blmf_id uuid;
  v_actor_uid uuid;
  v_error_caught boolean := false;
  v_error_msg text;
BEGIN
  SELECT id INTO v_consulta_id FROM test_consulta_id LIMIT 1;
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf-test';
  
  -- Recuperer un coordenador BLMF pour simuler le caller
  SELECT user_id INTO v_actor_uid
  FROM public.user_library_memberships
  WHERE library_id = v_blmf_id
    AND role = 'coordenador'
    AND status = 'active'
  LIMIT 1;
  
  IF v_actor_uid IS NULL THEN
    RAISE EXCEPTION 'SETUP TEST 1 FAILED : aucun coordenador actif sur BLMF';
  END IF;
  
  -- Simuler le contexte authenticated avec sub = coordenador
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', 
    jsonb_build_object('sub', v_actor_uid::text, 'role', 'authenticated')::text, 
    true);
  
  BEGIN
    PERFORM api.advance_consulta(
      v_consulta_id, 
      ARRAY[1]::integer[], 
      'cancelada_biblioteca', 
      NULL  -- NOTE NULL
    );
    RAISE EXCEPTION 'TEST 1 FAILED : annulation sans note acceptee, garde cancel_note_required manquante';
  EXCEPTION 
    WHEN SQLSTATE 'P0001' THEN
      GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
      IF v_error_msg LIKE '%cancel_note_required%' THEN
        v_error_caught := true;
      ELSE
        RAISE EXCEPTION 'TEST 1 FAILED : raise inattendu : %', v_error_msg;
      END IF;
    WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
      RAISE EXCEPTION 'TEST 1 FAILED : erreur inattendue : %', v_error_msg;
  END;
  
  RESET ROLE;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 1 OK : annulation sans note rejetee (cancel_note_required)';
  END IF;
END $$;

-- ============================================================
-- TEST 2 — Annulation avec note vide ('') → raise
-- ============================================================
DO $$
DECLARE
  v_consulta_id bigint;
  v_blmf_id uuid;
  v_actor_uid uuid;
  v_error_caught boolean := false;
  v_error_msg text;
BEGIN
  SELECT id INTO v_consulta_id FROM test_consulta_id LIMIT 1;
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf-test';
  SELECT user_id INTO v_actor_uid FROM public.user_library_memberships
    WHERE library_id = v_blmf_id AND role = 'coordenador' AND status = 'active' LIMIT 1;
  
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', 
    jsonb_build_object('sub', v_actor_uid::text, 'role', 'authenticated')::text, 
    true);
  
  BEGIN
    PERFORM api.advance_consulta(
      v_consulta_id, 
      ARRAY[1]::integer[], 
      'cancelada_biblioteca', 
      ''  -- NOTE VIDE
    );
    RAISE EXCEPTION 'TEST 2 FAILED : annulation avec note vide acceptee';
  EXCEPTION 
    WHEN SQLSTATE 'P0001' THEN
      GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
      IF v_error_msg LIKE '%cancel_note_required%' THEN
        v_error_caught := true;
      ELSE
        RAISE EXCEPTION 'TEST 2 FAILED : raise inattendu : %', v_error_msg;
      END IF;
  END;
  
  RESET ROLE;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 2 OK : annulation avec note vide rejetee';
  END IF;
END $$;

-- ============================================================
-- TEST 3 — Annulation avec note trop courte (< 5 chars) → raise
-- ============================================================
DO $$
DECLARE
  v_consulta_id bigint;
  v_blmf_id uuid;
  v_actor_uid uuid;
  v_error_caught boolean := false;
  v_error_msg text;
BEGIN
  SELECT id INTO v_consulta_id FROM test_consulta_id LIMIT 1;
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf-test';
  SELECT user_id INTO v_actor_uid FROM public.user_library_memberships
    WHERE library_id = v_blmf_id AND role = 'coordenador' AND status = 'active' LIMIT 1;
  
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', 
    jsonb_build_object('sub', v_actor_uid::text, 'role', 'authenticated')::text, 
    true);
  
  BEGIN
    PERFORM api.advance_consulta(
      v_consulta_id, 
      ARRAY[1]::integer[], 
      'cancelada_biblioteca', 
      'ok'  -- 2 CHARS, INSUFFISANT
    );
    RAISE EXCEPTION 'TEST 3 FAILED : annulation avec note "ok" (2 chars) acceptee';
  EXCEPTION 
    WHEN SQLSTATE 'P0001' THEN
      GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
      IF v_error_msg LIKE '%cancel_note_required%' THEN
        v_error_caught := true;
      ELSE
        RAISE EXCEPTION 'TEST 3 FAILED : raise inattendu : %', v_error_msg;
      END IF;
  END;
  
  RESET ROLE;
  
  IF v_error_caught THEN
    RAISE NOTICE 'TEST 3 OK : annulation avec note "ok" (2 chars) rejetee';
  END IF;
END $$;

-- ============================================================
-- TEST 4 — Annulation avec note valide (>= 5 chars) → succes
-- ============================================================
DO $$
DECLARE
  v_consulta_id bigint;
  v_blmf_id uuid;
  v_actor_uid uuid;
  v_result jsonb;
  v_final_stage text;
  v_final_note text;
BEGIN
  SELECT id INTO v_consulta_id FROM test_consulta_id LIMIT 1;
  SELECT id INTO v_blmf_id FROM public.libraries WHERE slug = 'blmf-test';
  SELECT user_id INTO v_actor_uid FROM public.user_library_memberships
    WHERE library_id = v_blmf_id AND role = 'coordenador' AND status = 'active' LIMIT 1;
  
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims', 
    jsonb_build_object('sub', v_actor_uid::text, 'role', 'authenticated')::text, 
    true);
  
  -- Annulation valide
  SELECT api.advance_consulta(
    v_consulta_id, 
    ARRAY[1]::integer[], 
    'cancelada_biblioteca', 
    'Livro indisponivel temporariamente'  -- 34 chars, valide
  ) INTO v_result;
  
  RESET ROLE;
  
  -- Verifier que la transition a eu lieu et que la note est bien enregistree
  SELECT workflow_stage, workflow_note INTO v_final_stage, v_final_note
  FROM public.consulta_item_workflow_v2
  WHERE consulta_id = v_consulta_id AND line_no = 1;
  
  IF v_final_stage <> 'cancelada_biblioteca' THEN
    RAISE EXCEPTION 'TEST 4 FAILED : stage attendu cancelada_biblioteca, trouve %', v_final_stage;
  END IF;
  
  IF v_final_note <> 'Livro indisponivel temporariamente' THEN
    RAISE EXCEPTION 'TEST 4 FAILED : note attendue "Livro indisponivel temporariamente", trouvee "%"', v_final_note;
  END IF;
  
  RAISE NOTICE 'TEST 4 OK : annulation avec note valide enregistree (workflow_note = "%")', v_final_note;
END $$;

-- ============================================================
-- ROLLBACK : aucune donnee de test persiste
-- ============================================================

-- ============================================================
-- BILAN a la convention du corpus.
-- Jusqu'au 29/08/2026 ce fichier se terminait par un SELECT d'une chaine
-- CONSTANTE annoncant « 4/4 tests passent » — affichee telle quelle
-- meme quand un test venait d'echouer. Une suite ne doit pas proclamer son
-- succes : elle doit le prouver en l'atteignant. Chaque test ci-dessus leve
-- une EXCEPTION s'il echoue, donc arriver ici EST le succes, et c'est ici que
-- le bilan se dit -- sous la forme « OK : N/N » que cherche
-- scripts/ci/run-sql-suites.sh.
-- Si l'on ajoute un test a cette suite, mettre a jour le compte ci-dessous.
-- ============================================================
DO $$ BEGIN
  RAISE EXCEPTION 'PAQUET-A1 OK : 4/4 tests passes';
END $$;

ROLLBACK;
