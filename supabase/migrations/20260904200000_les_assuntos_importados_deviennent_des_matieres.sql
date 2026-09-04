-- =====================================================================
-- AnarBib -- Les « Assuntos importados » deviennent des matieres quand le thesaurus les a
-- Date    : 2026-09-04  ·  demande Xavier (soir)
--
-- 245 notices MLEG portent pour seule indexation une note d'import
-- « Assuntos importados: <categorie> » (douze categories de rayon). Regle de
-- Xavier : convertir en matiere EXISTANTE du thesaurus quand la correspondance
-- est exacte, ne JAMAIS creer d'entree ; ce qui ne se convertit pas reste en
-- attente, la note continue de porter l'information.
--
-- Quatre categories ont leur matiere :
--   Revolucao Espanhola  -> revolucao-espanhola
--   Sindicalismo         -> sindicalismo
--   Mulheres Anarquistas -> mulheres-anarquistas
--   Pedagogia Libertaria -> educacao-libertaria (l'entree « pedagogia-libertaria »
--                           du thesaurus est DEPRECIEE, sans usage : c'est la meme)
-- Huit restent en attente, la note reste : Anarquismo no Brasil (50),
-- Anarquismo Internacional (42), Classicos Anarquistas (35), Transversais (21),
-- Ciencias Humanas (14), Literatura Libertaria (6), Edgar Rodrigues (5, un
-- auteur, pas un sujet), Coletaneas (3). Convertir « Anarquismo no Brasil » en
-- « Anarquismo » perdrait la geographie : on ne le fait pas.
--
-- Au passage, les 43 residus « resumo=… » / « url=… » de l'import BTL perdent
-- leur prefixe technique. Brouillons publies alignes (une reprise repartirait
-- sinon de la note). Idempotent ; le garde-fou verifie qu'aucune matiere n'est nee.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  v_subjects_avant int; v_subjects_apres int;
  m record; r record; v_sid bigint; v_n int := 0;
BEGIN
  SELECT count(*) INTO v_subjects_avant FROM public.subjects;

  FOR m IN SELECT * FROM (VALUES
      ('Revolução Espanhola',  'revolucao-espanhola'),
      ('Sindicalismo',         'sindicalismo'),
      ('Mulheres Anarquistas', 'mulheres-anarquistas'),
      ('Pedagogia Libertária', 'educacao-libertaria')
    ) v(label, slug) LOOP
    SELECT id INTO v_sid FROM public.subjects WHERE slug = m.slug AND status = 'ativo';
    IF v_sid IS NULL THEN
      RAISE NOTICE 'Matiere % absente ou inactive : categorie « % » laissee en attente', m.slug, m.label;
      CONTINUE;
    END IF;
    FOR r IN
      SELECT b.id
        FROM public.books b
       WHERE lower(extensions.unaccent(b.notas)) ~ ('(^|\n)\s*assuntos importados:\s*' || lower(extensions.unaccent(m.label)) || '\s*(\n|$)')
    LOOP
      INSERT INTO public.book_subjects (book_id, subject_id, ord)
      SELECT r.id, v_sid, COALESCE((SELECT max(ord) FROM public.book_subjects WHERE book_id = r.id), 0) + 1
       WHERE NOT EXISTS (SELECT 1 FROM public.book_subjects WHERE book_id = r.id AND subject_id = v_sid);
      UPDATE public.books
         SET notas = NULLIF(btrim(regexp_replace(notas, '(^|\n)\s*Assuntos importados:\s*' || m.label || '\s*(\n|$)', '\1', 'gi'), E' \n\r\t'), '')
       WHERE id = r.id;
      UPDATE public.book_drafts
         SET notas = NULLIF(btrim(regexp_replace(notas, '(^|\n)\s*Assuntos importados:\s*' || m.label || '\s*(\n|$)', '\1', 'gi'), E' \n\r\t'), '')
       WHERE published_book_id = r.id AND notas ~* 'Assuntos importados';
      v_n := v_n + 1;
    END LOOP;
  END LOOP;

  -- Les residus « resumo= » / « url= » perdent leur prefixe technique.
  UPDATE public.books
     SET notas = regexp_replace(notas, '(^|\n)(resumo|url)=', '\1', 'g')
   WHERE notas ~ '(^|\n)(resumo|url)=';
  UPDATE public.book_drafts
     SET notas = regexp_replace(notas, '(^|\n)(resumo|url)=', '\1', 'g')
   WHERE notas ~ '(^|\n)(resumo|url)=';

  SELECT count(*) INTO v_subjects_apres FROM public.subjects;
  IF v_subjects_apres <> v_subjects_avant THEN
    RAISE EXCEPTION 'Garde-fou : le thesaurus a change (% -> %)', v_subjects_avant, v_subjects_apres;
  END IF;
  RAISE NOTICE 'Assuntos importados : % notice(s) converties, % en attente.',
    v_n, (SELECT count(*) FROM public.books WHERE notas ~* 'Assuntos importados');
END $$;

COMMIT;
