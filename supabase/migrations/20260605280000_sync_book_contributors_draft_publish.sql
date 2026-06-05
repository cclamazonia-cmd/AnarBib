-- =========================================================================
-- Paquet fix — contributeurs : reprise (seed) + publication (sync)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / contributeurs (trou architectural brouillon<->publie)
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- L'editeur de contributeurs du catalogage ecrit dans book_draft_contributors
-- (table brouillon), mais publish_book_draft ne propage RIEN vers
-- book_contributors (publie). De plus create_book_draft_from_book ne copie pas
-- les contributeurs dans le brouillon. Resultat : editer un contributeur puis
-- publier ne change rien au livre publie (ni a la fiche). Impossible de
-- corriger une coquille de nom (ex. "Hernadez" -> "Hernandez").
--
-- CORRECTIF (2 triggers isoles, sans recreer les grosses fonctions)
--   T1. AFTER INSERT book_drafts (published_book_id non null) : seed
--       book_draft_contributors depuis book_contributors du livre repris.
--   T2. AFTER UPDATE OF status book_drafts (transition -> published) : sync
--       book_contributors depuis book_draft_contributors, en PRESERVANT les
--       author_id par nom normalise (map jsonb). Garde : si le brouillon n'a
--       aucun contributeur, on ne touche pas (evite tout effacement). Le
--       trigger book_contributors->book_authors propage ensuite les liens.
--
-- DOCTRINE : trigger SECURITY DEFINER + search_path + REVOKE EXECUTE FROM PUBLIC.
-- =========================================================================

BEGIN;

-- T1 : seed des contributeurs a la reprise -------------------------------
CREATE OR REPLACE FUNCTION public.fn_seed_draft_contributors()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  IF NEW.published_book_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.book_draft_contributors dc WHERE dc.draft_id = NEW.id) THEN
    INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary)
    SELECT NEW.id, bc.position, bc.name, bc.role, bc.is_primary
    FROM public.book_contributors bc
    WHERE bc.book_id = NEW.published_book_id
    ORDER BY bc.position, bc.id;
  END IF;
  RETURN NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_seed_draft_contributors() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_seed_draft_contributors ON public.book_drafts;
CREATE TRIGGER trg_seed_draft_contributors
  AFTER INSERT ON public.book_drafts
  FOR EACH ROW
  WHEN (NEW.published_book_id IS NOT NULL)
  EXECUTE FUNCTION public.fn_seed_draft_contributors();

-- T2 : sync des contributeurs a la publication ---------------------------
CREATE OR REPLACE FUNCTION public.fn_sync_book_contributors_on_publish()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
DECLARE
  v_prior jsonb;
BEGIN
  -- Garde : besoin d'un livre publie et d'au moins un contributeur de brouillon.
  IF NEW.published_book_id IS NULL
     OR NOT EXISTS (SELECT 1 FROM public.book_draft_contributors dc WHERE dc.draft_id = NEW.id) THEN
    RETURN NULL;
  END IF;

  -- Capturer les author_id existants (par nom normalise) AVANT remplacement.
  SELECT jsonb_object_agg(nf, author_id) INTO v_prior
  FROM (
    SELECT public.fn_normalize_name(name) AS nf, max(author_id) AS author_id
    FROM public.book_contributors
    WHERE book_id = NEW.published_book_id AND author_id IS NOT NULL
    GROUP BY public.fn_normalize_name(name)
  ) s;

  -- Remplacer les contributeurs publies par ceux du brouillon, en preservant
  -- author_id par correspondance de nom normalise (le trigger book_authors suit).
  DELETE FROM public.book_contributors WHERE book_id = NEW.published_book_id;

  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id)
  SELECT NEW.published_book_id, dc.position, dc.name, dc.role, dc.is_primary,
         NULLIF(v_prior ->> public.fn_normalize_name(dc.name), '')::bigint
  FROM public.book_draft_contributors dc
  WHERE dc.draft_id = NEW.id
  ORDER BY dc.position, dc.id;

  RETURN NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_sync_book_contributors_on_publish() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_sync_book_contributors_on_publish ON public.book_drafts;
CREATE TRIGGER trg_sync_book_contributors_on_publish
  AFTER UPDATE OF status ON public.book_drafts
  FOR EACH ROW
  WHEN (NEW.status = 'published' AND NEW.status IS DISTINCT FROM OLD.status)
  EXECUTE FUNCTION public.fn_sync_book_contributors_on_publish();

COMMENT ON FUNCTION public.fn_seed_draft_contributors() IS
  'Seed book_draft_contributors a la reprise d''un livre publie. Paquet du 05/06/2026.';
COMMENT ON FUNCTION public.fn_sync_book_contributors_on_publish() IS
  'Sync book_contributors depuis le brouillon a la publication (preserve author_id). Paquet du 05/06/2026.';

COMMIT;

-- =========================================================================
-- Rollback :
--   DROP TRIGGER IF EXISTS trg_seed_draft_contributors ON public.book_drafts;
--   DROP TRIGGER IF EXISTS trg_sync_book_contributors_on_publish ON public.book_drafts;
--   DROP FUNCTION IF EXISTS public.fn_seed_draft_contributors();
--   DROP FUNCTION IF EXISTS public.fn_sync_book_contributors_on_publish();
-- =========================================================================
