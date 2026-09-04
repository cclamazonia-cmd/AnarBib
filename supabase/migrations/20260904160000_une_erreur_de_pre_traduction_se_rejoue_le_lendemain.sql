-- =====================================================================
-- AnarBib -- Une erreur de pre-traduction se rejoue le lendemain
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre  ·  decision Xavier (fin de journee)
-- Depend  : 20260904130100 (fn_work_titles_pending)
--
-- Le premier quart d'heure de l'autofill a montre une erreur « Overloaded »
-- du modele : transitoire, quelques minutes. Le delai de reprise etait de
-- sept jours -- une semaine sans titre pour une oeuvre a cause d'une minute
-- d'encombrement. Xavier tranche : un jour. Meme corps, une seule ligne change.
-- =====================================================================

BEGIN;

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
       AND (w.titles_autofill_at IS NULL OR w.titles_autofill_at < now() - interval '1 day')
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

COMMENT ON COLUMN public.works.titles_autofill_at IS
  'Derniere tentative de pre-traduction des titres (work-titles-autofill). Une erreur se reessaie apres 1 jour (decision du 04/09/2026).';

DO $$
BEGIN
  IF has_function_privilege('anon', 'public.fn_work_titles_pending(integer)', 'EXECUTE')
  OR has_function_privilege('authenticated', 'public.fn_work_titles_pending(integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'Garde-fou : fn_work_titles_pending reste reservee au service';
  END IF;
END $$;

COMMIT;
