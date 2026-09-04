-- =====================================================================
-- AnarBib -- Les oeuvres se rattachent et se fusionnent (lot 1b, OPAC par oeuvre)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  decisions Xavier du 04/09
-- Depend  : 20260904095317 (les 30 groupes arbitres a la main)
--
-- CE QUE LE 04/09 A MONTRE. fn_books_ensure_work cree une oeuvre par notice
-- publiee, et RIEN ne les rapproche ensuite : les huit « Desobediencia civil »
-- de Thoreau vivaient sur six oeuvres. Pire, group_books_as_editions deplacait
-- les notices sans supprimer l'oeuvre qu'elles quittaient -- d'ou les cinq
-- oeuvres vides trouvees le 04/09. Une bibliotheque qui arrive avec ses
-- editions recree le probleme a chaque notice.
--
-- CE QUE CE PAQUET POSE (lot 1b) :
--   1. work_not_same : la memoire des « garder separees », pour qu'un faux
--      positif arbitre une fois ne revienne pas a chaque balayage (comme
--      book_not_duplicate pour les notices) ;
--   2. fn_work_prune_if_empty : une oeuvre quittee par sa derniere notice
--      disparait ; assign_book_to_work, detach_book_from_work et
--      group_books_as_editions l'appellent desormais ;
--   3. merge_works : fusionner une oeuvre entiere dans une autre (notices,
--      brouillons, pistes audio, notes de lecture suivent ; notes concatenees) ;
--   4. suggest_split_works : le balayage « oeuvres probablement scindees »
--      (meme auteur principal + titre normalise proche), l'heuristique qui a
--      sorti les 30 groupes du 04/09, servie a l'assistant de doublons ;
--   5. mark_works_not_same : le geste « garder separees » ;
--   6. search_works_for_link : le selecteur « rattacher a une autre oeuvre »
--      du formulaire de catalogage ;
--   7. les 218 oeuvres sans auteur principal mais dont une notice en a un le
--      recoivent (sinon l'heuristique ne les voit pas) ;
--   8. les trois faux positifs du 04/09 (Malatesta, Armand, Aiex) entrent
--      dans work_not_same.
--
-- DOCTRINE : jamais de fusion par script. Le balayage PROPOSE, une personne
-- DECIDE, la RPC applique. Fonctions SECURITY DEFINER a garde staff, revoquees
-- de PUBLIC, anon ET authenticated puis accordees a authenticated (checklist
-- _TEMPLATE.sql). Idempotent, sur en CI (base vide = rien a rattraper).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. La memoire des « garder separees »
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_not_same (
  work_id_a   bigint NOT NULL REFERENCES public.works(id) ON DELETE CASCADE,
  work_id_b   bigint NOT NULL REFERENCES public.works(id) ON DELETE CASCADE,
  reason      text,
  decided_by  uuid,
  decided_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (work_id_a, work_id_b),
  CONSTRAINT work_not_same_ordered CHECK (work_id_a < work_id_b)
);
COMMENT ON TABLE public.work_not_same IS
  'Paires d''oeuvres arbitrees « ce ne sont pas la meme oeuvre » : suggest_split_works ne les repropose plus. '
  'Pendant de book_not_duplicate pour les notices. Lot 1b OPAC par oeuvre, 04/09/2026.';

-- La garde fk_sans_index_garde_tests exige un index par FK : la premiere
-- colonne est couverte par la cle primaire, pas la seconde.
CREATE INDEX IF NOT EXISTS work_not_same_work_id_b_idx ON public.work_not_same (work_id_b);

ALTER TABLE public.work_not_same ENABLE ROW LEVEL SECURITY;
-- Les ALTER DEFAULT PRIVILEGES de Supabase donnent TOUT a anon/authenticated
-- sur une table neuve : on ne garde que la lecture (staff, par policy).
REVOKE ALL ON public.work_not_same FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.work_not_same TO authenticated;
GRANT ALL    ON public.work_not_same TO service_role;
DROP POLICY IF EXISTS work_not_same_read_staff ON public.work_not_same;
CREATE POLICY work_not_same_read_staff ON public.work_not_same
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.user_library_memberships m
    WHERE m.user_id = (SELECT auth.uid())
      AND m.role = ANY (ARRAY['librarian','coordenador'])
      AND m.status = 'active'));
-- Aucune policy d'ecriture : on n'ecrit que par mark_works_not_same (DEFINER).

-- ---------------------------------------------------------------------
-- 2. Une oeuvre quittee par sa derniere notice disparait
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_work_prune_if_empty(p_work_id bigint)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF p_work_id IS NULL THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM public.books              WHERE work_id = p_work_id)
  OR EXISTS (SELECT 1 FROM public.book_drafts        WHERE work_id = p_work_id)
  OR EXISTS (SELECT 1 FROM public.audio_tracks       WHERE work_id = p_work_id)
  OR EXISTS (SELECT 1 FROM public.book_reading_notes WHERE work_id = p_work_id) THEN
    RETURN false;
  END IF;
  DELETE FROM public.works WHERE id = p_work_id;
  RETURN FOUND;
END;
$$;
COMMENT ON FUNCTION public.fn_work_prune_if_empty(bigint) IS
  'Supprime l''oeuvre si plus rien ne la reference (notice, brouillon, piste audio, note de lecture). '
  'Interne : appelee par les RPC de rattachement, jamais exposee.';
REVOKE EXECUTE ON FUNCTION public.fn_work_prune_if_empty(bigint) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. Fusionner une oeuvre entiere dans une autre
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.merge_works(p_source_work_id bigint, p_target_work_id bigint)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  v_src public.works%rowtype;
  v_tgt public.works%rowtype;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF p_source_work_id = p_target_work_id THEN
    RAISE EXCEPTION 'Uma obra não se funde consigo mesma.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.sameWork';
  END IF;
  SELECT * INTO v_src FROM public.works WHERE id = p_source_work_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Obra inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound'; END IF;
  SELECT * INTO v_tgt FROM public.works WHERE id = p_target_work_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Obra inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound'; END IF;

  -- Tout ce qui pointait la source pointe la cible. Le trigger de books
  -- recalcule l'expression FRBR (langue) dans la cible.
  UPDATE public.books              SET work_id = p_target_work_id WHERE work_id = p_source_work_id;
  UPDATE public.book_drafts        SET work_id = p_target_work_id WHERE work_id = p_source_work_id;
  UPDATE public.audio_tracks       SET work_id = p_target_work_id WHERE work_id = p_source_work_id;
  UPDATE public.book_reading_notes SET work_id = p_target_work_id WHERE work_id = p_source_work_id;

  -- La cible garde son titre ; elle herite l'auteur et les notes qu'elle n'avait pas.
  UPDATE public.works
     SET primary_author_id = COALESCE(v_tgt.primary_author_id, v_src.primary_author_id),
         notes = CASE
                   WHEN NULLIF(v_src.notes, '') IS NULL THEN v_tgt.notes
                   WHEN NULLIF(v_tgt.notes, '') IS NULL THEN v_src.notes
                   ELSE v_tgt.notes || E'\n' || v_src.notes
                 END,
         updated_at = now()
   WHERE id = p_target_work_id;

  -- La source, vide, disparait (work_not_same et work_expressions suivent en cascade).
  PERFORM public.fn_work_prune_if_empty(p_source_work_id);

  -- Expressions FRBR de la cible que plus aucune notice ne porte.
  DELETE FROM public.work_expressions we
   WHERE we.work_id = p_target_work_id
     AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.expression_id = we.id);

  RETURN p_target_work_id;
END;
$$;
COMMENT ON FUNCTION public.merge_works(bigint, bigint) IS
  'Fusionne l''oeuvre source dans la cible : notices, brouillons, pistes audio et notes de lecture suivent, '
  'la source est supprimee. Staff seulement. Lot 1b OPAC par oeuvre.';
REVOKE EXECUTE ON FUNCTION public.merge_works(bigint, bigint) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.merge_works(bigint, bigint) TO authenticated;

-- ---------------------------------------------------------------------
-- 4. Les gestes existants ne laissent plus d'oeuvre vide derriere eux
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assign_book_to_work(p_book_id bigint, p_work_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_old bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  SELECT work_id INTO v_old FROM public.books WHERE id = p_book_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Documento inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = p_work_id) THEN
    RAISE EXCEPTION 'Obra inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound';
  END IF;
  UPDATE public.books SET work_id = p_work_id WHERE id = p_book_id;
  IF v_old IS DISTINCT FROM p_work_id THEN PERFORM public.fn_work_prune_if_empty(v_old); END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.detach_book_from_work(p_book_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_old bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  SELECT work_id INTO v_old FROM public.books WHERE id = p_book_id;
  UPDATE public.books SET work_id = NULL WHERE id = p_book_id;
  PERFORM public.fn_work_prune_if_empty(v_old);
END;
$$;

CREATE OR REPLACE FUNCTION public.group_books_as_editions(p_book_ids bigint[])
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_work bigint; v_oldest bigint; v_title text; v_author bigint; v_n int; v_olds bigint[]; v_o bigint;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  SELECT count(*) INTO v_n FROM public.books WHERE id = ANY(p_book_ids);
  IF v_n < 2 THEN
    RAISE EXCEPTION 'Selecione ao menos dois documentos.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.needTwo';
  END IF;

  -- oeuvre cible : la plus petite oeuvre deja presente dans la selection
  SELECT min(work_id) INTO v_work FROM public.books WHERE id = ANY(p_book_ids) AND work_id IS NOT NULL;
  IF v_work IS NULL THEN
    SELECT id, titulo INTO v_oldest, v_title FROM public.books WHERE id = ANY(p_book_ids)
      ORDER BY NULLIF(substring(ano FROM '\d{4}'), '')::int NULLS LAST, id LIMIT 1;
    SELECT author_id INTO v_author FROM public.book_authors WHERE book_id = v_oldest AND role = 'autor' ORDER BY ord LIMIT 1;
    INSERT INTO public.works (uniform_title, sort_title, primary_author_id, created_by)
    VALUES (COALESCE(NULLIF(v_title, ''), '(sans titre)'), public.fn_normalize_name(v_title), v_author, auth.uid())
    RETURNING id INTO v_work;
  END IF;

  -- Les oeuvres quittees, memorisees AVANT le deplacement.
  SELECT array_agg(DISTINCT work_id) INTO v_olds
    FROM public.books WHERE id = ANY(p_book_ids) AND work_id IS NOT NULL AND work_id <> v_work;

  UPDATE public.books SET work_id = v_work WHERE id = ANY(p_book_ids);

  -- Une oeuvre quittee par sa derniere notice ne reste pas vide (defaut du 04/09).
  IF v_olds IS NOT NULL THEN
    FOREACH v_o IN ARRAY v_olds LOOP PERFORM public.fn_work_prune_if_empty(v_o); END LOOP;
  END IF;
  RETURN v_work;
END;
$$;

-- ---------------------------------------------------------------------
-- 5. Le balayage « oeuvres probablement scindees »
-- ---------------------------------------------------------------------
-- L'heuristique du 04/09 : meme auteur principal (celui de l'oeuvre, sinon
-- celui de sa plus ancienne notice) et titre normalise proche (trigrammes,
-- ou memes 14 premiers caracteres). Les paires arbitrees « pas la meme
-- oeuvre » sont exclues. Le balayage PROPOSE, la personne decide.
CREATE OR REPLACE FUNCTION public.suggest_split_works(p_max integer DEFAULT 300)
RETURNS TABLE(
  work_id_a bigint, title_a text, editions_a integer, libraries_a text, years_a text,
  work_id_b bigint, title_b text, editions_b integer, libraries_b text, years_b text,
  author_id bigint, author_name text, score real)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;

  RETURN QUERY
  WITH w AS (
    SELECT wk.id, wk.uniform_title,
           COALESCE(wk.primary_author_id, (
             SELECT ba.author_id FROM public.books b
             JOIN public.book_authors ba ON ba.book_id = b.id AND ba.role = 'autor' AND ba.author_id IS NOT NULL
             WHERE b.work_id = wk.id
             ORDER BY NULLIF(substring(b.ano FROM '\d{4}'), '')::int NULLS LAST, b.id, ba.ord
             LIMIT 1)) AS auth_id,
           COALESCE(NULLIF(wk.sort_title, ''), public.fn_normalize_name(wk.uniform_title)) AS key,
           regexp_replace(lower(extensions.unaccent(COALESCE(wk.sort_title, wk.uniform_title, ''))), '[^a-z0-9]', '', 'g') AS compact,
           (SELECT count(*)::int FROM public.books b WHERE b.work_id = wk.id) AS editions,
           (SELECT string_agg(DISTINCT COALESCE(l.short_name, l.name), ', ' ORDER BY COALESCE(l.short_name, l.name))
              FROM public.books b JOIN public.book_holdings h ON h.book_id = b.id JOIN public.libraries l ON l.id = h.library_id
             WHERE b.work_id = wk.id) AS libraries,
           (SELECT CASE WHEN min(y) IS NULL THEN NULL
                        WHEN min(y) = max(y) THEN min(y)::text
                        ELSE min(y)::text || '–' || max(y)::text END
              FROM (SELECT NULLIF(substring(b.ano FROM '\d{4}'), '')::int AS y FROM public.books b WHERE b.work_id = wk.id) s) AS years
    FROM public.works wk
  ),
  pairs AS (
    SELECT a.id AS ia, b.id AS ib, a.auth_id,
           GREATEST(extensions.similarity(a.key, b.key),
                    CASE WHEN length(a.compact) >= 8 AND left(a.compact, 14) = left(b.compact, 14) THEN 0.7 ELSE 0 END)::real AS sc
    FROM w a
    JOIN w b ON b.auth_id = a.auth_id AND b.id > a.id
    WHERE a.auth_id IS NOT NULL
      AND a.editions > 0 AND b.editions > 0
      AND NOT EXISTS (SELECT 1 FROM public.work_not_same n WHERE n.work_id_a = a.id AND n.work_id_b = b.id)
  )
  SELECT wa.id, wa.uniform_title, wa.editions, wa.libraries, wa.years,
         wb.id, wb.uniform_title, wb.editions, wb.libraries, wb.years,
         p.auth_id, au.preferred_name, p.sc
  FROM pairs p
  JOIN w wa ON wa.id = p.ia
  JOIN w wb ON wb.id = p.ib
  LEFT JOIN public.authors au ON au.id = p.auth_id
  WHERE p.sc >= 0.55
  ORDER BY p.sc DESC, wa.uniform_title, wa.id, wb.id
  LIMIT GREATEST(COALESCE(p_max, 300), 1);
END;
$$;
COMMENT ON FUNCTION public.suggest_split_works(integer) IS
  'Paires d''oeuvres probablement scindees (meme auteur principal, titre normalise proche), hors paires '
  'arbitrees dans work_not_same. Balayage servi a l''assistant de doublons. Lot 1b OPAC par oeuvre.';
REVOKE EXECUTE ON FUNCTION public.suggest_split_works(integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.suggest_split_works(integer) TO authenticated;

-- ---------------------------------------------------------------------
-- 6. « Garder separees »
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_works_not_same(p_a bigint, p_b bigint, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  IF p_a IS NULL OR p_b IS NULL OR p_a = p_b THEN
    RAISE EXCEPTION 'Duas obras distintas são necessárias.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.sameWork';
  END IF;
  INSERT INTO public.work_not_same (work_id_a, work_id_b, reason, decided_by)
  VALUES (LEAST(p_a, p_b), GREATEST(p_a, p_b), NULLIF(btrim(p_reason), ''), auth.uid())
  ON CONFLICT (work_id_a, work_id_b) DO UPDATE
     SET reason = COALESCE(EXCLUDED.reason, public.work_not_same.reason),
         decided_by = EXCLUDED.decided_by, decided_at = now();
END;
$$;
REVOKE EXECUTE ON FUNCTION public.mark_works_not_same(bigint, bigint, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.mark_works_not_same(bigint, bigint, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 7. Le selecteur « rattacher a une autre oeuvre »
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_works_for_link(p_q text, p_limit integer DEFAULT 20)
RETURNS TABLE(work_id bigint, uniform_title text, author_name text, editions integer, years text, score real)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE v_q text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.user_library_memberships m
                 WHERE m.user_id = auth.uid() AND m.role = ANY(ARRAY['librarian','coordenador']) AND m.status = 'active') THEN
    RAISE EXCEPTION 'Apenas bibliotecárias e coordenadoras podem editar o catálogo.'
      USING ERRCODE = '42501', HINT = 'error.catalog.discard.forbidden';
  END IF;
  v_q := lower(extensions.unaccent(COALESCE(btrim(p_q), '')));
  IF length(v_q) < 2 THEN RETURN; END IF;

  RETURN QUERY
  SELECT wk.id, wk.uniform_title, au.preferred_name,
         (SELECT count(*)::int FROM public.books b WHERE b.work_id = wk.id),
         (SELECT CASE WHEN min(y) IS NULL THEN NULL
                      WHEN min(y) = max(y) THEN min(y)::text
                      ELSE min(y)::text || '–' || max(y)::text END
            FROM (SELECT NULLIF(substring(b.ano FROM '\d{4}'), '')::int AS y FROM public.books b WHERE b.work_id = wk.id) s),
         GREATEST(extensions.similarity(lower(extensions.unaccent(wk.uniform_title)), v_q),
                  CASE WHEN lower(extensions.unaccent(wk.uniform_title)) LIKE '%' || v_q || '%' THEN 0.9 ELSE 0 END)::real
  FROM public.works wk
  LEFT JOIN public.authors au ON au.id = wk.primary_author_id
  WHERE lower(extensions.unaccent(wk.uniform_title)) LIKE '%' || v_q || '%'
     OR lower(extensions.unaccent(COALESCE(au.preferred_name, ''))) LIKE '%' || v_q || '%'
     OR extensions.similarity(lower(extensions.unaccent(wk.uniform_title)), v_q) >= 0.4
  ORDER BY 6 DESC, wk.uniform_title
  LIMIT GREATEST(COALESCE(p_limit, 20), 1);
END;
$$;
REVOKE EXECUTE ON FUNCTION public.search_works_for_link(text, integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.search_works_for_link(text, integer) TO authenticated;

-- ---------------------------------------------------------------------
-- 8. Les oeuvres sans auteur principal en recoivent un quand une notice en a
-- ---------------------------------------------------------------------
-- fn_books_ensure_work insere primary_author_id NULL (book_authors n'existe
-- pas encore a l'INSERT). 218 oeuvres etaient dans ce cas le 04/09 : invisibles
-- au balayage. Rattrapage garde, rejouable, silencieux sur base vide.
UPDATE public.works wk
   SET primary_author_id = s.author_id, updated_at = now()
  FROM (
    SELECT DISTINCT ON (b.work_id) b.work_id, ba.author_id
      FROM public.books b
      JOIN public.book_authors ba ON ba.book_id = b.id AND ba.role = 'autor' AND ba.author_id IS NOT NULL
     WHERE b.work_id IS NOT NULL
     ORDER BY b.work_id, NULLIF(substring(b.ano FROM '\d{4}'), '')::int NULLS LAST, b.id, ba.ord
  ) s
 WHERE wk.id = s.work_id AND wk.primary_author_id IS NULL;

-- ---------------------------------------------------------------------
-- 9. Les trois faux positifs arbitres le 04/09 n'y reviendront pas
-- ---------------------------------------------------------------------
INSERT INTO public.work_not_same (work_id_a, work_id_b, reason)
SELECT LEAST(a, b), GREATEST(a, b), r
FROM (VALUES
  (2069, 2351, 'Malatesta : deux textes differents (arbitrage 04/09/2026)'),
  (918,  2291, 'Armand : deux textes differents (arbitrage 04/09/2026)'),
  (177,  2314, 'Graeber : le recueil « e outros ensaios » n''est pas le texte seul (arbitrage 04/09/2026)')
) v(a, b, r)
WHERE EXISTS (SELECT 1 FROM public.works WHERE id = v.a)
  AND EXISTS (SELECT 1 FROM public.works WHERE id = v.b)
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------
-- 10. Garde-fous
-- ---------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.fn_work_prune_if_empty(bigint)',
    'public.merge_works(bigint,bigint)',
    'public.suggest_split_works(integer)',
    'public.mark_works_not_same(bigint,bigint,text)',
    'public.search_works_for_link(text,integer)'
  ] LOOP
    IF has_function_privilege('anon', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'Garde-fou : % reste executable par anon', f;
    END IF;
  END LOOP;
  IF has_function_privilege('authenticated', 'public.fn_work_prune_if_empty(bigint)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : fn_work_prune_if_empty ne doit pas etre exposee';
  END IF;
END $$;

COMMIT;
