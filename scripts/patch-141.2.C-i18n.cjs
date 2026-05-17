// ============================================================
// Patch sous-paquet 141.2.C v2 — i18n (3 cles, l.note deja existante)
// ============================================================
// Ajoute dans _shared/i18n/mail-strings.ts :
//   - cwf.reader.em_preparacao (template lecteur B2)
//   - cwf.reader.nao_compareceu (template lecteur B5)
//   - cwf.staff.nao_compareceu (titre court mail coordination B5)
//
// NOTE : l.note existe deja (ligne 214 du fichier), pas besoin de l'ajouter.
//
// Doctrine : workflow_note injectee comme ligne 'details' dans renderEmail,
// pas comme {workflow_note} dans le template (cf. spread du patch C2 sur
// consultas.ts).
//
// Strings i18n utilisent escape unicode \uXXXX pour eviter tout probleme
// d'encodage lors de l'execution Node sur Windows (la console PowerShell
// peut rendre mal les UTF-8 mais le fichier ecrit est bien en UTF-8 propre).
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/i18n/mail-strings.ts');

console.log('===== Patch 141.2.C v2 i18n =====\n');

if (!fs.existsSync(FILE)) {
  console.error(`[FATAL] Fichier introuvable : ${FILE}`);
  process.exit(1);
}

const originalBuf = fs.readFileSync(FILE);
let content = originalBuf.toString('utf8');
const originalMd5 = crypto.createHash('md5').update(originalBuf).digest('hex');
const eolStyle = content.includes('\r\n') ? 'CRLF' : 'LF';
const originalSize = originalBuf.length;

console.log(`Fichier : ${FILE}`);
console.log(`  Avant : ${originalSize} bytes, EOL=${eolStyle}, MD5=${originalMd5.slice(0, 8)}\n`);

if (content.includes('"cwf.reader.em_preparacao"') 
    || content.includes('"cwf.reader.nao_compareceu"')
    || content.includes('"cwf.staff.nao_compareceu"')) {
  console.log('[INFO] Patch deja applique (au moins une des nouvelles cles existe).');
  process.exit(0);
}

function normalizeEol(str) {
  const lf = str.replace(/\r\n/g, '\n');
  if (eolStyle === 'CRLF') return lf.replace(/\n/g, '\r\n');
  return lf;
}

function patchZone(label, anchor, replacement) {
  const a = normalizeEol(anchor);
  const r = normalizeEol(replacement);
  if (!content.includes(a)) {
    throw new Error(`${label} : ancre introuvable`);
  }
  let count = 0;
  let idx = 0;
  while ((idx = content.indexOf(a, idx)) !== -1) {
    count++;
    idx += a.length;
  }
  if (count !== 1) {
    throw new Error(`${label} : ancre trouvee ${count} fois (attendu 1)`);
  }
  content = content.replace(a, r);
  console.log(`  OK : ${label}`);
}

try {

// ============================================================
// MODIF — Ajouter 3 templates cwf.* juste avant cwf.actionBox.replySlot
// ============================================================
// Ancre courte sans accents pour eviter probleme d'encodage.
console.log('[1/1] Ajout 3 templates cwf.* (em_preparacao + nao_compareceu reader + staff)...');

patchZone('M1',
`  "cwf.actionBox.replySlot": {`,

`  // ===== Paquet 141.2 (16/05/2026) =====
  // Templates pour 2 nouveaux events workflow consultas :
  //   - em_preparacao (B2) : transition solicitada -> em_preparacao
  //   - nao_compareceu (B5) : transition vers nao_compareceu
  // Doctrine : la note workflow_note (si presente) est injectee comme
  // ligne supplementaire dans 'details' du renderEmail, pas dans le template.
  "cwf.reader.em_preparacao": {
    "pt-BR": "Sua solicita\u00E7\u00E3o de consulta local est\u00E1 em prepara\u00E7\u00E3o. A biblioteca vai propor um hor\u00E1rio em breve.",
    fr: "Ta demande de consultation est en pr\u00E9paration. La biblioth\u00E8que te proposera un horaire bient\u00F4t.",
    es: "Tu solicitud de consulta local est\u00E1 en preparaci\u00F3n. La biblioteca propondr\u00E1 un horario pronto.",
    en: "Your local consultation request is being prepared. The library will propose a time slot soon.",
    it: "La tua richiesta di consultazione locale \u00E8 in preparazione. La biblioteca proporr\u00E0 un orario a breve.",
    de: "Deine Anfrage zur lokalen Einsichtnahme wird vorbereitet. Die Bibliothek wird bald einen Termin vorschlagen."
  },
  "cwf.reader.nao_compareceu": {
    "pt-BR": "Voc\u00EA foi marcado(a/e) como ausente na consulta local agendada para {date}, das {time_start} \u00E0s {time_end}. A biblioteca tinha se preparado para te receber. Caso queira marcar um novo hor\u00E1rio, entre em contato com a biblioteca.",
    fr: "Tu as \u00E9t\u00E9 marqu\u00E9\u00B7e comme absent\u00B7e \u00E0 la consultation pr\u00E9vue le {date}, de {time_start} \u00E0 {time_end}. La biblioth\u00E8que s'\u00E9tait pr\u00E9par\u00E9e \u00E0 t'accueillir. Si tu souhaites fixer un nouvel horaire, contacte la biblioth\u00E8que.",
    es: "Has sido marcado(a/e) como ausente en la consulta local programada para {date}, de {time_start} a {time_end}. La biblioteca se hab\u00EDa preparado para recibirte. Si quieres fijar un nuevo horario, contact\u00E1 a la biblioteca.",
    en: "You have been marked as absent for the local consultation scheduled on {date}, from {time_start} to {time_end}. The library had prepared to welcome you. If you wish to schedule a new time, please contact the library.",
    it: "Sei stato/a/* segnalato/a/* come assente alla consultazione locale prevista per il {date}, dalle {time_start} alle {time_end}. La biblioteca si era preparata ad accoglierti. Se desideri fissare un nuovo orario, contatta la biblioteca.",
    de: "Du wurdest als abwesend bei der lokalen Einsichtnahme am {date} von {time_start} bis {time_end} markiert. Die Bibliothek hatte sich darauf vorbereitet, dich zu empfangen. Wenn du einen neuen Termin vereinbaren m\u00F6chtest, kontaktiere die Bibliothek."
  },
  "cwf.staff.nao_compareceu": {
    "pt-BR": "N\u00E3o comparecimento registrado",
    fr: "Non-pr\u00E9sentation enregistr\u00E9e",
    es: "No comparecencia registrada",
    en: "No-show recorded",
    it: "Mancata presentazione registrata",
    de: "Nichterscheinen erfasst"
  },
  "cwf.actionBox.replySlot": {`);

// ============================================================
// Verifications
// ============================================================
console.log('\n===== Verifications =====');

const checks = [
  { name: 'cwf.reader.em_preparacao', pattern: /"cwf\.reader\.em_preparacao":\s*{/g, expected: 1 },
  { name: 'cwf.reader.nao_compareceu', pattern: /"cwf\.reader\.nao_compareceu":\s*{/g, expected: 1 },
  { name: 'cwf.staff.nao_compareceu', pattern: /"cwf\.staff\.nao_compareceu":\s*{/g, expected: 1 },
];

let allOk = true;
for (const c of checks) {
  const count = (content.match(c.pattern) || []).length;
  const ok = count === c.expected;
  console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(40)} : ${count} (att ${c.expected})`);
  if (!ok) allOk = false;
}

if (!allOk) {
  console.error('\n[FATAL] Compteurs incoherents');
  process.exit(1);
}

// ============================================================
// Ecriture
// ============================================================
console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  mail-strings.ts : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);
console.log(`  EOL : ${eolStyle}`);

console.log('\n===== Patch 141.2.C i18n applique avec succes =====');
console.log('\nProchaine etape : sous-paquet 141.2.C-spread (patch consultas.ts)');
console.log('  - Ajout ...noteDetailReader/Staff dans details des renderEmail lifecycle');
console.log('  - Creation noteDetailReader/Staff dans workflow + spread');
console.log('  - Resolution des 2 warnings TS6133 du sous-paquet B');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
