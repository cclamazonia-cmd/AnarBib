-- =========================================================================
-- Paquet fix — fusion autorite Kropotkine (10091 -> 5) + dedup contributeurs
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / fusion + dedup (suite du nettoyage 20260605350000)
-- Auteur   : Xavier + Claude
--
-- CONTEXTE (inventaire lecture MCP, 2026-06-05)
-- --------------------------------------------
-- Deux fiches authors pour Kropotkine :
--   * #5     "KROPOTKIN, Piotr" (1842-1921) — canonique : 66 contrib, 72
--            book_authors, 2 traductions, 25 alias (dont deja "Kropotkine, P.").
--   * #10091 "Kropotkine, P." (vide) — doublon : 3 contrib (books 649/731/1006),
--            3 book_authors, 0 traduction, 1 alias ("Kropotkine, P." deja sur #5).
--
-- Doublons de contributeurs DANS un meme livre (catalogue entier = 3 cas ; le
-- texte books.autor duplique lui-meme l'auteur) :
--   * book 1176 : "Kropotkin, Pedro" (id 3779, pos1) + "Kropotkin, Piotr"
--                 (id 3780, pos2), tous deux lies #5.
--   * book 1924 : "Kropotkin, Petr Alekseevic" (id 4662, pos1) + "Kropotkin,
--                 Piotr Alekseevich" (id 4663, pos2), tous deux author_id NULL.
--   * book 1794 : "Makhno, Nestor" (id 4501, pos1) + "Makhno, Nestor" (id 4503,
--                 pos3), tous deux lies #10029.
-- Contributeur Kropotkine non lie : book 1207, "KROPOTKIN, Piotr" (id 5335).
--
-- CE QUE FAIT CETTE MIGRATION (replique la logique de la RPC merge_author, SANS
-- sa garde staff auth.uid() — inapplicable en migration — et sans merge_log) :
--   1. Dedup : supprime les contributeurs en double 3780, 4663, 4503.
--      (le trigger trg_sync_book_authors retire le book_authors derive associe).
--   2. Nettoie le lien book_authors legacy ORPHELIN restant du book 1924
--      (1924,5,ord2 : son contributeur pos2 vient d'etre supprime, et les liens
--       1924 n'etaient pas adosses a un contributeur).
--   3. Fusion #10091 -> #5 : repoint des 3 contributeurs (le trigger migre
--      book_authors 10091->5), nettoyage defensif des book_authors residuels,
--      puis suppression de la fiche #10091 (CASCADE : son unique alias, deja
--      present sur #5, et 0 traduction ; aucun brouillon ne la reference).
--   4. Liaison a #5 des contributeurs non lies : 4662 (book 1924) et 5335 (1207).
--
-- Effets : la fiche /autor/5 cesse de lister 1176/1794/1924 en double, gagne
-- les livres de #10091, et #10091 disparait. Aucun impact sur d'autres fiches.
-- =========================================================================

BEGIN;

-- 1. Dedup des contributeurs en double ------------------------------------
DO $dedup$
DECLARE n int;
BEGIN
  DELETE FROM public.book_contributors WHERE id IN (3780, 4663, 4503);
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 3 THEN
    RAISE EXCEPTION 'dedup : % suppressions au lieu de 3 (donnees modifiees ? re-auditer)', n;
  END IF;
END
$dedup$;

-- 2. Nettoyage du lien book_authors orphelin du book 1924 (ord2 sans contrib)
DO $orphan$
DECLARE n int;
BEGIN
  DELETE FROM public.book_authors
   WHERE book_id = 1924 AND author_id = 5 AND role = 'autor' AND ord = 2;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 1 THEN
    RAISE EXCEPTION 'orphan 1924 : % suppression au lieu de 1', n;
  END IF;
END
$orphan$;

-- 3. Fusion #10091 -> #5 --------------------------------------------------
DO $merge$
DECLARE n int;
BEGIN
  -- 3a. repoint des contributeurs (le trigger migre book_authors 10091->5)
  UPDATE public.book_contributors SET author_id = 5 WHERE author_id = 10091;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 3 THEN
    RAISE EXCEPTION 'merge : % contributeurs repointes au lieu de 3', n;
  END IF;

  -- 3b. liens book_authors legacy residuels eventuels (defensif ; 0 attendu)
  INSERT INTO public.book_authors (book_id, author_id, role, ord)
    SELECT book_id, 5, role, ord FROM public.book_authors WHERE author_id = 10091
  ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;
  DELETE FROM public.book_authors WHERE author_id = 10091;
END
$merge$;

-- 4. Liaison des contributeurs Kropotkine non lies a #5 -------------------
DO $link$
DECLARE n int;
BEGIN
  UPDATE public.book_contributors SET author_id = 5
   WHERE id IN (4662, 5335) AND author_id IS NULL;
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 2 THEN
    RAISE EXCEPTION 'link : % liaisons au lieu de 2', n;
  END IF;
END
$link$;

-- 5. Suppression de la fiche doublon #10091 (CASCADE alias deja present sur #5)
DELETE FROM public.authors WHERE id = 10091;

-- 6. Verification fail-fast -----------------------------------------------
DO $verif$
DECLARE v int;
BEGIN
  IF EXISTS (SELECT 1 FROM public.authors WHERE id = 10091) THEN
    RAISE EXCEPTION 'VERIF_a : fiche 10091 non supprimee';
  END IF;

  SELECT count(*) INTO v FROM public.book_contributors WHERE author_id = 10091;
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_b : % book_contributors pointent encore 10091', v; END IF;

  SELECT count(*) INTO v FROM public.book_authors WHERE author_id = 10091;
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_c : % book_authors pointent encore 10091', v; END IF;

  -- contributeurs attendus desormais lies a #5 (3 fusionnes + 2 enrichis)
  SELECT count(*) INTO v FROM public.book_contributors
   WHERE id IN (3181, 3283, 3591, 4662, 5335) AND author_id = 5;
  IF v <> 5 THEN RAISE EXCEPTION 'VERIF_d : % / 5 contributeurs lies a #5', v; END IF;

  -- contributeurs dedup bien supprimes
  SELECT count(*) INTO v FROM public.book_contributors WHERE id IN (3780, 4663, 4503);
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_e : % contributeur(s) dedup encore present(s)', v; END IF;

  -- aucun doublon (book_id, author_id) sur les livres touches
  SELECT count(*) INTO v FROM (
    SELECT book_id, author_id FROM public.book_contributors
    WHERE book_id IN (1176, 1794, 1924, 1207, 649, 731, 1006) AND author_id IS NOT NULL
    GROUP BY book_id, author_id HAVING count(*) > 1
  ) d;
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_f : % doublon(s) (book_id, author_id) sur livres touches', v; END IF;

  -- aucun lien book_authors orphelin (sans contributeur adosse) sur ces livres
  SELECT count(*) INTO v FROM public.book_authors ba
   WHERE ba.book_id IN (1176, 1794, 1924, 1207, 649, 731, 1006)
     AND NOT EXISTS (
       SELECT 1 FROM public.book_contributors bc
       WHERE bc.book_id = ba.book_id AND bc.author_id = ba.author_id
         AND bc.role = ba.role AND bc.position = ba.ord
     );
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_g : % lien(s) book_authors orphelin(s) sur livres touches', v; END IF;

  RAISE NOTICE 'merge_kropotkin OK — 10091 fusionnee dans 5, 3 dedup, 2 liaisons, aucun orphelin';
END
$verif$;

COMMIT;

-- =========================================================================
-- Apres COMMIT : REFRESH des 2 MV catalogue (materialisees, lisent book_authors
-- via first_author + v_book_authors_canonical). Aligne sur 20260605350000.
-- =========================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- =========================================================================
-- Rollback (manuel, partiel) :
--   - Recreer la fiche #10091 et y repointer les contributeurs 3181/3283/3591
--     (le trigger remigrera book_authors). Les dedup (3780/4663/4503) et le
--     lien orphelin 1924 supprimes ne sont pas restaures automatiquement
--     (donnees erronees). Delier 4662/5335 : SET author_id = NULL.
--   REFRESH des 2 MV.
-- =========================================================================
