// Ajoute les clés i18n de la page « Oficina de autoridades » (/atelier-autoridades)
// aux 10 locales. pt-BR / fr / es / en traduits ; de / it / ca / nl / el / eo en
// repli anglais (à traduire au fil de l'eau, cf. DOC-I18N-1). Idempotent.
// Miroir de scripts/i18n-add-painel-onboarding.cjs (append avant le `}` final).
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];

// Valeurs en quadruplet [pt-BR, fr, es, en]. Les autres locales reprennent l'anglais.
const T = {
  'atelier.page.title':           ['Oficina de autoridades', "Atelier des autorités", 'Taller de autoridades', 'Authorities workshop'],
  'atelier.page.subtitle':        ['A fila de propostas de contribuição ao corpus compartilhado de autoridades (pessoas, coletividades, matérias). As decisões se dão por consentimento: sem objeção motivada até o prazo, a proposta é aplicada por um membro da equipe.', "La file des propositions de contribution au corpus partagé d'autorités (personnes, collectivités, matières). Les décisions se prennent par consentement : sans objection motivée avant l'échéance, la proposition est appliquée par un membre de l'équipe.", 'La cola de propuestas de contribución al corpus compartido de autoridades (personas, colectividades, materias). Las decisiones se toman por consentimiento: sin objeción motivada antes del plazo, la propuesta la aplica un miembro del equipo.', 'The queue of contribution proposals to the shared authorities corpus (people, collectivities, subjects). Decisions are made by consent: with no motivated objection by the deadline, the proposal is applied by a team member.'],
  'atelier.action.closeForm':     ['Fechar', 'Fermer', 'Cerrar', 'Close'],
  'atelier.action.newFusion':     ['Propor uma fusão', 'Proposer une fusion', 'Proponer una fusión', 'Propose a merge'],
  'atelier.action.refresh':       ['Atualizar', 'Actualiser', 'Actualizar', 'Refresh'],
  'atelier.action.apply':         ['Aplicar', 'Appliquer', 'Aplicar', 'Apply'],
  'atelier.action.withdraw':      ['Retirar', 'Retirer', 'Retirar', 'Withdraw'],
  'atelier.form.error.ids':       ['Informe os dois identificadores (duplicata e canônica).', 'Indiquez les deux identifiants (duplicata et canonique).', 'Indique los dos identificadores (duplicado y canónico).', 'Provide both identifiers (duplicate and canonical).'],
  'atelier.form.error.rationale': ['Explique brevemente o motivo da proposta.', 'Expliquez brièvement le motif de la proposition.', 'Explique brevemente el motivo de la propuesta.', 'Briefly explain the reason for the proposal.'],
  'atelier.form.success':         ['Proposta registrada. A discussão fica aberta até o prazo.', "Proposition enregistrée. La discussion reste ouverte jusqu'à l'échéance.", 'Propuesta registrada. La discusión queda abierta hasta el plazo.', 'Proposal registered. The discussion stays open until the deadline.'],
  'atelier.form.title':           ['Propor a fusão de uma duplicata', "Proposer la fusion d'une duplicata", 'Proponer la fusión de un duplicado', 'Propose merging a duplicate'],
  'atelier.form.targetKind':      ['Tipo de autoridade', "Type d'autorité", 'Tipo de autoridad', 'Authority type'],
  'atelier.form.duplicate':       ['ID da duplicata (a remover)', 'ID de la duplicata (à supprimer)', 'ID del duplicado (a eliminar)', 'Duplicate ID (to remove)'],
  'atelier.form.canonical':       ['ID da canônica (a manter)', 'ID de la canonique (à conserver)', 'ID de la canónica (a mantener)', 'Canonical ID (to keep)'],
  'atelier.form.rationale':       ['Motivo', 'Motif', 'Motivo', 'Reason'],
  'atelier.form.sending':         ['Enviando…', 'Envoi…', 'Enviando…', 'Sending…'],
  'atelier.form.submit':          ['Registrar proposta', 'Enregistrer la proposition', 'Registrar propuesta', 'Register proposal'],
  'atelier.kind.author':          ['Pessoa / coletividade (author)', 'Personne / collectivité (author)', 'Persona / colectividad (author)', 'Person / collectivity (author)'],
  'atelier.kind.subject':         ['Matéria (subject)', 'Matière (subject)', 'Materia (subject)', 'Subject'],
  'atelier.row.by':               ['por {name}', 'par {name}', 'por {name}', 'by {name}'],
  'atelier.row.deadline':         ['prazo: {date}', 'échéance : {date}', 'plazo: {date}', 'deadline: {date}'],
  'atelier.row.objections':       ['{n} objeção(ões)', '{n} objection(s)', '{n} objeción(es)', '{n} objection(s)'],
  // criar-conta : option « compte contributeur » (Atelier autorités).
  'auth.create.intent.optionContributor': ['Sou contribuinte de autoridades (sem biblioteca)', "Je suis contributeur·rice d'autorités (sans bibliothèque)", 'Soy contribuyente de autoridades (sin biblioteca)', "I'm an authorities contributor (no library)"],
  'auth.create.intent.contributor.title': ['Conta de contribuinte de autoridades', 'Compte de contribution aux autorités', 'Cuenta de contribución a autoridades', 'Authorities contributor account'],
  'auth.create.intent.contributor.body':  ['Uma conta de rede, sem vínculo a uma biblioteca, para colaborar com o corpus compartilhado de autoridades (pessoas, coletividades, matérias): propor fusões, correções, traduções. Você propõe; a aplicação se dá por consentimento.', "Un compte réseau, sans rattachement à une bibliothèque, pour collaborer au corpus partagé d'autorités (personnes, collectivités, matières) : proposer des fusions, corrections, traductions. Vous proposez ; l'application se fait par consentement.", 'Una cuenta de red, sin vínculo a una biblioteca, para colaborar con el corpus compartido de autoridades (personas, colectividades, materias): proponer fusiones, correcciones, traducciones. Tú propones; la aplicación se hace por consentimiento.', 'A network account, not tied to a library, to collaborate on the shared authorities corpus (people, collectivities, subjects): propose merges, corrections, translations. You propose; application happens by consent.'],
  // Objection (atelier page) — coordenador d'une biblio utilisatrice.
  'atelier.action.object':   ['Objetar', 'Objecter', 'Objetar', 'Object'],
  'atelier.obj.library':     ['Biblioteca que objeta', 'Bibliothèque qui objecte', 'Biblioteca que objeta', 'Objecting library'],
  'atelier.obj.libraryPh':   ['Escolha…', 'Choisir…', 'Elegir…', 'Choose…'],
  'atelier.obj.reason':      ['Motivação (mín. 20 caracteres)', 'Motivation (min. 20 caractères)', 'Motivación (mín. 20 caracteres)', 'Reason (min. 20 characters)'],
  'atelier.obj.submit':      ['Registrar objeção', "Enregistrer l'objection", 'Registrar objeción', 'Register objection'],
  'atelier.obj.error.lib':   ['Selecione a biblioteca que objeta.', 'Choisissez la bibliothèque qui objecte.', 'Seleccione la biblioteca que objeta.', 'Select the objecting library.'],
  'atelier.obj.error.reason':['A objeção precisa de uma motivação (mín. 20 caracteres).', "L'objection requiert une motivation (min. 20 caractères).", 'La objeción necesita una motivación (mín. 20 caracteres).', 'The objection needs a reason (min. 20 characters).'],
  'atelier.obj.refused':     ['Objeção registrada — a proposta foi recusada (2+ bibliotecas usuárias).', 'Objection enregistrée — la proposition est refusée (2+ bibliothèques utilisatrices).', 'Objeción registrada — la propuesta fue rechazada (2+ bibliotecas usuarias).', 'Objection registered — the proposal was refused (2+ using libraries).'],
  'atelier.obj.contested':   ['Objeção registrada — a discussão está aberta.', 'Objection enregistrée — la discussion est ouverte.', 'Objeción registrada — la discusión está abierta.', 'Objection registered — the discussion is open.'],
  // Feature traduction (mode du formulaire de proposition).
  'atelier.form.newTitle':       ['Nova proposta', 'Nouvelle proposition', 'Nueva propuesta', 'New proposal'],
  'atelier.form.kind':           ['Tipo de proposta', 'Type de proposition', 'Tipo de propuesta', 'Proposal type'],
  'atelier.kindProp.fusion':     ['Fusão de duplicata', 'Fusion de duplicata', 'Fusión de duplicado', 'Merge a duplicate'],
  'atelier.kindProp.traduction': ['Tradução de biografia (pessoa)', 'Traduction de biographie (personne)', 'Traducción de biografía (persona)', 'Biography translation (person)'],
  'atelier.form.authorId':       ['ID da autoridade (pessoa)', "ID de l'autorité (personne)", 'ID de la autoridad (persona)', 'Authority ID (person)'],
  'atelier.form.lang':           ['Idioma', 'Langue', 'Idioma', 'Language'],
  'atelier.form.bio':            ['Biografia traduzida', 'Biographie traduite', 'Biografía traducida', 'Translated biography'],
  'atelier.form.error.authorId': ['Informe o ID da autoridade (pessoa).', "Indiquez l'ID de l'autorité (personne).", 'Indique el ID de la autoridad (persona).', 'Provide the authority ID (person).'],
  'atelier.form.error.bio':      ['Escreva a biografia traduzida.', 'Saisissez la biographie traduite.', 'Escriba la biografía traducida.', 'Write the translated biography.'],
};

function valFor(loc, quad) {
  switch (loc) {
    case 'pt-BR': return quad[0];
    case 'fr':    return quad[1];
    case 'es':    return quad[2];
    default:      return quad[3]; // en + repli (de/it/ca/nl/el/eo)
  }
}

let total = 0;
for (const loc of LOCALES) {
  const file = path.join(__dirname, '..', 'src', 'i18n', 'locales', loc + '.json');
  let content = fs.readFileSync(file, 'utf8');
  const existing = JSON.parse(content);
  const entries = [];
  for (const [k, quad] of Object.entries(T)) {
    if (k in existing) continue;
    entries.push('  ' + JSON.stringify(k) + ': ' + JSON.stringify(valFor(loc, quad)));
  }
  if (entries.length === 0) { console.log(loc + ': rien a ajouter'); continue; }
  const marker = content.lastIndexOf('}');
  const head = content.slice(0, marker).replace(/\s*$/, '');
  const tail = content.slice(marker);
  content = head + ',\n' + entries.join(',\n') + '\n' + tail;
  if (!content.endsWith('\n')) content += '\n';
  fs.writeFileSync(file, content, 'utf8');
  JSON.parse(fs.readFileSync(file, 'utf8')); // valide le JSON
  console.log(loc + ': +' + entries.length + ' cles');
  total += entries.length;
}
console.log('Total: ' + total + ' entrees ajoutees.');
