-- =====================================================================
-- AnarBib -- Trente groupes d'oeuvres scindees, arbitres le 04/09/2026
-- Date    : 2026-09-04  ·  Chantier OPAC par oeuvre (lot 1 : donnees)
-- Depend  : 20260831124714 (fn_editions_distinctes) et du backfill d'oeuvres du 20/06
--
-- CONSTAT : fn_books_ensure_work cree une oeuvre par notice publiee et rien ne
-- les rapproche ensuite. Les huit « Desobediencia civil » de Thoreau vivaient
-- sur six oeuvres. Une heuristique (meme auteur principal + 14 premiers
-- caracteres du titre normalise) a sorti 30 groupes / 68 fiches d'oeuvre ;
-- Xavier a arbitre chaque groupe sur l'export du 04/09 (scratchpad
-- arbitrage-oeuvres-scindees-2026-09-04.md). Cette migration APPLIQUE ses
-- decisions, rien d'autre : aucune fusion n'est decidee par script.
--
-- CE QUI EST FAIT
--   1. quatre notices recoivent leur langue (2467, 2192, 2549 -> pt-BR ; 2361 -> es)
--      AVANT le deplacement, pour que l'expression FRBR se cree dans la bonne langue ;
--   2. 31 notices changent d'oeuvre (UPDATE books.work_id, ce que fait
--      assign_book_to_work sans sa garde auth.uid(), inoperante en migration) ;
--   3. coquilles corrigees sur 10 notices et 5 titres uniformes, parenthese de
--      Colonia Cecilia rangee en sous-titre, meme correction reportee sur les
--      brouillons publies correspondants (sinon une reprise efface en silence) ;
--   4. trois oeuvres recoivent une note expliquant la variation de titre ;
--   5. 35 oeuvres devenues vides (dont 5 qui l'etaient deja) sont supprimees,
--      chacune verifiee sans notice, brouillon, piste audio ni note de lecture ;
--   6. les expressions FRBR orphelines des oeuvres cibles sont purgees.
--
-- CE QUI N'EST PAS FAIT (releve de l'assistant de doublons, pas des oeuvres)
--   - 1458/2333 (Deriva 2011), 1451/1446 (Sade), 1359/1353 (Campo) : meme
--     edition cataloguee deux fois, a fusionner comme NOTICES ;
--   - doctrine « oeuvre-serie » retenue pour les tomes (Mechoso 38, Hugh Thomas 16) ;
--     la notice BTL 375 ne dit pas quel tome elle est (I ou IV) ;
--   - l'autorite « Anoar Aiex » sur l'oeuvre 178 : le texte est de Raoul
--     Vaneigem (Ratgeb), a revoir au catalogage.
--
-- IDEMPOTENT ET SUR EN CI : chaque geste est garde par l'etat constate le
-- 04/09 (la notice est bien sur l'oeuvre source, le titre est bien la coquille).
-- Un geste dont l'etat a change est SAUTE avec un avertissement, jamais force.
-- Sur une base vide (banc d'essai), tout est saute.
-- =====================================================================

BEGIN;

DO $$
DECLARE
  -- [notice, oeuvre source, oeuvre cible]
  moves bigint[][] := ARRAY[
    [2642,2152,2335],  -- grp 2  Bookchin, O Bairro, a Comuna, a Cidade (MLEG -> BTL)
    [691,1811,1300],   -- grp 3  Bayer, Anarquistas expropriadores (pt-BR)
    [1287,2118,1300],  -- grp 3  Bayer (es, Recortes 2009)
    [2283,2368,1300],  -- grp 3  Bayer (es, Planeta)
    [2493,879,38],     -- grp 4  Mechoso, tomo III (MLEG) -> oeuvre-serie
    [2492,2260,38],    -- grp 4  Mechoso, tomo II (MLEG)
    [2494,2261,38],    -- grp 4  Mechoso, tomo IV (MLEG)
    [2654,2164,936],   -- grp 6  Leuenroth, Maximalismo ou Bolchevismo (Entremares 2017)
    [1463,2213,936],   -- grp 6  Leuenroth (1919)
    [1217,1522,1163],  -- grp 8  Goldman, L'Epopee d'une anarchiste (Complexe 1984)
    [1458,1690,64],    -- grp 10 Graeber, Fragmentos (Deriva 2011, BTL)
    [514,2371,1343],   -- grp 11 Joyeux, Autogestao (A Batalha 1975)
    [1322,1174,317],   -- grp 12 Neill, Liberdade sem medo (IBRASA 1970)
    [2070,2127,1014],  -- grp 13 Fabbri, Socialismo, dictadura y revolucion (FAU 1964)
    [1300,1077,504],   -- grp 15 Tucci Carneiro, Livros proibidos (Estacao Liberdade 1997)
    [2192,2377,97],    -- grp 16 Thoreau, A desobediencia civil (Antigona 1987) -> texte seul
    [983,387,1867],    -- grp 17 Thoreau, ... y otros textos (Terramar 2009) -> oeuvre-recueil
    [2467,2251,1867],  -- grp 16 Thoreau, ... & outros escritos (Martin Claret 2011) -> oeuvre-recueil
    [291,2263,1179],   -- grp 18 Goncalves, A imprensa libertaria no Ceara (BTL)
    [1586,2481,2480],  -- grp 19 Santana, Memoria de um militante
    [2474,571,16],     -- grp 20 Hugh Thomas, vol. II (MLEG) -> oeuvre-serie
    [2473,2256,16],    -- grp 20 Hugh Thomas, vol. I (MLEG)
    [1400,2139,119],   -- grp 21 Archinov, Historia del movimiento makhnovista (Tupac/LaMalatesta)
    [2624,2300,2444],  -- grp 22 Home, Manifesto neoista (MLEG)
    [2533,95,427],     -- grp 23 Pallottini, Colonia Cecilia (MLEG-0076)
    [2534,95,427],     -- grp 23 Pallottini, Colonia Cecilia (MLEG-0077)
    [2351,241,1316],   -- grp 24 Reich, Psicologia de massa do fascismo (Escorpiao 1974)
    [1446,875,844],    -- grp 25 Sade, Franceses, mais um esforco (BTL-TL-001540)
    [815,1381,178],    -- grp 26 Vaneigem/Ratgeb, De la huelga salvaje (Mariposas del Caos 1974)
    [1353,1095,235],   -- grp 27 Campo, Las ideas libertarias y el tango (BTL-TL-001440)
    [793,2228,1403]    -- grp 28 Kassick, A pedagogia libertaria (Achiame 2000)
  ];
  -- [notice, ancien titre, nouveau titre]
  titles text[][] := ARRAY[
    ['1463', 'O que é Maximismo o Bolchevismo',                          'O que é Maximismo ou Bolchevismo'],
    ['1217', 'L''Epopee d''une Anarchiste',                              'L''Épopée d''une Anarchiste'],
    ['2640', 'O Anarquismo no Sec.XXI',                                  'O Anarquismo no Sec. XXI'],
    ['1588', 'Max Stirner E O Anarquismo Individualista',                'Max Stirner e o Anarquismo individualista'],
    ['1300', 'Livros Poribidos, Ideias Malditas',                        'Livros Proibidos, Ideias Malditas'],
    ['1400', 'Historia del Movimento Makhnovista',                       'Historia del Movimiento Makhnovista'],
    ['1446', 'Franceses, mais um esforço se quiseredes ser republicanos', 'Franceses, mais um esforço se quiserdes ser republicanos'],
    ['1353', 'Las ideas libetarias y la cuestión social en el tango',    'Las ideas libertarias y la cuestión social en el tango']
  ];
  -- [oeuvre, ancien titre uniforme, nouveau titre uniforme]
  wtitles text[][] := ARRAY[
    ['2335', 'O Bairro, a Comuna, a Cidade... Espaçs Libertários!', 'O Bairro, a Comuna, a Cidade... Espaços Libertários'],
    ['918',  'Max Stirner E O Anarquismo Individualista',           'Max Stirner e o Anarquismo individualista'],
    ['64',   'Fragmentos de Antropología Anarquista',               'Fragmentos de Antropologia anarquista'],
    ['2314', 'O Anarquismo no Sec.XXI',                             'O Anarquismo no Sec. XXI'],
    ['119',  'Historia Del Movimiento Makhnovista',                 'Historia del Movimiento Makhnovista (1918-1921)']
  ];
  -- oeuvres a supprimer une fois vides (30 videes par les deplacements + 5 deja vides)
  doomed bigint[] := ARRAY[2152,2342,1811,2118,2368,879,2260,2261,51,2164,2213,1948,1522,1690,2371,1174,
                           2127,1077,2377,387,2251,2263,2481,571,2256,2139,2300,95,241,875,1381,1095,2228,159,2155];
  targets bigint[] := ARRAY[2335,1300,38,936,1163,64,1343,317,1014,504,97,1867,1179,2480,16,119,2444,427,1316,844,178,235,1403];
  i int;
  n_moved int := 0; n_titles int := 0; n_wtitles int := 0; n_deleted int := 0; n_expr int := 0; n_lang int := 0; n_drafts int := 0;
  v_report text := '';
BEGIN
  -- Garde banc d'essai : sans la notice pivot de Thoreau, la base n'est pas la prod.
  IF NOT EXISTS (SELECT 1 FROM public.books WHERE id = 977 AND work_id = 97) THEN
    RAISE NOTICE 'Fusion des oeuvres scindees : base sans les donnees du constat, rien a faire.';
    RETURN;
  END IF;

  -- 1. Langues (avant les deplacements : l'expression FRBR se cree sur NEW.idioma)
  UPDATE public.books SET idioma = 'pt-BR' WHERE id IN (2467, 2192, 2549) AND idioma IS NULL;
  GET DIAGNOSTICS n_lang = ROW_COUNT;
  UPDATE public.books SET idioma = 'es' WHERE id = 2361 AND idioma IS NULL;
  n_lang := n_lang + (SELECT count(*) FROM public.books WHERE id = 2361 AND idioma = 'es');
  UPDATE public.book_drafts SET idioma = 'pt-BR' WHERE id IN (502, 471) AND published_book_id IN (2467, 2549) AND idioma IS NULL;

  -- 2. Deplacements notice -> oeuvre cible, gardes par l'oeuvre source constatee
  FOR i IN 1 .. array_length(moves, 1) LOOP
    UPDATE public.books SET work_id = moves[i][3]
     WHERE id = moves[i][1] AND work_id = moves[i][2]
       AND EXISTS (SELECT 1 FROM public.works WHERE id = moves[i][3]);
    IF FOUND THEN n_moved := n_moved + 1;
    ELSE v_report := v_report || format(' [deplacement saute: notice %s (%s->%s)]', moves[i][1], moves[i][2], moves[i][3]);
    END IF;
  END LOOP;

  -- 3a. Coquilles sur les notices
  FOR i IN 1 .. array_length(titles, 1) LOOP
    UPDATE public.books SET titulo = titles[i][3] WHERE id = titles[i][1]::bigint AND titulo = titles[i][2];
    IF FOUND THEN n_titles := n_titles + 1;
    ELSE v_report := v_report || format(' [titre saute: notice %s]', titles[i][1]);
    END IF;
  END LOOP;
  -- Colonia Cecilia : la parenthese est un sous-titre
  UPDATE public.books SET titulo = 'Colônia Cecília', subtitulo = 'Um Pouco de Ideal e de Polenta'
   WHERE id = 2533 AND titulo = 'Colônia Cecília (Um Pouco de Ideal e de Polenta)' AND subtitulo IS NULL;
  IF FOUND THEN n_titles := n_titles + 1; ELSE v_report := v_report || ' [titre saute: notice 2533]'; END IF;
  UPDATE public.books SET titulo = 'Colônia Cecília', subtitulo = 'Um Pouco de Ideal e de Polenta'
   WHERE id = 2534 AND titulo = 'Colônia Cecília: Um Pouco de Ideal e de Polenta' AND subtitulo IS NULL;
  IF FOUND THEN n_titles := n_titles + 1; ELSE v_report := v_report || ' [titre saute: notice 2534]'; END IF;
  -- ... et sur les brouillons publies correspondants (reprise = trois endroits)
  UPDATE public.book_drafts SET titulo = 'Colônia Cecília', subtitulo = 'Um Pouco de Ideal e de Polenta'
   WHERE id IN (441, 148) AND published_book_id IN (2533, 2534) AND titulo LIKE 'Colônia Cecília%' AND subtitulo IS NULL;
  GET DIAGNOSTICS n_drafts = ROW_COUNT;
  UPDATE public.book_drafts SET titulo = 'O Anarquismo no Sec. XXI'
   WHERE id = 208 AND published_book_id = 2640 AND titulo = 'O Anarquismo no Sec.XXI';
  IF FOUND THEN n_drafts := n_drafts + 1; END IF;

  -- 3b. Titres uniformes (sort_title recalcule comme le fait fn_books_ensure_work)
  FOR i IN 1 .. array_length(wtitles, 1) LOOP
    UPDATE public.works SET uniform_title = wtitles[i][3], sort_title = public.fn_normalize_name(wtitles[i][3]), updated_at = now()
     WHERE id = wtitles[i][1]::bigint AND uniform_title = wtitles[i][2];
    IF FOUND THEN n_wtitles := n_wtitles + 1;
    ELSE v_report := v_report || format(' [titre uniforme saute: oeuvre %s]', wtitles[i][1]);
    END IF;
  END LOOP;

  -- 4. Notes d'oeuvre (variation de titre entre editions), sans ecraser une note existante
  UPDATE public.works SET notes = concat_ws(E'\n', nullif(notes, ''),
    'Título varia conforme a edição: «Autogestão, gestão direta, gestão operária» (Novos Tempos, Brasil, 1988) e «Autogestão, Gestão Operária, Gestão Directa» (A Batalha, Portugal, 1975). Mesmo texto; grafias portuguesas de antes e depois da reforma ortográfica.'),
    updated_at = now()
   WHERE id = 1343 AND coalesce(notes, '') NOT LIKE '%Título varia conforme a edição%';
  UPDATE public.works SET notes = concat_ws(E'\n', nullif(notes, ''),
    'Título varia conforme a edição: «Liberdade sem Mêdo» (Theor, 1972) e «Liberdade sem mêdo (Summerhill)» (IBRASA, 1970). Mesma obra (Summerhill).'),
    updated_at = now()
   WHERE id = 317 AND coalesce(notes, '') NOT LIKE '%Título varia conforme a edição%';
  UPDATE public.works SET notes = concat_ws(E'\n', nullif(notes, ''),
    'Mesma obra sob dois títulos de tradução: «De la huelga salvaje a la autogestión revolucionaria» (Anagrama, 1978) e «De la huelga salvaje a la autogestión generalizada» (Mariposas del Caos, 1974). Texto de 1974 assinado Ratgeb (Raoul Vaneigem); a autoridade «Anoar Aiex» é a rever no catalogação.'),
    updated_at = now()
   WHERE id = 178 AND coalesce(notes, '') NOT LIKE '%Mesma obra sob dois títulos%';

  -- 5. Suppression des oeuvres vides, chacune verifiee sans dependant
  FOR i IN 1 .. array_length(doomed, 1) LOOP
    IF EXISTS (SELECT 1 FROM public.books WHERE work_id = doomed[i])
       OR EXISTS (SELECT 1 FROM public.book_drafts WHERE work_id = doomed[i])
       OR EXISTS (SELECT 1 FROM public.audio_tracks WHERE work_id = doomed[i])
       OR EXISTS (SELECT 1 FROM public.book_reading_notes WHERE work_id = doomed[i]) THEN
      v_report := v_report || format(' [suppression sautee: oeuvre %s encore referencee]', doomed[i]);
      CONTINUE;
    END IF;
    DELETE FROM public.works WHERE id = doomed[i];
    IF FOUND THEN n_deleted := n_deleted + 1; END IF;
  END LOOP;

  -- 6. Expressions FRBR orphelines sur les oeuvres cibles (langue posee apres coup)
  DELETE FROM public.work_expressions we
   WHERE we.work_id = ANY(targets)
     AND NOT EXISTS (SELECT 1 FROM public.books b WHERE b.expression_id = we.id);
  GET DIAGNOSTICS n_expr = ROW_COUNT;

  RAISE NOTICE 'Fusion des oeuvres scindees : % langues, % deplacements, % titres, % brouillons, % titres uniformes, % oeuvres supprimees, % expressions purgees.%',
    n_lang, n_moved, n_titles, n_drafts, n_wtitles, n_deleted, n_expr, v_report;
END $$;

COMMIT;
