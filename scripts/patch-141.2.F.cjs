// ============================================================
// Patch sous-paquet 141.2.F — Handler EF : lire schedule_reply_note (Fix B3)
// ============================================================
// Modif minimale dans consultas.ts : lire schedule_reply_note du payload
// (envoye par le trigger workflow depuis 141.2.E) et l'utiliser en priorite
// sur workflow_note pour les noteDetail.
//
// Doctrine : retro-compatible. Si schedule_reply_note absent (autres events
// que resposta_creneau), on retombe sur workflow_note.
// 
// Concerne uniquement handleConsultaV2WorkflowEvent (le motif du refus est
// specifique a ce handler). Le lifecycle handler garde son comportement
// inchange.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/domain/consultas.ts');

console.log('===== Patch sous-paquet 141.2.F (Fix B3 handler EF) =====\n');

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
if (content.includes('scheduleReplyNote')) {
  console.log('[INFO] Patch deja applique. Aucune modification.');
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
// MODIF 1 — Extraire schedule_reply_note + effectiveNote
// ============================================================
console.log('[1/2] Extraction schedule_reply_note + effectiveNote...');

patchZone('M1',
`  // Paquet 141.2 : extraction workflow_note (note staff lors de proposition,
  // note lecteur lors de refus, note staff lors de no-show, etc.).
  // Propagee via slotVars pour interpolation {workflow_note} dans templates i18n.
  const workflowNote = String(getPayloadValue(payload, "workflow_note") || items.find((i) => i.workflow_note)?.workflow_note || "").trim();
  const slotVars = buildSlotVars(startsAt, endsAt, tz, locale, workflowNote);
  const slotVarsLib = buildSlotVars(startsAt, endsAt, tz, libLocale, workflowNote);`,

`  // Paquet 141.2 : extraction workflow_note (note staff lors de proposition,
  // note staff lors de no-show, etc.).
  const workflowNote = String(getPayloadValue(payload, "workflow_note") || items.find((i) => i.workflow_note)?.workflow_note || "").trim();
  // Paquet 141.2.F (16/05/2026) : Fix B3 - le motif du refus par le
  // lecteur est dans schedule_reply_note (colonne dediee dans
  // consulta_item_workflow_v2), pas dans workflow_note. Le trigger
  // workflow le propage depuis paquet 141.2.E.
  // effectiveNote = schedule_reply_note prioritaire sur workflow_note
  // (retro-compatible : si reply_note absent, on retombe sur workflow_note).
  const scheduleReplyNote = String(getPayloadValue(payload, "schedule_reply_note") || items.find((i) => i.schedule_reply_note)?.schedule_reply_note || "").trim();
  const effectiveNote = scheduleReplyNote || workflowNote;
  const slotVars = buildSlotVars(startsAt, endsAt, tz, locale, effectiveNote);
  const slotVarsLib = buildSlotVars(startsAt, endsAt, tz, libLocale, effectiveNote);`);

// ============================================================
// MODIF 2 — noteDetailReaderWf et noteDetailStaffWf utilisent effectiveNote
// ============================================================
console.log('\n[2/2] noteDetailReaderWf / StaffWf utilisent effectiveNote...');

patchZone('M2',
`  // Paquet 141.2.C : ligne 'Observacao' a injecter dans details (lecteur ET staff)
  // si workflowNote presente. Resout B3 generalise (motif refus, motif annulation,
  // note staff lors de proposition, etc.) cote workflow event.
  const noteDetailReaderWf = workflowNote ? [{ label: label(locale, "note") || "Note", value: workflowNote }] : [];
  const noteDetailStaffWf = workflowNote ? [{ label: label(libLocale, "note") || "Note", value: workflowNote }] : [];`,

`  // Paquet 141.2.C : ligne 'Observacao' a injecter dans details (lecteur ET staff)
  // si effectiveNote presente. Resout B3 (motif refus lecteur via schedule_reply_note)
  // et autres cas (motif annulation, note staff lors de proposition) cote workflow event.
  const noteDetailReaderWf = effectiveNote ? [{ label: label(locale, "note") || "Note", value: effectiveNote }] : [];
  const noteDetailStaffWf = effectiveNote ? [{ label: label(libLocale, "note") || "Note", value: effectiveNote }] : [];`);

// ============================================================
// Verifications
// ============================================================
console.log('\n===== Verifications =====');
const checks = [
  { name: 'scheduleReplyNote declaration', pattern: /const scheduleReplyNote/g, expected: 1 },
  { name: 'effectiveNote (1 decl + 2 buildSlotVars + 2 noteDetail = 5+)', pattern: /effectiveNote/g, min: 5, max: 10 },
  { name: 'workflowNote toujours present (declaration)', pattern: /const workflowNote/g, expected: 2 },  // 1 lifecycle + 1 workflow
];

let allOk = true;
for (const c of checks) {
  const count = (content.match(c.pattern) || []).length;
  let ok;
  if (c.expected !== undefined) {
    ok = count === c.expected;
    console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(50)} : ${count} (att ${c.expected})`);
  } else {
    ok = count >= c.min && count <= c.max;
    console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(50)} : ${count} (range [${c.min},${c.max}])`);
  }
  if (!ok) allOk = false;
}

if (!allOk) {
  console.error('\n[FATAL] Compteurs incoherents');
  process.exit(1);
}

// Ecriture
console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  consultas.ts : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);

console.log('\n===== Patch 141.2.F applique avec succes =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff supabase/functions/_shared/domain/consultas.ts');
console.log('  2. npm run build');
console.log('  3. git add + commit + push');
console.log('  4. supabase functions deploy notify-event --no-verify-jwt');
console.log('  5. Re-test B3 (lecteur refuse creneau avec note -> verifier mail biblio)');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
