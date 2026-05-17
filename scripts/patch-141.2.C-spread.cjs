// ============================================================
// Patch sous-paquet 141.2.C-spread — consultas.ts
// ============================================================
// Finalise le sous-paquet 141.2 en spread des noteDetail dans les 4 sections
// 'details' des renderEmail :
//
//   M1. handleConsultaV2LifecycleEvent mail lecteur : ...noteDetailReader
//   M2. handleConsultaV2LifecycleEvent mail staff   : ...noteDetailStaff
//   M3. handleConsultaV2WorkflowEvent mail lecteur  : ...noteDetailReaderWf (nouvelle const)
//   M4. handleConsultaV2WorkflowEvent mail staff    : ...noteDetailStaffWf (nouvelle const)
//
// noteDetailReader/Staff existent deja (paquet 141.2.B, M7).
// noteDetailReaderWf/StaffWf sont creees dans ce patch (M3a/M4a) puis
// spreadees (M3b/M4b).
//
// Resultat : B2, B3 generalise, B5, complement B6 entierement resolus
// cote handler EF. Les notes workflow apparaitront comme ligne "Observacao: X"
// dans les mails quand workflow_note est non-vide.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/domain/consultas.ts');

console.log('===== Patch 141.2.C-spread =====\n');

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

// Idempotence
if (content.includes('noteDetailReaderWf') || content.includes('noteDetailStaffWf')) {
  console.log('[INFO] Patch deja applique (noteDetailReaderWf/StaffWf detecte).');
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
// MODIF 1 — Lifecycle, mail lecteur : spread noteDetailReader
// ============================================================
// Ancre unique : 4 spaces indent, se termine par 'refs' (pas de date dans
// lifecycle), suivie de footerHtml.
console.log('[1/6] Lifecycle mail lecteur : spread noteDetailReader...');

patchZone('M1',
`      details: [
        ...(tits ? [{ label: label(locale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(locale, "refs"), value: brfs }] : [])
      ],
      footerHtml: footerPadrao(ctx),`,

`      details: [
        ...(tits ? [{ label: label(locale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(locale, "refs"), value: brfs }] : []),
        ...noteDetailReader
      ],
      footerHtml: footerPadrao(ctx),`);

// ============================================================
// MODIF 2 — Lifecycle, mail staff : spread noteDetailStaff
// ============================================================
// Ancre unique : 4 spaces indent, commence par 'reader: aun' (specifique staff),
// se termine par 'refs' (pas de date).
console.log('\n[2/6] Lifecycle mail staff : spread noteDetailStaff...');

patchZone('M2',
`      details: [
        { label: label(libLocale, "reader"), value: aun },
        ...(tits ? [{ label: label(libLocale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(libLocale, "refs"), value: brfs }] : [])
      ],
      footerHtml: footerPadrao(ctx),`,

`      details: [
        { label: label(libLocale, "reader"), value: aun },
        ...(tits ? [{ label: label(libLocale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(libLocale, "refs"), value: brfs }] : []),
        ...noteDetailStaff
      ],
      footerHtml: footerPadrao(ctx),`);

// ============================================================
// MODIF 3 — Workflow event : creer noteDetailReaderWf et noteDetailStaffWf
// ============================================================
// On insere les 2 declarations juste apres la ligne 'when = whenStart && whenEnd...'
// pour qu'elles soient disponibles dans les 2 sections mail (lecteur + staff).
console.log('\n[3/6] Workflow event : creer noteDetailReaderWf et noteDetailStaffWf...');

patchZone('M3-create',
`  const whenStart = startsAt ? formatDateTimeInZone(startsAt, tz) : "";
  const whenEnd = endsAt ? (formatDateTimeInZone(endsAt, tz).split(" ")[1] || "") : "";
  const when = whenStart && whenEnd ? \`\${whenStart} - \${whenEnd}\` : whenStart;`,

`  const whenStart = startsAt ? formatDateTimeInZone(startsAt, tz) : "";
  const whenEnd = endsAt ? (formatDateTimeInZone(endsAt, tz).split(" ")[1] || "") : "";
  const when = whenStart && whenEnd ? \`\${whenStart} - \${whenEnd}\` : whenStart;
  // Paquet 141.2.C : ligne 'Observacao' a injecter dans details (lecteur ET staff)
  // si workflowNote presente. Resout B3 generalise (motif refus, motif annulation,
  // note staff lors de proposition, etc.) cote workflow event.
  const noteDetailReaderWf = workflowNote ? [{ label: label(locale, "note") || "Note", value: workflowNote }] : [];
  const noteDetailStaffWf = workflowNote ? [{ label: label(libLocale, "note") || "Note", value: workflowNote }] : [];`);

// ============================================================
// MODIF 4 — Workflow event, mail lecteur : spread noteDetailReaderWf
// ============================================================
// Ancre unique : 6 spaces indent (handler workflow imbrique dans if reader), 
// se termine par 'date' (sa specificite vs lifecycle), suivi de footerHtml.
console.log('\n[4/6] Workflow event mail lecteur : spread noteDetailReaderWf...');

patchZone('M4',
`      details: [
        ...(tits ? [{ label: label(locale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(locale, "refs"), value: brfs }] : []),
        ...(when ? [{ label: label(locale, "date"), value: when }] : [])
      ],
      footerHtml: footerPadrao(ctx),`,

`      details: [
        ...(tits ? [{ label: label(locale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(locale, "refs"), value: brfs }] : []),
        ...(when ? [{ label: label(locale, "date"), value: when }] : []),
        ...noteDetailReaderWf
      ],
      footerHtml: footerPadrao(ctx),`);

// ============================================================
// MODIF 5 — Workflow event, mail staff : spread noteDetailStaffWf
// ============================================================
// Ancre unique : 6 spaces indent, commence par 'reader: aun', se termine par 'date'.
console.log('\n[5/6] Workflow event mail staff : spread noteDetailStaffWf...');

patchZone('M5',
`      details: [
        { label: label(libLocale, "reader"), value: aun },
        ...(tits ? [{ label: label(libLocale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(libLocale, "refs"), value: brfs }] : []),
        ...(when ? [{ label: label(libLocale, "date"), value: when }] : [])
      ],
      footerHtml: footerPadrao(ctx),`,

`      details: [
        { label: label(libLocale, "reader"), value: aun },
        ...(tits ? [{ label: label(libLocale, "items"), value: tits }] : []),
        ...(brfs ? [{ label: label(libLocale, "refs"), value: brfs }] : []),
        ...(when ? [{ label: label(libLocale, "date"), value: when }] : []),
        ...noteDetailStaffWf
      ],
      footerHtml: footerPadrao(ctx),`);

console.log('\n[6/6] Verifications finales...');

// ============================================================
// Verifications
// ============================================================
const checks = [
  // Les 2 constantes preparees au paquet B sont maintenant utilisees
  { name: 'noteDetailReader (decl + spread)', pattern: /noteDetailReader\b/g, min: 2, max: 5 },
  { name: 'noteDetailStaff (decl + spread)', pattern: /noteDetailStaff\b/g, min: 2, max: 5 },
  // Les 2 nouvelles constantes workflow sont declarees et utilisees
  { name: 'noteDetailReaderWf (decl + spread)', pattern: /noteDetailReaderWf/g, min: 2, max: 5 },
  { name: 'noteDetailStaffWf (decl + spread)', pattern: /noteDetailStaffWf/g, min: 2, max: 5 },
  // Les 4 spreads correspondants
  { name: 'spread ...noteDetailReader (lifecycle)', pattern: /\.\.\.noteDetailReader\b/g, min: 1, max: 1 },
  { name: 'spread ...noteDetailStaff (lifecycle)', pattern: /\.\.\.noteDetailStaff\b/g, min: 1, max: 1 },
  { name: 'spread ...noteDetailReaderWf', pattern: /\.\.\.noteDetailReaderWf/g, min: 1, max: 1 },
  { name: 'spread ...noteDetailStaffWf', pattern: /\.\.\.noteDetailStaffWf/g, min: 1, max: 1 },
];

let allOk = true;
for (const c of checks) {
  const count = (content.match(c.pattern) || []).length;
  const ok = count >= c.min && count <= c.max;
  console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(44)} : ${count} (range [${c.min},${c.max}])`);
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

console.log(`  consultas.ts : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);
console.log(`  EOL : ${eolStyle}`);

console.log('\n===== Patch 141.2.C-spread applique avec succes =====');
console.log('\nPROCHAINES ETAPES :');
console.log('  1. git diff supabase/functions/_shared/');
console.log('  2. npm run build (les 2 warnings TS6133 du paquet B doivent disparaitre)');
console.log('  3. git add + commit + push (i18n + spread en 1 commit cohesif)');
console.log('  4. supabase functions deploy notify-event --no-verify-jwt');
console.log('  5. Tests fonctionnels en prod (rederouler scenarios QA 2, 3, 5, 6, 8)');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
