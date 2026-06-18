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
