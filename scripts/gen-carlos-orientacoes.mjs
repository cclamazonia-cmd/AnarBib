/**
 * Gera o documento DOCX de orientações para Carlos Baqueiro
 * sobre a publicação dos 415 rascunhos da MLEG.
 *
 * Usage: node scripts/gen-carlos-orientacoes.mjs
 * Output: docs/orientacoes-publicacao-rascunhos-mleg.docx
 */

import {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  WidthType, AlignmentType, HeadingLevel, BorderStyle, ShadingType,
  PageBreak,
} from 'docx';
import fs from 'fs';
import path from 'path';

/* ------------------------------------------------------------------ */
/*  Données                                                            */
/* ------------------------------------------------------------------ */

const DUPLICATAS_CERTAS = [
  ['A Bibliografia Libertária', 'Gonçalves, Silva', '1999', 'Imaginário', '1999, Imaginário'],
  ['A Ciência e a Questão Vital da Revolução', 'Mikhail Bakunin', '2009', 'Imaginário', '2009, Imaginário'],
  ['A Doutrina Anarquista ao Alcance de Todos', 'José Oiticica', '2006', 'Achiamé', '2006, Achiamé'],
  ['A Escola da Anarquia', 'Josefa Martin Luengo', '2007', 'Achiamé', 'Achiamé'],
  ['A Falência da Política', 'Maurício Tragtemberg', '2009', 'Unesp', '2009, Unesp'],
  ['A Ideia dos Sovietes', 'Pano Vassilev', '2008', 'Faísca/Imaginário', '2008, Imaginário'],
  ['A Ideologia do Anarquismo', 'Rudolf Rocker', '2005', 'Faísca', '2005, Faísca'],
  ['A Instrução Integral', 'Bakunin', '2003', 'Imaginário', '2003, Imaginário'],
  ['A Insurreição Anarquista no Rio de Janeiro', 'Carlos Augusto Addor', '1986', 'Dois Pontos', '1986, Dois Pontos'],
  ['A Nova Sociedade (2 rascunhos)', 'Proudhon', '—', 'Rés', 'Edições Rés'],
  ['A Pedagogia Libertária…', 'Kassick', '2004', 'Achiamé', '2004, Achiamé'],
  ['A Pedagogia Libertária…', 'Kassick', '2000', 'Achiamé', '2000, Achiamé'],
  ['A Revolução Mexicana', 'Flores Magón', '2003', 'Imaginário', '2003, Imaginário'],
  ['Abc do Sindicalismo Revolucionário', 'Edgar Rodrigues', '1987', 'Achiamé', '1987, Achiamé'],
  ['Alvorada Operária', 'Edgar Rodrigues', '1979', 'Mundo Livre', '1979, Mundo Livre'],
  ['Anarco Comunismo Italiano', 'Malatesta, Fabbri', '—', 'Luta Libertária', 'Luta Libertária'],
  ['Anarquia pela Educação', 'Élisée Reclus', '2011', 'Hedra', '2011, Hedra'],
  ['Anarquismo à Moda Antiga', 'Edgar Rodrigues', '—', 'Achiamé', 'Achiamé'],
  ['Anarquismo e Anarcossindicalismo', 'Giuseppina Sferra', '1987', 'Ática', '1987, Ática'],
  ['Anarquismo e Anticlericalismo', 'Eduardo Valladares', '2000', 'Imaginário', '2000, Imaginário'],
  ['Anarquismo ou Marxismo', 'Gilbert Green', '1982', 'Achiamé', '1982, Achiamé'],
  ['Anarquismo Social e Organização', 'FARJ', '2008', 'Faísca', '2008, Faísca'],
  ['Anarquismo Social e Organização', 'FARJ', '2009', 'Faísca', '2009, Faísca'],
  ['Anarquistas e Anarquismo', 'James Joll', '1977', 'Dom Quixote', '1977, Dom Quixote'],
  ['Anarquistas Expropriadores', 'Osvaldo Bayer', '2004', 'Luta Libertária', '2004, Luta Libertária'],
  ['Autoritarismo e Anarquismo', 'Malatesta', '2004', 'Imaginário', '2004, Imaginário'],
  ['Bakunin', 'Vários', '1994', 'Imaginário', '1994, Imaginário'],
  ['Catecismo Revolucionário', 'Mikhail Bakunin', '2009', 'Imaginário', '2009, Imaginário'],
  ['Cinema e Anarquia', 'Isabelle Marinone', '2009', 'Azougue', '2009, Azougue'],
  ['Contos Anarquistas', 'Hardman, Prado', '1985', 'Brasiliense', '1985, Brasiliense'],
  ['Conversação Libertária com Paulo Freire', 'Edson Passetti', '1998', 'Imaginário', '1998, Imaginário'],
  ['Deus e o Estado', 'Bakunin', '2000', 'Imaginário', '2000, Imaginário'],
  ['Deus e o Estado', 'Bakunin', '2011', 'Hedra', '2011, Hedra'],
  ['Dia de Eleição', 'Carlos Pronzato', '2010', 'La Mestiza', '2010, La Mestiza'],
  ['Do Princípio Federativo (2 rascunhos)', 'Proudhon', '2001', 'Imaginário', '2001, Imaginário'],
  ['Educação e Liberdade', 'Ivan Illich', '1990', 'Imaginário', '1990, Imaginário'],
  ['El Anarquismo Individualista', 'Émile Armand', '2007', 'Terramar', '2007, Terramar'],
  ['Elysio de Carvalho, Um Militante do Anarquismo', 'Sant\'Ana', '1982', 'Arquivo Público', '1982, Arquivo Público'],
  ['Emma Goldman', 'Elisabeth Souza Lobo', '1983', 'Brasiliense', '1983, Brasiliense'],
  ['Entre Camponeses', 'Errico Malatesta', '2009', 'Hedra', '2009, Hedra'],
  ['Escritos Revolucionários', 'Malatesta', '2000', 'Imaginário', '2000, Imaginário'],
  ['Escritos Revolucionários', 'Malatesta', '1989', 'Novos Tempos', '1989, Novos Tempos'],
  ['Essência da Religião / O Patriotismo', 'Bakunin', '2009', 'Imaginário', '2009, Imaginário'],
  ['Estatismo e Anarquia', 'Mikhail Bakunin', '2003', 'Imaginário', '2003, Imaginário'],
  ['Foucault e o Anarquismo', 'Salvo Vaccaro', '—', 'Achiamé', 'Achiamé'],
  ['Fragmentos de uma Antropologia Anarquista', 'David Graeber', '2011', 'Deriva', '2011, Deriva'],
  ['A Guerrilha Surreal', 'José Chrispiniano', '2002', 'Conrad', '2002, Conrad'],
  ['História da Anarquia', 'Max Nettlau', '2008', 'Hedra', '2008, Hedra'],
  ['Ideología Anarquista', 'Malatesta', '2008', 'Recortes', '2008, Recortes'],
  ['La destrucción del Estado', 'Godwin, Proudhon etc.', '1972', 'Centro Editor', '1972, Centro Editor'],
  ['La Moral Anarquista', 'Kropotkin', '1978', 'Jucar', '1978, Jucar'],
  ['La Utopía es Posible', 'Bookchin etc.', '—', 'Tupac', 'Tupac Ediciones'],
  ['Lembranças Incompletas', 'Edgar Rodrigues', '2007', 'Opúsculo', '2007, Opúsculo'],
  ['Max Stirner e o Anarquismo Individualista (2 rascunhos)', 'Armand, Barrué etc.', '2003', 'Imaginário', '2003, Imaginário'],
  ['Moral Pública & Martírio Privado', 'Alexandre Samis', '1999', 'Achiamé', '2000, Achiamé'],
  ['Mudar o Mundo sem Tomar o Poder', 'John Holloway', '2003', 'Viramundo', '2003, Viramundo'],
  ['Municipalismo Libertário', 'Murray Bookchin', '—', 'Imaginário', '1999, Imaginário'],
  ['Notas sobre o Anarquismo', 'Noam Chomsky', '2004', 'Imaginário', '2004, Imaginário'],
  ['O Anarquismo', 'Marx & Engels', '1987', 'Acadêmica', '1987, Acadêmica'],
  ['O Anarquismo e a Democracia Burguesa', 'Bakunin, Malatesta etc.', '1986', 'Global', '1980, Global'],
  ['O Anarquismo e a Democracia Burguesa', 'Bakunin, Malatesta etc.', '1979', 'Global', '1980, Global'],
  ['O Anarquismo Social', 'Frank Mintz', '2006', 'Imaginário', '2006, Imaginário'],
  ['O Essencial Proudhon', 'Francisco Trindade', '2001', 'Imaginário', '2001, Imaginário'],
  ['O Falso Princípio da Nossa Educação', 'Max Stirner', '2001', 'Imaginário', '2001, Intemezzo'],
  ['O Mito Político no Teatro Anarquista', 'Souza', '2003', 'Achiamé', '2003, Achiamé'],
  ['O Que é a Propriedade?', 'Proudhon', '1975', 'Estampa', '1975, Estampa'],
  ['O que é Autonomia Operária', 'Lúcia Bruno', '1985', 'Brasiliense', '1985, Brasiliense'],
  ['Os Anarquistas e as Eleições', 'Bakunin, Kropotkin etc.', '1986', 'Novos Tempos', '1986, Novos Tempos'],
  ['Os Fanzines Contam uma História sobre Punks', 'Oliveira', '2006', 'Achiamé', '2006, Achiamé'],
  ['Pedagogia do Risco', 'Silvio Gallo', '1995', 'Papirus', '1995, Papirus'],
  ['Proudhon', 'Georges Gurvitch', '1983', 'Edições 70', '1983, Edições 70'],
  ['Proudhon e Marx', 'Georges Gurvitch', '1980', 'Presença', '1980, Presença'],
  ['Reflexões sobre a Anarquia', 'Maurice Joyeux', '1992', 'Terra Livre', '1992, Terra Livre'],
  ['Renovação 1919', 'Maria Lacerda de Moura', '2015', 'UFC', '2015, UFC'],
  ['Revolução e Guerra Civil na Espanha', 'Mendes de Almeida', '1981', 'Brasiliense', '1981, Brasiliense'],
  ['Sindicalismo e Movimentos Sociais', 'Alexandre Samis', '2010', 'Faísca', '2010, Faísca'],
  ['Sindicalismo Revolucionario', 'Sorel etc.', '1977', 'Jucar', '1978, Jucar'],
  ['Sobre o Anarquismo', 'Nicolas Walter', '—', 'Achiamé', 'Achiamé'],
  ['Solução Anarquista para a Questão Social', 'Malatesta', '1962', 'Guilda', '1962, Guilda'],
  ['Surrealismo e Anarquismo (2 rascunhos)', 'Plínio Coelho', '1990', 'Imaginário', '1990, Imaginário'],
  ['Três Ensaios Sobre Religião', 'Emma Goldman', '2005', 'Index', '2005, Index'],
  ['Um Ensaio sobre a Revolução Sexual', 'Daniel Guérin', '1980', 'Brasiliense', '1980, Brasiliense'],
  ['Um Episódio de Amor Livre na Colônia Cecília', 'Giovanni Rossi', '—', 'Achiamé', 'Achiamé'],
  ['Utopias Anarquistas', 'Flávio Luizetto', '1987', 'Brasiliense', '1987, Brasiliense'],
  ['A Anarquia', 'Malatesta', '2001', 'Imaginário', '1999, Imaginário'],
];

const CASOS_AMBIGUOS = [
  ['A Conquista do Pão', 'Kropotkin', '2012', 'Rizoma', 'Edições de 1953–2011 (outras editoras)', 'Edição Rizoma 2012 não consta no catálogo'],
  ['A Conquista do Pão', 'Kropotkin', '2011', 'Achiamé', '2011 existe mas editoras BTL diferentes', 'Verificar se é a mesma edição Achiamé'],
  ['A Doutrina Anarquista…', 'Oiticica', '1976', 'A Batalha', '1983, 2006', 'Edição 1976 ausente'],
  ['A Escola Moderna', 'Ferrer y Guardia', '2014', 'Terra Livre', '2021, BTL', 'Ano diferente'],
  ['A Revolução Russa', 'Tragtenberg', '2007', 'Unesp', '2007, Faísca', 'Editora diferente'],
  ['Anarquistas, Socialistas e Comunistas', 'Malatesta', '2014', 'Imaginário', '1989, Cortez', 'Edição claramente diferente'],
  ['Contos Anarquistas', 'Vários Autores', '2011', 'Martins Fontes', '1985, Brasiliense', 'Edição diferente'],
  ['Desobediência Civil', 'Thoreau', '1997', 'L&PM', 'Ediouro', 'Editora diferente'],
  ['Escritos sobre Educação e Geografia', 'Reclus/Kropotkin', '2014', 'Terra Livre', '2011, BTL', 'Ano diferente'],
  ['O Anarquismo Experimental…', 'Mello Neto', '2017', 'UEPG', '1998, UEPG', '2ª edição?'],
  ['O Anarquismo no Século XXI', 'Graeber', '2013', 'Rizoma', 'Coletivo coisa preta', 'Editora diferente'],
  ['O Indivíduo, a Sociedade e o Estado…', 'Goldman', '1989', 'Imaginário', '2011, Hedra', 'Edição diferente'],
  ['O Indivíduo, a Sociedade e o Estado…', 'Goldman', '2007', 'Hedra', '2011, Hedra', 'Ano próximo'],
  ['O Que é a Propriedade?', 'Proudhon', '1998', 'L&PM', '1975, Estampa', 'Edição diferente'],
  ['O Que é a Propriedade?', 'Proudhon', '1971', 'Estampa', '1975, Estampa', 'Ano próximo'],
  ['Os Fanzines… sobre Punks', 'Oliveira', '2015', 'Rizoma', '2006, Achiamé', '2ª edição'],
  ['Colônia Cecília', 'Pallottini', '1987', 'Tchê!', '2001, Achiamé', 'Edição diferente'],
  ['Pela Educação e pelo Trabalho', 'Pinho', '2012', 'Terra Livre', '2015, BTL', 'Ano diferente'],
  ['Educar para Emancipar', 'Lenoir', '2007', 'Imaginário', '2007, UFAM', 'Editora diferente'],
  ['Anarquistas en América Latina', 'Viñas', '2009', 'Paradiso', '2004, Paradiso', '2ª edição?'],
  ['A Formação da Classe Trabalhadora', 'Góes', '1988', 'Fundação', '1988, Jorge Zahar', 'Editora diferente'],
  ['Os Companheiros de São Paulo', 'Beiguelman', '1981', 'Global', '1977, Símbolo', 'Edição diferente'],
  ['Manual Filosófico do Individualista', 'Han Ryner', '—', 'Achiamé', '1966, Germinal', 'Editora diferente'],
  ['Liberdade Sem Excesso', 'Neill', '1971', 'IBRASA', 'Theor', 'Editora diferente'],
  ['Liberdade, Escola, Amor e Juventude', 'Neill', '1970', 'IBRASA', '1972, Theor', 'Editora diferente'],
];

const FALSOS_DUPLICADOS = [
  ['A Anarquia', 'Kropotkin (rascunho)', 'Malatesta (catálogo)', 'Autores diferentes — livros distintos'],
  ['A Greve de 1917', 'Edgard Leuenroth', 'Bodela, Miguel', 'Autores diferentes'],
  ['A Guerra Civil Espanhola', 'José Carlos Sebe Bom Meihy', 'Thomas, Hugh', 'Autores diferentes'],
  ['La Actualidad del Anarquismo (2 rasc.)', 'Carlos Diaz', 'Ibáñez, Tomás', 'Autores diferentes'],
  ['O Anarquismo Hoje', 'Jorge E. Silva (Achiamé)', 'Federação Anarquista (Imaginário)', 'Obras distintas, mesmo título'],
  ['Três Depoimentos Libertários', 'Rodrigues, Cubero, Giménez', 'Jeremias, Marcolino', 'Autores diferentes'],
  ['Emiliano Zapata', 'Eric Nepomuceno', 'NEPOMUCENO, Eric', 'MESMO autor — publicar OK, mas já existe!'],
];

/* ------------------------------------------------------------------ */
/*  Helpers                                                             */
/* ------------------------------------------------------------------ */

const BORDER_THIN = {
  top: { style: BorderStyle.SINGLE, size: 1, color: '999999' },
  bottom: { style: BorderStyle.SINGLE, size: 1, color: '999999' },
  left: { style: BorderStyle.SINGLE, size: 1, color: '999999' },
  right: { style: BorderStyle.SINGLE, size: 1, color: '999999' },
};

function cell(text, opts = {}) {
  const { bold, shading, width, alignment } = opts;
  return new TableCell({
    borders: BORDER_THIN,
    width: width ? { size: width, type: WidthType.PERCENTAGE } : undefined,
    shading: shading ? { type: ShadingType.SOLID, color: shading } : undefined,
    children: [
      new Paragraph({
        alignment: alignment || AlignmentType.LEFT,
        spacing: { before: 40, after: 40 },
        children: [
          new TextRun({
            text: String(text ?? '—'),
            bold: !!bold,
            size: 20,
            font: 'Calibri',
          }),
        ],
      }),
    ],
  });
}

function headerCell(text, width) {
  return cell(text, { bold: true, shading: '333333', width });
}

function sectionTitle(text, level = HeadingLevel.HEADING_2) {
  return new Paragraph({
    heading: level,
    spacing: { before: 360, after: 120 },
    children: [new TextRun({ text, bold: true, font: 'Calibri' })],
  });
}

function bodyPara(text, opts = {}) {
  return new Paragraph({
    spacing: { before: 80, after: 80 },
    alignment: opts.alignment || AlignmentType.LEFT,
    children: [
      new TextRun({
        text,
        bold: !!opts.bold,
        italics: !!opts.italics,
        size: 22,
        font: 'Calibri',
        color: opts.color,
      }),
    ],
  });
}

function bulletPara(text) {
  return new Paragraph({
    spacing: { before: 40, after: 40 },
    bullet: { level: 0 },
    children: [new TextRun({ text, size: 22, font: 'Calibri' })],
  });
}

/* ------------------------------------------------------------------ */
/*  Document                                                           */
/* ------------------------------------------------------------------ */

const doc = new Document({
  styles: {
    paragraphStyles: [
      {
        id: 'Title',
        name: 'Title',
        run: { size: 36, bold: true, font: 'Calibri' },
        paragraph: { alignment: AlignmentType.CENTER },
      },
    ],
  },
  sections: [
    {
      properties: {
        page: { margin: { top: 720, right: 720, bottom: 720, left: 720 } },
      },
      children: [
        /* ---------- Titre ---------- */
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 120 },
          children: [
            new TextRun({
              text: 'Orientações para Publicação dos Rascunhos',
              bold: true, size: 36, font: 'Calibri',
            }),
          ],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 60 },
          children: [
            new TextRun({
              text: 'Maloca Libertária / Biblioteca Emma Goldman (MLEG)',
              bold: true, size: 28, font: 'Calibri', color: '555555',
            }),
          ],
        }),
        new Paragraph({
          alignment: AlignmentType.CENTER,
          spacing: { after: 300 },
          children: [
            new TextRun({
              text: `Preparado em 8 de junho de 2026 — AnarBib`,
              size: 20, font: 'Calibri', color: '888888', italics: true,
            }),
          ],
        }),

        /* ---------- Resumo ---------- */
        sectionTitle('Resumo da situação'),
        bodyPara('A MLEG possui 415 rascunhos prontos para publicação no sistema AnarBib. Antes de publicá-los, foi feita uma verificação cruzada com os livros já catalogados na rede (BTL + BLMF). Resultado:'),
        new Paragraph({ spacing: { before: 120 } }),

        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: [
            new TableRow({
              children: [
                headerCell('Categoria', 40),
                headerCell('Qtd.', 12),
                headerCell('Ação', 48),
              ],
            }),
            new TableRow({
              children: [
                cell('Duplicatas certas (mesmo livro já existe)', { shading: 'FFCCCC' }),
                cell('~85', { alignment: AlignmentType.CENTER, shading: 'FFCCCC' }),
                cell('NÃO PUBLICAR — vincular como exemplar MLEG', { shading: 'FFCCCC', bold: true }),
              ],
            }),
            new TableRow({
              children: [
                cell('Casos ambíguos (edição pode ser diferente)', { shading: 'FFF3CC' }),
                cell('~25', { alignment: AlignmentType.CENTER, shading: 'FFF3CC' }),
                cell('VERIFICAR com o livro em mãos', { shading: 'FFF3CC', bold: true }),
              ],
            }),
            new TableRow({
              children: [
                cell('Falsos duplicados (título igual, autor diferente)', { shading: 'CCFFCC' }),
                cell('~8', { alignment: AlignmentType.CENTER, shading: 'CCFFCC' }),
                cell('PUBLICAR sem problema', { shading: 'CCFFCC' }),
              ],
            }),
            new TableRow({
              children: [
                cell('Títulos novos (sem correspondência)', { shading: 'CCFFCC' }),
                cell('286', { alignment: AlignmentType.CENTER, shading: 'CCFFCC' }),
                cell('PUBLICAR sem problema', { shading: 'CCFFCC' }),
              ],
            }),
          ],
        }),

        /* ---------- Instruções ---------- */
        sectionTitle('O que fazer na prática'),
        bodyPara('Para evitar duplicatas no catálogo, siga estes passos:'),
        bulletPara('Os 286 títulos novos (sem correspondência no catálogo) podem ser publicados normalmente. Basta clicar em "Editar" e depois "Publicar".'),
        bulletPara('Os ~85 rascunhos marcados como "duplicatas certas" (lista abaixo) NÃO devem ser publicados como novas fichas. O livro já existe no catálogo. O procedimento correto é: buscar a ficha existente no catálogo e adicionar um exemplar da MLEG.'),
        bulletPara('Os ~25 casos ambíguos precisam de verificação: compare o livro em mãos (editora, ano, número de páginas) com a ficha existente. Se for a mesma edição → tratar como duplicata. Se for uma edição diferente → pode publicar.'),
        bulletPara('Os ~8 "falsos duplicados" têm o mesmo título mas autores diferentes. São livros distintos, podem ser publicados.'),

        bodyPara(''),
        bodyPara('ATENÇÃO: publicar um rascunho duplicado cria uma ficha separada no catálogo. Isso confunde os leitores e complica a gestão dos empréstimos. Na dúvida, NÃO publique e peça orientação.', { bold: true, color: 'CC0000' }),

        /* ---------- LISTA 1 : Duplicatas certas ---------- */
        new Paragraph({ children: [new PageBreak()] }),
        sectionTitle('Lista 1 — Duplicatas certas (NÃO publicar)', HeadingLevel.HEADING_1),
        bodyPara('Estes rascunhos correspondem a livros já presentes no catálogo (mesma obra, mesma editora, mesmo ano ou muito próximo). Não publique como ficha nova.', { italics: true, color: '666666' }),
        new Paragraph({ spacing: { before: 120 } }),

        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: [
            new TableRow({
              children: [
                headerCell('#', 4),
                headerCell('Título (rascunho)', 30),
                headerCell('Autor (rascunho)', 18),
                headerCell('Ano', 6),
                headerCell('Editora (rascunho)', 16),
                headerCell('Já existe no catálogo', 26),
              ],
            }),
            ...DUPLICATAS_CERTAS.map((row, i) =>
              new TableRow({
                children: [
                  cell(i + 1, { alignment: AlignmentType.CENTER }),
                  ...row.map(v => cell(v)),
                ],
              })
            ),
          ],
        }),

        /* ---------- LISTA 2 : Casos ambíguos ---------- */
        new Paragraph({ children: [new PageBreak()] }),
        sectionTitle('Lista 2 — Casos ambíguos (verificar)', HeadingLevel.HEADING_1),
        bodyPara('Estes rascunhos têm o mesmo título e autor de um livro já catalogado, mas a editora ou o ano são diferentes. Pode ser uma edição distinta (legítima) ou o mesmo livro com dados ligeiramente diferentes. Verifique com o exemplar em mãos.', { italics: true, color: '666666' }),
        new Paragraph({ spacing: { before: 120 } }),

        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: [
            new TableRow({
              children: [
                headerCell('#', 4),
                headerCell('Título', 22),
                headerCell('Autor', 12),
                headerCell('Ano', 5),
                headerCell('Ed. (rascunho)', 13),
                headerCell('Já existe', 22),
                headerCell('Dúvida', 22),
              ],
            }),
            ...CASOS_AMBIGUOS.map((row, i) =>
              new TableRow({
                children: [
                  cell(i + 1, { alignment: AlignmentType.CENTER }),
                  ...row.map(v => cell(v)),
                ],
              })
            ),
          ],
        }),

        /* ---------- LISTA 3 : Falsos duplicados ---------- */
        new Paragraph({ children: [new PageBreak()] }),
        sectionTitle('Lista 3 — Falsos duplicados (pode publicar)', HeadingLevel.HEADING_1),
        bodyPara('Estes rascunhos têm o mesmo título de um livro catalogado, mas são de autores diferentes. São obras distintas. Podem ser publicados.', { italics: true, color: '666666' }),
        new Paragraph({ spacing: { before: 120 } }),

        new Table({
          width: { size: 100, type: WidthType.PERCENTAGE },
          rows: [
            new TableRow({
              children: [
                headerCell('#', 5),
                headerCell('Título', 25),
                headerCell('Autor (rascunho)', 20),
                headerCell('Autor (catálogo)', 20),
                headerCell('Observação', 30),
              ],
            }),
            ...FALSOS_DUPLICADOS.map((row, i) =>
              new TableRow({
                children: [
                  cell(i + 1, { alignment: AlignmentType.CENTER }),
                  ...row.map(v => cell(v)),
                ],
              })
            ),
          ],
        }),

        /* ---------- Nota final ---------- */
        new Paragraph({ spacing: { before: 400 } }),
        bodyPara('Em caso de dúvida, entre em contato com Xavier antes de publicar.', { bold: true }),
        bodyPara('Documento gerado automaticamente pelo sistema AnarBib.', { italics: true, color: '999999' }),
      ],
    },
  ],
});

/* ------------------------------------------------------------------ */
/*  Écriture                                                           */
/* ------------------------------------------------------------------ */

const outDir = path.resolve('docs');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, 'orientacoes-publicacao-rascunhos-mleg.docx');

const buffer = await Packer.toBuffer(doc);
fs.writeFileSync(outPath, buffer);
console.log(`✅ Documento gerado: ${outPath}`);
console.log(`   Tamanho: ${(buffer.length / 1024).toFixed(1)} KB`);
