-- =========================================================================
-- Paquet fix — book_contributors manquant (livre 518, KROPOTKIN)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / coherence book_contributors <-> book_authors
-- Auteur   : Xavier + Claude
--
-- PROBLEME
-- --------
-- Le livre 518 ("Autour d'une Vie", KROPOTKIN, Piotr) avait une ligne
-- book_authors (author_id 5, role 'autor') mais AUCUNE ligne dans
-- book_contributors — la source de verite des contributeurs. Incoherence
-- relevee en corrigeant #CAT-LIST-AUTEURS-INCOMPLETE (migration
-- 20260605310000) : depuis que v_book_authors_canonical lit book_contributors,
-- ce livre n'a plus de chip structure (il reste affiche/cliquable via le
-- fallback frontend book.author_id, mais en mode degrade).
--
-- PORTEE — pourquoi pas un backfill general
-- -----------------------------------------
-- La migration 20260605230000_book_authors_sync_infra a DELIBEREMENT preserve
-- 94 liens legacy book_authors sans contributeur (« JAMAIS de rebuild », Q3).
-- On ne touche donc PAS a ces liens. Le critere retenu ci-dessous ne cible que
-- les livres ayant un auteur lie mais AUCUN book_contributors : au 2026-06-05
-- c'est le seul livre 518 (les 93 autres liens legacy sont sur des livres qui
-- ont deja des contributeurs, donc non concernes par l'affichage).
--
-- CORRECTIF
-- ---------
-- Inserer le contributeur manquant, derive de book_authors + authors
-- (name = sort_name canonique, position = ord, is_primary = (ord = 1)).
-- Idempotent : NOT EXISTS + ON CONFLICT (book_id, position) DO NOTHING.
-- Le trigger trg_sync_book_authors reinsere dans book_authors en
-- ON CONFLICT DO NOTHING : le lien existant est preserve, pas de doublon.
-- =========================================================================

BEGIN;

INSERT INTO public.book_contributors (book_id, author_id, position, name, role, is_primary)
SELECT ba.book_id,
       ba.author_id,
       ba.ord,
       COALESCE(NULLIF(btrim(a.sort_name), ''), NULLIF(btrim(a.preferred_name), '')),
       ba.role,
       (ba.ord = 1)
FROM public.book_authors ba
JOIN public.authors a ON a.id = ba.author_id
WHERE ba.role = 'autor'
  AND ba.author_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.book_contributors bc WHERE bc.book_id = ba.book_id
  )
ON CONFLICT (book_id, "position") DO NOTHING;

-- ---------------------------------------------------------------------------
-- Verification fail-fast : plus aucun livre avec auteur lie sans contributeur
-- ---------------------------------------------------------------------------
DO $verif$
DECLARE
  v_remaining int;
BEGIN
  SELECT count(*) INTO v_remaining
    FROM public.book_authors ba
   WHERE ba.role = 'autor'
     AND ba.author_id IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM public.book_contributors bc WHERE bc.book_id = ba.book_id
     );
  IF v_remaining > 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL : % livre(s) ont encore un auteur lie sans aucun book_contributors', v_remaining;
  END IF;

  RAISE NOTICE 'fix_book518 — plus aucun livre avec auteur lie sans book_contributors';
END
$verif$;

COMMIT;

-- =========================================================================
-- Apres COMMIT : REFRESH de la MV pour que le livre corrige expose ses chips.
-- =========================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- =========================================================================
-- Rollback (cible) :
--   DELETE FROM public.book_contributors
--    WHERE book_id = 518 AND author_id = 5 AND "position" = 1;
--   -- (la ligne book_authors preexistante n'est pas touchee)
--   REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
-- =========================================================================
