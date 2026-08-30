-- ===========================================================================
-- seed.sql — fixtures de TEST (local uniquement : appliqué par `supabase db
-- reset`/`start`, JAMAIS par `db push` → ne touche jamais la prod).
-- ---------------------------------------------------------------------------
-- Données 100% SYNTHÉTIQUES (aucune PII). Fournit le monde minimal dont les
-- suites tests/sql/*.sql (à fixtures dynamiques) ont besoin pour s'exécuter
-- réellement contre une base baseline (schéma-only) en CI.
--
-- Couvre aujourd'hui : suite cotisation (biblio à cotisation + staff + profil
-- sans adhésion). La suite renouvellement granulaire est surtout déterministe
-- (introspection/auth) ; son test E2E (prêt ouvert) SKIP faute de prêt seedé
-- — à étoffer plus tard si on veut le couvrir.
-- ===========================================================================

-- Biblio de test — id = celui attendu par tests/sql/paquet_cotisation_tests.sql.
INSERT INTO public.libraries (id, slug, name, membership_enabled)
VALUES ('1234825f-a0f9-4fbd-a875-6551c30ea4ca', 'blmf-test', 'BLMF (base de test)', true)
ON CONFLICT (id) DO UPDATE SET membership_enabled = true;

-- public.profiles.id porte une FK vers auth.users(id) → créer d'abord les comptes
-- auth. Dans GoTrue la quasi-totalité des colonnes sont nullable/à défaut ; on
-- fournit le minimum d'un compte e-mail confirmé. Mot de passe OMIS volontairement
-- (les suites simulent le JWT via set_config(request.jwt.claims), jamais de login).
INSERT INTO auth.users (instance_id, id, aud, role, email,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
VALUES
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'coord.test@anarbib.local',
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'outsider.test@anarbib.local',
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Profils de test (insérés après auth.users pour satisfaire profiles_id_fkey ;
-- un éventuel trigger handle_new_user les aurait déjà créés → ON CONFLICT).
INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'coord.test@anarbib.local', 'Coord', 'Test', 'fr'),
  ('22222222-2222-2222-2222-222222222222', 'outsider.test@anarbib.local', 'Outsider', 'Test', 'fr')
ON CONFLICT (id) DO NOTHING;

-- Le profil 1 est coordenador (staff) de la biblio de test → résout v_staff
-- (acteur staff) dans la suite cotisation. Le profil 2 reste SANS adhésion BLMF
-- → résout v_subject (sujet pilotable). (Pas de contrainte unique sur
-- (user_id,library_id) ; base fraîche à chaque reset → pas de doublon.)
INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
VALUES ('11111111-1111-1111-1111-111111111111', '1234825f-a0f9-4fbd-a875-6551c30ea4ca', 'coordenador', 'active', true);

-- ===========================================================================
-- Personas synthétiques et monde de circulation minimal
-- Ajoutés le 29/08/2026 (backlog v34, item I7).
--
-- POURQUOI. Les suites paquet19/24/25 désignaient leurs acteurs par des UUID
-- relevés en production le 11/05/2026, et `tests/sql/README.md` en donnait la
-- table de correspondance prénom → identifiant. Un UUID seul est pseudonyme ;
-- accompagné de cette table, il identifie des personnes réelles — dont des
-- tiers — dans un dépôt public. Les quatre acteurs sont désormais synthétiques
-- et fournis ici. Règle : une fixture relevée en production reste une donnée
-- de production.
--
-- Correspondance retenue (les deux premiers existaient déjà au-dessus) :
--   11111111-…  coordenador BLMF        (ex-acteur « staff »)
--   22222222-…  compte sans aucun rôle  (ex-acteur « sans rôle »)
--   33333333-…  lectrice A, reader BLMF actif
--   44444444-…  lecteur B,  reader BLMF actif
--
-- Le monde de circulation (livre + holding + exemplaire) débloque le setup de
-- paquetA1 et les SKIP « aucun book_holding BLMF seedé » disséminés dans
-- cotisation, granulaire, emprestimos, reservas, paquet24 et paquet25 : sans
-- un seul exemplaire en base, aucun chemin nominal de la circulation n'est
-- éprouvé.
-- ===========================================================================

INSERT INTO auth.users (instance_id, id, aud, role, email,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
VALUES
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333',
   'authenticated', 'authenticated', 'leitora.a.test@anarbib.local',
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000000', '44444444-4444-4444-4444-444444444444',
   'authenticated', 'authenticated', 'leitor.b.test@anarbib.local',
   now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, email, first_name, last_name, preferred_language)
VALUES
  ('33333333-3333-3333-3333-333333333333', 'leitora.a.test@anarbib.local', 'Leitora', 'A', 'pt-BR'),
  ('44444444-4444-4444-4444-444444444444', 'leitor.b.test@anarbib.local',  'Leitor',  'B', 'pt-BR')
ON CONFLICT (id) DO NOTHING;

-- Deux lecteur·rices actif·ves : les suites d'ownership ont besoin de DEUX
-- comptes distincts pour éprouver « untel n'agit pas sur l'emprunt d'autrui ».
INSERT INTO public.user_library_memberships (user_id, library_id, role, status, is_primary)
VALUES
  ('33333333-3333-3333-3333-333333333333', '1234825f-a0f9-4fbd-a875-6551c30ea4ca', 'reader', 'active', true),
  ('44444444-4444-4444-4444-444444444444', '1234825f-a0f9-4fbd-a875-6551c30ea4ca', 'reader', 'active', true);

-- Monde de circulation : un livre, son holding BLMF, un exemplaire empruntable.
DO $$
DECLARE
  c_blmf      constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  v_book_id   bigint;
  v_holding_id bigint;
BEGIN
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Obra de teste — circulação', 'TEST-CIRC-1', 'livro', 'ambos', true)
  RETURNING id INTO v_book_id;

  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  VALUES (v_book_id, c_blmf, 1, 1)
  RETURNING id INTO v_holding_id;

  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id,
                                 circulation_policy, visibility)
  VALUES ('TEST-CIRC-1', 'TESTE-000001', c_blmf, v_holding_id, 'ambos', 'public');

  RAISE NOTICE 'seed circulation : livre %, holding %, 1 exemplaire sur BLMF', v_book_id, v_holding_id;
END $$;

-- ===========================================================================
-- Deux emprunts : un ouvert, un clos
-- Ajoutés le 30/08/2026 (backlog v34, item I15).
--
-- POURQUOI. Douze SKIP disséminés dans `paquet19`, `paquet24`, `paquet25`,
-- `cotisation` et `granulaire` disaient tous la même chose : « aucun emprunt
-- en base ». Autrement dit, aucun chemin nominal de la circulation — le cœur
-- du logiciel — n'était éprouvé, et une suite qui SKIP se lit comme une suite
-- qui passe. Le seed fournit désormais de quoi les écrire.
--
--   * la lectrice A porte un emprunt OUVERT, échéance dans 14 jours. Il rend
--     testables : la prolongation par la propriétaire, le refus opposé à
--     quelqu'un d'autre (le lecteur B sur l'emprunt de la lectrice A —
--     l'invariant d'appartenance, qui n'était jusqu'ici jamais exercé),
--     l'agenda de retour, et le renouvellement d'un membre à cotisation
--     restreinte.
--   * le lecteur B porte un emprunt CLOS, rendu il y a trois jours. Il rend
--     testable le refus d'agir sur un emprunt déjà terminé, qui n'a pas la
--     même cause que le refus opposé à un inconnu et méritait son propre cas.
--
-- Un exemplaire par emprunt : rien n'interdirait de les faire porter par le
-- même, mais deux exemplaires évitent de dépendre d'une hypothèse sur ce que
-- la base autorise, et coûtent une ligne.
-- ===========================================================================

DO $$
DECLARE
  c_blmf      constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  c_leitora_a constant uuid := '33333333-3333-3333-3333-333333333333';
  c_leitor_b  constant uuid := '44444444-4444-4444-4444-444444444444';
  v_holding_id bigint;
  v_book_id    bigint;
  v_item_1     bigint;
  v_item_2     bigint;
  v_emp        bigint;
BEGIN
  SELECT h.id, h.book_id INTO v_holding_id, v_book_id
    FROM public.book_holdings h
   WHERE h.library_id = c_blmf
   ORDER BY h.id
   LIMIT 1;

  IF v_holding_id IS NULL THEN
    RAISE EXCEPTION 'seed : aucun holding BLMF — le bloc de circulation ci-dessus n''a pas tourné';
  END IF;

  SELECT id INTO v_item_1 FROM public.exemplares WHERE tombo = 'TESTE-000001';

  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id,
                                 circulation_policy, visibility)
  VALUES ('TEST-CIRC-1', 'TESTE-000002', c_blmf, v_holding_id, 'ambos', 'public')
  RETURNING id INTO v_item_2;

  -- Emprunt OUVERT — lectrice A
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
  VALUES (c_leitora_a, c_blmf, 'aberto', (current_date + 14))
  RETURNING id INTO v_emp;

  INSERT INTO public.emprestimo_itens_v2
    (emprestimo_id, line_no, sub_id, book_id, item_id, holding_id,
     bib_ref, titulo_cache, item_status, due_at)
  VALUES
    (v_emp, 1, 'TESTE-EMP-1.1', v_book_id, v_item_1, v_holding_id,
     'TEST-CIRC-1', 'Obra de teste — circulação', 'aberto', (current_date + 14));

  -- Emprunt CLOS — lecteur B, rendu il y a trois jours
  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
  VALUES (c_leitor_b, c_blmf, 'encerrado', (current_date - 10))
  RETURNING id INTO v_emp;

  INSERT INTO public.emprestimo_itens_v2
    (emprestimo_id, line_no, sub_id, book_id, item_id, holding_id,
     bib_ref, titulo_cache, item_status, due_at, returned_at)
  VALUES
    (v_emp, 1, 'TESTE-EMP-2.1', v_book_id, v_item_2, v_holding_id,
     'TEST-CIRC-1', 'Obra de teste — circulação', 'devolvido', (current_date - 10),
     (now() - interval '3 days'));

  RAISE NOTICE 'seed circulation : 1 emprunt ouvert (lectrice A), 1 emprunt clos (lecteur B)';
END $$;

-- ===========================================================================
-- Une consulta et une réservation — les deux derniers manques
-- Ajoutés le 30/08/2026 (backlog v34, item I15, seconde passe).
--
-- Après les deux emprunts, il restait sept SKIP, tous de la même famille :
-- « pas de consulta active BLMF », « pas de consulta non-terminale », « pas de
-- consulta solicitada/em_preparacao », « pas de consulta de la lectrice A »,
-- « pas de réservation active BLMF », « Xavier n'a aucun emprunt ouvert ».
--
-- UN HOLDING PAR SITUATION, et c'est délibéré. Le modèle porte deux invariants
-- croisés — on ne réserve pas ce qui est en consulta, on ne consulte pas ce qui
-- est réservé — et ce sont précisément eux que `paquet24` C.2 et C.3 éprouvent.
-- Les entasser sur un même holding, c'est fabriquer un état que le produit
-- refuse et rendre les tests illisibles. Trois holdings :
--   holding 1 → les emprunts (lectrice A ouvert, lecteur B clos, coordination)
--   holding 2 → la consulta de la lectrice A, en `em_preparacao`
--   holding 3 → la réservation active du lecteur B
-- ===========================================================================

DO $$
DECLARE
  c_blmf      constant uuid := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  c_coord     constant uuid := '11111111-1111-1111-1111-111111111111';
  c_leitora_a constant uuid := '33333333-3333-3333-3333-333333333333';
  c_leitor_b  constant uuid := '44444444-4444-4444-4444-444444444444';
  v_h1 bigint; v_b1 bigint;
  v_h2 bigint; v_b2 bigint; v_i2 bigint;
  v_h3 bigint; v_b3 bigint; v_i3 bigint;
  v_i_coord bigint;
  v_emp bigint; v_cons bigint; v_res bigint;
BEGIN
  SELECT h.id, h.book_id INTO v_h1, v_b1
    FROM public.book_holdings h WHERE h.library_id = c_blmf ORDER BY h.id LIMIT 1;

  -- --- Emprunt de la coordination, sur un exemplaire du holding 1 ---------
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('TEST-CIRC-1', 'TESTE-000003', c_blmf, v_h1, 'ambos', 'public')
  RETURNING id INTO v_i_coord;

  INSERT INTO public.emprestimos_v2 (user_id, library_id, status_global, due_at)
  VALUES (c_coord, c_blmf, 'aberto', (current_date + 21))
  RETURNING id INTO v_emp;

  INSERT INTO public.emprestimo_itens_v2
    (emprestimo_id, line_no, sub_id, book_id, item_id, holding_id, bib_ref, titulo_cache, item_status, due_at)
  VALUES (v_emp, 1, 'TESTE-EMP-3.1', v_b1, v_i_coord, v_h1,
          'TEST-CIRC-1', 'Obra de teste — circulação', 'aberto', (current_date + 21));

  -- --- Holding 2 : la consulta de la lectrice A --------------------------
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Obra de teste — consulta local', 'TEST-CONS-1', 'livro', 'consulta', false)
  RETURNING id INTO v_b2;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  VALUES (v_b2, c_blmf, 1, 1) RETURNING id INTO v_h2;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('TEST-CONS-1', 'TESTE-000004', c_blmf, v_h2, 'consulta', 'public')
  RETURNING id INTO v_i2;

  INSERT INTO public.consultas_locais_v2 (user_id, library_id, status_global, notes)
  VALUES (c_leitora_a, c_blmf, 'ativa', 'Fixture de seed — consulta en preparation')
  RETURNING id INTO v_cons;

  INSERT INTO public.consulta_linhas_v2
    (consulta_id, line_no, book_id, holding_id, item_id, bib_ref, titulo_cache, item_status, expires_at)
  VALUES (v_cons, 1, v_b2, v_h2, v_i2, 'TEST-CONS-1',
          'Obra de teste — consulta local', 'ativa', (now() + interval '30 days'));

  -- `em_preparacao` : etape non terminale, celle que cherchent C.5/C.6 et D.4.
  INSERT INTO public.consulta_item_workflow_v2 (consulta_id, line_no, workflow_stage, workflow_note)
  VALUES (v_cons, 1, 'em_preparacao', 'Fixture de seed');

  -- --- Holding 3 : la réservation du lecteur B ---------------------------
  INSERT INTO public.books (titulo, bib_ref, tipo_material, circulation_default, loanable)
  VALUES ('Obra de teste — reserva', 'TEST-RES-1', 'livro', 'emprestavel', true)
  RETURNING id INTO v_b3;
  INSERT INTO public.book_holdings (book_id, library_id, exemplares_total, available_count)
  VALUES (v_b3, c_blmf, 1, 1) RETURNING id INTO v_h3;
  INSERT INTO public.exemplares (bib_ref, tombo, library_id, holding_id, circulation_policy, visibility)
  VALUES ('TEST-RES-1', 'TESTE-000005', c_blmf, v_h3, 'emprestavel', 'public')
  RETURNING id INTO v_i3;

  INSERT INTO public.reservas_v2 (user_id, library_id, status_global, notes)
  VALUES (c_leitor_b, c_blmf, 'ativa', 'Fixture de seed — reserve active')
  RETURNING id INTO v_res;

  INSERT INTO public.reserva_linhas_v2
    (reserva_id, line_no, sub_id, book_id, holding_id, item_id, bib_ref, titulo_cache, item_status, expires_at)
  VALUES (v_res, 1, 'TESTE-RES-1.1', v_b3, v_h3, v_i3, 'TEST-RES-1',
          'Obra de teste — reserva', 'ativa', (now() + interval '7 days'));

  RAISE NOTICE 'seed circulation : + 1 emprunt coordination, 1 consulta (em_preparacao), 1 reservation active';
END $$;
