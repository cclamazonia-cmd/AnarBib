-- =========================================================================
-- Les citations et exports d'une fiche nomment un contributeur lié par la
-- forme inversée de son autorité (« Russell, Bertrand ») — CAT-G4 étendu.
-- =========================================================================
-- Date     : 2026-10-05
-- Chantier : OPAC — fiche d'ouvrage, citations (APA/Chicago/MLA, BibTeX, RIS)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Doublons SNI & forme autorisée des contributeurs
--
-- Demande de Xavier, 05/10/2026 : aligner les citations sur CAT-G4. La fiche
-- affiche depuis 20261004212710 la forme autorisée (authority_name =
-- preferred_name, forme directe), mais citeAuthorString (src/lib/citations.js)
-- citait toujours book_contributors.name, la transcription figée.
--
-- Une citation et un export bibliographique attendent le nom INVERSÉ (RIS :
-- « AU - Nom, Prénom » ; BibTeX : « Nom, Prénom » ; APA/Chicago : vedette
-- inversée) : c'est authors.sort_name, la forme de classement de l'autorité —
-- celle que la liste du catalogue affiche déjà (v_book_authors_canonical).
--
-- Mécanique : la RPC rend une colonne de plus, authority_sort_name (NULL si
-- non lié). name et authority_name INCHANGÉS. Changer le type de retour impose
-- DROP + CREATE ; droits reposés à l'identique (anon, authenticated —
-- tests/sql/grants_herites_tests.sql). DROP sans CASCADE.
-- =========================================================================

DROP FUNCTION IF EXISTS public.get_book_contributors_public(bigint);

CREATE FUNCTION public.get_book_contributors_public(p_book_id bigint)
RETURNS TABLE(
  "position"          integer,
  name                text,
  role                text,
  is_primary          boolean,
  author_id           bigint,
  authority_name      text,
  authority_sort_name text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT bc.position, bc.name, bc.role, bc.is_primary, bc.author_id,
         a.preferred_name AS authority_name,
         a.sort_name      AS authority_sort_name
  FROM public.book_contributors bc
  LEFT JOIN public.authors a ON a.id = bc.author_id
  WHERE bc.book_id = p_book_id
    -- uniquement pour un livre reellement publie (table books)
    AND EXISTS (SELECT 1 FROM public.books b WHERE b.id = bc.book_id)
  ORDER BY bc.position, bc.id;
$function$;

COMMENT ON FUNCTION public.get_book_contributors_public(bigint) IS
  'Liste complete des contributeurs d''un livre publie (lies + non lies) pour la fiche publique. '
  'name = transcription (editable au catalogage) ; authority_name = forme autorisee directe (affichage, CAT-G4) ; '
  'authority_sort_name = forme autorisee inversee (citations, exports). Paquet du 05/06/2026, authority_* des 04-05/10/2026.';

REVOKE EXECUTE ON FUNCTION public.get_book_contributors_public(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_book_contributors_public(bigint) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
