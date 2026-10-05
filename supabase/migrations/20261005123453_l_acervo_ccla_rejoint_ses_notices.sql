-- =========================================================================
-- L'acervo histórico du CCLA rejoint le catalogue : 24 brouillons pré-remplis
-- à la BLMF, chacun avec son PDF, et l'affiche du 1º de Maio 2002 sur sa notice
-- =========================================================================
-- Date     : 2026-10-05
-- Chantier : ressources numériques (suite de l'étape 4)
-- Auteur   : Claude (Opus 5.5), pour Xavier
-- Session  : Retours du catalogage & numérique
--
-- CONSTAT (05/10/2026). L'espace public anarbib-pdf-public portait 33 fichiers
-- qu'aucune ressource ne désignait. 29 viennent du dépôt en bloc du 17/06 à
-- 02:32 (books/ccla-acervo-historico/) : l'acervo histórico du CCLA. Le même
-- jour, quatre de ces documents ont été catalogués (notices 2722 à 2725), le
-- PDF reversé par le brouillon : leurs copies du lot sont des doublons. Les 25
-- autres n'ont jamais eu de notice — la recherche par titre ne trouve rien.
-- Lus un à un (texte et première page) avant d'écrire cette migration.
--
-- DÉCISION DE XAVIER (05/10) : plutôt que supprimer, rattacher. Des brouillons
-- PRÉ-REMPLIS, pas des notices publiées : la description reste le travail des
-- camarades de la BLMF, la migration ne fait que leur apporter le fichier et
-- ce qu'on lit sur le document. Accès public, en cession par le CCLA.
--
-- (1) Un lot « Acervo histórico CCLA — PDF a catalogar » à la BLMF, qui détient
--     déjà les quatre documents catalogués du même fonds.
-- (2) 24 brouillons (25 fichiers : la thèse au congrès de la CBB a deux
--     numérisations). Titre transcrit du document, année, pages, organisation
--     émettrice, type ; provenance « Acervo CCLA » comme les quatre premiers ;
--     consultation sur place. Le CCL/CCLA est lié à son autorité (11322) ;
--     les autres organisations restent en transcription : aucune autorité
--     créée en masse. Chaque note dit ce qui reste à conférer.
-- (3) Chaque PDF reste où il est (espace public, accès public : cohérent avec
--     la règle de dépôt), en cessão autoral par le CCLA, justification écrite.
--     Exception assumée : le caderno de formação sindical de la CAB porte sa
--     propre licence (copyleft) — il est déclaré en licence libre, ce qu'il
--     est. La correspondance bibliographique n'est PAS cochée : c'est à la
--     personne qui catalogue de la valider, document en main.
-- (4) 1-de-maio-de-2002.pdf n'est pas un doublon : c'est l'affiche (Na Morada
--     da Arte, 28/04 et 01/05/2002) de l'acte dont la notice 2722 décrit le
--     dossier. Seconde ressource de 2722, non principale.
--
-- CE QU'ELLE NE FAIT PAS : aucune suppression. Les 7 doublons (4 copies du
-- lot, un second envoi de SINDICAL-1, un doublon des 16 Tesis, le
-- .emptyFolderPlaceholder) restent dans l'espace de stockage : une suppression
-- de fichier passe par l'API Storage, à la main.
--
-- IDEMPOTENTE ET SANS EFFET SUR UNE BASE VIDE. Sans la BLMF (base de test
-- reconstruite), rien ne se fait et la NOTICE le dit. Un brouillon déjà posé
-- (même source_record_id) n'est pas reposé ; un fichier absent de l'espace de
-- stockage n'est pas lié ; l'affiche n'est ajoutée qu'une fois.
--
-- CHECKLIST DOCTRINE
--   [x] Migration de DONNÉES : bornée, idempotente, sans effet si rien à faire
--   [x] Aucune DDL, aucun droit modifié
--   [x] Compte rendu chiffré en NOTICE
-- =========================================================================

BEGIN;

DO $acervo$
DECLARE
  c_blmf    constant uuid   := '1234825f-a0f9-4fbd-a875-6551c30ea4ca';
  c_xavier  constant uuid   := 'd6710372-e5e5-4608-800b-99a26817c677';
  c_ccla    constant bigint := 11322;
  c_seau    constant text   := 'anarbib-pdf-public';
  c_dossier constant text   := 'books/ccla-acervo-historico/';
  c_affiche constant text   := 'books/1017/1781664704167_1-de-maio-de-2002.pdf';
  c_lot_nom constant text   := 'Acervo histórico CCLA — PDF a catalogar';
  c_cessao  constant text   := 'Cessão do CCLA: documento do acervo histórico do Centro de Cultura '
                               'Libertária da Amazônia, posto em leitura pública por decisão do CCLA '
                               '(05/10/2026).';
  v_createur uuid;
  v_ccla     bigint;
  v_lot      bigint;
  v_draft    bigint;
  v_serial   bigint;
  v_pos      int;
  d          record;
  f          record;
  v_affiche  int := 0;
  v_poses    int := 0;
  v_deja     int := 0;
  v_fichiers int := 0;
  v_absents  int := 0;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.libraries WHERE id = c_blmf) THEN
    RAISE NOTICE 'acervo CCLA : pas de BLMF dans cette base — rien à faire.';
    RETURN;
  END IF;

  SELECT id INTO v_createur FROM public.profiles WHERE id = c_xavier;
  SELECT id INTO v_ccla FROM public.authors WHERE id = c_ccla;

  -- -----------------------------------------------------------------------
  -- (4) L'affiche du 1º de Maio 2002, seconde ressource de la notice 2722.
  -- -----------------------------------------------------------------------
  IF EXISTS (SELECT 1 FROM public.books WHERE id = 2722)
     AND private.fn_storage_object_exists(c_seau, c_affiche)
     AND NOT EXISTS (SELECT 1 FROM public.book_digital_resources WHERE storage_path = c_affiche) THEN
    INSERT INTO public.book_digital_resources (
      book_id, resource_type, usage_type, access_scope, status, is_active,
      storage_bucket, storage_path, mime_type, language_code, label,
      rights_status, rights_justification, is_primary,
      bibliographic_match_validated, activated_at)
    VALUES (
      2722, 'pdf_publico', 'leitura_online', 'publico', 'active', true,
      c_seau, c_affiche, 'application/pdf', 'pt',
      'Cartaz — Ato político-cultural do 1º de Maio de 2002 (Na Morada da Arte)',
      'cessao_autoral', c_cessao, false, true, now());
    v_affiche := 1;
  END IF;

  -- -----------------------------------------------------------------------
  -- (1) Le lot.
  -- -----------------------------------------------------------------------
  SELECT id INTO v_lot FROM public.catalog_batches
   WHERE library_id = c_blmf AND name = c_lot_nom;
  IF v_lot IS NULL THEN
    INSERT INTO public.catalog_batches (name, notes, status, created_by, library_id)
    VALUES (c_lot_nom,
            'Documentos do acervo histórico do CCLA depositados em 17/06/2026 sem notícia. '
            'Pré-catalogados em 05/10/2026 a partir da leitura de cada PDF: conferir título, '
            'data, autoria e tipo, validar a correspondência do ficheiro e publicar.',
            'open', v_createur, c_blmf)
    RETURNING id INTO v_lot;
  END IF;

  -- -----------------------------------------------------------------------
  -- (2)+(3) Les brouillons et leurs fichiers.
  -- -----------------------------------------------------------------------
  FOR d IN
    SELECT * FROM jsonb_to_recordset($j$[
      {"cle":"ccl-informativo-01-1993","titulo":"Informativo do CCL — Centro de Cultura Libertária, nº 01","tipo":"periodico","titulo_periodico":"Informativo do CCL","numero":"1","ano":"1993","data_edicao":"15 de janeiro de 1993","paginas":19,"autor":"Centro de Cultura Libertária","ccla":true,
       "notas":"Editorial sobre a criação do CCL (inaugurado em 12 e 13 de dezembro). Título de periódico ainda sem autoridade: vincular na Oficina de periódicos.",
       "fichiers":[{"f":"CCL-1993 (1).pdf"}]},
      {"cle":"ccl-programacao-mar-abr-1993","titulo":"Programação mar./abr. do CCL","subtitulo":"Reinauguração do CCL João Plácido de Albuquerque","tipo":"tract","ano":"1993","paginas":1,"autor":"Centro de Cultura Libertária","ccla":true,
       "notas":"Atividades de 21/03 a 18/04/1993 (debates, palestras, vídeo).",
       "fichiers":[{"f":"CCL-1993.pdf"}]},
      {"cle":"ccl-joao-placido-quem-foi","titulo":"Centro de Cultura Libertária João Plácido de Albuquerque","subtitulo":"1 – Quem foi?","tipo":"tract","paginas":4,"autor":"Centro de Cultura Libertária","ccla":true,
       "notas":"Sem data; provavelmente 1993 (reinauguração do CCL João Plácido em 21/03/1993). Cabeçalho da Confederação Operária Brasileira; assinado por anarco-sindicalistas da LTOV-COB/AIT e companheiros do CCL.",
       "fichiers":[{"f":"Digitalizado_20250304-0758.pdf"}]},
      {"cle":"ccl-8-de-marco-1997","titulo":"Cidadania da mulher","subtitulo":"Palestra com Luzia A. Miranda (Grupo de Estudos Eneida de Moraes)","tipo":"cartaz","ano":"1997","data_edicao":"8 de março de 1997","paginas":1,"autor":"Centro de Cultura Libertária","ccla":true,
       "notas":"Local: Na Morada da Arte. Título lido numa digitalização difícil: conferir na imagem.",
       "fichiers":[{"f":"8M-1997-CCL.pdf"}]},
      {"cle":"cbb-cartilha","titulo":"CBB — Comissão dos Bairros de Belém","subtitulo":"O povo oprimido está cada vez mais consciente e organizado","tipo":"livro","paginas":22,"autor":"Comissão dos Bairros de Belém",
       "notas":"Cartilha. A CBB foi criada em janeiro de 1979. Sem data.",
       "fichiers":[{"f":"CBB-1.pdf"}]},
      {"cle":"cbb-vi-congresso-1994","titulo":"VI Congresso da CBB — Caderno de teses","subtitulo":"Gestão democrática: a cidadania que queremos","tipo":"livro","ano":"1994","data_edicao":"27 a 29 de maio de 1994","paginas":37,"autor":"Comissão dos Bairros de Belém",
       "notas":"Assinaturas manuscritas na capa.",
       "fichiers":[{"f":"CBB-2.pdf"}]},
      {"cle":"cbb-tese-contribuicao-libertaria-1999","titulo":"A luta pela reforma urbana no contexto neoliberal","subtitulo":"Tese 4 – Força aos que lutam: contribuição libertária ao Congresso da Comissão dos Bairros de Belém (CBB)","tipo":"livro","ano":"1999","data_edicao":"14 e 15 de janeiro de 1999","paginas":25,
       "notas":"Autoria não indicada nas primeiras páginas (o lema « força aos que lutam » é também o da Organização Socialista Libertária): conferir. Dois ficheiros: COMUNITARIA.pdf (25 p.) e Congresso-CBB.pdf (2 p., provavelmente capa e primeira página da mesma tese).",
       "fichiers":[{"f":"COMUNITARIA.pdf","label":"Tese completa (25 p.)"},{"f":"Congresso-CBB.pdf","label":"Outra digitalização (2 p.)"}]},
      {"cle":"tendencia-estudantil-acao-direta","titulo":"Tendência Estudantil Ação Direta","subtitulo":"Lutar para organizar, organizar para lutar","tipo":"livro","paginas":18,"autor":"Tendência Estudantil Ação Direta",
       "notas":"Sem data. Documento irmão de ES-2.pdf (« Propostas de Universidade (TLMD) », 1994, notícia 0000272). Carimbo da Biblioteca Libertária Maxwell Ferreira na capa.",
       "fichiers":[{"f":"ES-1.pdf"}]},
      {"cle":"dce-raizes-1995","titulo":"Raízes","subtitulo":"Resgatando a força do movimento estudantil — DCE 95","tipo":"tract","ano":"1995","paginas":3,
       "notas":"Chapa às eleições do DCE da UFPA, 1995.",
       "fichiers":[{"f":"DCE-Raizes-1995.pdf"}]},
      {"cle":"osl-manifesto-universidade-1996","titulo":"Garantir a democracia na universidade é garantir a universidade pública, gratuita e de qualidade","tipo":"tract","ano":"1996","paginas":1,"autor":"Organização Socialista Libertária",
       "notas":"Estudantes da OSL, eleição para reitor da UFPA. Contato: R. Arcipreste Manoel Teodoro, 837 – CCL.",
       "fichiers":[{"f":"Manifesto-Universidades-publicas-OSL-1996.pdf"}]},
      {"cle":"osl-acao-direta-01-1996","titulo":"Ação Direta — Boletim informativo da Organização Socialista Libertária, nº 01","subtitulo":"Eleições: a grande farsa","tipo":"periodico","titulo_periodico":"Ação Direta","serial":1,"numero":"1","ano":"1996","data_edicao":"Outubro de 1996","paginas":2,"autor":"Organização Socialista Libertária",
       "notas":"Ano 1, nº 01. Atenção: a notícia 0000274 (maio de 1997) também se diz nº 01 — conferir a numeração. O nome do ficheiro sugere o exemplar de Maxwell Ferreira.",
       "fichiers":[{"f":"OSL-1996-Maxwell-Ferreira.pdf"}]},
      {"cle":"osl-seguindo-a-trilha-cabana-1997","titulo":"Organização Socialista Libertária — Seguindo a trilha cabana","subtitulo":"Na luta e organização dos povos oprimidos latino-americanos: força aos que lutam!","tipo":"cartaz","ano":"1997","paginas":1,"autor":"Organização Socialista Libertária",
       "notas":"Ano segundo o nome do ficheiro (OSL-PA-1997.pdf).",
       "fichiers":[{"f":"OSL-PA-1997.pdf"}]},
      {"cle":"cob-manifesto-anarco-ecologico-1991","titulo":"Manifesto anarco-ecológico","tipo":"tract","ano":"1991","paginas":1,"autor":"Confederação Operária Brasileira",
       "notas":"Militantes anarquistas e anarco-sindicalistas da COB protestam contra a política ecológica e indígena do governo federal. Título atribuído a partir do nome do ficheiro.",
       "fichiers":[{"f":"Manifesto-anarco-ecologico-1991.pdf"}]},
      {"cle":"mann-1989","titulo":"Movimento Anarquista Norte/Nordeste (MANN)","subtitulo":"89, virada da década…","tipo":"tract","ano":"1989","paginas":1,"autor":"Movimento Anarquista Norte/Nordeste",
       "notas":"Apresentação do MANN, com contatos no Pará, Ceará, Rio Grande do Norte, Paraíba e Alagoas. Título atribuído.",
       "fichiers":[{"f":"MANN-1989.pdf"}]},
      {"cle":"mnrinp-belem-2000","titulo":"Movimento Nacional de Resistência Indígena, Negra e Popular — Projeto Belém/PA 2000","tipo":"relatorio","ano":"2000","paginas":2,"autor":"Comitê Outros 500 – Pará",
       "notas":"Projeto de atividade; entre os realizadores, a Resistência Popular Amazônica.",
       "fichiers":[{"f":"MNRINP-2000.pdf"}]},
      {"cle":"projeto-nuaru","titulo":"Projeto de funcionamento do NUARU","tipo":"relatorio","paginas":1,
       "notas":"Núcleo de estudantes junto às comunidades (grafado também NUARA, UFPA). Sem data.",
       "fichiers":[{"f":"Projeto-Nuaru.pdf"}]},
      {"cle":"narc-ato-de-fundacao-2013","titulo":"Ato de fundação do Núcleo Anarquista Resistência Cabana","subtitulo":"O anarquismo como ferramenta de luta e organização","tipo":"cartaz","ano":"2013","data_edicao":"30 de novembro de 2013","paginas":1,"autor":"Núcleo Anarquista Resistência Cabana",
       "notas":"Local: CNBB, Travessa Barão do Triunfo, Marco, Belém. Contato: Biblioteca Libertária Maxwell Ferreira.",
       "fichiers":[{"f":"Ato-de-Fundacao-do-NARC-2013.pdf"}]},
      {"cle":"rpa-congresso-de-fundacao-1999","titulo":"Resistência Popular Amazônica — Congresso de fundação","subtitulo":"Organizar para avançar na luta popular!","tipo":"tract","ano":"1999","data_edicao":"25 e 26 de setembro de 1999","paginas":8,"autor":"Resistência Popular Amazônica",
       "notas":"Contém o Hino à Cabanagem (letra: Eduardo Angelim).",
       "fichiers":[{"f":"RPA.pdf"}]},
      {"cle":"rpa-programa-geral","titulo":"Resistência Popular Amazônica — Programa geral","tipo":"livro","paginas":44,"autor":"Resistência Popular Amazônica",
       "notas":"Sem data (congresso de fundação em setembro de 1999).",
       "fichiers":[{"f":"Resistencia-Popular.pdf"}]},
      {"cle":"cab-caderno-formacao-sindical-01","titulo":"Caderno de formação sindical nº 01","tipo":"livro","ano":"2017","edicao":"1ª ed.","local":"","paginas":24,"autor":"Coordenação Anarquista Brasileira",
       "notas":"GT Sindical da CAB, impresso em 2017. Copyleft. Não confundir com MLEG-0072 (Cadernos de formação 1, 2012).",
       "licence":"Copyleft: livre para cópia e distribuição sem fins lucrativos, com indicação da origem (Coordenação Anarquista Brasileira, 2017).",
       "fichiers":[{"f":"Caderno-de-Formacao-Sindical-CAB.pdf"}]},
      {"cle":"na-morada-resistencia-cultural-iv","titulo":"Ato Show Resistência Cultural IV","subtitulo":"Programação cultural","tipo":"tract","ano":"1996","paginas":2,"autor":"Na Morada da Arte – Associação Cultural",
       "notas":"Ano segundo o nome do ficheiro (Namorada-da-Arte-1996-1.pdf). Apoio: DCE/UFPA, Câmara Municipal de Belém.",
       "fichiers":[{"f":"Namorada-da-Arte-1996-1.pdf"}]},
      {"cle":"na-morada-resistencia-cultural-ii","titulo":"Ato Show Resistência Cultural II","subtitulo":"Boletim informativo nº 02/95","tipo":"tract","ano":"1995","data_edicao":"31/03 e 01/04","paginas":2,"autor":"Na Morada da Arte – Cooperativa Cultural",
       "notas":"O nome do ficheiro diz 1996, o boletim diz 02/95. Entre as entidades: o Centro de Cultura Libertária.",
       "fichiers":[{"f":"Namorada-da-Arte-1996-2.pdf"}]},
      {"cle":"ccl-capa-logotipo","titulo":"Centro de Cultura Libertária — Conquista da consciência e da liberdade","tipo":"cartaz","paginas":1,"autor":"Centro de Cultura Libertária","ccla":true,
       "notas":"Capa com o logotipo do CCL (Belém–Pará). Ficheiro Namorada-da-Arte-1996-capa.pdf: talvez a capa de um dos programas da Na Morada da Arte — conferir.",
       "fichiers":[{"f":"Namorada-da-Arte-1996-capa.pdf"}]},
      {"cle":"na-morada-21-de-marco-1996","titulo":"Na Morada da Arte — 21 de março de 1996","subtitulo":"Programação cultural","tipo":"tract","ano":"1996","data_edicao":"21 de março de 1996","paginas":2,"autor":"Na Morada da Arte",
       "notas":"Teatro, música e poesia, das 15h às 22h. Agradecimentos: DCE e Teatro Waldemar Henrique.",
       "fichiers":[{"f":"Na-Morada-da-Arte-marco-de-1996.pdf"}]}
    ]$j$::jsonb) AS x(cle text, titulo text, subtitulo text, tipo text, titulo_periodico text,
                      serial bigint, numero text, ano text, data_edicao text, edicao text,
                      local text, paginas int, autor text, ccla boolean, notas text,
                      licence text, fichiers jsonb)
  LOOP
    IF EXISTS (SELECT 1 FROM public.book_drafts WHERE source_record_id = 'CCLA-pdf-' || d.cle) THEN
      v_deja := v_deja + 1;
      CONTINUE;
    END IF;
    -- Pas de brouillon sans fichier : il n'aurait rien à rattacher.
    IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(d.fichiers) e
                    WHERE private.fn_storage_object_exists(c_seau, c_dossier || (e->>'f'))) THEN
      v_absents := v_absents + jsonb_array_length(d.fichiers);
      CONTINUE;
    END IF;

    v_serial := NULL;
    IF d.serial IS NOT NULL THEN
      SELECT id INTO v_serial FROM public.serials WHERE id = d.serial;
    END IF;

    INSERT INTO public.book_drafts (
      action, status, titulo, subtitulo, tipo_material, titulo_periodico, serial_id,
      numero, ano, data_edicao, edicao, local_publicacao, paginas, autor, idioma,
      notas, owner_library_id, batch_id, created_by, circulation_default, loanable,
      source_label, provenance_note, source_record_id, marc_json)
    VALUES (
      'create', 'draft', d.titulo, d.subtitulo, d.tipo, d.titulo_periodico, v_serial,
      d.numero, d.ano, d.data_edicao, d.edicao,
      CASE WHEN d.local IS NULL THEN 'Belém' ELSE nullif(d.local, '') END,
      d.paginas, d.autor, 'pt-BR',
      concat_ws(' ', d.notas,
                'Ficheiro(s): ' || (SELECT string_agg(e->>'f', ', ') FROM jsonb_array_elements(d.fichiers) e) || '.',
                'Pré-catalogado em 05/10/2026 a partir da leitura do documento: conferir antes de publicar.'),
      c_blmf, v_lot, v_createur, 'consulta', false,
      'Fonds historique CCLA (BLMF)', 'Acervo CCLA', 'CCLA-pdf-' || d.cle,
      jsonb_build_object('anarbib_provenance', jsonb_build_object(
        'provenance_note', 'Acervo CCLA', 'source_record_id', 'CCLA-pdf-' || d.cle)))
    RETURNING id INTO v_draft;
    v_poses := v_poses + 1;

    IF d.autor IS NOT NULL THEN
      INSERT INTO public.book_draft_contributors (draft_id, position, name, role, is_primary, author_id)
      VALUES (v_draft, 1, d.autor, 'organizacao', true,
              CASE WHEN coalesce(d.ccla, false) THEN v_ccla END);
    END IF;

    v_pos := 0;
    FOR f IN SELECT e->>'f' AS fichier, e->>'label' AS label FROM jsonb_array_elements(d.fichiers) e LOOP
      IF NOT private.fn_storage_object_exists(c_seau, c_dossier || f.fichier) THEN
        v_absents := v_absents + 1;
        CONTINUE;
      END IF;
      v_pos := v_pos + 1;
      INSERT INTO public.book_draft_digital_resources (
        book_draft_id, resource_type, usage_type, access_scope, status, is_active,
        storage_bucket, storage_path, mime_type, language_code, label,
        rights_status, rights_justification, is_primary, bibliographic_match_validated)
      VALUES (
        v_draft, 'pdf_publico', 'leitura_online', 'publico', 'draft', true,
        c_seau, c_dossier || f.fichier, 'application/pdf', 'pt', coalesce(f.label, f.fichier),
        CASE WHEN d.licence IS NULL THEN 'cessao_autoral' ELSE 'licenca_livre' END,
        coalesce(d.licence, c_cessao), v_pos = 1, false);
      v_fichiers := v_fichiers + 1;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'acervo CCLA : lot %, % brouillon(s) posé(s), % déjà là, % fichier(s) rattaché(s), % absent(s) de l''espace ; affiche 2722 : %.',
    v_lot, v_poses, v_deja, v_fichiers, v_absents, v_affiche;
END;
$acervo$;

COMMIT;
