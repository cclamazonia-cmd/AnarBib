-- =========================================================================
-- C11 — les verdicts restants de la file de l'OPAC par œuvre, et les matières
--        des notices MLEG (27/09/2026)
-- =========================================================================
-- Réf. : backlog v34 C11 ; THES-4 (jamais créer de matière) ;
--        fiche docs/journal/arbitrages/ARBITRAGE_file_opac_par_oeuvre_2026-09-27.md,
--        validée en bloc par Xavier le 27/09.
--
-- Partage des gestes, décidé avec Xavier le 27/09 : les FUSIONS (irréversibles)
-- et les réunions de tomes ont été faites par lui, dans l'assistant de
-- dédoublonnage, sous son nom. Cette migration ne pose que des décisions qui ne
-- détruisent rien, EN SON PROPRE NOM : decided_by / created_by vides, motif
-- explicite « arbitrage C11 du 27/09, validé par Xavier, appliqué par migration ».
-- Elle n'emprunte l'identité de personne.
--
--   1. O Capital (Marx) : « ce ne sont pas des tomes » — quatre éditions.
--   2. O Homem e a Terra, édition Imaginário (2010-2011) — demande de Xavier du
--      27/09 : « doit passer dans les livres en volumes », le thème comme volume.
--      Les six volumes thématiques (notices 1510, 1511, 1512, 1515, 1516, 1517),
--      éclatés entre quatre œuvres, rejoignent l'œuvre 880, chacun avec son thème
--      en volume ; l'œuvre reprend le titre « O Homem e a Terra ». Le regroupement
--      suit pas à pas merge_works (déplacement des notices, brouillons, pistes,
--      notes de lecture ; fn_work_prune_if_empty ; expressions inutilisées ;
--      fn_work_titles_reseed) — sans en emprunter la garde d'identité. Deux
--      notices numérotées de tomes différents ne ressortent plus comme doublons :
--      la paire 1510 / 1511 quitte « À décider » sans verdict à poser.
--   3. Notes MLEG « Assuntos importados » : une matière EXISTANTE par catégorie
--      pour six catégories ; deux restent en note seule (Transversais, Ciências
--      Humanas) ; aucune matière créée, aucune note effacée.
--
-- Garde : sur une base qui n'a pas ces notices (banc), rien n'est fait.
-- =========================================================================

BEGIN;

DO $$
DECLARE
  k_motif constant text := ' (arbitrage C11 du 27/09, validé par Xavier, appliqué par migration)';
  v_subjects_avant int; v_n int; v_sid bigint; m record; r record;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 1510 AND titulo LIKE 'O Homem e a Terra%')
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 1511 AND titulo LIKE 'O Homem e a Terra%') THEN
    RAISE NOTICE 'C11 : notices du relevé absentes (banc) — rien à appliquer.';
    RETURN;
  END IF;
  SELECT count(*) INTO v_subjects_avant FROM public.subjects;

  -- 1. O Capital : pas des tomes
  INSERT INTO public.volume_group_dismissals (group_key, reason, decided_by)
  VALUES ('a:25|capital o', 'Quatre éditions différentes, pas des tomes' || k_motif, NULL)
  ON CONFLICT (group_key) DO NOTHING;

  -- 2. O Homem e a Terra (Imaginário) : six volumes thématiques dans l'œuvre 880
  IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = 880) THEN
    RAISE EXCEPTION 'C11 : l''œuvre 880 (O Homem e a Terra) a disparu depuis le relevé';
  END IF;
  FOR r IN SELECT DISTINCT work_id AS src FROM public.books
            WHERE id IN (1510, 1511, 1512, 1515, 1516, 1517) AND work_id IS DISTINCT FROM 880 AND work_id IS NOT NULL
  LOOP
    UPDATE public.books              SET work_id = 880 WHERE work_id = r.src;
    UPDATE public.book_drafts        SET work_id = 880 WHERE work_id = r.src;
    UPDATE public.audio_tracks       SET work_id = 880 WHERE work_id = r.src;
    UPDATE public.book_reading_notes SET work_id = 880 WHERE work_id = r.src;
    PERFORM public.fn_work_prune_if_empty(r.src);
  END LOOP;
  UPDATE public.books SET work_id = 880 WHERE id IN (1510, 1511, 1512, 1515, 1516, 1517) AND work_id IS NULL;
  FOR m IN SELECT * FROM (VALUES
      (1510, 'Progresso'), (1511, 'Internacionais'), (1512, 'O Estado Moderno'),
      (1515, 'Educação'), (1516, 'A Indústria e o Comércio'), (1517, 'A Cultura e a Propriedade')
    ) v(book_id, volume) LOOP
    UPDATE public.books SET volume = m.volume WHERE id = m.book_id;
  END LOOP;
  DELETE FROM public.work_expressions we
   WHERE we.work_id = 880 AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.expression_id = we.id);
  PERFORM public.fn_work_titles_reseed(880);
  UPDATE public.works SET uniform_title = 'O Homem e a Terra', sort_title = public.fn_normalize_name('O Homem e a Terra'), updated_at = now()
   WHERE id = 880;
  INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
  VALUES (880, 'pt-BR', 'O Homem e a Terra', 'manual', false)
  ON CONFLICT (work_id, lang) DO UPDATE SET title = EXCLUDED.title, source = 'manual', source_book_id = NULL,
                                            needs_review = false, updated_at = now();

  -- 3. Notes MLEG : une matière existante par catégorie (THES-4)
  FOR m IN SELECT * FROM (VALUES
      ('Anarquismo no Brasil', 'anarquismo'), ('Anarquismo Internacional', 'anarquismo'),
      ('Clássicos Anarquistas', 'anarquismo'), ('Coletâneas', 'anarquismo'),
      ('Edgar Rodrigues', 'historia-anarquismo'), ('Literatura Libertária', 'ficcao')
    ) v(label, slug) LOOP
    SELECT id INTO v_sid FROM public.subjects WHERE slug = m.slug AND status = 'ativo';
    IF v_sid IS NULL THEN RAISE EXCEPTION 'C11 : matière % absente ou inactive', m.slug; END IF;
    FOR r IN SELECT b.id FROM public.books b
              WHERE lower(extensions.unaccent(b.notas)) ~ ('(^|\n)\s*assuntos importados:\s*' || lower(extensions.unaccent(m.label)) || '\s*(\n|$)')
    LOOP
      INSERT INTO public.book_subjects (book_id, subject_id, ord)
      SELECT r.id, v_sid, COALESCE((SELECT max(ord) FROM public.book_subjects WHERE book_id = r.id), 0) + 1
       WHERE NOT EXISTS (SELECT 1 FROM public.book_subjects WHERE book_id = r.id AND subject_id = v_sid);
    END LOOP;
  END LOOP;

  -- Vérification
  IF (SELECT count(*) FROM public.subjects) <> v_subjects_avant THEN
    RAISE EXCEPTION 'C11 : le nombre de matières a changé (THES-4)';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.volume_group_dismissals WHERE group_key = 'a:25|capital o') THEN
    RAISE EXCEPTION 'C11 : le groupe O Capital n''est pas écarté';
  END IF;
  IF (SELECT count(*) FROM public.books WHERE id IN (1510, 1511, 1512, 1515, 1516, 1517) AND work_id = 880 AND volume IS NOT NULL) <> 6
     OR EXISTS (SELECT 1 FROM public.works WHERE id IN (2326, 2473, 2312)) THEN
    RAISE EXCEPTION 'C11 : les six volumes de O Homem e a Terra ne sont pas réunis dans l''œuvre 880';
  END IF;
  SELECT count(*) INTO v_n FROM public.books b
   WHERE lower(extensions.unaccent(b.notas)) ~ '(^|\n)\s*assuntos importados:\s*(anarquismo no brasil|anarquismo internacional|classicos anarquistas|coletaneas|edgar rodrigues|literatura libertaria)\s*(\n|$)'
     AND NOT EXISTS (SELECT 1 FROM public.book_subjects bs WHERE bs.book_id = b.id);
  IF v_n > 0 THEN RAISE EXCEPTION 'C11 : % notice(s) MLEG sans matière après application', v_n; END IF;

  SELECT count(*) INTO v_n FROM public.books WHERE notas ~ 'Assuntos importados';
  RAISE NOTICE 'C11 : O Capital écarté, O Homem e a Terra en six volumes, % notices MLEG lues (six catégories indexées, deux en note seule).', v_n;
END $$;

COMMIT;
