// Ajoute les clés i18n criar-conta : champ « organisation/collectif » (remplace
// l'ancien champ statistique sur le genre), champ « motivation » libre transmis
// aux admins, et la variante de sous-titre « contributeur·rice ».
// pt-BR / fr / es / en traduits ; de / it / ca / nl / el / eo en repli anglais
// (à traduire au fil de l'eau, cf. DOC-I18N-1). Idempotent.
// Miroir de scripts/i18n-add-atelier-autoridades.cjs (append avant le `}` final).
const fs = require('fs');
const path = require('path');

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];

// Valeurs en quadruplet [pt-BR, fr, es, en]. Les autres locales reprennent l'anglais.
const T = {
  // Sous-titre criar-conta — variante affichée uniquement pour le compte contributeur.
  'auth.create.subtitleContributor': [
    'Preencha os dados abaixo para se cadastrar como contribuinte.',
    "Remplis les champs ci-dessous pour t'inscrire comme contributeur·rice.",
    'Rellena los campos a continuación para registrarte como contribuyente.',
    'Fill in the fields below to sign up as a contributor.'
  ],
  // Organisation / collectif d'appartenance (remplace l'ancien champ « genre »).
  'auth.create.org': [
    'Organização ou coletivo (opcional)',
    'Organisation ou collectif (facultatif)',
    'Organización o colectivo (opcional)',
    'Organization or collective (optional)'
  ],
  'auth.create.orgHint': [
    'Se você faz parte de um coletivo, organização ou grupo, indique aqui.',
    "Si tu fais partie d'un collectif, d'une organisation ou d'un groupe, indique-le ici.",
    'Si formas parte de un colectivo, organización o grupo, indícalo aquí.',
    'If you belong to a collective, organization or group, mention it here.'
  ],
  // Motivation libre — transmise à l'équipe dans l'e-mail interne d'inscription.
  'auth.create.motivation': [
    'Sua motivação (opcional)',
    'Ta motivation (facultatif)',
    'Tu motivación (opcional)',
    'Your motivation (optional)'
  ],
  'auth.create.motivationHint': [
    'Algumas palavras sobre o que te traz à AnarBib. Esta mensagem é enviada à equipe.',
    "Quelques mots sur ce qui t'amène à AnarBib. Ce message est transmis à l'équipe.",
    'Unas palabras sobre lo que te trae a AnarBib. Este mensaje se envía al equipo.',
    'A few words about what brings you to AnarBib. This message is sent to the team.'
  ],
  // Libellé du champ « organisation/collectif » dans /conta et le backstage.
  'account.profile.org': [
    'Organização ou coletivo',
    'Organisation ou collectif',
    'Organización o colectivo',
    'Organization or collective'
  ],
  'panel.reader.org': [
    'Organização ou coletivo',
    'Organisation ou collectif',
    'Organización o colectivo',
    'Organization or collective'
  ],
  // Consentement e-mail — variante compte contributeur (sans mention d'emprunt
  // ni de bibliothèque ; facultatif).
  'auth.create.consentEmailContributor': [
    'Aceito receber comunicações por e-mail da rede AnarBib (opcional).',
    "J'accepte de recevoir des communications par e-mail du réseau AnarBib (facultatif).",
    'Acepto recibir comunicaciones por correo electrónico de la red AnarBib (opcional).',
    'I agree to receive email communications from the AnarBib network (optional).'
  ],
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
