-- =====================================================================
-- AnarBib -- Les oeuvres ont un titre par langue (lot 3, OPAC par oeuvre)
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  decisions Xavier du 04/09
-- Depend  : 20260904130000 (merge_works, fn_work_prune_if_empty)
--
-- LA DECISION. Le titre d'une oeuvre s'affiche dans la langue de la lectrice.
-- works.uniform_title est un texte unique ; il fallait une table de titres par
-- locale (decision 2 du 04/09 : table, pas JSON -- une ligne par langue,
-- unicite oeuvre+langue, RLS et audit simples, coherent avec work_expressions).
--
-- TROIS SOURCES, DANS L'ORDRE :
--   manual   : saisi ou corrige a la main au catalogage (set_work_title) ;
--   edition  : le titre d'une edition existante dans cette langue (seme par
--              trigger, suit les corrections de la notice) ;
--   auto     : pre-traduit par l'Edge Function work-titles-autofill, marque
--              needs_review -- « corrige-moi », meme doctrine que les Communs
--              (decision 4 du 04/09). Perimetre : les oeuvres a plusieurs
--              editions, celles dont le titre uniforme s'affiche a l'OPAC ;
--              une oeuvre a une seule edition montre le titre de cette edition.
-- Affichage : fn_work_display_title(oeuvre, locale) = titre dans la locale,
-- sinon titre d'une edition dans cette langue, sinon uniform_title.
--
-- Checklist _TEMPLATE.sql : table publique lisible par anon (donnee de
-- catalogue), aucune policy d'ecriture (RPC DEFINER), fonctions revoquees de
-- PUBLIC/anon/authenticated puis accordees au role cible. Idempotent, sur en
-- CI (le banc a un stub cron et un stub vault ; la lecture vault reste dans le
-- corps de la fonction appelee par le cron, jamais au moment de la migration).
-- =====================================================================

BEGIN;

-- ---------------------------------------------------------------------
-- 1. La table
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.work_titles (
  work_id        bigint NOT NULL REFERENCES public.works(id) ON DELETE CASCADE,
  lang           text   NOT NULL CHECK (lang IN ('pt-BR','fr','es','it','en','de','ca','eo','nl','el')),
  title          text   NOT NULL CHECK (btrim(title) <> ''),
  source         text   NOT NULL DEFAULT 'manual' CHECK (source IN ('manual','edition','auto')),
  source_book_id bigint REFERENCES public.books(id) ON DELETE SET NULL,
  needs_review   boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (work_id, lang)
);
COMMENT ON TABLE public.work_titles IS
  'Titre d''une oeuvre par locale de l''app. source = manual (catalogage) | edition (titre d''une edition dans '
  'cette langue, seme par trigger) | auto (pre-traduction, needs_review = « corrige-moi »). Lot 3 OPAC par oeuvre, 04/09/2026.';

-- La garde fk_sans_index_garde_tests exige un index par FK.
CREATE INDEX IF NOT EXISTS work_titles_source_book_id_idx ON public.work_titles (source_book_id);

ALTER TABLE public.work_titles ENABLE ROW LEVEL SECURITY;
-- Les ALTER DEFAULT PRIVILEGES de Supabase donnent TOUT a anon/authenticated
-- sur une table neuve : on ne garde que la lecture.
REVOKE ALL ON public.work_titles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.work_titles TO anon, authenticated;
GRANT ALL    ON public.work_titles TO service_role;
DROP POLICY IF EXISTS work_titles_read_all ON public.work_titles;
CREATE POLICY work_titles_read_all ON public.work_titles FOR SELECT TO anon, authenticated USING (true);
-- Aucune policy d'ecriture : set_work_title et l'autofill (DEFINER) seulement.

ALTER TABLE public.works
  ADD COLUMN IF NOT EXISTS titles_autofill_at    timestamptz,
  ADD COLUMN IF NOT EXISTS titles_autofill_error text;
COMMENT ON COLUMN public.works.titles_autofill_at IS
  'Derniere tentative de pre-traduction des titres (work-titles-autofill). Une erreur se reessaie apres 7 jours.';

-- ---------------------------------------------------------------------
-- 2. De la langue d'une notice a une locale de l'app
-- ---------------------------------------------------------------------
-- books.idioma porte un code BCP-47 (CONV-7), avec un residu libre. On ne
-- reconnait que ce qui se projette sur une des dix locales.
CREATE OR REPLACE FUNCTION public.fn_locale_from_idioma(p_idioma text)
RETURNS text
LANGUAGE sql IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE
    WHEN v IN ('pt-br','pt','pt-pt','por')  THEN 'pt-BR'
    WHEN v IN ('fr','fra','fre','fr-fr','fr-be','fr-ca') THEN 'fr'
    WHEN v IN ('es','spa','es-es','es-ar','es-mx') THEN 'es'
    WHEN v IN ('it','ita','it-it')          THEN 'it'
    WHEN v IN ('en','eng','en-us','en-gb')  THEN 'en'
    WHEN v IN ('de','ger','deu','de-de')    THEN 'de'
    WHEN v IN ('ca','cat')                  THEN 'ca'
    WHEN v IN ('eo','epo')                  THEN 'eo'
    WHEN v IN ('nl','nld','dut')            THEN 'nl'
    WHEN v IN ('el','ell','gre')            THEN 'el'
    ELSE NULL END
  FROM (SELECT lower(btrim(COALESCE(p_idioma, ''))) AS v) s;
$$;

-- ---------------------------------------------------------------------
-- 3. Le titre affiche
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_work_display_title(p_work_id bigint, p_lang text)
RETURNS text
LANGUAGE sql STABLE
SET search_path = public, pg_catalog
AS $$
  SELECT COALESCE(
    (SELECT wt.title FROM public.work_titles wt WHERE wt.work_id = p_work_id AND wt.lang = p_lang),
    (SELECT b.titulo FROM public.books b
      WHERE b.work_id = p_work_id AND public.fn_locale_from_idioma(b.idioma) = p_lang
      ORDER BY NULLIF(substring(b.ano FROM '\d{4}'), '')::int NULLS LAST, b.id LIMIT 1),
    (SELECT w.uniform_title FROM public.works w WHERE w.id = p_work_id));
$$;
GRANT EXECUTE ON FUNCTION public.fn_work_display_title(bigint, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.fn_locale_from_idioma(text) TO anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Les titres d'edition se sement tout seuls
-- ---------------------------------------------------------------------
-- Pour chaque langue portee par une notice de l'oeuvre : une ligne
-- source='edition' (la plus ancienne edition de cette langue), sauf si une
-- ligne manuelle existe. Une ligne 'auto' cede la place a une vraie edition.
-- Les lignes 'edition' dont la langue n'a plus de notice disparaissent.
CREATE OR REPLACE FUNCTION public.fn_work_titles_reseed(p_work_id bigint)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF p_work_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.works WHERE id = p_work_id) THEN RETURN; END IF;

  DELETE FROM public.work_titles wt
   WHERE wt.work_id = p_work_id AND wt.source = 'edition'
     AND NOT EXISTS (SELECT 1 FROM public.books b
                      WHERE b.work_id = p_work_id AND public.fn_locale_from_idioma(b.idioma) = wt.lang
                        AND NULLIF(btrim(b.titulo), '') IS NOT NULL);

  INSERT INTO public.work_titles (work_id, lang, title, source, source_book_id, needs_review)
  SELECT p_work_id, s.lang, s.titulo, 'edition', s.book_id, false
    FROM (
      SELECT DISTINCT ON (public.fn_locale_from_idioma(b.idioma))
             public.fn_locale_from_idioma(b.idioma) AS lang, b.titulo, b.id AS book_id
        FROM public.books b
       WHERE b.work_id = p_work_id
         AND public.fn_locale_from_idioma(b.idioma) IS NOT NULL
         AND NULLIF(btrim(b.titulo), '') IS NOT NULL
       ORDER BY public.fn_locale_from_idioma(b.idioma), NULLIF(substring(b.ano FROM '\d{4}'), '')::int NULLS LAST, b.id
    ) s
  ON CONFLICT (work_id, lang) DO UPDATE
     SET title = EXCLUDED.title, source = 'edition', source_book_id = EXCLUDED.source_book_id,
         needs_review = false, updated_at = now()
   WHERE public.work_titles.source IN ('edition', 'auto');
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_work_titles_reseed(bigint) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.trg_books_reseed_work_titles()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') AND OLD.work_id IS NOT NULL
     AND (TG_OP = 'DELETE' OR OLD.work_id IS DISTINCT FROM NEW.work_id) THEN
    PERFORM public.fn_work_titles_reseed(OLD.work_id);
  END IF;
  IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.work_id IS NOT NULL THEN
    PERFORM public.fn_work_titles_reseed(NEW.work_id);
  END IF;
  RETURN NULL;
END;
$$;
-- Une fonction trigger n'a besoin d'aucun grant (privilege verifie a la
-- creation du trigger, jamais au declenchement) ; les ALTER DEFAULT PRIVILEGES
-- l'ouvriraient a anon, ce que la garde grants_herites_tests (T10) refuse.
REVOKE EXECUTE ON FUNCTION public.trg_books_reseed_work_titles() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS trg_books_reseed_work_titles ON public.books;
CREATE TRIGGER trg_books_reseed_work_titles
  AFTER INSERT OR DELETE OR UPDATE OF work_id, titulo, idioma ON public.books
  FOR EACH ROW EXECUTE FUNCTION public.trg_books_reseed_work_titles();

-- Rattrapage : toutes les oeuvres existantes (silencieux sur base vide).
SELECT public.fn_work_titles_reseed(w.id) FROM public.works w;

-- ---------------------------------------------------------------------
-- 5. Saisir ou corriger un titre (catalogage)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_work_title(p_work_id bigint, p_lang text, p_title text)
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
  IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = p_work_id) THEN
    RAISE EXCEPTION 'Obra inexistente.' USING ERRCODE = 'P0002', HINT = 'error.catalog.work.notFound';
  END IF;
  IF p_lang IS NULL OR p_lang <> ALL (ARRAY['pt-BR','fr','es','it','en','de','ca','eo','nl','el']) THEN
    RAISE EXCEPTION 'Locale desconhecida.' USING ERRCODE = 'P0001', HINT = 'error.catalog.work.badLocale';
  END IF;
  IF NULLIF(btrim(COALESCE(p_title, '')), '') IS NULL THEN
    -- Effacer la saisie manuelle : le titre d'edition ou uniforme reprend.
    DELETE FROM public.work_titles WHERE work_id = p_work_id AND lang = p_lang;
    PERFORM public.fn_work_titles_reseed(p_work_id);
    RETURN;
  END IF;
  INSERT INTO public.work_titles (work_id, lang, title, source, source_book_id, needs_review)
  VALUES (p_work_id, p_lang, btrim(p_title), 'manual', NULL, false)
  ON CONFLICT (work_id, lang) DO UPDATE
     SET title = EXCLUDED.title, source = 'manual', source_book_id = NULL, needs_review = false, updated_at = now();
  UPDATE public.works SET updated_at = now() WHERE id = p_work_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.set_work_title(bigint, text, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.set_work_title(bigint, text, text) TO authenticated;

-- ---------------------------------------------------------------------
-- 6. La pre-traduction : ce qui reste a faire, et comment le poser
-- ---------------------------------------------------------------------
-- Service seulement (l'Edge Function work-titles-autofill, avec la cle
-- secrete). Une oeuvre est « en attente » quand elle a au moins deux editions,
-- au moins un titre de depart, des locales manquantes, et pas de tentative
-- recente (7 jours : une erreur ne se rejoue pas toutes les dix minutes).
CREATE OR REPLACE FUNCTION public.fn_work_titles_pending(p_limit integer DEFAULT 5)
RETURNS TABLE(work_id bigint, uniform_title text, author_name text, titles jsonb, editions jsonb, missing text[])
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
  WITH locales AS (SELECT unnest(ARRAY['pt-BR','fr','es','it','en','de','ca','eo','nl','el']) AS lang),
  cand AS (
    SELECT w.id, w.uniform_title, w.primary_author_id
      FROM public.works w
     WHERE (SELECT count(*) FROM public.books b WHERE b.work_id = w.id) >= 2
       AND EXISTS (SELECT 1 FROM public.work_titles t WHERE t.work_id = w.id)
       AND (SELECT count(*) FROM public.work_titles t WHERE t.work_id = w.id) < 10
       AND (w.titles_autofill_at IS NULL OR w.titles_autofill_at < now() - interval '7 days')
     ORDER BY w.titles_autofill_at NULLS FIRST, w.id
     LIMIT GREATEST(COALESCE(p_limit, 5), 1)
  )
  SELECT c.id, c.uniform_title, a.preferred_name,
         COALESCE((SELECT jsonb_object_agg(t.lang, jsonb_build_object('title', t.title, 'source', t.source))
                     FROM public.work_titles t WHERE t.work_id = c.id), '{}'::jsonb),
         COALESCE((SELECT jsonb_agg(jsonb_build_object('titulo', b.titulo, 'idioma', b.idioma, 'ano', b.ano, 'editora', b.editora)
                                     ORDER BY b.id)
                     FROM public.books b WHERE b.work_id = c.id), '[]'::jsonb),
         ARRAY(SELECT l.lang FROM locales l
                WHERE NOT EXISTS (SELECT 1 FROM public.work_titles t WHERE t.work_id = c.id AND t.lang = l.lang)
                ORDER BY l.lang)
    FROM cand c
    LEFT JOIN public.authors a ON a.id = c.primary_author_id;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_work_titles_pending(integer) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_work_titles_pending(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.fn_work_titles_autofill_apply(p_work_id bigint, p_titles jsonb, p_error text DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE v_n integer := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = p_work_id) THEN RETURN 0; END IF;
  IF p_error IS NULL AND jsonb_typeof(COALESCE(p_titles, 'null'::jsonb)) = 'object' THEN
    INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
    SELECT p_work_id, kv.key, btrim(kv.value), 'auto', true
      FROM jsonb_each_text(p_titles) kv
     WHERE kv.key = ANY (ARRAY['pt-BR','fr','es','it','en','de','ca','eo','nl','el'])
       AND NULLIF(btrim(kv.value), '') IS NOT NULL
    ON CONFLICT (work_id, lang) DO NOTHING;   -- jamais par-dessus manual / edition
    GET DIAGNOSTICS v_n = ROW_COUNT;
  END IF;
  UPDATE public.works
     SET titles_autofill_at = now(), titles_autofill_error = LEFT(p_error, 500)
   WHERE id = p_work_id;
  RETURN v_n;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_work_titles_autofill_apply(bigint, jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.fn_work_titles_autofill_apply(bigint, jsonb, text) TO service_role;

-- Le cron appelle l'Edge Function, avec le secret partage des crons de la
-- gazette (meme domaine de confiance : pg_cron -> nos fonctions). Rien a
-- faire s'il n'y a rien en attente.
CREATE OR REPLACE FUNCTION public.fn_work_titles_autofill_call()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_url    text := 'https://uflwmikiyjfnikiphtcp.supabase.co/functions/v1/work-titles-autofill';
  v_secret text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.fn_work_titles_pending(1)) THEN RETURN; END IF;
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'gazette_cron_secret';
  PERFORM net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'X-Cron-Secret', COALESCE(v_secret, '')),
    body    := '{}'::jsonb
  );
END;
$$;
REVOKE EXECUTE ON FUNCTION public.fn_work_titles_autofill_call() FROM PUBLIC, anon, authenticated;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'anarbib-work-titles-autofill';
SELECT cron.schedule('anarbib-work-titles-autofill', '*/10 * * * *', $$select public.fn_work_titles_autofill_call()$$);

-- ---------------------------------------------------------------------
-- 7. merge_works emporte les titres manuels de la source
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

  -- Les titres saisis a la main sur la source survivent si la cible n'en a pas.
  INSERT INTO public.work_titles (work_id, lang, title, source, needs_review)
  SELECT p_target_work_id, t.lang, t.title, 'manual', false
    FROM public.work_titles t WHERE t.work_id = p_source_work_id AND t.source = 'manual'
  ON CONFLICT (work_id, lang) DO UPDATE
     SET title = EXCLUDED.title, source = 'manual', source_book_id = NULL, needs_review = false, updated_at = now()
   WHERE public.work_titles.source <> 'manual';

  UPDATE public.books              SET work_id = p_target_work_id WHERE work_id = p_source_work_id;
  UPDATE public.book_drafts        SET work_id = p_target_work_id WHERE work_id = p_source_work_id;
  UPDATE public.audio_tracks       SET work_id = p_target_work_id WHERE work_id = p_source_work_id;
  UPDATE public.book_reading_notes SET work_id = p_target_work_id WHERE work_id = p_source_work_id;

  UPDATE public.works
     SET primary_author_id = COALESCE(v_tgt.primary_author_id, v_src.primary_author_id),
         notes = CASE
                   WHEN NULLIF(v_src.notes, '') IS NULL THEN v_tgt.notes
                   WHEN NULLIF(v_tgt.notes, '') IS NULL THEN v_src.notes
                   ELSE v_tgt.notes || E'\n' || v_src.notes
                 END,
         updated_at = now()
   WHERE id = p_target_work_id;

  PERFORM public.fn_work_prune_if_empty(p_source_work_id);

  DELETE FROM public.work_expressions we
   WHERE we.work_id = p_target_work_id
     AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.expression_id = we.id);
  PERFORM public.fn_work_titles_reseed(p_target_work_id);

  RETURN p_target_work_id;
END;
$$;

-- ---------------------------------------------------------------------
-- 8. La page Oeuvre recoit le titre affiche et les titres par langue
-- ---------------------------------------------------------------------
-- Le front appelle work_public_detail avec p_work_id seul : une surcharge
-- rendrait l'appel ambigu pour PostgREST. On remplace donc la signature.
DROP FUNCTION IF EXISTS api.work_public_detail(bigint);
CREATE OR REPLACE FUNCTION api.work_public_detail(p_work_id bigint, p_lang text DEFAULT NULL)
RETURNS jsonb
LANGUAGE sql STABLE
SET search_path = public, pg_catalog
AS $$
  WITH rows AS (
    SELECT c.book_id, c.titulo, c.ano, c.editora, b.idioma, c.cover_object_path, c.bib_ref, b.expression_id
    FROM api.catalog_list_anon_v1 c
    JOIN public.books b ON b.id = c.book_id
    WHERE b.work_id = p_work_id
  ),
  eds AS (SELECT count(*) n FROM rows),
  trans AS (
    SELECT r.expression_id AS eid,
           jsonb_agg(DISTINCT jsonb_build_object('author_id', a2.id, 'name', a2.preferred_name)) tr
    FROM rows r
    JOIN public.book_contributors bc ON bc.book_id = r.book_id AND bc.role = 'tradutor' AND bc.author_id IS NOT NULL
    JOIN public.authors a2 ON a2.id = bc.author_id
    GROUP BY r.expression_id
  ),
  flat AS (
    SELECT jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref)
           ORDER BY NULLIF(substring(r.ano FROM '\d{4}'), '')::int NULLS LAST, r.titulo) arr
    FROM rows r
  ),
  expr AS (
    SELECT jsonb_agg(g.e ORDER BY g.lang) arr FROM (
      SELECT COALESCE(we.lang, '') AS lang,
        jsonb_build_object('lang', COALESCE(we.lang, ''),
          'editions', jsonb_agg(jsonb_build_object('book_id', r.book_id, 'titulo', r.titulo, 'ano', r.ano, 'editora', r.editora, 'idioma', r.idioma, 'cover_object_path', r.cover_object_path, 'bib_ref', r.bib_ref)
            ORDER BY NULLIF(substring(r.ano FROM '\d{4}'), '')::int NULLS LAST, r.titulo),
          'translators', COALESCE((SELECT tr FROM trans WHERE trans.eid = r.expression_id), '[]'::jsonb)) AS e
      FROM rows r LEFT JOIN public.work_expressions we ON we.id = r.expression_id
      GROUP BY r.expression_id, COALESCE(we.lang, '')
    ) g
  ),
  titles AS (
    SELECT COALESCE(jsonb_object_agg(t.lang, jsonb_build_object('title', t.title, 'source', t.source, 'needs_review', t.needs_review)), '{}'::jsonb) obj
    FROM public.work_titles t WHERE t.work_id = p_work_id
  )
  SELECT CASE WHEN (SELECT n FROM eds) = 0 THEN NULL
    ELSE jsonb_build_object(
      'id', w.id, 'uniform_title', w.uniform_title,
      'display_title', public.fn_work_display_title(w.id, COALESCE(NULLIF(p_lang, ''), 'pt-BR')),
      'titles', (SELECT obj FROM titles),
      'primary_author_id', w.primary_author_id, 'author_name', a.preferred_name,
      'editions', COALESCE((SELECT arr FROM flat), '[]'::jsonb),
      'expressions', COALESCE((SELECT arr FROM expr), '[]'::jsonb)
    ) END
  FROM public.works w
  LEFT JOIN public.authors a ON a.id = w.primary_author_id
  WHERE w.id = p_work_id;
$$;
GRANT EXECUTE ON FUNCTION api.work_public_detail(bigint, text) TO anon, authenticated;

-- ---------------------------------------------------------------------
-- 9. Garde-fous
-- ---------------------------------------------------------------------
DO $$
DECLARE f text;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.fn_work_titles_reseed(bigint)',
    'public.set_work_title(bigint,text,text)',
    'public.fn_work_titles_pending(integer)',
    'public.fn_work_titles_autofill_apply(bigint,jsonb,text)',
    'public.fn_work_titles_autofill_call()',
    'public.merge_works(bigint,bigint)'
  ] LOOP
    IF has_function_privilege('anon', f, 'EXECUTE') THEN
      RAISE EXCEPTION 'Garde-fou : % reste executable par anon', f;
    END IF;
  END LOOP;
  IF has_function_privilege('authenticated', 'public.fn_work_titles_pending(integer)', 'EXECUTE')
  OR has_function_privilege('authenticated', 'public.fn_work_titles_autofill_apply(bigint,jsonb,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : l''autofill est reserve au service';
  END IF;
  IF NOT has_function_privilege('anon', 'api.work_public_detail(bigint,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : la page Oeuvre doit rester publique';
  END IF;
END $$;

COMMIT;
