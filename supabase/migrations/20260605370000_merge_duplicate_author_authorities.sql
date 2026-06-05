-- =========================================================================
-- Paquet fix — fusion globale des fiches authors en double
-- =========================================================================
-- (Re-declenchement CI : pousse initialement sous un commit de tete [CI SKIP],
--  puis pipeline manuel #997 qui ne lance pas deploy-migrations (event=manual).
--  Ce changement reel force un event=push pour appliquer la migration.)
-- Date     : 2026-06-05
-- Chantier : Autorites / dedoublonnage des fiches authors (balayage global)
-- Auteur   : Xavier + Claude
--
-- CONTEXTE (balayage MCP, 2026-06-05 — 158 fiches, similarite trigramme)
-- ---------------------------------------------------------------------
-- 6 personnes possedent 2+ fiches authors (meme personne, graphies/translit.
-- differentes). Confirme avec l'utilisateur ; canoniques retenues :
--   * Tolstoi (3 fiches) : 10108, 10109 -> 10023 ; fiche renommee "Tolstói, Lev".
--   * Cappelletti        : 10044 (Ángel, vide) -> 10027 (Angel J., 11 contrib).
--   * Mechoso            : 10056 (Juan C.) -> 33 (Juan Carlos, 1935).
--   * Mintz              : 10016 (Frank, 9 contrib) -> 12 (1941) ; 12 renommee
--                          "MINTZ, Frank" (10016 portait deja la bonne graphie).
--   * Hamon              : 10052 (A.) -> 10086 (Augustin).
--   * Gori               : 10011 (Pedro) -> 10084 (Pietro).
-- NON fusionnes (personnes distinctes) : Reclus #1 Élisée (1830) vs #10026 Élie
--   (1827) = freres ; Fabbri #10031 Luigi vs #10048 Luce = pere/fille.
--
-- Audit prealable (lecture) : aucun chevauchement intra-livre (overlap=0 -> pas
-- de dedup contributeur a faire), 0 traduction et 0 brouillon sur les doublons,
-- seulement des alias a reporter ; aucun doublon (book,author) preexistant sur
-- les canoniques.
--
-- MECANIQUE (replique merge_author SANS sa garde staff auth.uid() ni merge_log)
-- pour chaque paire (canonique, doublon) :
--   1. dedup intra-livre defensif (0 attendu) ; 2. repoint des contributeurs
--   (le trigger trg_sync_book_authors migre book_authors) ; 3. book_authors
--   residuels (INSERT ON CONFLICT + DELETE) ; 4. traductions (langues absentes
--   du canonique) ; 5. alias non deja presents reportes ; 6. brouillons ;
--   7. suppression du doublon (CASCADE alias/traductions restants).
-- =========================================================================

BEGIN;

-- 1. Fusions ---------------------------------------------------------------
DO $merge$
DECLARE r record; n_total int := 0;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    (10023, 10108), (10023, 10109),   -- Tolstoi
    (10027, 10044),                   -- Cappelletti
    (33,    10056),                   -- Mechoso
    (12,    10016),                   -- Mintz
    (10086, 10052),                   -- Hamon
    (10084, 10011)                    -- Gori
  ) AS t(canonical, duplicate)
  LOOP
    IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id = r.canonical) THEN
      RAISE EXCEPTION 'merge : fiche canonique % absente', r.canonical;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id = r.duplicate) THEN
      RAISE EXCEPTION 'merge : fiche doublon % absente', r.duplicate;
    END IF;

    -- 1. dedup intra-livre defensif (0 attendu d'apres l'audit)
    DELETE FROM public.book_contributors d
     WHERE d.author_id = r.duplicate
       AND EXISTS (SELECT 1 FROM public.book_contributors c
                   WHERE c.book_id = d.book_id AND c.author_id = r.canonical AND c.role = d.role);

    -- 2. repoint des contributeurs (le trigger migre book_authors)
    UPDATE public.book_contributors SET author_id = r.canonical WHERE author_id = r.duplicate;

    -- 3. liens book_authors residuels
    INSERT INTO public.book_authors (book_id, author_id, role, ord)
      SELECT book_id, r.canonical, role, ord FROM public.book_authors WHERE author_id = r.duplicate
    ON CONFLICT (book_id, author_id, role, ord) DO NOTHING;
    DELETE FROM public.book_authors WHERE author_id = r.duplicate;

    -- 4. traductions (langues absentes du canonique)
    UPDATE public.author_translations t SET author_id = r.canonical
     WHERE t.author_id = r.duplicate
       AND NOT EXISTS (SELECT 1 FROM public.author_translations c
                       WHERE c.author_id = r.canonical AND c.lang = t.lang);

    -- 5. alias : reporter ceux non deja presents sur le canonique (le reste
    --    part au CASCADE du DELETE)
    UPDATE public.author_name_aliases al SET author_id = r.canonical
     WHERE al.author_id = r.duplicate
       AND NOT EXISTS (SELECT 1 FROM public.author_name_aliases c
                       WHERE c.author_id = r.canonical AND c.alias_norm = al.alias_norm);

    -- 6. brouillons (0 attendu)
    UPDATE public.author_drafts SET published_author_id = r.canonical WHERE published_author_id = r.duplicate;
    UPDATE public.book_draft_contributors SET author_id = r.canonical WHERE author_id = r.duplicate;

    -- 7. supprimer la fiche doublon
    DELETE FROM public.authors WHERE id = r.duplicate;

    n_total := n_total + 1;
  END LOOP;

  IF n_total <> 7 THEN
    RAISE EXCEPTION 'merge : % fusions au lieu de 7', n_total;
  END IF;
END
$merge$;

-- 2. Renommage des fiches canoniques retenues -----------------------------
UPDATE public.authors SET sort_name = 'Tolstói, Lev', preferred_name = 'Lev Tolstói' WHERE id = 10023;
UPDATE public.authors SET sort_name = 'MINTZ, Frank',  preferred_name = 'Frank MINTZ'  WHERE id = 12;

-- 3. Verification fail-fast ------------------------------------------------
DO $verif$
DECLARE v int;
BEGIN
  SELECT count(*) INTO v FROM public.authors WHERE id IN (10108,10109,10044,10056,10016,10052,10011);
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_a : % fiche(s) doublon non supprimee(s)', v; END IF;

  SELECT count(*) INTO v FROM public.book_contributors WHERE author_id IN (10108,10109,10044,10056,10016,10052,10011);
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_b : % book_contributors pointent encore un doublon', v; END IF;

  SELECT count(*) INTO v FROM public.book_authors WHERE author_id IN (10108,10109,10044,10056,10016,10052,10011);
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_c : % book_authors pointent encore un doublon', v; END IF;

  SELECT count(*) INTO v FROM (
    SELECT book_id, author_id FROM public.book_contributors
    WHERE author_id IN (10023,10027,33,12,10086,10084)
    GROUP BY book_id, author_id HAVING count(*) > 1
  ) d;
  IF v <> 0 THEN RAISE EXCEPTION 'VERIF_d : % doublon(s) (book,author) sur une fiche canonique', v; END IF;

  IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id=10023 AND sort_name='Tolstói, Lev') THEN
    RAISE EXCEPTION 'VERIF_e : renommage Tolstoi non applique'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.authors WHERE id=12 AND sort_name='MINTZ, Frank') THEN
    RAISE EXCEPTION 'VERIF_f : renommage Mintz non applique'; END IF;

  RAISE NOTICE 'merge_duplicate_authorities OK — 7 fusions, 2 renommages';
END
$verif$;

COMMIT;

-- =========================================================================
-- Apres COMMIT : REFRESH des 2 MV catalogue (les libelles de chips des livres
-- Tolstoi/Mintz changent via authors.sort_name canonicalise).
-- =========================================================================
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_v1;
REFRESH MATERIALIZED VIEW public.mv_books_catalog_list_network_v1;

-- =========================================================================
-- Rollback (manuel, partiel) : recreer les fiches doublons supprimees et y
-- repointer leurs contributeurs (le trigger remigrera book_authors) ; restaurer
-- sort_name/preferred_name de 10023 ("TOLSTOI, Leon"/"Leon TOLSTOI") et 12
-- ("MINTZ, Franck"/"Franck MINTZ"). Les alias/traductions absorbes ne sont pas
-- restaures automatiquement. REFRESH des 2 MV.
-- =========================================================================
