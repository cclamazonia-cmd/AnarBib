-- =========================================================================
-- Paquet fix — get_book_contributors_public (fiche livre : tous les contributeurs)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / affichage fiche livre (#FICHE-AUTEURS-INCOMPLETE)
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- La fiche livre publique (BookPage) affiche les auteurs depuis author_chips/
-- authors_json, construits a partir de book_authors (autorites LIEES seulement).
-- Les contributeurs sans autorite (book_contributors.author_id IS NULL)
-- disparaissent. Ex. "Maio de 68" : 4 contributeurs en notice, 2 sur la fiche.
-- Or book_contributors n'est lisible que par le staff (RLS librarian, pas anon)
-- -> impossible de le lire cote frontend public.
--
-- CORRECTIF
-- ---------
-- RPC publique SECURITY DEFINER exposant la liste COMPLETE des contributeurs
-- d'un livre publie (les contributeurs sont deja une info publique : le champ
-- texte books.autor les montre). Le frontend rend chaque contributeur en lien
-- /autor/:id si author_id present, en texte sinon.
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION public.get_book_contributors_public(p_book_id bigint)
RETURNS TABLE (
  position    integer,
  name        text,
  role        text,
  is_primary  boolean,
  author_id   bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $function$
  SELECT bc.position, bc.name, bc.role, bc.is_primary, bc.author_id
  FROM public.book_contributors bc
  WHERE bc.book_id = p_book_id
    -- uniquement pour un livre reellement publie (table books)
    AND EXISTS (SELECT 1 FROM public.books b WHERE b.id = bc.book_id)
  ORDER BY bc.position, bc.id;
$function$;

REVOKE EXECUTE ON FUNCTION public.get_book_contributors_public(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_book_contributors_public(bigint) TO anon, authenticated;

COMMENT ON FUNCTION public.get_book_contributors_public(bigint) IS
  'Liste complete des contributeurs d''un livre publie (lies + non lies) pour la fiche publique. Paquet du 05/06/2026.';

NOTIFY pgrst, 'reload schema';

COMMIT;

-- =========================================================================
-- Rollback : DROP FUNCTION IF EXISTS public.get_book_contributors_public(bigint);
-- =========================================================================
