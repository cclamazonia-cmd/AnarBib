-- =====================================================================
-- AnarBib — Tests : la règle de casse des titres, SQL et saisie d'accord (C6 §7.2)
-- Date    : 2026-09-27
-- Réf     : public.fn_conv_lower_stopwords (20260821090000_conventions_07_tiret_sous_titre.sql)
--           src/lib/titleCase.js — son miroir côté saisie (bouton « Normaliser la casse »)
--           src/tests/title-case.test.js — les MÊMES cas, passés au JS
--
-- CE QUE CETTE SUITE PROUVE.
--   La fonction SQL rend, sur douze titres, exactement ce que le banc vitest
--   attend du miroir JS. Si l'une des deux implémentations dérive, l'un des
--   deux bancs rougit.
--
-- Convention : bilan « TITLE-CASE OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  ok int := 0; total int := 0; r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('A Revolução Desconhecida', 'pt-BR', 'A Revolução Desconhecida'),
      ('História Do Anarquismo No Brasil', 'pt-BR', 'História do Anarquismo no Brasil'),
      ('La C.N.T. Y La Revolución', 'es', 'La C.N.T. y la Revolución'),
      ('Durruti - Da Revolta a Revolução', 'pt-BR', 'Durruti - Da Revolta a Revolução'),
      ('The Story Of Crass', 'en', 'The Story of Crass'),
      ('Die Revolution Und Der Staat', 'de', 'Die Revolution und der Staat'),
      ('Ελευθερία Και Αναρχία', 'el', 'Ελευθερία Και Αναρχία'),
      ('O Anarquismo: Uma Introdução', 'pt-BR', 'O Anarquismo: Uma Introdução'),
      ('Anarquia  E   Organização', 'pt-BR', 'Anarquia e Organização'),
      ('Capítulo IV Do Livro', 'pt-BR', 'Capítulo IV do Livro'),
      ('Le Monde Et La Guerre Des Classes', 'fr', 'Le Monde et la Guerre des Classes'),
      ('Storia Dell Anarchismo In Italia', 'it', 'Storia Dell Anarchismo in Italia')
    ) c(titre, langue, attendu)
  LOOP
    total := total + 1;
    v := public.fn_conv_lower_stopwords(r.titre, r.langue);
    IF v = r.attendu THEN ok := ok + 1;
    ELSE RAISE WARNING 'casse : « % » (%) → « % », attendu « % »', r.titre, r.langue, v, r.attendu; END IF;
  END LOOP;

  IF ok = total THEN
    RAISE NOTICE 'TITLE-CASE OK : %/% tests passés — la fonction SQL rend ce que le miroir JS attend', ok, total;
  ELSE
    RAISE EXCEPTION 'TITLE-CASE ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
