-- =====================================================================
-- AnarBib -- C18 : Nettlau, deux œuvres distinctes (2036 / 196)
-- Date     : 2026-10-05  ·  Item C18 (backlog v34)
-- Auteur   : Claude (Opus 5.5), à la demande de Xavier
-- Session  : Recherche catalogue — auteur·rice et titres d'œuvre
--
-- CONSTAT. L'œuvre 2036 (La Anarquía a través de los tiempos, Júcar 1978)
-- portait le titre « auto » pt-BR « História da Anarquia » — le titre de
-- l'œuvre 196 (História da anarquia: das origens ao anarco-comunismo, Hedra
-- 2008). Même œuvre ou non ?
--
-- PIÈCE. Page de crédits de l'éd. Hedra, lue par Xavier sur l'exemplaire BLMF
-- (0000083) le 05/10 : aucun « Título original » ; CIP : « Frank Mintz (org.
-- e intro). Plínio Augusto Coêlho (trad.) ». C'est un RECUEIL de textes de
-- Nettlau choisi et présenté par Frank Mintz, pas la traduction d'un livre :
-- une œuvre à part (précédent Thoreau, 20260904095317 : texte seul et
-- œuvre-recueil distincts). Décision de Xavier le 05/10 : distinctes.
--
-- CE QUI EST FAIT
--   · 2036 : son titre pt-BR « auto » devient son titre propre (manual) ;
--     ses autres titres « auto » (A Short History of Anarchism, Histoire de
--     l'anarchie…) sont plausibles et restent ; une note les départage.
--   · 196 : une note dit ce qu'est l'édition.
-- Gardé par l'état constaté le 05/10 ; sur une base sans ces œuvres, rien.
-- =====================================================================

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.works WHERE id = 2036)
     OR NOT EXISTS (SELECT 1 FROM public.works WHERE id = 196)
     OR NOT EXISTS (SELECT 1 FROM public.books WHERE id = 2287 AND work_id = 196 AND editora ILIKE '%Hedra%') THEN
    RAISE NOTICE 'C18 Nettlau : base sans les œuvres du constat, rien à faire.';
    RETURN;
  END IF;

  UPDATE public.work_titles
     SET title = 'La Anarquía a través de los tiempos', source = 'manual', needs_review = false,
         source_book_id = NULL, updated_at = now()
   WHERE work_id = 2036 AND lang = 'pt-BR' AND source = 'auto' AND title = 'História da Anarquia';

  UPDATE public.works
     SET notes = concat_ws(E'\n', NULLIF(btrim(notes), ''),
           'Não confundir com «História da anarquia: das origens ao anarco-comunismo» (Hedra, 2008), obra 196: '
           || 'seleção de textos de Nettlau organizada por Frank Mintz, obra distinta (C18, decisão de 05/10/2026).'),
         updated_at = now()
   WHERE id = 2036 AND coalesce(notes, '') NOT LIKE '%(C18,%';

  UPDATE public.works
     SET notes = concat_ws(E'\n', NULLIF(btrim(notes), ''),
           'Seleção de textos de Max Nettlau organizada e introduzida por Frank Mintz, tradução de Plínio Augusto Coêlho; '
           || 'a edição não indica título original (página de créditos lida em 05/10/2026). '
           || 'Obra distinta de «La Anarquía a través de los tiempos» (obra 2036) (C18, decisão de 05/10/2026).'),
         updated_at = now()
   WHERE id = 196 AND coalesce(notes, '') NOT LIKE '%(C18,%';

  -- Vérification
  IF EXISTS (SELECT 1 FROM public.work_titles WHERE work_id = 2036 AND title ILIKE 'História da Anarquia%') THEN
    RAISE EXCEPTION 'C18 Nettlau : 2036 porte encore le titre de 196';
  END IF;
  IF (SELECT count(*) FROM public.works WHERE id IN (2036, 196) AND notes LIKE '%(C18, decisão de 05/10/2026)%') <> 2 THEN
    RAISE EXCEPTION 'C18 Nettlau : notes absentes';
  END IF;
END $$;

COMMIT;
