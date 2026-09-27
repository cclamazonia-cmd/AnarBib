-- =====================================================================
-- AnarBib — Tests : la casse de la langue, côté base (C6, spec conventions §4.1)
-- Date    : 2026-09-27
-- Réf     : public.fn_conv_casse_titre (20260927154351_c6_la_casse_de_la_langue_cote_base.sql)
--           src/lib/titleCase.js — proposerCasse / normaliserCasse, le bouton de la fiche
--           src/tests/title-case.test.js — les MÊMES cas (CAS_BOUTON, CAS_DICO), passés au JS
--
-- CE QUE CETTE SUITE PROUVE. La fonction SQL qui fait la proposition de la file
-- « titre_casse » rend, cas pour cas, ce que rend le bouton : si l'une des deux
-- implémentations dérive, l'un des deux bancs rougit.
--
-- Convention : bilan « CASSE-TITRE OK : N/N » puis ROLLBACK.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  ok int := 0; total int := 0; r record; v text;
BEGIN
  FOR r IN SELECT * FROM (VALUES
      -- CAS_BOUTON
      ('lE tRuc qui FAIT cHIER', 'fr', false, 'Le truc qui fait chier'),
      ('Le Mouvement Anarchiste En France', 'fr', false, 'Le mouvement anarchiste en France'),
      ('Le mouvement anarchiste en France', 'fr', false, 'Le mouvement anarchiste en France'),
      ('La C.N.T. Y La Revolución', 'es', false, 'La C.N.T. y la revolución'),
      ('La CNT Y La Revolución', 'es', false, 'La CNT y la revolución'),
      ('¿QUÉ ES LA PROPIEDAD?', 'es', false, '¿Qué es la propiedad?'),
      ('Capítulo IV Do Livro XIX', 'pt-BR', false, 'Capítulo IV do livro XIX'),
      ('O Anarquismo: Uma Introdução', 'pt-BR', false, 'O anarquismo: Uma introdução'),
      ('L''ANARCHIE', 'fr', false, 'L''anarchie'),
      ('MI VIDA', 'es', false, 'Mi vida'),
      ('CNT', 'es', false, 'CNT'),
      ('the story of CRASS', 'en', false, 'The Story of Crass'),
      ('A PEOPLE''S HISTORY OF THE UNITED STATES', 'en', false, 'A People''s History of the United States'),
      ('Die Revolution Und Der Staat', 'de', false, 'Die Revolution und der Staat'),
      ('ΕΛΕΥΘΕΡΙΑ ΚΑΙ ΑΝΑΡΧΙΑ', 'el', false, 'Ελευθερια και αναρχια'),
      ('Uma Introdução Ao Tema', 'pt-BR', true, 'uma introdução ao tema'),
      -- CAS_DICO : les noms propres attestés
      ('Tratado Geral Do Brasil', 'pt-BR', false, 'Tratado geral do Brasil'),
      ('La Guerra Civil En España', 'es', false, 'La guerra civil en España'),
      ('Da Escravidao Nos Estados Unidos', 'pt-BR', false, 'Da escravidao nos Estados Unidos'),
      ('Conversaciones Con Bakunin', 'es', false, 'Conversaciones con Bakunin'),
      ('The doctrine of anarchism of Michael A. Bakunin', 'en', false, 'The Doctrine of Anarchism of Michael A. Bakunin'),
      ('Congreso De La Confederación Nacional Del Trabajo', 'es', false, 'Congreso de la Confederación Nacional del Trabajo'),
      ('Anarquismo e Estado', 'pt-BR', false, 'Anarquismo e estado'),
      -- sans règle
      ('Война И Мир', 'ru', false, 'Война И Мир')
    ) c(titre, langue, sous, attendu)
  LOOP
    total := total + 1;
    v := public.fn_conv_casse_titre(r.titre, r.langue, r.sous);
    IF v = r.attendu THEN ok := ok + 1;
    ELSE RAISE WARNING 'casse : « % » (%) → « % », attendu « % »', r.titre, r.langue, v, r.attendu; END IF;
  END LOOP;

  -- Le semeur des titres propose la nouvelle forme
  total := total + 1;
  IF pg_get_functiondef('public.fn_conv_lot_titre_casse_seed()'::regprocedure) ~ 'fn_conv_casse_titre\(b\.titulo, b\.idioma\)' THEN ok := ok + 1;
  ELSE RAISE WARNING 'le semeur ne passe pas par fn_conv_casse_titre'; END IF;

  -- Fermée au navigateur
  total := total + 1;
  IF NOT has_function_privilege('authenticated', 'public.fn_conv_casse_titre(text, text, boolean)', 'EXECUTE')
     AND NOT has_function_privilege('anon', 'public.fn_conv_casse_titre(text, text, boolean)', 'EXECUTE') THEN ok := ok + 1;
  ELSE RAISE WARNING 'fn_conv_casse_titre ouverte au navigateur'; END IF;

  IF ok = total THEN
    RAISE NOTICE 'CASSE-TITRE OK : %/% tests passés — la fonction SQL rend ce que rend le bouton', ok, total;
  ELSE
    RAISE EXCEPTION 'CASSE-TITRE ECHEC : %/% tests passés', ok, total;
  END IF;
END $$;

ROLLBACK;
