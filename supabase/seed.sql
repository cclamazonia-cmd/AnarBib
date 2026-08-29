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
