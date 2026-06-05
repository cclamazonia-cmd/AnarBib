-- =========================================================================
-- Paquet fix — backfill book_contributors pour les livres legacy SANS contributeur
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / coherence contributeurs (#CAT-AUTOR-LEGACY-SANS-CONTRIB)
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- book_contributors est la SOURCE DE VERITE des contributeurs ; book_authors
-- n'en est qu'un derive, maintenu en sens unique (book_contributors ->
-- book_authors) par le trigger trg_sync_book_authors / fn_sync_book_authors_
-- from_contributor (cf. 20260605230000). Ce trigger ne fait JAMAIS de rebuild :
-- il preserve volontairement les liens legacy book_authors crees AVANT
-- l'existence de book_contributors.
--
-- Depuis 20260605310000, v_book_authors_canonical (et la MV catalogue) part de
-- book_contributors et non plus de book_authors, en filtrant role='autor'. Un
-- livre qui a un lien d'autorite UNIQUEMENT dans book_authors (aucune ligne
-- book_contributors) perd donc l'affichage de son auteur dans le catalogue liste
-- (le frontend retombe sur le texte books.autor, d'ou l'absence d'urgence).
--
-- PERIMETRE — verifie en lecture le 2026-06-05 (MCP) :
--   * Liens book_authors role='autor' lies a une autorite, sans contributeur
--     correspondant (ni author_id, ni nom normalise) : 75 liens / 74 livres.
--   * Parmi ces livres, UN SEUL n'a AUCUN book_contributors : book_id 518
--     (« Autour d'une Vie », KROPOTKIN, author_id 5). C'est le seul vrai
--     « contributeur manquant », et le seul corrige ici.
--   * Les 73 autres livres ONT deja des contributeurs ; leur lien book_authors
--     est ERRONE et VOLONTAIREMENT EXCLU du backfill, car l'inserer
--     creerait un doublon ou un faux auteur. Categories observees :
--       - autorite fantome  : book_authors -> "[AUTOR SEM FICHA #NNNNN]" alors
--         que l'auteur reel est deja la, lie a une autre fiche (ex. book 2) ;
--       - lien faux         : book_authors pointe un auteur sans rapport avec
--         le livre (ex. book 116 RECLUS/LEUENROTH vs Porcel/Proudhon) ;
--       - variante d'ecriture: meme personne sous une autre translitteration,
--         deja presente (ex. book 119 "BAKUNIN, Mikhail" vs "Bakunin, Mijail").
--     -> Ces 73 liens relevent d'un nettoyage d'autorites a part (revue humaine),
--        pas d'un backfill automatique.
--
-- CORRECTIF
-- ---------
-- Backfill IDEMPOTENT et ETROIT : pour chaque lien book_authors role='autor'
-- lie a une autorite nommee dont le livre n'a AUCUN book_contributors, creer la
-- ligne contributeur a partir de :
--   * name       = COALESCE(authors.sort_name, authors.preferred_name)
--                  (meme source/format que v_book_authors_canonical)
--   * role       = book_authors.role  ('autor')
--   * author_id  = book_authors.author_id
--   * position   = book_authors.ord
--   * is_primary = (ord = 1)
--
-- Note trigger : l'INSERT dans book_contributors declenche trg_sync_book_authors,
-- qui re-tente l'INSERT du lien book_authors deja present -> ON CONFLICT DO
-- NOTHING -> no-op. Aucun effet de bord.
-- =========================================================================

BEGIN;

-- 1. Backfill des contributeurs des livres SANS aucun contributeur --------
WITH inserted AS (
  INSERT INTO public.book_contributors (book_id, position, name, role, is_primary, author_id)
  SELECT ba.book_id,
         ba.ord::integer,
         COALESCE(NULLIF(btrim(a.sort_name), ''), NULLIF(btrim(a.preferred_name), '')) AS name,
         ba.role,
         (ba.ord = 1) AS is_primary,
         ba.author_id
  FROM public.book_authors ba
  JOIN public.authors a ON a.id = ba.author_id
  WHERE ba.role = 'autor'::text
    AND COALESCE(NULLIF(btrim(a.sort_name), ''), NULLIF(btrim(a.preferred_name), '')) IS NOT NULL
    -- Garde stricte : uniquement les livres qui n'ont AUCUN contributeur.
    AND NOT EXISTS (
      SELECT 1 FROM public.book_contributors bc WHERE bc.book_id = ba.book_id
    )
  RETURNING book_id
)
SELECT count(*) AS n FROM inserted;

-- 2. Verification fail-fast ----------------------------------------------
DO $verif$
DECLARE
  v_count     int;
  v_518_ok    int;
  v_remaining int;
BEGIN
  -- a. plus aucun livre « lien autor mais zero contributeur » ne subsiste
  SELECT count(DISTINCT ba.book_id) INTO v_remaining
  FROM public.book_authors ba
  JOIN public.authors a ON a.id = ba.author_id
  WHERE ba.role = 'autor'::text
    AND COALESCE(NULLIF(btrim(a.sort_name), ''), NULLIF(btrim(a.preferred_name), '')) IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.book_contributors bc WHERE bc.book_id = ba.book_id
    );
  IF v_remaining <> 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : % livre(s) ont encore un lien autor sans aucun book_contributors', v_remaining;
  END IF;

  -- b. cas pilote : book 518 a desormais un contributeur lie a author_id 5
  SELECT count(*) INTO v_518_ok
  FROM public.book_contributors
  WHERE book_id = 518 AND author_id = 5 AND role = 'autor'::text;
  IF v_518_ok < 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : book 518 n''a toujours pas de book_contributors lie a author_id 5';
  END IF;

  -- c. la vue canonique restitue maintenant un author_display pour book 518
  SELECT count(*) INTO v_count
  FROM public.v_book_authors_canonical
  WHERE book_id = 518 AND author_display IS NOT NULL;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_c : v_book_authors_canonical ne restitue pas book 518 (%/1)', v_count;
  END IF;

  RAISE NOTICE 'backfill_book_contributors_from_legacy_book_authors OK — 0 livre sans contributeur restant, book 518 restitue';
END
$verif$;

COMMIT;

-- =========================================================================
-- Apres COMMIT : REFRESH pour propager le nouveau contributeur a la MV
-- catalogue (mv_books_catalog_list_network_v1 joint v_book_authors_canonical).
-- REFRESH NON concurrent (un REFRESH CONCURRENTLY ne peut pas tourner dans un
-- bloc transactionnel, et la CLI Supabase enveloppe la migration) — aligne sur
-- 20260605310000 et paquetC5 (20260519200000).
-- =========================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- =========================================================================
-- Rollback (manuel, cible) : supprimer le contributeur backfille de book 518.
--   DELETE FROM public.book_contributors
--    WHERE book_id = 518 AND author_id = 5 AND role = 'autor';
--   REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
-- (Le DELETE declenche trg_sync_book_authors qui retire AUSSI le lien
--  book_authors correspondant ; le re-creer pour restaurer l'etat legacy :
--   INSERT INTO public.book_authors (book_id, author_id, role, ord)
--   VALUES (518, 5, 'autor', 1) ON CONFLICT DO NOTHING; )
-- =========================================================================
