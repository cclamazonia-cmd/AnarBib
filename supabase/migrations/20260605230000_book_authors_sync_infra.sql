-- =========================================================================
-- Paquet liaison autorites P1 — synchro book_contributors -> book_authors
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Liaison autorites<->oeuvres (spec-liaison-autorites-oeuvres v0.2)
-- Auteur   : Xavier + Claude
--
-- OBJET
-- -----
-- 1. fn_normalize_name(text) : normalisation de nom (minuscules, accents
--    replies, tokens tries) pour le matching. IMMUTABLE (indexable).
-- 2. Trigger CIBLE sur book_contributors : maintient book_authors quand
--    author_id est pose/modifie/supprime. JAMAIS de rebuild (94 liens legacy
--    book_authors sans contributeur a preserver — Q3).
-- 3. Backfill unique : 371 contributeurs lies (author_id non NULL) sans ligne
--    book_authors -> creation des liens manquants (verifie : 0 risque doublon).
--
-- DOCTRINE : trigger SECURITY DEFINER (ecrit book_authors quelle que soit la
-- source) + SET search_path + REVOKE EXECUTE FROM PUBLIC.
-- =========================================================================

BEGIN;

-- 1. Normalisation de nom (ordre-insensible : tokens tries) ---------------
CREATE OR REPLACE FUNCTION public.fn_normalize_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $function$
  SELECT coalesce(
    array_to_string(
      array(
        SELECT tok
        FROM unnest(
          regexp_split_to_array(
            translate(
              replace(replace(lower(coalesce(p_name, '')), 'œ', 'oe'), 'æ', 'ae'),
              'àáâãäåçèéêëìíîïñòóôõöøùúûüýÿ',
              'aaaaaaceeeeiiiinoooooouuuuyy'
            ),
            '[^a-z0-9]+'
          )
        ) AS tok
        WHERE tok <> ''
        ORDER BY tok
      ),
      ' '
    ),
    ''
  );
$function$;

COMMENT ON FUNCTION public.fn_normalize_name(text) IS
  'Normalise un nom (minuscules, accents replies, tokens alphanum tries) pour matching d''autorite. Paquet liaison autorites du 05/06/2026.';

-- 2. Trigger de synchro ciblee -------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_sync_book_authors_from_contributor()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
BEGIN
  -- Retrait du lien associe a l'ancienne valeur (UPDATE author_id change / DELETE)
  IF (TG_OP = 'DELETE')
     OR (TG_OP = 'UPDATE' AND OLD.author_id IS NOT NULL
         AND OLD.author_id IS DISTINCT FROM NEW.author_id) THEN
    IF OLD.author_id IS NOT NULL THEN
      -- Ne supprimer que si aucun AUTRE contributeur ne porte le meme lien.
      IF NOT EXISTS (
        SELECT 1 FROM public.book_contributors c
        WHERE c.book_id = OLD.book_id AND c.author_id = OLD.author_id
          AND c.role = OLD.role AND c.position = OLD.position
          AND c.id <> OLD.id
      ) THEN
        DELETE FROM public.book_authors ba
        WHERE ba.book_id = OLD.book_id AND ba.author_id = OLD.author_id
          AND ba.role = OLD.role AND ba.ord = OLD.position;
      END IF;
    END IF;
  END IF;

  -- Ajout du lien pour la nouvelle valeur (INSERT / UPDATE)
  IF (TG_OP IN ('INSERT', 'UPDATE')) AND NEW.author_id IS NOT NULL THEN
    INSERT INTO public.book_authors (book_id, author_id, role, ord)
    VALUES (NEW.book_id, NEW.author_id, NEW.role, NEW.position::smallint)
    ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;
  END IF;

  RETURN NULL; -- AFTER trigger
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.fn_sync_book_authors_from_contributor() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_sync_book_authors ON public.book_contributors;
CREATE TRIGGER trg_sync_book_authors
  AFTER INSERT OR UPDATE OF author_id, role, position OR DELETE
  ON public.book_contributors
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_sync_book_authors_from_contributor();

COMMENT ON FUNCTION public.fn_sync_book_authors_from_contributor() IS
  'Maintient book_authors a partir de book_contributors.author_id (cible, pas de rebuild). Paquet liaison autorites du 05/06/2026.';

-- 3. Backfill unique des 371 liens manquants ------------------------------
INSERT INTO public.book_authors (book_id, author_id, role, ord)
SELECT bc.book_id, bc.author_id, bc.role, bc.position::smallint
FROM public.book_contributors bc
WHERE bc.author_id IS NOT NULL
ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback cible :
--   DROP TRIGGER IF EXISTS trg_sync_book_authors ON public.book_contributors;
--   DROP FUNCTION IF EXISTS public.fn_sync_book_authors_from_contributor();
--   DROP FUNCTION IF EXISTS public.fn_normalize_name(text);
--   -- (le backfill des liens n'est pas annule automatiquement)
-- =========================================================================
