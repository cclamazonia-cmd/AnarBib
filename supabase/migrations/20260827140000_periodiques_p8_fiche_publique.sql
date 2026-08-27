-- =========================================================================
-- Paquet PÉRIODIQUES P8 — De la notice au titre : le chaînon public
-- =========================================================================
-- Date     : 2026-08-27
-- Chantier : périodiques (spec-periodiques v0.1, §11 paquet P8)
-- Auteur   : Xavier (arbitrages) + Claude (rédaction)
--
-- POURQUOI. La page publique d'un document lit api.catalog_book_detail_public_v2.
-- Cette vue ne porte NI serial_id, NI la désignation du fascicule : elle expose
-- `volume` mais pas `numero`, `fasciculo` ni `data_edicao`. Conséquence visible
-- aujourd'hui : la fiche publique d'un numéro de revue n'affiche pas son
-- numéro. Ce n'est pas une régression des périodiques, c'est un manque qui
-- préexiste — et qui devient bloquant dès qu'on veut relier le fascicule à sa
-- revue.
--
-- POURQUOI PAS ÉLARGIR LA VUE. catalog_book_detail_public_v2 est la surface
-- centrale de l'OPAC : agrégats d'exemplaires, bibliothèques détentrices,
-- auteurs en JSON. La réécrire entière pour cinq colonnes ferait porter à toutes
-- les fiches du catalogue le risque d'une régression qui ne concerne que les
-- périodiques. On ajoute donc une fonction dédiée, sur le modèle déjà en place
-- de api.book_other_editions(p_book_id) et api.audio_tracklist_public(p_book_id) :
-- la page appelle en plus, personne d'autre n'est exposé.
--
-- SECURITY INVOKER, comme tout le reste du chantier : si la revue est encore
-- `proposto`, la RLS de public.serials la masque et la fonction rend le
-- fascicule sans lien. Le staff, lui, voit le lien. Une seule règle, écrite une
-- seule fois, deux comportements corrects.
--
-- CHECKLIST DOCTRINE
--   [x] Lecture en SECURITY INVOKER (la RLS filtre)
--   [x] REVOKE PUBLIC + GRANT anon, authenticated
--   [x] DO block de vérification structurelle
-- =========================================================================

BEGIN;

CREATE OR REPLACE FUNCTION api.book_serial_v1(p_book_id bigint)
RETURNS TABLE (
  book_id          bigint,
  serial_id        bigint,
  serial_slug      text,
  serial_title     text,
  -- Forme TRANSCRITE sur le fascicule. Rendue à côté de la forme retenue et
  -- non à sa place : quand les deux diffèrent, c'est une information
  -- catalographique, et la page les montre toutes les deux.
  titulo_periodico text,
  volume           text,
  numero           text,
  fasciculo        text,
  data_edicao      text,
  ano              text,
  periodicidade    text
)
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $function$
  SELECT b.id, s.id, s.slug, s.uniform_title,
         b.titulo_periodico, b.volume, b.numero, b.fasciculo,
         b.data_edicao, b.ano, b.periodicidade
  FROM public.books b
  LEFT JOIN public.serials s ON s.id = b.serial_id
  WHERE b.id = p_book_id;
$function$;

REVOKE ALL ON FUNCTION api.book_serial_v1(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION api.book_serial_v1(bigint) TO anon, authenticated;

COMMENT ON FUNCTION api.book_serial_v1(bigint) IS
  'Titre de revue (forme d''autorité) et désignation du fascicule pour la fiche '
  'publique d''un document. Complète api.catalog_book_detail_public_v2, qui ne '
  'porte ni serial_id ni numero/fasciculo/data_edicao — plutôt que de réécrire '
  'cette vue centrale pour cinq colonnes. SECURITY INVOKER : une revue encore '
  'proposée est masquée par la RLS, le fascicule est alors rendu sans lien. '
  'Paquet PÉRIODIQUES P8 du 27/08/2026.';

-- -------------------------------------------------------------------------
-- Vérification structurelle
-- -------------------------------------------------------------------------
DO $verif$
BEGIN
  IF to_regprocedure('api.book_serial_v1(bigint)') IS NULL THEN
    RAISE EXCEPTION 'P8 : api.book_serial_v1 absente.';
  END IF;
  IF NOT has_function_privilege('anon', 'api.book_serial_v1(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'P8 : api.book_serial_v1 n''est pas lisible en anon — la fiche publique serait muette.';
  END IF;
  -- SECURITY INVOKER : prosecdef doit être faux. Une fonction DEFINER ici
  -- publierait le titre d'une revue encore proposée.
  IF (SELECT p.prosecdef FROM pg_proc p WHERE p.oid = 'api.book_serial_v1(bigint)'::regprocedure) THEN
    RAISE EXCEPTION 'P8 : api.book_serial_v1 est SECURITY DEFINER — elle contournerait la RLS de serials.';
  END IF;
  RAISE NOTICE 'Paquet PÉRIODIQUES P8 : vérification structurelle OK (fonction, grants, security invoker).';
END $verif$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =========================================================================
-- Rollback ciblé :
--   BEGIN; DROP FUNCTION IF EXISTS api.book_serial_v1(bigint); COMMIT;
-- =========================================================================
