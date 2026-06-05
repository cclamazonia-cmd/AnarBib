-- =========================================================================
-- Paquet fix — nettoyage des liens legacy book_authors erronnes (autorites)
-- =========================================================================
-- Date     : 2026-06-05
-- Chantier : Autorites / coherence book_authors <-> book_contributors
-- Auteur   : Xavier + Claude
--
-- CONTEXTE
-- --------
-- book_contributors est la source de verite des contributeurs ; book_authors
-- n'en est qu'un derive (sens unique, cf. 20260605230000). book_authors reste
-- lu par author_books_public (fiche auteur /autor/:id -> ses oeuvres), par
-- v_book_detail_public_v2.authors_json et par first_author.author_id (fiche
-- livre + MV catalogue).
--
-- Diagnostic (lecture MCP, 2026-06-05) : 75 liens book_authors role='autor'
-- lies a une autorite mais SANS contributeur correspondant.
--   * 1 = vrai contributeur manquant (book 518) -> deja corrige (20260605320000).
--   * 74 = liens sur des livres qui ONT deja des contributeurs. Tries en
--     croisant le patronyme de l'autorite avec le texte books.autor :
--       - 46 ERRONNES (44 faux + 2 fantomes) : l'autorite n'a aucun rapport
--         avec le livre (ex. MARX#25 sur un livre de Schmidt ; CHOMSKY#9 sur
--         Bodela ; RECLUS#1 sur Vega ; fantomes "[AUTOR SEM FICHA #10001/3]").
--         Effet de bord : ces livres polluent la fiche des auteurs vises et
--         faussent first_author.author_id. -> A SUPPRIMER.
--       - 28 VARIANTES legitimes : l'autorite EST un auteur du livre, mais le
--         contributeur figure sous une autre graphie (translitteration), avec
--         author_id NULL. -> A LIER (enrichissement), pas a supprimer.
--
-- CE QUE FAIT CETTE MIGRATION
-- ---------------------------
-- 1. SUPPRIME les 46 liens book_authors erronnes (liste explicite auditee).
--    Aucun trigger sur book_authors -> pas d'effet de bord. Corrige les fiches
--    auteurs polluees + authors_json + first_author.author_id.
-- 2. LIE 23 des 28 variantes : UPDATE book_contributors.author_id sur le
--    contributeur exact (id explicite) -> chip catalogue cliquable. Pour ces 23,
--    verifie : contributeur unique, author_id actuellement NULL, et ord legacy =
--    position contributeur (le trigger trg_sync_book_authors re-insere alors le
--    meme lien book_authors en ON CONFLICT DO NOTHING -> pas de doublon sur la
--    fiche auteur).
--
-- HORS PERIMETRE (4 variantes laissees INTACTES, revue d'autorites a part) :
--   * books 649, 731, 1006 : contributeur "Kropotkine, P." DEJA lie a une AUTRE
--     fiche Kropotkine (author_id 10091) -> doublon d'autorite 5 vs 10091 a
--     fusionner, pas un simple enrichissement.
--   * book 1924 : deux contributeurs Kropotkin dupliques (id 4662 & 4663) et deux
--     liens book_authors -> dedup contributeur requis avant liaison.
-- Ces liens sont "legitimes" (vrais livres de Kropotkine) donc ils ne polluent
-- pas la fiche ; on les garde tels quels en attendant la fusion d'autorites.
-- =========================================================================

BEGIN;

-- 1. Suppression des 46 liens erronnes ------------------------------------
DO $del$
DECLARE n integer;
BEGIN
  DELETE FROM public.book_authors ba
  USING (VALUES
    (132,1),(159,1),(239,1),(319,1),
    (296,2),(371,2),
    (237,3),(241,3),(323,3),
    (186,4),(297,4),
    (151,5),(176,5),(244,5),(372,5),
    (222,6),(227,6),
    (179,8),
    (302,9),
    (360,16),
    (375,17),
    (272,25),
    (189,29),(369,29),
    (387,30),
    (116,32),(161,32),
    (356,33),
    (367,34),
    (145,38),
    (381,39),
    (152,40),
    (137,41),
    (120,42),(206,42),
    (146,43),
    (304,44),(358,44),
    (255,45),
    (182,46),
    (173,48),
    (158,51),(170,51),
    (240,52),
    (2,10001),(4,10003)
  ) AS f(book_id, author_id)
  WHERE ba.book_id = f.book_id
    AND ba.author_id = f.author_id
    AND ba.role = 'autor';

  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 46 THEN
    RAISE EXCEPTION 'DELETE liens erronnes : % lignes supprimees au lieu de 46 (dossier modifie ? re-auditer)', n;
  END IF;
  RAISE NOTICE 'cleanup book_authors : 46 liens erronnes supprimes';
END
$del$;

-- 2. Enrichissement : lier 23 contributeurs variantes a leur autorite ------
DO $upd$
DECLARE n integer;
BEGIN
  UPDATE public.book_contributors bc
  SET author_id = l.author_id
  FROM (VALUES
    (3653,1),(3706,1),(4173,1),
    (2579,3),(2998,3),(3163,3),(3652,3),(3656,3),(5005,3),
    (3577,4),(3588,4),(4012,4),(4693,4),
    (2608,5),(3150,5),(3546,5),(4552,5),(5007,5),(5010,5),
    (2837,24),(4695,24),
    (3528,29),
    (4331,10026)
  ) AS l(contrib_id, author_id)
  WHERE bc.id = l.contrib_id
    AND bc.author_id IS NULL;   -- garde : ne jamais ecraser un lien existant

  GET DIAGNOSTICS n = ROW_COUNT;
  IF n <> 23 THEN
    RAISE EXCEPTION 'UPDATE enrichissement : % lignes liees au lieu de 23 (donnees modifiees ? re-auditer)', n;
  END IF;
  RAISE NOTICE 'cleanup book_authors : 23 contributeurs variantes lies a leur autorite';
END
$upd$;

-- 3. Verification fail-fast ------------------------------------------------
DO $verif$
DECLARE
  v_dup int;
  v_518 int;
BEGIN
  -- a. aucun livre touche ne se retrouve avec 2 contributeurs sur la meme autorite
  SELECT count(*) INTO v_dup
  FROM (
    SELECT bc.book_id, bc.author_id
    FROM public.book_contributors bc
    WHERE bc.author_id IN (1,3,4,5,24,29,10026)
    GROUP BY bc.book_id, bc.author_id
    HAVING count(*) > 1
  ) d;
  IF v_dup <> 0 THEN
    RAISE EXCEPTION 'VERIF_FAIL_a : % livre(s) avec doublon (book_id, author_id) apres enrichissement', v_dup;
  END IF;

  -- b. book 518 (corrige precedemment) reste intact
  SELECT count(*) INTO v_518
  FROM public.book_contributors WHERE book_id = 518 AND author_id = 5 AND role='autor';
  IF v_518 <> 1 THEN
    RAISE EXCEPTION 'VERIF_FAIL_b : book 518 alteré (% lignes)', v_518;
  END IF;

  RAISE NOTICE 'cleanup book_authors OK — 46 supprimes, 23 lies, aucun doublon, book 518 intact';
END
$verif$;

COMMIT;

-- =========================================================================
-- Apres COMMIT : REFRESH des MV catalogue (les deux sont materialisees et
-- lisent book_authors via first_author.author_id + v_book_authors_canonical).
-- NON concurrent (bloc transactionnel CLI) — aligne sur 20260605310000/320000.
-- =========================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- =========================================================================
-- Rollback (manuel) :
--   -- delier les 23 contributeurs enrichis :
--   UPDATE public.book_contributors SET author_id = NULL
--    WHERE id IN (3653,3706,4173,2579,2998,3163,3652,3656,5005,3577,3588,4012,
--                 4693,2608,3150,3546,4552,5007,5010,2837,4695,3528,4331);
--   -- les 46 liens book_authors supprimes etaient erronnes (autorite sans
--   --   rapport) ; restauration NON souhaitable. Liste auditee dans l'en-tete.
--   REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
--   REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;
-- =========================================================================
