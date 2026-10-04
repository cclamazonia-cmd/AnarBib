-- =========================================================================
-- La fiche d'ouvrage nomme un contributeur lié par la forme autorisée de son
-- autorité ; la transcription reste la donnée de la mention de responsabilité.
-- =========================================================================
-- Date     : 2026-10-04
-- Chantier : OPAC — fiche d'ouvrage (/livro/:id)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Doublons SNI & forme autorisée des contributeurs
--
-- Constat de Xavier, 04/10/2026, à l'écran (/livro/2736) : l'autorité 11555
-- vient d'être corrigée (« Serviço Nacional de Informações »), la fiche montre
-- toujours « Serviço Nacional d Informações – SNI ». La RPC rendait
-- book_contributors.name — la transcription figée au rattachement — et jamais
-- authors.preferred_name : corriger une autorité ne changeait aucune fiche.
--
-- Doctrine (ISBD / RDA / MARC, REGISTRE CAT-G4) : deux choses distinctes.
--   * La mention de responsabilité se transcrit telle qu'imprimée
--     (books.autor, vue ISBD) et ne suit pas les autorités.
--   * Les points d'accès — les liens auteur·rice — portent la forme autorisée
--     de la notice d'autorité : on la corrige une fois, toutes les fiches
--     suivent. Un contributeur non lié n'a pas de forme autorisée : son nom
--     transcrit reste affiché (CONV-8 inchangé).
--
-- Mécanique : la RPC rend une colonne de plus, authority_name
-- (authors.preferred_name, NULL si non lié). La colonne name est INCHANGÉE :
-- BookDraftForm (reprise d'un livre publié) la charge comme ligne éditable et
-- l'écrirait dans book_draft_contributors.name — la remplacer par la forme
-- autorisée effacerait la transcription au prochain enregistrement.
--
-- Changer le type de retour impose DROP + CREATE (pas de CREATE OR REPLACE) ;
-- les droits sont reposés à l'identique — anon et authenticated, attendus par
-- tests/sql/grants_herites_tests.sql (une fonction naît fermée à anon depuis
-- B2 lot 3). DROP sans CASCADE : aucune dépendance attendue, échouer sinon.
-- =========================================================================

DROP FUNCTION IF EXISTS public.get_book_contributors_public(bigint);

CREATE FUNCTION public.get_book_contributors_public(p_book_id bigint)
RETURNS TABLE(
  "position"     integer,
  name           text,
  role           text,
  is_primary     boolean,
  author_id      bigint,
  authority_name text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog'
AS $function$
  SELECT bc.position, bc.name, bc.role, bc.is_primary, bc.author_id,
         a.preferred_name AS authority_name
  FROM public.book_contributors bc
  LEFT JOIN public.authors a ON a.id = bc.author_id
  WHERE bc.book_id = p_book_id
    -- uniquement pour un livre reellement publie (table books)
    AND EXISTS (SELECT 1 FROM public.books b WHERE b.id = bc.book_id)
  ORDER BY bc.position, bc.id;
$function$;

COMMENT ON FUNCTION public.get_book_contributors_public(bigint) IS
  'Liste complete des contributeurs d''un livre publie (lies + non lies) pour la fiche publique. '
  'name = transcription (editable au catalogage) ; authority_name = forme autorisee de l''autorite liee, '
  'a afficher en point d''acces (CAT-G4). Paquet du 05/06/2026, authority_name du 04/10/2026.';

REVOKE EXECUTE ON FUNCTION public.get_book_contributors_public(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_book_contributors_public(bigint) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';
