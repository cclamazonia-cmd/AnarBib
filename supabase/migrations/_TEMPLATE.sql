-- =========================================================================
-- Paquet [NOM_PAQUET] — [DESCRIPTION COURTE]
-- =========================================================================
-- Date     : YYYY-MM-DD
-- Chantier : [nom du chantier global, par exemple "admin réseau", "consultations"]
-- Auteur   : [nom du contributeur·rice]
--
-- CHECKLIST DOCTRINE (cf. docs/decisions/CHANTIER_doctrine_creation_objets_securises_2026-05-12.md)
--
--   [ ] Si création de fonction SECURITY DEFINER :
--       [ ] SET search_path = public, pg_catalog
--       [ ] REVOKE EXECUTE ... FROM PUBLIC, anon, authenticated
--           /!\ LES TROIS. Deux mécanismes INDÉPENDANTS donnent l'accès :
--           le grant hérité de PUBLIC, et les grants DIRECTS à anon/
--           authenticated posés par les ALTER DEFAULT PRIVILEGES de Supabase
--           sur le schéma `public`. Révoquer l'un laisse l'autre.
--           Vécu le 30/08/2026 : fn_library_ensure_mail_channel est arrivée en
--           prod ouverte à anon avec un REVOKE FROM PUBLIC en bonne et due
--           forme — cette ligne ne disait que PUBLIC. Rattrapée par le T10 de
--           tests/sql/grants_herites_tests.sql, corrigée par 20260830210000.
--       [ ] GRANT EXECUTE ... TO <rôle ciblé>
--           Une fonction RETURNS trigger n'en a besoin pour PERSONNE : le
--           privilège n'est vérifié qu'à la création du trigger, jamais au
--           déclenchement.
--       [ ] DO block de garde : has_function_privilege('anon', …) = false
--       [ ] Exception helpers RLS anon-lisibles : GRANT TO anon conservé
--
--   [ ] Si création de table dans public :
--       [ ] GRANT SELECT/INSERT/UPDATE/DELETE explicites (futur-proof 30/10/2026)
--       [ ] ALTER TABLE ... ENABLE ROW LEVEL SECURITY
--       [ ] Au moins une CREATE POLICY par opération autorisée
--       [ ] GRANT ALL TO service_role
--
--   [ ] Si création de vue :
--       [ ] WITH (security_invoker = true)
--       [ ] Exception SECURITY DEFINER : justification dans COMMENT + note dans docs/decisions
--
--   [ ] Si touche permissions / policies / search_path / extensions :
--       [ ] DO block de vérification automatique en fin de transaction
--       [ ] Tests parcours critiques en contexte anon ET authenticated simulés
--
-- =========================================================================
-- IMPORTANT : Ce fichier _TEMPLATE.sql est ignoré par Supabase CLI grâce
-- au underscore initial. Pour créer un vrai paquet, copier-renommer :
--   cd "C:\Users\accat\Claude's AnarBib\anarbib-app"
--   Copy-Item supabase\migrations\_TEMPLATE.sql `
--             supabase\migrations\<timestamp>_<nom_paquet>.sql
-- =========================================================================

BEGIN;

-- -------------------------------------------------------------------------
-- BLOC A — Création de fonction SECURITY DEFINER (à dupliquer si besoin)
-- -------------------------------------------------------------------------
-- Décommenter et adapter

/*
CREATE OR REPLACE FUNCTION public.fn_nom_de_fonction(
  p_arg1 type1,
  p_arg2 type2
)
RETURNS type_retour
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  -- variables locales
BEGIN
  -- corps de la fonction
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_nom_de_fonction(type1, type2) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.fn_nom_de_fonction(type1, type2) TO authenticated;

COMMENT ON FUNCTION public.fn_nom_de_fonction(type1, type2) IS
  'Description courte. Créé par paquet X.Y du JJ/MM/AAAA.';
*/

-- -------------------------------------------------------------------------
-- BLOC B — Création de table avec RLS (à dupliquer si besoin)
-- -------------------------------------------------------------------------
-- Choisir UN scénario A/B/C parmi les GRANT

/*
CREATE TABLE public.ma_nouvelle_table (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  library_id uuid REFERENCES public.libraries(id) ON DELETE CASCADE,
  -- colonnes métier
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ma_nouvelle_table_user_id_idx ON public.ma_nouvelle_table(user_id);
CREATE INDEX ma_nouvelle_table_library_id_idx ON public.ma_nouvelle_table(library_id);

-- GRANT explicites futur-proof (choisir UN scénario)

-- Scénario A : Catalogue public (lisible par anon)
-- GRANT SELECT ON public.ma_nouvelle_table TO anon;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON public.ma_nouvelle_table TO authenticated;

-- Scénario B : Table métier privée (authenticated uniquement)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON public.ma_nouvelle_table TO authenticated;

-- Scénario C : Table hors Data API (uniquement via RPC SECURITY DEFINER)
-- REVOKE ALL ON public.ma_nouvelle_table FROM anon, authenticated;

GRANT ALL ON public.ma_nouvelle_table TO service_role;

ALTER TABLE public.ma_nouvelle_table ENABLE ROW LEVEL SECURITY;

-- Dans une policy, TOUJOURS emballer auth.*() en (select auth.*()) : nu, il est
-- réévalué À CHAQUE LIGNE (advisor auth_rls_initplan) ; emballé, une fois par
-- requête. Neuf policies écrites entre le 03/07 et le 29/08 ont copié l'ancien
-- exemple nu de ce modèle — rejouées par 20260831171526. Sémantiquement neutre.
CREATE POLICY "ma_nouvelle_table_select_owner"
  ON public.ma_nouvelle_table
  FOR SELECT
  TO authenticated
  USING (user_id = (select auth.uid()));

-- Autres policies selon les besoins métier
-- CREATE POLICY ... FOR INSERT TO authenticated WITH CHECK (...);
-- CREATE POLICY ... FOR UPDATE TO authenticated USING (...) WITH CHECK (...);

CREATE TRIGGER ma_nouvelle_table_set_updated_at
  BEFORE UPDATE ON public.ma_nouvelle_table
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

COMMENT ON TABLE public.ma_nouvelle_table IS
  'Description courte. Créé par paquet X.Y du JJ/MM/AAAA.';
*/

-- -------------------------------------------------------------------------
-- BLOC C — Création de vue (à dupliquer si besoin)
-- -------------------------------------------------------------------------
-- Décommenter et adapter

/*
CREATE OR REPLACE VIEW public.v_ma_vue
WITH (security_invoker = true)
AS
  SELECT t.col1, t.col2
  FROM public.ma_table t
  WHERE -- conditions
  ;

GRANT SELECT ON public.v_ma_vue TO authenticated;
-- GRANT SELECT ON public.v_ma_vue TO anon;  -- décommenter si vue publique

COMMENT ON VIEW public.v_ma_vue IS
  'Description courte. security_invoker=true depuis sa création '
  '(paquet X.Y du JJ/MM/AAAA). Sources : public.ma_table.';
*/

-- -------------------------------------------------------------------------
-- BLOC D — Vérification automatique (recommandé pour migrations sensibles)
-- -------------------------------------------------------------------------
-- Décommenter si la migration touche aux permissions, policies, search_path
-- ou extensions. RAISE EXCEPTION déclenche un rollback automatique.

/*
DO $$
DECLARE
  v_count int;
BEGIN
  -- Test en contexte anon PostgREST-like
  SET LOCAL ROLE anon;
  SET LOCAL "request.jwt.claims" = '{}';

  SELECT count(*) INTO v_count FROM public.ma_table_critique;

  IF v_count < 1 THEN
    RAISE EXCEPTION 'Vérification échouée : ma_table_critique invisible en anon (% lignes). Rollback automatique.', v_count;
  END IF;

  RESET ROLE;

  -- Test en contexte authenticated simulé
  SET LOCAL ROLE authenticated;
  SET LOCAL "request.jwt.claims" = '{"sub":"00000000-0000-0000-0000-000000000000","role":"authenticated"}';

  -- ... autres tests authentifiés ...

  RESET ROLE;

  RAISE NOTICE 'Paquet [NOM_PAQUET] vérifications OK : % lignes', v_count;
END $$;
*/

COMMIT;

-- =========================================================================
-- Rollback ciblé en cas de régression post-déploiement (à adapter) :
-- =========================================================================
-- BEGIN;
--   -- DROP FUNCTION / DROP TABLE / DROP VIEW / etc.
-- COMMIT;
-- =========================================================================
