// Injecte les clés mail-strings `authority.*` (atelier autorités, sous-paquet 1b)
// dans supabase/functions/_shared/i18n/mail-strings.ts.
// Le type S est Record<SupportedMailLocale, string> (10 locales OBLIGATOIRES par
// entrée) et le test 2 exige une valeur non vide pour les 10. On traduit
// pt-BR/fr/es/en ; it/de/ca/eo/nl/el reprennent l'anglais (repli DOC-I18N-1,
// à traduire au fil de l'eau). Idempotent. Charte : aucun terme proscrit
// (camerata/Compas) dans les valeurs anglaises de repli.
const fs = require('fs');
const path = require('path');

const FILE = path.join(__dirname, '..', 'supabase', 'functions', '_shared', 'i18n', 'mail-strings.ts');
const ANCHOR = '  "network.cooptation_voted.cta": {';

// Quadruplets [pt-BR, fr, es, en]. Les 6 autres locales reprennent l'anglais.
const T = {
  'authority.proposal_opened.subject': [
    'Nova proposta no acervo de autoridades',
    "Nouvelle proposition dans le corpus d'autorités",
    'Nueva propuesta en el corpus de autoridades',
    'New proposal in the authorities corpus'],
  'authority.proposal_opened.intro': [
    'Uma proposta de contribuição foi aberta sobre uma autoridade que sua biblioteca utiliza. Sem objeção motivada até o prazo, ela será aplicada por consentimento.',
    "Une proposition de contribution vient d'être ouverte sur une autorité que ta bibliothèque utilise. Sans objection motivée avant l'échéance, elle sera appliquée par consentement.",
    'Se ha abierto una propuesta de contribución sobre una autoridad que tu biblioteca utiliza. Sin objeción motivada antes del plazo, se aplicará por consentimiento.',
    'A contribution proposal has been opened on an authority your library uses. Without a motivated objection before the deadline, it will be applied by consent.'],
  'authority.proposal_objected.subject': [
    'Objeção registrada em uma proposta',
    'Objection déposée sur une proposition',
    'Objeción registrada en una propuesta',
    'Objection filed on a proposal'],
  'authority.proposal_objected.intro': [
    'Uma objeção motivada foi registrada sobre uma proposta. A discussão permanece aberta (anti-blackball).',
    "Une objection motivée a été déposée sur une proposition. La discussion reste ouverte (anti-blackball).",
    'Se ha registrado una objeción motivada sobre una propuesta. La discusión permanece abierta (anti-blackball).',
    'A motivated objection has been filed on a proposal. The discussion stays open (anti-blackball).'],
  'authority.proposal_resolved_consent.subject': [
    'Proposta aceita por consentimento',
    'Proposition adoptée par consentement',
    'Propuesta aceptada por consentimiento',
    'Proposal accepted by consent'],
  'authority.proposal_resolved_consent.intro': [
    'O prazo terminou sem objeção: a proposta foi aceita por consentimento. Um membro da equipe poderá aplicá-la.',
    "L'échéance est passée sans objection : la proposition est adoptée par consentement. Un membre de l'équipe pourra l'appliquer.",
    'El plazo terminó sin objeción: la propuesta fue aceptada por consentimiento. Un miembro del equipo podrá aplicarla.',
    'The deadline passed without objection: the proposal is accepted by consent. A team member may apply it.'],
  'authority.proposal_refused.subject': [
    'Proposta recusada',
    'Proposition refusée',
    'Propuesta rechazada',
    'Proposal refused'],
  'authority.proposal_refused.intro': [
    'Sua proposta foi recusada após objeção(ões) motivada(s). A motivação está indicada abaixo.',
    "Ta proposition a été refusée suite à une ou des objections motivées. La motivation est indiquée ci-dessous.",
    'Tu propuesta fue rechazada tras una o varias objeciones motivadas. La motivación se indica a continuación.',
    'Your proposal was refused after one or more motivated objections. The reason is shown below.'],
  'authority.merge_executed.subject': [
    'Fusão aplicada no acervo de autoridades',
    "Fusion appliquée dans le corpus d'autorités",
    'Fusión aplicada en el corpus de autoridades',
    'Merge applied in the authorities corpus'],
  'authority.merge_executed.intro': [
    'Uma fusão de duplicata foi aplicada em uma autoridade que sua biblioteca utiliza.',
    'Une fusion de doublon a été appliquée sur une autorité que ta bibliothèque utilise.',
    'Se aplicó una fusión de duplicado en una autoridad que tu biblioteca utiliza.',
    'A duplicate merge was applied on an authority your library uses.'],
  'authority.edit_applied.subject': [
    'Edição aplicada no acervo de autoridades',
    "Édition appliquée dans le corpus d'autorités",
    'Edición aplicada en el corpus de autoridades',
    'Edit applied in the authorities corpus'],
  'authority.edit_applied.intro': [
    'Uma edição foi aplicada em uma autoridade que sua biblioteca utiliza.',
    'Une édition a été appliquée sur une autorité que ta bibliothèque utilise.',
    'Se aplicó una edición en una autoridad que tu biblioteca utiliza.',
    'An edit was applied on an authority your library uses.'],
  'authority.label.kind':      ['Tipo de proposta', 'Type de proposition', 'Tipo de propuesta', 'Proposal type'],
  'authority.label.authority': ['Autoridade', 'Autorité', 'Autoridad', 'Authority'],
  'authority.label.reason':    ['Motivação', 'Motivation', 'Motivación', 'Reason'],
  'authority.kind.creation':   ['Criação', 'Création', 'Creación', 'Creation'],
  'authority.kind.edition':    ['Edição', 'Édition', 'Edición', 'Edit'],
  'authority.kind.fusion':     ['Fusão', 'Fusion', 'Fusión', 'Merge'],
  'authority.kind.traduction': ['Tradução', 'Traduction', 'Traducción', 'Translation'],
  'authority.action.title':    ['Oficina de autoridades', "Atelier des autorités", 'Taller de autoridades', 'Authorities workshop'],
  'authority.action.cta':      ['Abrir a oficina', "Ouvrir l'atelier", 'Abrir el taller', 'Open the workshop'],
};

function entryFor(key, quad) {
  const [pt, fr, es, en] = quad;
  const J = (s) => JSON.stringify(s);
  // 10 locales : pt-BR/fr/es/en traduits ; it/de/ca/eo/nl/el = repli anglais.
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
console.log('Ajout de ' + keys.length + ' clés authority.* dans mail-strings.ts.');
