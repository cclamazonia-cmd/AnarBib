/* ===========================================================================
 * i18n-ptbr-vocabulario.cjs
 * pt-BR.json parlait le vocabulaire du PORTUGAL — relevé le 27/09/2026 après
 * la passe « você » (a805951b), qui l'avait laissé exprès (« chantier à
 * part ») : « ficheiro » 32 fois dans 27 valeurs (l'écran Exportação
 * surtout), « partilha digital »
 * alors que le droit s'appelle « Compartilhamento digital » dans Parcerias,
 * « Guardar », « A carregar… », « registo », « Gerir leitor(a/e) »… 78 valeurs
 * réécrites en brésilien, sens et placeholders inchangés.
 *
 * DÉCIDÉ MOT PAR MOT, UN ÉCRAN BASCULANT D'UN BLOC :
 *   ficheiro(s)          → arquivo(s)        Exportação, Compartilhamento
 *                                             digital, perfil de importação
 *   registo / registada  → registro / registrada   corbeille du catalogage
 *   partilha / partilhar → compartilhamento / compartilhar — le NOM DU DROIT
 *                          était déjà « Compartilhamento digital » dans
 *                          Parcerias (biblioteca.stabPartners.right.
 *                          digital_share) : l'écran digishare le cite
 *                          désormais tel qu'il s'affiche. Genre : « Partilha
 *                          encerrada » → « Compartilhamento encerrado ».
 *   Guardar (enregistrer) → Salvar ; « A guardar… » → « Salvando… » — et
 *                          « Documentos guardados para depois » suit le
 *                          bouton « Salvar para depois » qui remplit la liste.
 *   « A carregar… », « A confirmar… », « A anular… », « A enviar… » (le
 *                          progressif européen) → gérondif.
 *   gerir               → gerenciar : le fichier disait déjà « Gerencie o
 *                          ciclo de vida », « Gerenciar na página Biblioteca ».
 *   Eliminar o perfil    → Excluir (le verbe de tout le reste de l'app).
 *   Valores por omissão  → Valores padrão.
 *   Contacto, secção, fecho, plafond, actualmente, criámos, « Obrigada na
 *                          mesma », « material cinzento », « entretanto »
 *                          (au sens de « entre-temps ») → Contato, seção,
 *                          fechamento (le bouton voisin dit « Fechar »),
 *                          limite, atualmente, criamos, « mesmo assim »,
 *                          « material cinza » (comme les écrans voisins),
 *                          « nesse meio-tempo ».
 *   Dans deux phrases déjà réécrites : « Ligue um ficheiro… a um livro »
 *   → « Vincule um arquivo… » (« ligar » = allumer, appeler au Brésil ; le
 *   catalogage dit « vincular recurso digital ») ; « Anula uma verificação
 *   errada » → « Anule » (impératif du « tu » laissé par la passe « você » —
 *   l'anglais dit « Revoke »), « já não é restaurável » → « não é mais ».
 *
 * GARDÉS, PARCE QUE LE BRÉSIL LES DIT AUSSI, DANS CE SENS-LÀ :
 *   « separador » (le caractère entre l'année et le numéro — biblioteca.
 *   numbering.* : pas l'onglet européen) ; « guarda » nom (« recusada(s)
 *   pela guarda ») et « guardar » au sens de conserver (« Cada exclusão
 *   guarda um instantâneo », « Guarde as informações abaixo », « guardado em
 *   bruto ») ; « transferência » (« área de transferência » = presse-papiers
 *   au Brésil) ; « Recolher » (replier) ; « Sumário » ; « consigo » ;
 *   « utilizar » ; « detectar », « recepção », « excepcional » (le Brésil
 *   prononce la consonne).
 *
 * LAISSÉ À UNE DÉCISION DE XAVIER : « cota » (≈ 25 clés, biblioteca.
 *   numbering.*, catalogacao.batch.bibrefs*, error.bibref.*, labels) —
 *   terme européen de la cote de bibliothèque, mais c'est la NOTION même de
 *   l'écran Numeração (« a cota identifica a ficha », distincte de la « cota
 *   de arrumação ») : la renommer (« número de chamada » ?) est une décision
 *   de vocabulaire de catalogage, pas une correction.
 *
 * Réécriture DE → PARA, comme i18n-ptbr-voce.cjs : une clé n'est réécrite que
 * si elle porte EXACTEMENT l'ancienne valeur ; déjà brésilienne, elle est
 * comptée ; ni l'une ni l'autre, elle est signalée et laissée.
 *
 * Les scripts d'origine (« ajout si absent ») qui portaient ces valeurs sont
 * corrigés dans le même commit ; la plupart des 78 clés n'existaient que dans
 * les locales.
 *
 * La garde : src/tests/i18n-ecriture.test.js, chemin (5), `PT_EUROPEU`.
 * Usage : node scripts/i18n-ptbr-vocabulario.cjs
 * =========================================================================== */
const fs = require('fs');
const path = require('path');

const FICHIER = path.join(__dirname, '..', 'src', 'i18n', 'locales', 'pt-BR.json');

// clé : [valeur au vocabulaire européen, valeur brésilienne]
const DE_PARA = {
  // ── ficheiro → arquivo ───────────────────────────────────────────────────
  'digishare.transmit.noAssets': [
    'Nenhum ficheiro digital nesta ficha. Digitalize o documento primeiro.',
    'Nenhum arquivo digital nesta ficha. Digitalize o documento primeiro.',
  ],
  'digishare.transmit.selectAsset': [
    'Escolher um ficheiro',
    'Escolher um arquivo',
  ],
  'digishare.transmit.title': [
    'Transmitir o documento — escolha o ficheiro e o plafond de difusão:',
    'Transmitir o documento — escolha o arquivo e o limite de difusão:',
  ],
  'importacoes.adapter.profileColumn': [
    'Coluna do ficheiro',
    'Coluna do arquivo',
  ],
  'importacoes.export.attach.attached': [
    'Ficheiro anexado a « {title} » (verificado domínio público).',
    'Arquivo anexado a « {title} » (verificado domínio público).',
  ],
  'importacoes.export.attach.desc': [
    'Ligue um ficheiro recebido (fundo mutualizado) a um livro do seu catálogo: torna-se um ficheiro verificado « domínio público » e a ficha fica exportável por sua vez.',
    'Vincule um arquivo recebido (fundo mutualizado) a um livro do seu catálogo: torna-se um arquivo verificado « domínio público » e a ficha fica exportável por sua vez.',
  ],
  'importacoes.export.attach.empty': [
    'Nenhum ficheiro recebido à espera de anexação.',
    'Nenhum arquivo recebido à espera de anexação.',
  ],
  'importacoes.export.attach.load': [
    'Carregar os ficheiros recebidos',
    'Carregar os arquivos recebidos',
  ],
  'importacoes.export.attach.modeLabel': [
    'Destino do ficheiro',
    'Destino do arquivo',
  ],
  'importacoes.export.attach.title': [
    'Anexar os ficheiros recebidos',
    'Anexar os arquivos recebidos',
  ],
  'importacoes.export.curate.desc': [
    'Para que uma ficha seja exportável, um dos seus ficheiros públicos deve ser validado « domínio público » (ato distinto do « livre de direitos » marcado na catalogação). Eis os ficheiros públicos ainda não validados.',
    'Para que uma ficha seja exportável, um dos seus arquivos públicos deve ser validado « domínio público » (ato distinto do « livre de direitos » marcado na catalogação). Eis os arquivos públicos ainda não validados.',
  ],
  'importacoes.export.curate.empty': [
    'Nenhum ficheiro público a validar (ou todos já validados).',
    'Nenhum arquivo público a validar (ou todos já validados).',
  ],
  'importacoes.export.curate.load': [
    'Carregar os ficheiros a validar',
    'Carregar os arquivos a validar',
  ],
  'importacoes.export.fonds.desc': [
    'Entregar um lote de material cinza digitalizado (registros + ficheiros) a uma biblioteca parceira, num pacote ZIP. Só entram os ficheiros de domínio público confirmado.',
    'Entregar um lote de material cinza digitalizado (registros + arquivos) a uma biblioteca parceira, num pacote ZIP. Só entram os arquivos de domínio público confirmado.',
  ],
  'importacoes.export.fonds.directDesc': [
    'Transfere diretamente o lote (registros + ficheiros) para a fila de revisão da parceira, sem ZIP. Requer uma parceria ativa com o direito « mutualização ».',
    'Transfere diretamente o lote (registros + arquivos) para a fila de revisão da parceira, sem ZIP. Requer uma parceria ativa com o direito « mutualização ».',
  ],
  'importacoes.export.fonds.directSent': [
    'Lote depositado na parceira: {count} registros, {files} ficheiros. Ela o encontrará na sua fila de revisão.',
    'Lote depositado na parceira: {count} registros, {files} arquivos. Ela o encontrará na sua fila de revisão.',
  ],
  'importacoes.export.fonds.eligible': [
    '{count} registros elegíveis (≥ 1 ficheiro de domínio público confirmado).',
    '{count} registros elegíveis (≥ 1 arquivo de domínio público confirmado).',
  ],
  'importacoes.export.fonds.eligibleZero': [
    'Nenhum registro elegível (é preciso ao menos um ficheiro de domínio público confirmado).',
    'Nenhum registro elegível (é preciso ao menos um arquivo de domínio público confirmado).',
  ],
  'importacoes.export.fonds.gated': [
    'Reservado à coordenação. Ato de mutualização de fundo: só os ficheiros « domínio público confirmado » viajam com os seus registros e a sua proveniência.',
    'Reservado à coordenação. Ato de mutualização de fundo: só os arquivos « domínio público confirmado » viajam com os seus registros e a sua proveniência.',
  ],
  'importacoes.export.fonds.truncated': [
    'Lote truncado (limite de volume atingido): {count} ficheiros incluídos. Refine a seleção para uma exportação completa.',
    'Lote truncado (limite de volume atingido): {count} arquivos incluídos. Refine a seleção para uma exportação completa.',
  ],
  'importacoes.export.verified.confirm': [
    'Anular a verificação « domínio público » de « {title} »? O ficheiro verificado será removido.',
    'Anular a verificação « domínio público » de « {title} »? O arquivo verificado será removido.',
  ],
  'importacoes.export.verified.confirmAsk': [
    'Confirmar « domínio público » para « {title} » (fonte: {source})? O ficheiro torna-se exportável.',
    'Confirmar « domínio público » para « {title} » (fonte: {source})? O arquivo torna-se exportável.',
  ],
  'importacoes.export.verified.desc': [
    'Lista os ficheiros marcados « domínio público » nos livros desta biblioteca. Anula uma verificação errada: o ficheiro deixa de ser partilhado e, se nenhum catálogo o usa, é retirado do armazenamento.',
    'Lista os arquivos marcados « domínio público » nos livros desta biblioteca. Anule uma verificação errada: o arquivo deixa de ser compartilhado e, se nenhum catálogo o usa, é retirado do armazenamento.',
  ],
  'importacoes.export.verified.empty': [
    'Nenhum ficheiro verificado nesta biblioteca.',
    'Nenhum arquivo verificado nesta biblioteca.',
  ],
  'importacoes.export.verified.load': [
    'Carregar os ficheiros verificados',
    'Carregar os arquivos verificados',
  ],
  'importacoes.export.verified.revokedFile': [
    'Verificação anulada e ficheiro removido: {title}.',
    'Verificação anulada e arquivo removido: {title}.',
  ],
  'importacoes.wizard.source.fondsHint': [
    'Um ficheiro .zip é tratado como um lote de fundo recebido: os registros entram na fila de revisão e os ficheiros são depositados.',
    'Um arquivo .zip é tratado como um lote de fundo recebido: os registros entram na fila de revisão e os arquivos são depositados.',
  ],

  // ── registo → registro (corbeille du catalogage, revues) ─────────────────
  'catalogacao.queue.deletedDescription': [
    'Cada exclusão guarda um instantâneo restaurável por 90 dias. Depois disso, o registo permanece, o instantâneo não.',
    'Cada exclusão guarda um instantâneo restaurável por 90 dias. Depois disso, o registro permanece, o instantâneo não.',
  ],
  'catalogacao.queue.deletedEmpty': [
    'Nenhuma exclusão definitiva registada.',
    'Nenhuma exclusão definitiva registrada.',
  ],
  'error.catalog.restore_not_found': [
    'Esta entrada de registo não existe, ou não é uma exclusão.',
    'Esta entrada de registro não existe, ou não é uma exclusão.',
  ],
  'error.catalog.restore_no_snapshot': [
    'O instantâneo deste rascunho foi purgado (mais de 90 dias): o registo permanece, mas já não é restaurável.',
    'O instantâneo deste rascunho foi purgado (mais de 90 dias): o registro permanece, mas não é mais restaurável.',
  ],
  'error.catalog.restore_already': [
    'Este rascunho já existe: provavelmente foi restaurado entretanto.',
    'Este rascunho já existe: provavelmente foi restaurado nesse meio-tempo.',
  ],
  'catalogacao.queue.libraryRecorded': [
    'Biblioteca de destino, registada no rascunho.',
    'Biblioteca de destino, registrada no rascunho.',
  ],
  'rede.reviews.decided.ok': [
    'Veredito registado.',
    'Veredito registrado.',
  ],

  // ── partilha → compartilhamento ──────────────────────────────────────────
  'atelier.human.volet8': [
    'Visibilidade na rede. O que você partilha com as outras bibliotecas anars. Se tiver dúvida sobre o que expor, conversemos.',
    'Visibilidade na rede. O que você compartilha com as outras bibliotecas anars. Se tiver dúvida sobre o que expor, conversemos.',
  ],
  'atelier.volet_8_visibilidade.sub': [
    'O que você partilha com as outras bibliotecas anars.',
    'O que você compartilha com as outras bibliotecas anars.',
  ],
  'digishare.hint': [
    'Pedir ou fornecer um documento digitalizado a uma biblioteca parceira (material cinza, fora do PEB físico). Requer o direito « partilha digital » de uma parceria ativa.',
    'Pedir ou fornecer um documento digitalizado a uma biblioteca parceira (material cinza, fora do PEB físico). Requer o direito « compartilhamento digital » de uma parceria ativa.',
  ],
  'digishare.inactive': [
    'Ative o direito « partilha digital » numa parceria (secção Parcerias) para usar esta função.',
    'Ative o direito « compartilhamento digital » numa parceria (seção Parcerias) para usar esta função.',
  ],
  'digishare.msg.closed': [
    'Partilha encerrada.',
    'Compartilhamento encerrado.',
  ],
  'digishare.req.new': [
    'Pedir uma partilha',
    'Pedir um compartilhamento',
  ],
  'digishare.req.title': [
    'Novo pedido de partilha digital',
    'Novo pedido de compartilhamento digital',
  ],
  'digishare.title': [
    'Partilha digital',
    'Compartilhamento digital',
  ],
  'importacoes.export.partilha.title': [
    'Partilha ILL',
    'Compartilhamento ILL',
  ],
  'wizard.profile.option.catalog_mode.network_published.desc': [
    'O catálogo é partilhado com todas as bibliotecas da rede AnarBib. Aumenta a circulação dos livros e do conhecimento.',
    'O catálogo é compartilhado com todas as bibliotecas da rede AnarBib. Aumenta a circulação dos livros e do conhecimento.',
  ],
  'federacao.assembleias.firstPoints.q9': [
    'Vocabulário matéria: até onde apoiar-se no tesauro partilhado FICEDL? (a decidir com a FICEDL)',
    'Vocabulário matéria: até onde apoiar-se no tesauro compartilhado FICEDL? (a decidir com a FICEDL)',
  ],
  'inicio.kw.export': [
    'exportação partilha fundo companheira OAI fonte',
    'exportação compartilhamento fundo companheira OAI fonte',
  ],

  // ── Guardar (enregistrer) → Salvar ───────────────────────────────────────
  'book.saveForLater': [
    'Guardar para depois',
    'Salvar para depois',
  ],
  'account.tab.wishlist.hint': [
    'Documentos guardados para depois',
    'Documentos salvos para depois',
  ],
  'importacoes.adapter.profileSave': [
    'Guardar o perfil',
    'Salvar o perfil',
  ],
  'importacoes.adapter.profileSaving': [
    'A guardar…',
    'Salvando…',
  ],
  'rede.lettre.saveLocale': [
    'Guardar este idioma',
    'Salvar este idioma',
  ],
  'biblioteca.events.form.saveEdit': [
    'Guardar',
    'Salvar',
  ],
  'rede.gazeta.correct.saveAccept': [
    'Guardar e aceitar',
    'Salvar e aceitar',
  ],
  'rede.gazeta.correct.save': [
    'Guardar a correção',
    'Salvar a correção',
  ],

  // ── progressif européen « A + infinitif… » → gérondif ────────────────────
  'importacoes.export.verified.confirming': [
    'A confirmar…',
    'Confirmando…',
  ],
  'importacoes.export.verified.loading': [
    'A carregar…',
    'Carregando…',
  ],
  'importacoes.export.verified.revoking': [
    'A anular…',
    'Anulando…',
  ],
  'relatar.sending': [
    'A enviar…',
    'Enviando…',
  ],

  // ── « Relatar » (file des relatos) ───────────────────────────────────────
  'relatar.fila.contact': [
    'Contacto',
    'Contato',
  ],
  'relatar.fila.closeNote': [
    'Nota de fecho (opcional):',
    'Nota de fechamento (opcional):',
  ],
  'relatar.duplicate': [
    'Este problema já foi relatado e ainda está aberto: não criámos um segundo relato. Obrigada na mesma.',
    'Este problema já foi relatado e ainda está aberto: não criamos um segundo relato. Obrigada mesmo assim.',
  ],

  // ── gerir → gerenciar ────────────────────────────────────────────────────
  'catalogacao.infocard.exemplarUnsaved': [
    'Salve a ficha para gerir exemplares',
    'Salve a ficha para gerenciar exemplares',
  ],
  'importacoes.adapter.profileManage': [
    'Gerir / criar um perfil',
    'Gerenciar / criar um perfil',
  ],
  'panel.reader.manage': [
    'Gerir leitor(a/e)',
    'Gerenciar leitor(a/e)',
  ],
  'panel.reader.title': [
    'Gerir leitor(a/e)',
    'Gerenciar leitor(a/e)',
  ],
  'panel.tab.reader': [
    'Gerir leitor(a/e)',
    'Gerenciar leitor(a/e)',
  ],
  'team.modal.description.promoteToLibrarian': [
    'Confirmar a promoção a bibliotecári(o/a/e)? Est(e/a/e) camarada poderá realizar empréstimos, devoluções, cadastrar leitor(o/a/e)s e gerir o cotidiano da biblioteca.',
    'Confirmar a promoção a bibliotecári(o/a/e)? Est(e/a/e) camarada poderá realizar empréstimos, devoluções, cadastrar leitor(o/a/e)s e gerenciar o cotidiano da biblioteca.',
  ],
  'team.modal.quitAdmin.lastAdminWarning': [
    '⚠ Atenção máxima: você é o(a/e) último(a/e) administrador(a/e) da rede. Sem outr(o/a/e) admin em função, ninguém poderá promover novos coordenadores nem gerir a rede AnarBib via UI até intervenção técnica direta no banco de dados.',
    '⚠ Atenção máxima: você é o(a/e) último(a/e) administrador(a/e) da rede. Sem outr(o/a/e) admin em função, ninguém poderá promover novos coordenadores nem gerenciar a rede AnarBib via UI até intervenção técnica direta no banco de dados.',
  ],
  'team.modal.warningSelfDemote': [
    'Atenção: após sair da coordenação, você não poderá mais gerir a equipe nem alterar os parâmetros da biblioteca. Outr(o/a/e) coordenador(a/e) ou administrador(a/e) precisará promover você novamente, se for necessário.',
    'Atenção: após sair da coordenação, você não poderá mais gerenciar a equipe nem alterar os parâmetros da biblioteca. Outr(o/a/e) coordenador(a/e) ou administrador(a/e) precisará promover você novamente, se for necessário.',
  ],
  'inicio.i.subjects': [
    'Indexar e gerir os assuntos',
    'Indexar e gerenciar os assuntos',
  ],
  'inicio.i.lots': [
    'Gerir os lotes de catalogação',
    'Gerenciar os lotes de catalogação',
  ],
  'inicio.i.team': [
    'Gerir a equipe e os convites',
    'Gerenciar a equipe e os convites',
  ],
  'inicio.i.admins': [
    'Gerir os administradores da rede',
    'Gerenciar os administradores da rede',
  ],

  // ── perfil de importação : Eliminar, por omissão ─────────────────────────
  'importacoes.adapter.profileDelete': [
    'Eliminar o perfil',
    'Excluir o perfil',
  ],
  'importacoes.adapter.profileDeleteConfirm': [
    'Eliminar este perfil?',
    'Excluir este perfil?',
  ],
  'importacoes.adapter.profileDefaults': [
    'Valores por omissão',
    'Valores padrão',
  ],

  // ── isolés ───────────────────────────────────────────────────────────────
  'team.modal.description.quitAdminLast': [
    'Você é actualmente o(a/e) ÚNIC(O/A/E) administrador(a/e) ativ(o/a/e) da rede AnarBib. Sair sem promover outr(o/a/e) administrador(a/e) significa fechar a governança da rede até que o desenvolvimento técnico restaure manualmente um papel de administrador. Esta ação é registrada no histórico militante e notifica todes os membros do staff da rede.',
    'Você é atualmente o(a/e) ÚNIC(O/A/E) administrador(a/e) ativ(o/a/e) da rede AnarBib. Sair sem promover outr(o/a/e) administrador(a/e) significa fechar a governança da rede até que o desenvolvimento técnico restaure manualmente um papel de administrador. Esta ação é registrada no histórico militante e notifica todes os membros do staff da rede.',
  ],
  'importacoes.export.coord.hint': [
    'Gestos reservados à coordenação : preparar a elegibilidade, remeter um lote de material cinzento a uma biblioteca parceira, anexar o que foi recebido, verificar o domínio público.',
    'Gestos reservados à coordenação : preparar a elegibilidade, remeter um lote de material cinza a uma biblioteca parceira, anexar o que foi recebido, verificar o domínio público.',
  ],
};

const j = JSON.parse(fs.readFileSync(FICHIER, 'utf8'));
let reecrites = 0;
let dejaBr = 0;
const absentes = [];
const autres = [];
for (const [k, [de, para]] of Object.entries(DE_PARA)) {
  if (!(k in j)) absentes.push(k);
  else if (j[k] === de) { j[k] = para; reecrites++; }
  else if (j[k] === para) dejaBr++;
  else autres.push(k);
}
fs.writeFileSync(FICHIER, JSON.stringify(j, null, 2) + '\n');
console.log(`pt-BR : ${reecrites} réécrite(s), ${dejaBr} déjà brésilienne(s)`);
if (absentes.length) console.log(`absentes (laissées) : ${absentes.join(', ')}`);
if (autres.length) console.log(`modifiées depuis, ni européennes ni la version de ce script (laissées) : ${autres.join(', ')}`);
