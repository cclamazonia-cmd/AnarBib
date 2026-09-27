/* ===========================================================================
 * i18n-ptbr-frances.cjs
 * pt-BR.json, suite de i18n-ptbr-vocabulario.cjs (27/09/2026) : les deux
 * restes que celui-ci laissait — « cota », à trancher, et les mots FRANÇAIS
 * restés dans la traduction. Tranché par Xavier le soir même : « cota » →
 * « número de chamada ». 91 valeurs réécrites, placeholders inchangés.
 *
 *   cota (≈ 25 clés : Numeração, lotes, erros, perfil de importação,
 *   Communs) → número de chamada. Le mot change de genre : « a cota » →
 *   « o número de chamada », « Cotas em falta » → « Números de chamada
 *   faltantes », « cota(s) atribuída(s) » → « número(s) de chamada
 *   atribuído(s) ». L'infobulle de Numeração disait que la cote « n'arrange
 *   pas les livres » : réécrite pour ne pas se contredire (c'est la classe
 *   CDD qui donne la localização imprimée sur l'étiquette).
 *   GARDÉ : « Cotas e pagamentos » (panel.tab.memberships.hint) — les
 *   cotisations, sens brésilien juste.
 *   cote (le mot français, ×6) → « etiqueta(s) de lombada » (le terme
 *   brésilien de l'étiquette de dos, déjà dans les mots-clés de /inicio),
 *   « Número de chamada: » devant la ligne d'étagère.
 *   notícia (la notice bibliographique, ×14) → ficha, comme partout
 *   ailleurs dans l'app ; même genre, aucun accord ne bouge. « Boa notícia »
 *   (une nouvelle) n'est pas concerné.
 *   flux RSS (×10) → feed RSS.
 *   PEB (prêt entre bibliothèques, ×13) → EEB, le sigle brésilien — déjà
 *   dans les mots-clés de /inicio (« empréstimo entre bibliotecas EEB »).
 *   Importer → Importar ; « Novo import », « Import concluído! » /
 *   « Import maciço » → Importação ; « Tract / Panfleto », « Panfleto / tracto » → Panfleto
 *   (« Folheto » est un autre type de matériel) ; « painel de gouvernance…
 *   enviado por mail » → governança, e-mail ; « a pessoa concernida »
 *   (×7, « la personne concernée ») → « a pessoa em questão » — et
 *   « Será comunicado pessoa concernida » y retrouve son « à ».
 *   L'écran Numeração perd au passage l'espace français avant « : » et « ; »
 *   (neuf libellés), pour que l'écran entier bascule ensemble.
 *
 * EFFET DE BORD, trouvé par la garde « pas d'anglais laissé » (chemin 1) :
 * elle exempte une valeur identique à en.json quand elle l'est aussi à
 * pt-BR.json. « Panfleto / tracto » l'était — et c'était du PORTUGAIS, servi
 * tel quel en anglais, espagnol, italien et allemand sur
 * catalogacao.material.tract et catalogacao.guide.tract.title. En changeant
 * le pt-BR, l'exemption tombe. Ces huit valeurs reprennent la traduction que
 * chaque langue donne déjà à material.tract (AUTRES_LOCALES, plus bas).
 *
 * Réécriture DE → PARA, comme i18n-ptbr-vocabulario.cjs : une clé n'est
 * réécrite que si elle porte EXACTEMENT l'ancienne valeur.
 *
 * Les courriels : alignés sur l'écran par 49047ae3 (« compartilhamento »,
 * « Gerenciar », scripts/mail-ptbr-vocabulario.cjs). Il leur manquait le
 * sigle : le rapport hebdomadaire réseau (notify-network-weekly-report,
 * texte en dur, hors des modules de chaînes) disait « PEB » trois fois —
 * RAPPORT_RESEAU, plus bas, les passe à « EEB ». La CI redéploie la fonction.
 *
 * La garde : src/tests/helpers/ptbr-frances.js (FRANCES_EM_PT), lue par
 * i18n-ecriture.test.js (chemin 5) et mail-ptbr-voce.test.js.
 * Usage : node scripts/i18n-ptbr-frances.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

// clé : [ancienne valeur, valeur brésilienne]
const DE_PARA = {
  // ── cota → número de chamada ─────────────────────────────────────────────
  'atelier.volet4.classifSystem': [
    'Sistema de classificação / cota',
    'Sistema de classificação / número de chamada',
  ],
  'federacao.communs.doc.cotation.desc': [
    'Uma norma de cota e uma grade Dewey revisitada — um exemplo de catalogação situada.',
    'Uma norma de número de chamada e uma grade Dewey revisitada — um exemplo de catalogação situada.',
  ],
  'federacao.communs.doc.cotation.title': [
    'Cotação & classificação anarquista',
    'Números de chamada & classificação anarquista',
  ],
  'inicio.i.labels': [
    'Imprimir etiquetas e cotas',
    'Imprimir etiquetas e números de chamada',
  ],
  'inicio.kw.labels': [
    'etiqueta cota folha imprimir lombada',
    'etiqueta número de chamada folha imprimir lombada',
  ],
  'biblioteca.numbering.title': [
    'Numeração : tombo e cota',
    'Numeração: tombo e número de chamada',
  ],
  'biblioteca.numbering.hint': [
    'O número de tombo identifica cada exemplar físico e segue a ordem de entrada ; a cota identifica a ficha. Nenhum dos dois arruma os livros : é a classe (campo CDD) que faz a cota de arrumação da etiqueta. Sem série de tombo, a biblioteca não publica nenhum exemplar.',
    'O número de tombo identifica cada exemplar físico e segue a ordem de entrada; o número de chamada identifica a ficha. Nenhum dos dois ordena os livros na estante: é a classe (campo CDD) que dá a localização impressa na etiqueta de lombada. Sem série de tombo, a biblioteca não publica nenhum exemplar.',
  ],
  'biblioteca.numbering.bibRefTitle': [
    'Cota (referência da ficha)',
    'Número de chamada (referência da ficha)',
  ],
  'biblioteca.numbering.bibRefPrefix': [
    'Prefixo de cota',
    'Prefixo do número de chamada',
  ],
  'biblioteca.numbering.bibRefAuto': [
    'Propor a cota automaticamente',
    'Propor o número de chamada automaticamente',
  ],
  'catalogacao.batch.bibrefs': [
    'Cotas em falta',
    'Números de chamada faltantes',
  ],
  'catalogacao.batch.bibrefs.title': [
    'Atribuir as cotas em falta',
    'Atribuir os números de chamada faltantes',
  ],
  'catalogacao.batch.bibrefs.preview': [
    '{count} rascunho(s) sem cota em « {name} » vão receber uma cota de « {library} », de {first} a {last}, na ordem do lote.',
    '{count} rascunho(s) sem número de chamada em « {name} » vão receber um número de chamada de « {library} », de {first} a {last}, na ordem do lote.',
  ],
  'catalogacao.batch.bibrefs.none': [
    'Nenhum rascunho sem cota neste lote.',
    'Nenhum rascunho sem número de chamada neste lote.',
  ],
  'catalogacao.batch.bibrefs.ok': [
    '{count} cota(s) atribuída(s), de {first} a {last}.',
    '{count} número(s) de chamada atribuído(s), de {first} a {last}.',
  ],
  'error.numbering.pad_range': [
    'Preenchimento fora dos limites (0 a 8 dígitos para o tombo, 1 a 10 para a cota).',
    'Preenchimento fora dos limites (0 a 8 dígitos para o tombo, 1 a 10 para o número de chamada).',
  ],
  'error.numbering.bibref_prefix_taken': [
    'Este prefixo de cota já é usado por outra biblioteca da rede.',
    'Este prefixo de número de chamada já é usado por outra biblioteca da rede.',
  ],
  'error.bibref.batch.staff_only': [
    'Atribuir as cotas de um lote é reservado ao staff da biblioteca proprietária.',
    'Atribuir os números de chamada de um lote é reservado ao staff da biblioteca proprietária.',
  ],
  'error.bibref.batch.not_open': [
    'Só um lote aberto recebe cotas.',
    'Só um lote aberto recebe números de chamada.',
  ],
  'error.bibref.batch.mixed_owner': [
    'Os rascunhos sem cota deste lote pertencem a várias bibliotecas : reatribua o lote primeiro.',
    'Os rascunhos sem número de chamada deste lote pertencem a várias bibliotecas: reatribua o lote primeiro.',
  ],
  'error.bibref.batch.no_convention': [
    'A biblioteca proprietária não tem convenção de cota automática : defina-a em Biblioteca › Numeração.',
    'A biblioteca proprietária não tem convenção automática de número de chamada: defina-a em Biblioteca › Numeração.',
  ],
  'importacoes.adapter.profileItems.call_number': [
    'Cota',
    'Número de chamada',
  ],
  'catalogacao.exemplar.shelfRaw': [
    'Cota / localização de origem',
    'Número de chamada / localização de origem',
  ],
  'catalogacao.exemplar.shelfRaw.ph': [
    'Texto livre mantido como está (ex. cota importada)',
    'Texto livre mantido como está (ex. número de chamada importado)',
  ],

  // ── cote (le mot français) → número de chamada, etiqueta de lombada ──────
  'catalogacao.shelf.cotePrefix': [
    'Cote:',
    'Número de chamada:',
  ],
  'catalogacao.ui.labelPreview': [
    'Prévia local de cote / etiqueta',
    'Prévia local do número de chamada / etiqueta',
  ],
  'catalogacao.wizard.step.etiquetas.body': [
    'Imprima etiquetas de cote para os exemplares da sua biblioteca. Selecione os exemplares na lista, escolha quais campos incluir (autor, título, tombo, nota) e gere uma folha A4 pronta para impressão, com QR code opcional.',
    'Imprima etiquetas de lombada para os exemplares da sua biblioteca. Selecione os exemplares na lista, escolha quais campos incluir (autor, título, tombo, nota) e gere uma folha A4 pronta para impressão, com QR code opcional.',
  ],
  'catalogacao.wizard.step.indexacao.body': [
    'Cadastre exemplares (cópias físicas) vinculados a um documento. Cada exemplar tem um tombo (número de inventário), política de circulação e um rótulo para a etiqueta de cote.',
    'Cadastre exemplares (cópias físicas) vinculados a um documento. Cada exemplar tem um tombo (número de inventário), política de circulação e um rótulo para a etiqueta de lombada.',
  ],
  'labels.printTitle': [
    'Etiquetas de cote',
    'Etiquetas de lombada',
  ],
  'labels.title': [
    'Impressão de etiquetas de cote',
    'Impressão de etiquetas de lombada',
  ],

  // ── écran Numeração : l'espace français avant « : » et « ; » ─────────────
  'biblioteca.numbering.notConfigured': [
    'Nenhuma série de tombo definida : esta biblioteca não pode publicar exemplares enquanto não for definida.',
    'Nenhuma série de tombo definida: esta biblioteca não pode publicar exemplares enquanto não for definida.',
  ],
  'biblioteca.numbering.example': ['Exemplo :', 'Exemplo:'],
  'biblioteca.numbering.next': ['Próximo :', 'Próximo:'],
  'biblioteca.numbering.last': ['Último atribuído :', 'Último atribuído:'],
  'biblioteca.numbering.frozen': [
    'Um exemplar já usou esta série : o prefixo, o ano e o separador não mudam mais. Só o preenchimento continua modificável.',
    'Um exemplar já usou esta série: o prefixo, o ano e o separador não mudam mais. Só o preenchimento continua modificável.',
  ],
  'biblioteca.numbering.saved': [
    'Numeração gravada. Próximo tombo : {next}',
    'Numeração gravada. Próximo tombo: {next}',
  ],
  'error.numbering.prefix_taken': [
    'Este prefixo já é usado por outra biblioteca da rede : os números de tombo são únicos em toda a base.',
    'Este prefixo já é usado por outra biblioteca da rede: os números de tombo são únicos em toda a base.',
  ],
  'error.numbering.frozen': [
    'Um exemplar já usou esta série : o prefixo, o ano e o separador não mudam mais.',
    'Um exemplar já usou esta série: o prefixo, o ano e o separador não mudam mais.',
  ],
  'error.bibref.batch.no_owner': [
    'Os rascunhos deste lote não têm biblioteca proprietária : reatribua o lote primeiro.',
    'Os rascunhos deste lote não têm biblioteca proprietária: reatribua o lote primeiro.',
  ],

  // ── notícia (la notice) → ficha ──────────────────────────────────────────
  'catalogacao.reassign.confirm': [
    'Atribuir esta notícia e seus exemplares a “{library}”?',
    'Atribuir esta ficha e seus exemplares a “{library}”?',
  ],
  'catalogacao.reassign.multiHint': [
    'Esta notícia tem cópias em mais de uma biblioteca; escolha de qual mover.',
    'Esta ficha tem cópias em mais de uma biblioteca; escolha de qual mover.',
  ],
  'catalogacao.reassign.sourceAll': [
    'Toda a notícia (todas as cópias)',
    'Toda a ficha (todas as cópias)',
  ],
  'catalogacao.reassign.title': [
    'Atribuir a notícia e seus exemplares a uma biblioteca',
    'Atribuir a ficha e seus exemplares a uma biblioteca',
  ],
  'importacoes.wizard.preview.dupBody': [
    'Num catálogo mutualizado, criar um duplicado gera incoerências graves. Estas linhas NÃO serão promovidas automaticamente — verifique-as e prefira o vínculo à notícia existente.',
    'Num catálogo mutualizado, criar um duplicado gera incoerências graves. Estas linhas NÃO serão promovidas automaticamente — verifique-as e prefira o vínculo à ficha existente.',
  ],
  'importacoes.wizard.preview.dupTitle': [
    '{n} notícia(s) já presente(s) no catálogo da rede',
    '{n} ficha(s) já presente(s) no catálogo da rede',
  ],
  'importacoes.wizard.preview.summary': [
    '{n} notícia(s) pronta(s) para promoção.',
    '{n} ficha(s) pronta(s) para promoção.',
  ],
  'importacoes.wizard.promote.plan': [
    '{novos} nova(s) notícia(s) → rascunhos. {retenus} linha(s) retida(s) (duplicados ou a revisar).',
    '{novos} nova(s) ficha(s) → rascunhos. {retenus} linha(s) retida(s) (duplicados ou a revisar).',
  ],
  'importacoes.wizard.source.ingested': [
    'Notícia importada. Vá para a pré-visualização.',
    'Ficha importada. Vá para a pré-visualização.',
  ],
  'importacoes.run.encoding.fallback': [
    'Lido em {enc}, por suposição: o arquivo não é UTF-8 válido. Confira os acentos das primeiras notícias; se estiverem errados, reprocesse impondo a codificação.',
    'Lido em {enc}, por suposição: o arquivo não é UTF-8 válido. Confira os acentos das primeiras fichas; se estiverem errados, reprocesse impondo a codificação.',
  ],
  'importacoes.coverage.explain': [
    '« Guardado em bruto »: a informação fica no registro de origem da notícia, mas não alimenta nenhum campo do catálogo.',
    '« Guardado em bruto »: a informação fica no registro de origem da ficha, mas não alimenta nenhum campo do catálogo.',
  ],
  'importacoes.coverage.notTaken': [
    'Não aproveitados na notícia',
    'Não aproveitados na ficha',
  ],
  'importacoes.coverage.surplus': [
    '{n, plural, one {# repetição não aproveitada} other {# repetições não aproveitadas}} (só a primeira entra na notícia)',
    '{n, plural, one {# repetição não aproveitada} other {# repetições não aproveitadas}} (só a primeira entra na ficha)',
  ],
  'catalogacao.ui.coverIsbnEcart': [
    'Este ISBN corresponde à edição {trouvee}; a notícia indica {notice}. Reimpressão, outra edição ou ISBN incorreto: confira antes de escolher esta capa.',
    'Este ISBN corresponde à edição {trouvee}; a ficha indica {notice}. Reimpressão, outra edição ou ISBN incorreto: confira antes de escolher esta capa.',
  ],

  // ── flux → feed ──────────────────────────────────────────────────────────
  'importacoes.enterRssUrl': ['Informe a URL do flux RSS/Atom.', 'Informe a URL do feed RSS/Atom.'],
  'importacoes.fetchingRss': ['Buscando flux RSS…', 'Buscando feed RSS…'],
  'importacoes.noRssItems': ['Nenhum item encontrado neste flux RSS/Atom.', 'Nenhum item encontrado neste feed RSS/Atom.'],
  'importacoes.notRss': ['Esta URL não parece ser um flux RSS/Atom.', 'Esta URL não parece ser um feed RSS/Atom.'],
  'importacoes.rss.fetch': ['Buscar flux', 'Buscar feed'],
  'importacoes.rss.help': [
    'Cole a URL de um flux RSS ou Atom (blog, editora, revista, repositório). O sistema buscará os itens publicados e permitirá importar como rascunhos.',
    'Cole a URL de um feed RSS ou Atom (blog, editora, revista, repositório). O sistema buscará os itens publicados e permitirá importar como rascunhos.',
  ],
  'importacoes.rss.itemsFromFeed': [
    '{count} item(ns) encontrado(s) no flux « {feed} ».',
    '{count} item(ns) encontrado(s) no feed « {feed} ».',
  ],
  'importacoes.rss.label': ['URL do flux RSS/Atom', 'URL do feed RSS/Atom'],
  'importacoes.subtitle': [
    'Recepção artesanal, importação por URL, flux RSS/Atom e histórico de tratamentos.',
    'Recepção artesanal, importação por URL, feed RSS/Atom e histórico de tratamentos.',
  ],
  'importacoes.tab.rss': ['Flux RSS / Atom', 'Feed RSS / Atom'],

  // ── PEB → EEB ────────────────────────────────────────────────────────────
  'biblioteca.ill.archiveConfirm': [
    'Arquivar o PEB #{id}? Ele sai da lista ativa e fica consultável na aba Relatórios.',
    'Arquivar o EEB #{id}? Ele sai da lista ativa e fica consultável na aba Relatórios.',
  ],
  'biblioteca.ill.archived': ['PEB #{id} arquivado.', 'EEB #{id} arquivado.'],
  'biblioteca.pebHistory.empty': ['Nenhum PEB arquivado.', 'Nenhum EEB arquivado.'],
  'biblioteca.pebHistory.loadError': ['Não foi possível carregar os PEB arquivados.', 'Não foi possível carregar os EEB arquivados.'],
  'biblioteca.pebHistory.title': ['PEB arquivados', 'EEB arquivados'],
  'biblioteca.pebHistory.unarchiveConfirm': [
    'Desarquivar o PEB #{id}? Ele volta à lista ativa.',
    'Desarquivar o EEB #{id}? Ele volta à lista ativa.',
  ],
  'biblioteca.pebHistory.unarchiveError': ['Não foi possível desarquivar o PEB.', 'Não foi possível desarquivar o EEB.'],
  'biblioteca.report.illOngoing': ['PEB em curso: {count}', 'EEB em curso: {count}'],
  'biblioteca.report.illOngoingList': ['Detalhe dos PEB em curso', 'Detalhe dos EEB em curso'],
  'biblioteca.report.illSection': ['Empréstimos entre bibliotecas (PEB)', 'Empréstimos entre bibliotecas (EEB)'],
  'biblioteca.report.illTerminalPending': [
    'PEB encerrados aguardando arquivamento: {count}',
    'EEB encerrados aguardando arquivamento: {count}',
  ],
  'digishare.hint': [
    'Pedir ou fornecer um documento digitalizado a uma biblioteca parceira (material cinza, fora do PEB físico). Requer o direito « compartilhamento digital » de uma parceria ativa.',
    'Pedir ou fornecer um documento digitalizado a uma biblioteca parceira (material cinza, fora do EEB físico). Requer o direito « compartilhamento digital » de uma parceria ativa.',
  ],
  'digishare.req.greyOnly': [
    'Alvo: material cinza não comercializado. Documentos com ISBN/ISSN são redirecionados para o PEB.',
    'Alvo: material cinza não comercializado. Documentos com ISBN/ISSN são redirecionados para o EEB.',
  ],

  // ── autres mots français ─────────────────────────────────────────────────
  'importacoes.fontes.importCandidate': ['Importer', 'Importar'],
  // Trouvée par la garde, pas par le relevé : le seul « import » en minuscule.
  'importacoes.wizard.title': ['Novo import', 'Nova importação'],
  'importacoes.wizard.promote.done': [
    'Import concluído! {n} rascunho(s) criado(s).',
    'Importação concluída! {n} rascunho(s) criado(s).',
  ],
  'importacoes.circuit.migracao.hint': [
    'Import maciço via ISO 2709 / UNIMARC para migrar de um SIGB existente.',
    'Importação em massa via ISO 2709 / UNIMARC para migrar de um SIGB existente.',
  ],
  'material.tract': ['Tract / Panfleto', 'Panfleto'],
  'catalogacao.material.tract': ['Panfleto / tracto', 'Panfleto'],
  'catalogacao.guide.tract.title': ['Panfleto / tracto', 'Panfleto'],
  'team.modal.description.suspend': [
    'A suspensão impede temporariamente que est(e/a/e) camarada exerça suas funções. O motivo será visível no painel de gouvernance e enviado por mail. Use com discernimento — esta é uma decisão coletiva.',
    'A suspensão impede temporariamente que est(e/a/e) camarada exerça suas funções. O motivo será visível no painel de governança e enviado por e-mail. Use com discernimento — esta é uma decisão coletiva.',
  ],
  'biblioteca.leitores.proposeCoordConfirm': [
    'Propor {name} à coordenação? A coordenação não se dá sozinha: a proposta precisará do endosso de outra pessoa da equipe e depois da aceitação da pessoa concernida. Até lá, nada muda.',
    'Propor {name} à coordenação? A coordenação não se dá sozinha: a proposta precisará do endosso de outra pessoa da equipe e depois da aceitação da pessoa em questão. Até lá, nada muda.',
  ],
  'biblioteca.leitores.proposeCoordSuccess': [
    'Proposta registrada para {name}. Próximos passos: endosso da equipe e aceitação da pessoa concernida.',
    'Proposta registrada para {name}. Próximos passos: endosso da equipe e aceitação da pessoa em questão.',
  ],
  'biblioteca.leitores.proposeLibrarianConfirm': [
    'Propor {name} para a equipe como bibliotecária·o? A acolhida é colegiada: a proposta precisará do endosso da equipe e depois da aceitação da pessoa concernida. Até lá, nada muda.',
    'Propor {name} para a equipe como bibliotecária·o? A acolhida é colegiada: a proposta precisará do endosso da equipe e depois da aceitação da pessoa em questão. Até lá, nada muda.',
  ],
  'biblioteca.leitores.proposeLibrarianSuccess': [
    'Proposta registrada para {name}. Próximos passos: endosso da equipe e aceitação da pessoa concernida.',
    'Proposta registrada para {name}. Próximos passos: endosso da equipe e aceitação da pessoa em questão.',
  ],
  'team.note.coordProposedReady': [
    'Passagem à coordenação pronta — falta apenas a aceitação da pessoa concernida.',
    'Passagem à coordenação pronta — falta apenas a aceitação da pessoa em questão.',
  ],
  'team.modal.reason.placeholder': [
    'Explique o motivo coletivo da suspensão. Será comunicado pessoa concernida e à equipe.',
    'Explique o motivo coletivo da suspensão. Será comunicado à pessoa em questão e à equipe.',
  ],
  'team.modal.removeReason.placeholder': [
    'Explique o motivo coletivo da retirada. Será comunicado pessoa concernida e à equipe. A demanda fica registrada no histórico militante.',
    'Explique o motivo coletivo da retirada. Será comunicado à pessoa em questão e à equipe. A demanda fica registrada no histórico militante.',
  ],
};

// Le portugais « Panfleto / tracto » servi dans quatre autres langues : la
// traduction de material.tract de chaque langue, en minuscule après « / »
// comme les voisines du catalogage (« Octaveta / pamflet »).
const TRACT = ['catalogacao.material.tract', 'catalogacao.guide.tract.title'];
const AUTRES_LOCALES = {
  en: 'Leaflet / pamphlet',
  es: 'Volante / panfleto',
  it: 'Volantino / pamphlet',
  de: 'Flugblatt',
};

function reecrire(locale, paires) {
  const f = path.join(__dirname, '..', 'src', 'i18n', 'locales', `${locale}.json`);
  const j = JSON.parse(fs.readFileSync(f, 'utf8'));
  let reecrites = 0;
  let deja = 0;
  const absentes = [];
  const autres = [];
  for (const [k, [de, para]] of Object.entries(paires)) {
    if (!(k in j)) absentes.push(k);
    else if (j[k] === de) { j[k] = para; reecrites++; }
    else if (j[k] === para) deja++;
    else autres.push(k);
  }
  fs.writeFileSync(f, JSON.stringify(j, null, 2) + '\n');
  console.log(`${locale} : ${reecrites} réécrite(s), ${deja} déjà faite(s)`);
  if (absentes.length) console.log(`  absentes (laissées) : ${absentes.join(', ')}`);
  if (autres.length) console.log(`  modifiées depuis, ni l'ancienne ni la version de ce script (laissées) : ${autres.join(', ')}`);
}

reecrire('pt-BR', DE_PARA);
for (const [locale, para] of Object.entries(AUTRES_LOCALES)) {
  reecrire(locale, Object.fromEntries(TRACT.map((k) => [k, ['Panfleto / tracto', para]])));
}

// Le rapport hebdomadaire réseau : du texte pt-BR en dur dans l'Edge
// Function. Une occurrence attendue par aiguille ; déjà remplacée, comptée.
const RAPPORT_RESEAU = path.join(__dirname, '..', 'supabase', 'functions', 'notify-network-weekly-report', 'index.ts');
const RAPPORT_DE_PARA = [
  ['<b>PEB criados na semana (intercâmbios)</b>', '<b>EEB criados na semana (intercâmbios)</b>'],
  ['<b>PEB em circulação na rede (fim da semana)</b>', '<b>EEB em circulação na rede (fim da semana)</b>'],
  ['"Intercâmbios interbibliotecas da rede (PEB criados na semana)"', '"Intercâmbios interbibliotecas da rede (EEB criados na semana)"'],
];
let rapport = fs.readFileSync(RAPPORT_RESEAU, 'utf8');
const bilan = { faits: 0, deja: 0, refus: 0 };
for (const [de, para] of RAPPORT_DE_PARA) {
  const n = rapport.split(de).length - 1;
  if (n === 1) { rapport = rapport.replace(de, () => para); bilan.faits++; }
  else if (n === 0 && rapport.split(para).length - 1 === 1) bilan.deja++;
  else { console.log(`  REFUS : ${n} occurrence(s) de ${de}`); bilan.refus++; }
}
if (!bilan.refus) fs.writeFileSync(RAPPORT_RESEAU, rapport);
console.log(`rapport hebdomadaire réseau : ${bilan.faits} remplacé(s), ${bilan.deja} déjà fait(s), ${bilan.refus} refus`);
if (bilan.refus) process.exit(1);
