// ============================================================
// Patch sous-paquet 141.2.D — Fix CON_WE_MAP dans events.ts
// ============================================================
// Bug repere en QA prod 16/05/2026 apres deploiement 141.2.B+C :
// 
//   Event consulta_v2_em_preparacao recu par EF -> dispatch.ts route vers
//   handleConsultaV2WorkflowEvent -> normalizeConsultaWorkflowEvent retourne
//   "" (mapping absent dans CON_WE_MAP) -> we fallback sur event brut
//   "consulta_v2_em_preparacao" -> aucune branche if matche -> 
//   skippedEmailResult("user_mail", "unknown_workflow_event").
//
// Fix : ajouter les 2 mappings manquants dans CON_WE_MAP de events.ts.
//
//   consulta_v2_em_preparacao -> em_preparacao  (matche if "we === em_preparacao")
//   consulta_v2_nao_compareceu -> nao_compareceu (matche if "we === nao_compareceu")
//
// Apres ce patch + redeploy EF :
// - B2 : mail lecteur em_preparacao envoye
// - B5 : mail lecteur + mail coordination nao_compareceu envoyes
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/shared/events.ts');

console.log('===== Patch 141.2.D - fix CON_WE_MAP =====\n');

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
if (content.includes('consulta_v2_em_preparacao:') || content.includes('"consulta_v2_em_preparacao":')) {
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

console.log('[1/1] Ajout 2 mappings dans CON_WE_MAP...');

patchZone('M1',
`const CON_WE_MAP: Record<string, string> = {
  consulta_v2_agendada: "consulta_agendada",
  consulta_v2_resposta_creneau: "resposta_creneau"
};`,

`const CON_WE_MAP: Record<string, string> = {
  consulta_v2_agendada: "consulta_agendada",
  consulta_v2_resposta_creneau: "resposta_creneau",
  consulta_v2_em_preparacao: "em_preparacao",
  consulta_v2_nao_compareceu: "nao_compareceu"
};`);

// Verifications
console.log('\n===== Verifications =====');
const checks = [
  { name: 'consulta_v2_em_preparacao mapping', pattern: /consulta_v2_em_preparacao:\s*"em_preparacao"/g, expected: 1 },
  { name: 'consulta_v2_nao_compareceu mapping', pattern: /consulta_v2_nao_compareceu:\s*"nao_compareceu"/g, expected: 1 },
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

// Ecriture
console.log('\n===== Ecriture =====');
const newBuf = Buffer.from(content, 'utf8');
const newMd5 = crypto.createHash('md5').update(newBuf).digest('hex');
const newSize = newBuf.length;
fs.writeFileSync(FILE, newBuf);

console.log(`  events.ts : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize})`);
console.log(`  MD5 : ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);
console.log(`  EOL : ${eolStyle}`);

console.log('\n===== Patch 141.2.D applique avec succes =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff supabase/functions/_shared/shared/events.ts');
console.log('  2. npm run build');
console.log('  3. git add + commit + push');
console.log('  4. supabase functions deploy notify-event --no-verify-jwt');
console.log('  5. Re-test B2 (em_preparacao) et B5 (nao_compareceu)');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
