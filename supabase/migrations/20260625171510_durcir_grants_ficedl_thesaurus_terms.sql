-- =========================================================================
-- Thésaurus FICEDL — durcissement des privilèges (anon/authenticated = SELECT)
-- =========================================================================
-- Date     : 2026-06-25
-- Chantier : Intégration thésaurus FICEDL comme vocabulaire-sujets (anti-fork)
-- Auteur   : AnarBib
-- Session  : Intégration thésaurus FICEDL P1 (table-cache + seed)
--
-- POURQUOI
--   À la création de public.ficedl_thesaurus_terms (migration 20260625163727),
--   les *default privileges* Supabase ont accordé d'office le CRUD complet
--   (+ TRUNCATE/REFERENCES/TRIGGER) à anon ET authenticated, alors que la migration
--   ne déclarait qu'un GRANT SELECT. La RLS (policy SELECT seule) bloque déjà les
--   écritures via l'API, et TRUNCATE n'est pas exposé par PostgREST — mais on rend
--   ici la posture EXPLICITE et futur-proof (suppression des default privileges
--   Supabase annoncée au 30/10/2026) : anon/authenticated en LECTURE SEULE.
--
--   ANTI-FORK : seul service_role (script de sync) écrit le vocabulaire partagé.
--   service_role et postgres conservent ALL (non touchés par les REVOKE ci-dessous).
-- =========================================================================

BEGIN;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.ficedl_thesaurus_terms FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON public.ficedl_thesaurus_terms FROM authenticated;

-- Réaffirme la lecture (idempotent ; SELECT était déjà accordé).
GRANT SELECT ON public.ficedl_thesaurus_terms TO anon;
GRANT SELECT ON public.ficedl_thesaurus_terms TO authenticated;

-- -------------------------------------------------------------------------
-- Vérification : anon et authenticated ne doivent garder QUE SELECT.
-- -------------------------------------------------------------------------
DO $$
DECLARE
  v_extra text;
BEGIN
  SELECT string_agg(grantee || ':' || privilege_type, ', ')
    INTO v_extra
  FROM information_schema.role_table_grants
  WHERE table_schema = 'public'
    AND table_name = 'ficedl_thesaurus_terms'
    AND grantee IN ('anon', 'authenticated')
    AND privilege_type <> 'SELECT';

  IF v_extra IS NOT NULL THEN
    RAISE EXCEPTION 'Durcissement échoué : privilèges résiduels (% ). Rollback automatique.', v_extra;
  END IF;

  RAISE NOTICE 'ficedl_thesaurus_terms : anon/authenticated en lecture seule (SELECT).';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé (à adapter) :
-- =========================================================================
-- BEGIN;
--   GRANT INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
--     ON public.ficedl_thesaurus_terms TO anon, authenticated;
-- COMMIT;
-- =========================================================================
