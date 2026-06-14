// Ajoute les clés i18n de la page conta contributeur (ContributorAccountPage)
// aux 10 locales. pt-BR/fr/es/en traduits ; it/de/ca/nl/el/eo en repli anglais
// (DOC-I18N-1). Idempotent. Append avant le `}` final de chaque locale.
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];

// Quadruplets [pt-BR, fr, es, en]. Autres locales = repli anglais.
const T = {
  'contributor.conta.pageTitle':       ['Minha conta de contribuinte', 'Mon compte contributeur', 'Mi cuenta de colaboración', 'My contributor account'],
  'contributor.conta.title':           ['Meu espaço de contribuição', 'Mon espace contributeur·rice', 'Mi espacio de colaboración', 'My contributor space'],
  'contributor.conta.subtitle':        ['Voluntárie da rede AnarBib — você ajuda a melhorar o acervo compartilhado.', 'Bénévole du réseau AnarBib — tu aides à améliorer le corpus partagé.', 'Voluntarie de la red AnarBib — ayudas a mejorar el corpus compartido.', 'AnarBib network volunteer — you help improve the shared corpus.'],
  'contributor.conta.actions.title':   ['Contribuir', 'Contribuer', 'Contribuir', 'Contribute'],
  'contributor.conta.actions.atelier': ['Abrir a oficina de contribuição', "Ouvrir l'atelier de contribution", 'Abrir el taller de contribución', 'Open the contribution workshop'],
  'contributor.conta.actions.catalog': ['Explorar o acervo', 'Explorer le catalogue', 'Explorar el catálogo', 'Browse the catalog'],
  'contributor.conta.actions.hint':    ['Proponha fusões, correções e traduções de autoridades; ou explore o acervo compartilhado.', 'Propose des fusions, corrections et traductions sur les autorités ; ou parcours le catalogue partagé.', 'Propón fusiones, correcciones y traducciones de autoridades; o explora el catálogo compartido.', 'Propose merges, corrections and translations on authorities; or browse the shared catalog.'],
  'contributor.conta.proposals.title': ['Minhas contribuições', 'Mes contributions', 'Mis contribuciones', 'My contributions'],
  'contributor.conta.proposals.empty': ['Você ainda não fez nenhuma proposta.', "Tu n'as pas encore fait de proposition.", 'Aún no has hecho ninguna propuesta.', "You haven't made any proposal yet."],
  'contributor.conta.kind.creation':   ['Criação', 'Création', 'Creación', 'Creation'],
  'contributor.conta.kind.edition':    ['Edição', 'Édition', 'Edición', 'Edit'],
  'contributor.conta.kind.fusion':     ['Fusão', 'Fusion', 'Fusión', 'Merge'],
  'contributor.conta.kind.traduction': ['Tradução', 'Traduction', 'Traducción', 'Translation'],
  'contributor.conta.targetKind.author':  ['pessoa/coletividade', 'personne/collectivité', 'persona/colectividad', 'person/collectivity'],
  'contributor.conta.targetKind.subject': ['matéria', 'matière', 'materia', 'subject'],
  'contributor.conta.status.open':              ['Em aberto', 'Ouverte', 'Abierta', 'Open'],
  'contributor.conta.status.contested':         ['Contestada', 'Contestée', 'Impugnada', 'Contested'],
  'contributor.conta.status.resolved_consent':  ['Aceita por consentimento', 'Adoptée par consentement', 'Aceptada por consentimiento', 'Accepted by consent'],
  'contributor.conta.status.refused':           ['Recusada', 'Refusée', 'Rechazada', 'Refused'],
  'contributor.conta.status.applied':           ['Aplicada', 'Appliquée', 'Aplicada', 'Applied'],
  'contributor.conta.status.withdrawn':         ['Retirada', 'Retirée', 'Retirada', 'Withdrawn'],
  'contributor.conta.statut.title':    ['Meu status', 'Mon statut', 'Mi estatus', 'My status'],
  'contributor.conta.statut.active':   ['Contribuinte ativo·a', 'Contributeur·rice actif·ve', 'Colaborador·e activo·a', 'Active contributor'],
  'contributor.conta.statut.inactive': ['Conta de contribuinte', 'Compte contributeur·rice', 'Cuenta de colaboración', 'Contributor account'],
  'contributor.conta.statut.since':    ['membro desde {date}', 'membre depuis le {date}', 'miembro desde {date}', 'member since {date}'],
  'contributor.conta.notif.consent':   ['Receber comunicações por e-mail da rede AnarBib (opcional)', 'Recevoir les communications par e-mail du réseau AnarBib (facultatif)', 'Recibir comunicaciones por correo de la red AnarBib (opcional)', 'Receive email communications from the AnarBib network (optional)'],
  'contributor.conta.privacy.title':   ['Meus dados', 'Mes données', 'Mis datos', 'My data'],
  'contributor.conta.privacy.link':    ['Política de privacidade', 'Politique de confidentialité', 'Política de privacidad', 'Privacy policy'],
  'contributor.conta.profile.email':   ['E-mail', 'E-mail', 'Correo electrónico', 'Email'],
  'contributor.conta.profile.save':    ['Salvar', 'Enregistrer', 'Guardar', 'Save'],
};

function valFor(loc, quad) {
  switch (loc) {
    case 'pt-BR': return quad[0];
    case 'fr':    return quad[1];
    case 'es':    return quad[2];
    default:      return quad[3];
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
  JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(loc + ': +' + entries.length + ' cles');
  total += entries.length;
}
console.log('Total: ' + total + ' entrees ajoutees.');
