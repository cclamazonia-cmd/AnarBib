// ============================================================
// Patch sous-paquet 141.2.A v2 — Plumbing pour 2 nouveaux toggles
// ============================================================
// v2 (16/05/2026) : gere CRLF (Windows) et LF (Unix) en normalisant les
// ancres et les remplacements pour matcher le style de chaque fichier.
//
// Modifie 4 fichiers en une transaction (succes ou aucun changement) :
//   - types.ts                          : 2 champs interface
//   - library-notification-context.ts   : 2 defaults + 2 normalize
//   - policies.ts                       : 2 helpers
//   - dispatch.ts                       : 1 extension de routing
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');

const FILES = {
  types: path.join(REPO_ROOT, 'supabase/functions/_shared/core/types.ts'),
  context: path.join(REPO_ROOT, 'supabase/functions/_shared/context/library-notification-context.ts'),
  policies: path.join(REPO_ROOT, 'supabase/functions/_shared/context/policies.ts'),
  dispatch: path.join(REPO_ROOT, 'supabase/functions/_shared/core/dispatch.ts')
};

console.log('===== Patch sous-paquet 141.2.A v2 (CRLF/LF safe) =====\n');

// Verifier que les 4 fichiers existent
for (const [key, filePath] of Object.entries(FILES)) {
  if (!fs.existsSync(filePath)) {
    console.error(`[FATAL] Fichier introuvable : ${filePath}`);
    process.exit(1);
  }
}

// Lire les 4 fichiers + detecter style fin de ligne (CRLF ou LF)
const contents = {};
const eolStyle = {};
const originalMd5 = {};

for (const [key, filePath] of Object.entries(FILES)) {
  const buf = fs.readFileSync(filePath);
  contents[key] = buf.toString('utf8');
  originalMd5[key] = crypto.createHash('md5').update(buf).digest('hex');
  // Detecter CRLF : si on trouve \r\n, c'est CRLF, sinon LF
  eolStyle[key] = contents[key].includes('\r\n') ? 'CRLF' : 'LF';
  console.log(`  ${key.padEnd(10)} : ${buf.length} bytes, EOL=${eolStyle[key]}, MD5=${originalMd5[key].slice(0, 8)}`);
}
console.log('');

// Idempotence
const alreadyPatched = Object.values(contents).some(s => 
  s.includes('consulta_mail_em_preparacao_enabled')
);
if (alreadyPatched) {
  console.log('[INFO] Patch deja applique. Aucune modification.');
  console.log('Pour repartir de zero : git checkout supabase/');
  process.exit(0);
}

/**
 * Normalise une string multi-ligne au style EOL du fichier cible.
 * Mes ancres sont ecrites avec \n (LF). Si le fichier est CRLF, on convertit.
 */
function normalizeEol(str, targetStyle) {
  // D'abord tout normaliser en LF (au cas ou il y aurait du CRLF dans la string source)
  const lf = str.replace(/\r\n/g, '\n');
  if (targetStyle === 'CRLF') {
    return lf.replace(/\n/g, '\r\n');
  }
  return lf;
}

/**
 * Applique un remplacement en tenant compte du style EOL du fichier.
 * Retourne { success, newContent, count } ou { success: false, error }
 */
function patchFile(key, anchor, replacement) {
  const style = eolStyle[key];
  const normalizedAnchor = normalizeEol(anchor, style);
  const normalizedReplacement = normalizeEol(replacement, style);
  
  if (!contents[key].includes(normalizedAnchor)) {
    return { success: false, error: `ancre introuvable (style=${style})` };
  }
  
  // Compte le nombre d'occurrences pour s'assurer de l'unicite
  let count = 0;
  let idx = 0;
  while ((idx = contents[key].indexOf(normalizedAnchor, idx)) !== -1) {
    count++;
    idx += normalizedAnchor.length;
  }
  
  if (count !== 1) {
    return { success: false, error: `ancre trouvee ${count} fois (attendu 1)` };
  }
  
  contents[key] = contents[key].replace(normalizedAnchor, normalizedReplacement);
  return { success: true, count };
}

// ============================================================
// PATCH 1 — types.ts
// ============================================================
console.log('[1/4] Patch types.ts...');

const r1 = patchFile('types',
`  consulta_mail_realizada_enabled: boolean;
  consulta_mail_cancelada_enabled: boolean;
  consulta_mail_expirada_enabled: boolean;
  admin_copy_consultas_enabled: boolean;`,

`  consulta_mail_realizada_enabled: boolean;
  consulta_mail_cancelada_enabled: boolean;
  consulta_mail_expirada_enabled: boolean;
  consulta_mail_em_preparacao_enabled: boolean;
  consulta_mail_nao_compareceu_enabled: boolean;
  admin_copy_consultas_enabled: boolean;`);

if (!r1.success) {
  console.error(`[FATAL] types.ts : ${r1.error}`);
  process.exit(1);
}
console.log(`  OK : +2 champs interface LibraryNotificationContext`);

// ============================================================
// PATCH 2A — library-notification-context.ts (fallback)
// ============================================================
console.log('\n[2/4] Patch library-notification-context.ts...');

const r2a = patchFile('context',
`    consulta_mail_criada_enabled: true,
    consulta_mail_agendada_enabled: true,
    consulta_mail_resposta_creneau_enabled: true,
    consulta_mail_realizada_enabled: false,
    consulta_mail_cancelada_enabled: true,
    consulta_mail_expirada_enabled: true,
    admin_copy_consultas_enabled: true,`,

`    consulta_mail_criada_enabled: true,
    consulta_mail_agendada_enabled: true,
    consulta_mail_resposta_creneau_enabled: true,
    consulta_mail_realizada_enabled: false,
    consulta_mail_cancelada_enabled: true,
    consulta_mail_expirada_enabled: true,
    consulta_mail_em_preparacao_enabled: true,
    consulta_mail_nao_compareceu_enabled: true,
    admin_copy_consultas_enabled: true,`);

if (!r2a.success) {
  console.error(`[FATAL] context.ts fallback : ${r2a.error}`);
  process.exit(1);
}
console.log(`  OK 2a : +2 defaults fallbackLibraryNotificationContext`);

// PATCH 2B — context.ts normalize
const r2b = patchFile('context',
`    consulta_mail_criada_enabled: asBool(r.consulta_mail_criada_enabled, true),
    consulta_mail_agendada_enabled: asBool(r.consulta_mail_agendada_enabled, true),
    consulta_mail_resposta_creneau_enabled: asBool(r.consulta_mail_resposta_creneau_enabled, true),
    consulta_mail_realizada_enabled: asBool(r.consulta_mail_realizada_enabled, false),
    consulta_mail_cancelada_enabled: asBool(r.consulta_mail_cancelada_enabled, true),
    consulta_mail_expirada_enabled: asBool(r.consulta_mail_expirada_enabled, true),
    admin_copy_consultas_enabled: asBool(r.admin_copy_consultas_enabled, true),`,

`    consulta_mail_criada_enabled: asBool(r.consulta_mail_criada_enabled, true),
    consulta_mail_agendada_enabled: asBool(r.consulta_mail_agendada_enabled, true),
    consulta_mail_resposta_creneau_enabled: asBool(r.consulta_mail_resposta_creneau_enabled, true),
    consulta_mail_realizada_enabled: asBool(r.consulta_mail_realizada_enabled, false),
    consulta_mail_cancelada_enabled: asBool(r.consulta_mail_cancelada_enabled, true),
    consulta_mail_expirada_enabled: asBool(r.consulta_mail_expirada_enabled, true),
    consulta_mail_em_preparacao_enabled: asBool(r.consulta_mail_em_preparacao_enabled, true),
    consulta_mail_nao_compareceu_enabled: asBool(r.consulta_mail_nao_compareceu_enabled, true),
    admin_copy_consultas_enabled: asBool(r.admin_copy_consultas_enabled, true),`);

if (!r2b.success) {
  console.error(`[FATAL] context.ts normalize : ${r2b.error}`);
  process.exit(1);
}
console.log(`  OK 2b : +2 normalize asBool`);

// ============================================================
// PATCH 3 — policies.ts
// ============================================================
console.log('\n[3/4] Patch policies.ts...');

const r3 = patchFile('policies',
`export function consultaAdminCopyEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.admin_copy_consultas_enabled, true);
}`,

`export function consultaAdminCopyEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.admin_copy_consultas_enabled, true);
}
export function consultaEmPreparacaoEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_em_preparacao_enabled, true);
}
export function consultaNaoCompareceuEnabled(ctx?: LibraryNotificationContext|null) {
  return asBool(ctx?.consulta_mail_nao_compareceu_enabled, true);
}`);

if (!r3.success) {
  console.error(`[FATAL] policies.ts : ${r3.error}`);
  process.exit(1);
}
console.log(`  OK : +2 helpers consultaEmPreparacaoEnabled + consultaNaoCompareceuEnabled`);

// ============================================================
// PATCH 4 — dispatch.ts
// ============================================================
console.log('\n[4/4] Patch dispatch.ts...');

const r4 = patchFile('dispatch',
`  if (["consulta_v2_agendada","consulta_v2_resposta_creneau"].includes(event)) return await handleConsultaV2WorkflowEvent(recordId, event, payload);`,

`  if (["consulta_v2_em_preparacao","consulta_v2_agendada","consulta_v2_nao_compareceu","consulta_v2_resposta_creneau"].includes(event)) return await handleConsultaV2WorkflowEvent(recordId, event, payload);`);

if (!r4.success) {
  console.error(`[FATAL] dispatch.ts : ${r4.error}`);
  process.exit(1);
}
console.log(`  OK : extension du routing workflow consultas`);

// ============================================================
// Verifications finales
// ============================================================
console.log('\n===== Verifications finales =====');

const counts = {
  typesEm: (contents.types.match(/consulta_mail_em_preparacao_enabled/g) || []).length,
  typesNao: (contents.types.match(/consulta_mail_nao_compareceu_enabled/g) || []).length,
  ctxEm: (contents.context.match(/consulta_mail_em_preparacao_enabled/g) || []).length,
  ctxNao: (contents.context.match(/consulta_mail_nao_compareceu_enabled/g) || []).length,
  polEm: (contents.policies.match(/consultaEmPreparacaoEnabled/g) || []).length,
  polNao: (contents.policies.match(/consultaNaoCompareceuEnabled/g) || []).length,
  dispEm: (contents.dispatch.match(/consulta_v2_em_preparacao/g) || []).length,
  dispNao: (contents.dispatch.match(/consulta_v2_nao_compareceu/g) || []).length
};

console.log(`  types.ts        : em_preparacao=${counts.typesEm} (att 1), nao_compareceu=${counts.typesNao} (att 1)`);
console.log(`  context.ts      : em_preparacao=${counts.ctxEm} (att 3), nao_compareceu=${counts.ctxNao} (att 3)`);
console.log(`  policies.ts     : EmPreparacao=${counts.polEm} (att 1), NaoCompareceu=${counts.polNao} (att 1)`);
console.log(`  dispatch.ts     : em_preparacao=${counts.dispEm} (att 1), nao_compareceu=${counts.dispNao} (att 1)`);

const expected = { typesEm: 1, typesNao: 1, ctxEm: 3, ctxNao: 3, polEm: 1, polNao: 1, dispEm: 1, dispNao: 1 };
for (const [k, v] of Object.entries(expected)) {
  if (counts[k] !== v) {
    console.error(`[FATAL] Compteur ${k} = ${counts[k]} (attendu ${v})`);
    process.exit(1);
  }
}

// ============================================================
// Ecriture (4 fichiers, en preservant le style EOL d'origine)
// ============================================================
console.log('\n===== Ecriture =====');
for (const [key, filePath] of Object.entries(FILES)) {
  const buf = Buffer.from(contents[key], 'utf8');
  fs.writeFileSync(filePath, buf);
  const newMd5 = crypto.createHash('md5').update(buf).digest('hex');
  console.log(`  ${key.padEnd(10)} : ${buf.length} bytes (MD5: ${newMd5.slice(0, 8)}, EOL preserve=${eolStyle[key]})`);
}

console.log('\n===== Patch 141.2.A v2 applique avec succes =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff supabase/functions/_shared/');
console.log('  2. npm run build');
console.log('  3. git add + commit + push');
console.log('  4. Pas de deploy EF (sera fait apres 141.2.B)');
