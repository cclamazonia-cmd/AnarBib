// Injecte les clés mail-strings dédiées au COMPTE CONTRIBUTEUR (bénévole réseau,
// atelier autorités) dans supabase/functions/_shared/i18n/mail-strings.ts :
// gabarit de bienvenue propre (welcome.*.contributor) + e-mail admin dédié
// (register.internal.*.contributor), pour ne plus réutiliser le registre
// « orpheline ». 10 locales obligatoires (type Record + test) ; pt-BR/fr/es/en
// traduits, it/de/ca/eo/nl/el en repli anglais (DOC-I18N-1). Idempotent.
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'supabase', 'functions', '_shared', 'i18n', 'mail-strings.ts');
const ANCHOR = '  "network.cooptation_voted.cta": {';

// Quadruplets [pt-BR, fr, es, en]. it/de/ca/eo/nl/el = repli anglais.
const T = {
  'welcome.context.contributor': [
    'Sua conta de contribuinte foi criada. Você integra a equipe de contribuição do AnarBib: ajude a melhorar o acervo compartilhado de autoridades (pessoas, coletividades, matérias) propondo fusões, correções e traduções. Não é preciso ter biblioteca para isso.',
    "Ton compte de contributeur·rice est créé. Tu rejoins l'équipe de contribution d'AnarBib : aide à améliorer le corpus partagé d'autorités (personnes, collectivités, matières) en proposant des fusions, des corrections et des traductions. Pas besoin de bibliothèque pour cela.",
    'Tu cuenta de colaboración ha sido creada. Te unes al equipo de contribución de AnarBib: ayuda a mejorar el corpus compartido de autoridades (personas, colectividades, materias) proponiendo fusiones, correcciones y traducciones. No hace falta tener biblioteca para ello.',
    "Your contributor account has been created. You're joining AnarBib's contribution team: help improve the shared authorities corpus (people, collectivities, subjects) by proposing merges, corrections and translations. No library is needed for that."],
  'welcome.contributor.atelierCta': [
    'Abrir a oficina de contribuição',
    "Ouvrir l'atelier de contribution",
    'Abrir el taller de contribución',
    'Open the contribution workshop'],
  'welcome.contributor.catalogIntro': [
    'Você também pode explorar o acervo compartilhado:',
    'Tu peux aussi explorer le catalogue partagé :',
    'También puedes explorar el catálogo compartido:',
    'You can also browse the shared catalog:'],
  'welcome.pretitle.contributor': [
    'CONTA DE CONTRIBUINTE',
    'COMPTE CONTRIBUTEUR·RICE',
    'CUENTA DE COLABORACIÓN',
    'CONTRIBUTOR ACCOUNT'],
  'welcome.title.contributor': [
    'Bem-vinde à equipe de contribuição',
    "Bienvenue dans l'équipe de contribution",
    'Bienvenide al equipo de contribución',
    'Welcome to the contribution team'],
  'welcome.subtitle.contributor': [
    'Sua conta de contribuinte do AnarBib está pronta.',
    'Ton compte de contributeur·rice AnarBib est prêt.',
    'Tu cuenta de colaboración en AnarBib está lista.',
    'Your AnarBib contributor account is ready.'],
  'welcome.subject.contributor': [
    'Bem-vinde à equipe de contribuição do AnarBib',
    "Bienvenue dans l'équipe de contribution d'AnarBib",
    'Bienvenide al equipo de contribución de AnarBib',
    'Welcome to the AnarBib contribution team'],
  'register.internal.title.contributor': [
    'Novo contribuinte de rede',
    'Nouveau·elle contributeur·rice de réseau',
    'Nuevo·a colaborador·e de red',
    'New network contributor'],
  'register.internal.subtitle.contributor': [
    'Novo·a contribuinte de rede (sem biblioteca), ID {publicId}.',
    'Nouveau·elle contributeur·rice de réseau (sans bibliothèque), ID {publicId}.',
    'Nuevo·a colaborador·e de red (sin biblioteca), ID {publicId}.',
    'New network contributor (no library), ID {publicId}.'],
};

function entryFor(key, quad) {
  const [pt, fr, es, en] = quad;
  const J = (s) => JSON.stringify(s);
  return '  ' + J(key) + ': { ' +
    '"pt-BR": ' + J(pt) + ', "fr": ' + J(fr) + ', "es": ' + J(es) + ', "en": ' + J(en) + ', ' +
    '"it": ' + J(en) + ', "de": ' + J(en) + ', "ca": ' + J(en) + ', "eo": ' + J(en) + ', "nl": ' + J(en) + ', "el": ' + J(en) +
    ' },\n';
}

let content = fs.readFileSync(FILE, 'utf8');
const keys = Object.keys(T);
const already = keys.filter((k) => content.includes('"' + k + '"'));
if (already.length === keys.length) { console.log('Rien à ajouter (déjà présent).'); process.exit(0); }
if (already.length > 0) { console.error('État partiel inattendu, abandon. Présentes: ' + already.join(', ')); process.exit(1); }

const idx = content.indexOf(ANCHOR);
if (idx < 0) { console.error('Ancre introuvable: ' + ANCHOR); process.exit(1); }

let block = '';
for (const k of keys) block += entryFor(k, T[k]);
content = content.slice(0, idx) + block + content.slice(idx);
fs.writeFileSync(FILE, content, 'utf8');
console.log('Ajout de ' + keys.length + ' clés contributeur dans mail-strings.ts.');
