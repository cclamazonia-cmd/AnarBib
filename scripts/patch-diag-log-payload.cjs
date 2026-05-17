// ============================================================
// Patch DIAGNOSTIC — Log payload dans handlers consultas
// ============================================================
// TEMPORAIRE : ajoute un console.log au debut des 2 handlers pour
// voir le payload exact recu par l'EF. A RETIRER apres diagnostic.
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/domain/consultas.ts');

console.log('===== Patch DIAGNOSTIC log payload =====\n');

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
if (content.includes('[DIAG-141.2]')) {
  console.log('[INFO] Patch diagnostic deja applique.');
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
// MODIF 1 — Log dans handleConsultaV2LifecycleEvent
// ============================================================
console.log('[1/2] Log payload dans handleConsultaV2LifecycleEvent...');

patchZone('M1',
`export async function handleConsultaV2LifecycleEvent(
  recordId: number,
  event: string,
  payload?: NotifyPayload | null
) {
  const we = normalizeConsultaLifecycleEvent(event) || event;
  const cancelledBy = consultaCancelledByFromPayload(payload);`,

`export async function handleConsultaV2LifecycleEvent(
  recordId: number,
  event: string,
  payload?: NotifyPayload | null
) {
  // [DIAG-141.2] LOG TEMPORAIRE pour diagnostic B3/B6
  console.log("[DIAG-141.2-lifecycle] event=" + event + " recordId=" + recordId + " payload=" + JSON.stringify(payload));
  const we = normalizeConsultaLifecycleEvent(event) || event;
  const cancelledBy = consultaCancelledByFromPayload(payload);`);

// ============================================================
// MODIF 2 — Log dans handleConsultaV2WorkflowEvent
// ============================================================
console.log('\n[2/2] Log payload dans handleConsultaV2WorkflowEvent...');

patchZone('M2',
`export async function handleConsultaV2WorkflowEvent(
  recordId: number,
  event: string,
  payload?: NotifyPayload | null
) {
  const we = normalizeConsultaWorkflowEvent(event) || event;`,

`export async function handleConsultaV2WorkflowEvent(
  recordId: number,
  event: string,
  payload?: NotifyPayload | null
) {
  // [DIAG-141.2] LOG TEMPORAIRE pour diagnostic B3/B6
  console.log("[DIAG-141.2-workflow] event=" + event + " recordId=" + recordId + " payload=" + JSON.stringify(payload));
  const we = normalizeConsultaWorkflowEvent(event) || event;`);

// Verifications
console.log('\n===== Verifications =====');
const diagCount = (content.match(/\[DIAG-141\.2/g) || []).length;
console.log(`  [DIAG-141.2] occurrences : ${diagCount} (att 2 logs + commentaires = 4 total)`);

if (diagCount < 4 || diagCount > 6) {
  console.error('\n[FATAL] Compteur inattendu');
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

console.log('\n===== Patch DIAGNOSTIC applique =====');
console.log('\nProchaines etapes :');
console.log('  1. (PAS DE COMMIT du log diagnostic - patch temporaire)');
console.log('  2. supabase functions deploy notify-event --no-verify-jwt');
console.log('  3. Refaire un test B6 (creer consulta, biblio annule avec note)');
console.log('  4. Aller sur Supabase Dashboard > Functions > notify-event > Logs');
console.log('  5. Chercher [DIAG-141.2-lifecycle] dans les logs');
console.log('  6. Copier le JSON du payload (en particulier verifier');
console.log('     si "workflow_note" est present)');
console.log('  7. Apres diagnostic : git checkout supabase/functions/_shared/domain/consultas.ts');
console.log('     (annule les logs avant de continuer)');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
