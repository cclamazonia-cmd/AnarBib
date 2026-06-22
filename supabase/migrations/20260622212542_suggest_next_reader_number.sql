-- =========================================================================
-- Suggestion du prochain numéro de lecteur·rice local (à la validation)
-- =========================================================================
-- Date     : 2026-06-22
-- Chantier : validation des inscriptions (BLMF) — confort staff
-- Auteur   : Claude (livré en fichier, appliqué par Forgejo / supabase db push)
--
-- Contexte : à la validation présentielle (TabValidacoes), le champ « Nº de
-- leitora local » ne suggérait rien alors que la biblio numérote ses lecteur·ices
-- en séquence (BLMF-0001..0005). L'helper existant get_last_assigned_reader_identity
-- ne gère QUE les numéros purement numériques (^[0-9]+$) et exige coordenador —
-- il renvoie NULL pour un schéma préfixé comme « BLMF-0005 ».
--
-- On ajoute une RPC dédiée qui : parse « préfixe + suffixe numérique » du dernier
-- numéro vivant, incrémente le suffixe en CONSERVANT le padding (BLMF-0005 →
-- BLMF-0006 ; 42 → 43), et est accessible aux librarian+ (même garde que
-- list_pending_validations / validate_membership). Lecture seule. Renvoie NULL
-- si aucun numéro à incrémenter (modèle 'name', ou biblio sans numéro).
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.suggest_next_reader_number(p_library_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_last   text;
  v_prefix text;
  v_num    text;
  v_width  int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.';
  END IF;

  -- Staff actif (librarian/coordenador) de la biblio — même garde que
  -- api.list_pending_validations / api.validate_membership.
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships s
    WHERE s.user_id = auth.uid()
      AND s.library_id = p_library_id
      AND s.role IN ('librarian', 'coordenador')
      AND s.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Acesso de equipe obrigatório nesta biblioteca.'
      USING ERRCODE = 'P0001', HINT = 'error.staff_required';
  END IF;

  -- Dernier numéro vivant doté d'un suffixe numérique, choisi par la plus grande
  -- valeur de ce suffixe (gère les schémas préfixés 'BLMF-0005' ET purs '42').
  SELECT m.local_reader_number
    INTO v_last
    FROM public.user_library_memberships m
   WHERE m.library_id = p_library_id
     AND coalesce(m.status, '') NOT IN ('removed', 'terminated')
     AND m.local_reader_number ~ '[0-9]+\s*$'
   ORDER BY (regexp_replace(m.local_reader_number, '^.*?([0-9]+)\s*$', '\1'))::bigint DESC
   LIMIT 1;

  IF v_last IS NULL THEN
    RETURN NULL;
  END IF;

  v_prefix := regexp_replace(v_last, '([0-9]+)\s*$', '');           -- 'BLMF-'
  v_num    := regexp_replace(v_last, '^.*?([0-9]+)\s*$', '\1');     -- '0005'
  v_width  := length(v_num);                                       -- 4

  RETURN v_prefix || lpad((v_num::bigint + 1)::text, v_width, '0'); -- 'BLMF-0006'
END;
$function$;

REVOKE EXECUTE ON FUNCTION api.suggest_next_reader_number(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.suggest_next_reader_number(uuid) TO authenticated;

COMMENT ON FUNCTION api.suggest_next_reader_number(uuid) IS
  'Suggère le prochain numéro de lecteur·rice local (préfixe + suffixe numérique incrémenté, padding conservé). Staff librarian+. NULL si rien à incrémenter. Suite 4, 22/06/2026.';

-- PostgREST : exposer la nouvelle RPC sans attendre le reload périodique.
NOTIFY pgrst, 'reload schema';

-- -------------------------------------------------------------------------
-- Vérification : la fonction existe et est exécutable par authenticated.
-- -------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'api' AND p.proname = 'suggest_next_reader_number'
  ) THEN
    RAISE EXCEPTION 'Vérification échouée : api.suggest_next_reader_number absente. Rollback.';
  END IF;
  RAISE NOTICE 'api.suggest_next_reader_number en place. OK.';
END $$;

COMMIT;

-- =========================================================================
-- Rollback ciblé :
-- =========================================================================
-- BEGIN;
--   DROP FUNCTION IF EXISTS api.suggest_next_reader_number(uuid);
--   NOTIFY pgrst, 'reload schema';
-- COMMIT;
-- =========================================================================
