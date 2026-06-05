-- =========================================================================
-- Paquet Ateliers autorités — RPC de revue des notes bio multilingues
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorités / notes bio multilingues (spec-autorites-notes-bio-
--            multilingues v0.2, Q4 : workflow de revue dès la v1)
-- Auteur   : AnarBib (assisté)
--
-- HORODATAGE : l'horloge UTC réelle (~20:12) est INFÉRIEURE au max du dossier
--   (20260605350000, horodatages fabriqués HH>24). Conformément à la règle dure
--   CLAUDE.md (heure réelle ≤ max → max + 1 seconde), ce fichier prend
--   20260605350001 pour rester strictement après les migrations existantes.
--
-- OBJET (Q4 ✅, §3.1 option (b) recommandée)
-- ------------------------------------------
--   RPC set_author_translation_review : bascule une traduction bio entre
--   'draft' et 'reviewed' (pose/efface reviewed_by/reviewed_at). Réservée au
--   staff (librarian/coordenador, Q3). L'écriture/édition de la bio elle-même
--   reste sur le chemin upsert RLS existant (pose status='draft').
--
-- DOCTRINE : SECURITY DEFINER + SET search_path + REVOKE EXECUTE FROM PUBLIC +
--   GRANT authenticated + gating staff interne. Pas d'appel d'extension →
--   search_path = public, pg_catalog suffit.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.set_author_translation_review(
  p_author_id bigint,
  p_lang      text,
  p_reviewed  boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_found boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = auth.uid()
      AND m.role = ANY (ARRAY['librarian'::text, 'coordenador'::text])
  ) THEN
    RAISE EXCEPTION 'Acesso restrito ao staff de catalogacao.';
  END IF;

  IF p_reviewed THEN
    UPDATE public.author_translations
    SET status = 'reviewed', reviewed_by = auth.uid(), reviewed_at = now(), updated_at = now()
    WHERE author_id = p_author_id AND lang = p_lang;
  ELSE
    UPDATE public.author_translations
    SET status = 'draft', reviewed_by = NULL, reviewed_at = NULL, updated_at = now()
    WHERE author_id = p_author_id AND lang = p_lang;
  END IF;

  GET DIAGNOSTICS v_found = ROW_COUNT;
  RETURN v_found > 0;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.set_author_translation_review(bigint, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_author_translation_review(bigint, text, boolean) TO authenticated;

COMMENT ON FUNCTION public.set_author_translation_review(bigint, text, boolean) IS
  'Bascule une traduction bio entre draft/reviewed (pose reviewed_by/at). Staff seulement. Ateliers autorites notes bio, 05/06/2026.';

-- -------------------------------------------------------------------------
-- Vérification automatique
-- -------------------------------------------------------------------------
DO $verif$
BEGIN
  IF NOT has_function_privilege('authenticated', 'public.set_author_translation_review(bigint, text, boolean)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_1 : authenticated sans EXECUTE sur set_author_translation_review';
  END IF;
  IF has_function_privilege('public', 'public.set_author_translation_review(bigint, text, boolean)'::regprocedure, 'EXECUTE') THEN
    RAISE EXCEPTION 'VERIF_FAIL_2 : PUBLIC a EXECUTE sur set_author_translation_review (doit etre REVOKE)';
  END IF;
END
$verif$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback :
--   DROP FUNCTION IF EXISTS public.set_author_translation_review(bigint, text, boolean);
-- =========================================================================
