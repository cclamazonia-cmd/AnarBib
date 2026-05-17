// ============================================================
// Patch sous-paquet 141.2.B v3 — Handlers consultas.ts
// ============================================================
// v3 (16/05/2026) : compteurs de verification corriges (v2 levait des
// faux positifs sur 'workflowNote' et 'whenStart' qui matchent aussi
// dans les template-strings, j'avais sous-estime).
//
// Compteurs reels apres patch :
//   workflowNote : 10-11 occurrences (M2: 2, M3: 3, M6: 1, M7: 4)
//   whenStart    : 4 occurrences (declaration + 3 usages dans template)
//   whenEnd      : 3 occurrences (declaration + 2 usages)
// ============================================================

const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const FILE = path.join(REPO_ROOT, 'supabase/functions/_shared/domain/consultas.ts');

console.log('===== Patch sous-paquet 141.2.B v3 =====\n');

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
console.log(`  Avant : ${originalSize} bytes, EOL=${eolStyle}, MD5=${originalMd5.slice(0, 8)}`);
console.log('');

if (content.includes('consultaEmPreparacaoEnabled') || content.includes('consultaNaoCompareceuEnabled')) {
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
// MODIF 1 — Imports policies.ts
// ============================================================
console.log('[1/7] Imports policies.ts...');

patchZone('M1',
`import {
  consultaCriadaEnabled,
  consultaAgendadaEnabled,
  consultaRespostaCreneauEnabled,
  consultaRealizadaEnabled,
  consultaCanceladaEnabled,
  consultaExpiradaEnabled,
  consultaAdminCopyEnabled,
  localConsultationEnabled
} from "../context/policies.ts";`,

`import {
  consultaCriadaEnabled,
  consultaAgendadaEnabled,
  consultaRespostaCreneauEnabled,
  consultaRealizadaEnabled,
  consultaCanceladaEnabled,
  consultaExpiradaEnabled,
  consultaEmPreparacaoEnabled,
  consultaNaoCompareceuEnabled,
  consultaAdminCopyEnabled,
  localConsultationEnabled
} from "../context/policies.ts";`);

// ============================================================
// MODIF 2 — buildSlotVars : ajout param workflowNote
// ============================================================
console.log('\n[2/7] buildSlotVars : param workflowNote...');

patchZone('M2',
`function buildSlotVars(
  startsAt: string,
  endsAt: string,
  tz: string,
  locale: string | null
): Record<string, string> {
  if (!startsAt) return { date: "", time_start: "", time_end: "", tz };
  const startStr = formatDateTimeInZone(startsAt, tz);
  const endStr = endsAt ? formatDateTimeInZone(endsAt, tz) : "";
  // formatDateTimeInZone renvoie typiquement "DD/MM/YYYY HH:MM" - extraire
  // les parties date/heure pour une interpolation propre.
  const [startDate, startTime] = startStr.split(" ");
  const endTime = endStr ? endStr.split(" ")[1] || "" : "";
  return {
    date: formatDateLocale(startsAt, locale) || startDate || "",
    time_start: startTime || "",
    time_end: endTime || "",
    tz: tz || ""
  };
}`,

`function buildSlotVars(
  startsAt: string,
  endsAt: string,
  tz: string,
  locale: string | null,
  workflowNote?: string | null
): Record<string, string> {
  const note = String(workflowNote || "").trim();
  if (!startsAt) return { date: "", time_start: "", time_end: "", tz, workflow_note: note };
  const startStr = formatDateTimeInZone(startsAt, tz);
  const endStr = endsAt ? formatDateTimeInZone(endsAt, tz) : "";
  // formatDateTimeInZone renvoie "DD/MM/YYYY HH:MM" depuis paquet 141.3.
  // Extraire les parties date/heure pour une interpolation propre.
  const [startDate, startTime] = startStr.split(" ");
  const endTime = endStr ? endStr.split(" ")[1] || "" : "";
  return {
    date: formatDateLocale(startsAt, locale) || startDate || "",
    time_start: startTime || "",
    time_end: endTime || "",
    tz: tz || "",
    workflow_note: note
  };
}`);

// ============================================================
// MODIF 3 — WorkflowEvent : extraction workflowNote
// ============================================================
console.log('\n[3/7] WorkflowEvent : extraction workflowNote...');

patchZone('M3',
`  // Extraire le creneau depuis le payload OU depuis les items DB en fallback
  const startsAtPayload = String(getPayloadValue(payload, "consultation_starts_at") || "").trim();
  const endsAtPayload = String(getPayloadValue(payload, "consultation_ends_at") || "").trim();
  const startsAt = startsAtPayload || items.find((i) => i.consultation_starts_at)?.consultation_starts_at || "";
  const endsAt = endsAtPayload || items.find((i) => i.consultation_ends_at)?.consultation_ends_at || "";
  const slotVars = buildSlotVars(startsAt, endsAt, tz, locale);
  const slotVarsLib = buildSlotVars(startsAt, endsAt, tz, libLocale);`,

`  // Extraire le creneau depuis le payload OU depuis les items DB en fallback
  const startsAtPayload = String(getPayloadValue(payload, "consultation_starts_at") || "").trim();
  const endsAtPayload = String(getPayloadValue(payload, "consultation_ends_at") || "").trim();
  const startsAt = startsAtPayload || items.find((i) => i.consultation_starts_at)?.consultation_starts_at || "";
  const endsAt = endsAtPayload || items.find((i) => i.consultation_ends_at)?.consultation_ends_at || "";
  // Paquet 141.2 : extraction workflow_note (note staff lors de proposition,
  // note lecteur lors de refus, note staff lors de no-show, etc.).
  // Propagee via slotVars pour interpolation {workflow_note} dans templates i18n.
  const workflowNote = String(getPayloadValue(payload, "workflow_note") || items.find((i) => i.workflow_note)?.workflow_note || "").trim();
  const slotVars = buildSlotVars(startsAt, endsAt, tz, locale, workflowNote);
  const slotVarsLib = buildSlotVars(startsAt, endsAt, tz, libLocale, workflowNote);`);

// ============================================================
// MODIF 4 — WorkflowEvent : 2 branches em_preparacao et nao_compareceu
// ============================================================
console.log('\n[4/7] WorkflowEvent : 2 branches em_preparacao et nao_compareceu...');

patchZone('M4',
`  if (we === "consulta_agendada") {
    // Detection re-proposition : un workflow_stage qui etait deja 'consulta_agendada'
    // avant. Comme on n'a pas l'OLD dans le payload, on infere depuis schedule_reply_at
    // (si NULL = premiere proposition, sinon re-proposition).
    const isReschedule = items.some((i) => i.schedule_reply_at);
    readerKey = isReschedule ? "cwf.reader.rescheduled" : "cwf.reader.scheduled";
    staffKey = isReschedule ? "cwf.staff.rescheduled" : "cwf.staff.scheduled";
    readerActionUrl = READER_PAGE;  // CTA "Repondre a la proposition"
    granularFlag = consultaAgendadaEnabled(ctx);
  } else if (we === "resposta_creneau") {`,

`  if (we === "em_preparacao") {
    // Paquet 141 B2 : transition solicitada -> em_preparacao.
    // Mail lecteur uniquement (action courante de la biblio, pas de portee
    // collective). Pas de CTA : info pure, le lecteur attend la suite.
    readerKey = "cwf.reader.em_preparacao";
    staffKey = null;
    staffMailEnabled = false;  // pas de mail coordination (cf. doctrine R5)
    granularFlag = consultaEmPreparacaoEnabled(ctx);
  } else if (we === "consulta_agendada") {
    // Detection re-proposition : un workflow_stage qui etait deja 'consulta_agendada'
    // avant. Comme on n'a pas l'OLD dans le payload, on infere depuis schedule_reply_at
    // (si NULL = premiere proposition, sinon re-proposition).
    const isReschedule = items.some((i) => i.schedule_reply_at);
    readerKey = isReschedule ? "cwf.reader.rescheduled" : "cwf.reader.scheduled";
    staffKey = isReschedule ? "cwf.staff.rescheduled" : "cwf.staff.scheduled";
    readerActionUrl = READER_PAGE;  // CTA "Repondre a la proposition"
    granularFlag = consultaAgendadaEnabled(ctx);
  } else if (we === "nao_compareceu") {
    // Paquet 141 B5 : transition vers nao_compareceu.
    // Doctrine : mail no-show = rappel d'engagement reciproque, pas punition.
    // Mail lecteur (B5) + mail coordination (R8 tracabilite coordination :
    // tous les bibliothecaires + coordenadores doivent etre informes de
    // l'absence, pas seulement la personne qui a clique).
    readerKey = "cwf.reader.nao_compareceu";
    staffKey = "cwf.staff.nao_compareceu";
    staffMailEnabled = true;  // mail collectif a admin_notification_email
    // Pas de staffActionUrl : info pure pour la coordination, action terminee.
    granularFlag = consultaNaoCompareceuEnabled(ctx);
  } else if (we === "resposta_creneau") {`);

// ============================================================
// MODIF 5 — Fix endsAt mail biblio
// ============================================================
console.log('\n[5/7] Fix endsAt mail biblio...');

patchZone('M5',
`  const tits = joinTitles(items.map((i) => String(i.titulo || \`[linha \${i.line_no || "?"}]\`)));
  const brfs = joinTitles(items.map((i) => String(i.bib_ref || "")), ", ");
  const when = startsAt ? formatDateTimeInZone(startsAt, tz) : "";`,

`  const tits = joinTitles(items.map((i) => String(i.titulo || \`[linha \${i.line_no || "?"}]\`)));
  const brfs = joinTitles(items.map((i) => String(i.bib_ref || "")), ", ");
  // Paquet 141.2 : enrichir 'when' avec heure de fin si dispo (avant 141.2,
  // seule l'heure de debut etait affichee dans mail biblio). On affiche
  // "DD/MM/YYYY HH:MM - HH:MM" si endsAt present, sinon "DD/MM/YYYY HH:MM".
  const whenStart = startsAt ? formatDateTimeInZone(startsAt, tz) : "";
  const whenEnd = endsAt ? (formatDateTimeInZone(endsAt, tz).split(" ")[1] || "") : "";
  const when = whenStart && whenEnd ? \`\${whenStart} - \${whenEnd}\` : whenStart;`);

// ============================================================
// MODIF 6 — LifecycleEvent : extraction workflowNote
// ============================================================
console.log('\n[6/7] LifecycleEvent : extraction workflowNote...');

patchZone('M6',
`  const we = normalizeConsultaLifecycleEvent(event) || event;
  const cancelledBy = consultaCancelledByFromPayload(payload);

  const { consulta, profile, items } = await getConsultaV2Bundle(recordId);`,

`  const we = normalizeConsultaLifecycleEvent(event) || event;
  const cancelledBy = consultaCancelledByFromPayload(payload);
  // Paquet 141.2 (B3 generalise + complement B6) : extraction workflow_note
  // depuis le payload (la note d'annulation par la biblio doit etre affichee
  // au lecteur, le motif d'annulation par le lecteur doit etre affiche a la
  // biblio, etc.).
  const workflowNote = String(getPayloadValue(payload, "workflow_note") || "").trim();

  const { consulta, profile, items } = await getConsultaV2Bundle(recordId);`);

// ============================================================
// MODIF 7 — LifecycleEvent : declaration des noteDetail
// ============================================================
console.log('\n[7/7] LifecycleEvent : declaration noteDetail...');

patchZone('M7',
`  const tits = joinTitles(items.map((i) => String(i.titulo || \`[\${String(i.bib_ref || "").trim()}]\`)));
  const brfs = joinTitles(items.map((i) => String(i.bib_ref || "")), ", ");

  // ---- Mail lecteur ----`,

`  const tits = joinTitles(items.map((i) => String(i.titulo || \`[\${String(i.bib_ref || "").trim()}]\`)));
  const brfs = joinTitles(items.map((i) => String(i.bib_ref || "")), ", ");
  // Paquet 141.2 (B3 generalise + complement B6) : ligne 'Note' a injecter
  // dans les 2 mails (lecteur et staff) si workflowNote presente.
  // Utilise label cle 'note' (sera ajoutee a mail-strings.ts en paquet 141.2.C
  // si pas encore presente). En attendant : fallback texte 'Note'.
  const noteDetailReader = workflowNote ? [{ label: label(locale, "note") || "Note", value: workflowNote }] : [];
  const noteDetailStaff = workflowNote ? [{ label: label(libLocale, "note") || "Note", value: workflowNote }] : [];

  // ---- Mail lecteur ----`);

console.log("\n[NOTE] Modif 7 partielle : les constantes noteDetailReader/Staff sont");
console.log("       declarees mais pas encore spreadees dans les details des");
console.log("       renderEmail du handler lifecycle. Cela sera fait au");
console.log("       sous-paquet 141.2.C en meme temps que l'ajout de la cle i18n.");
console.log("       Warning TS6133 attendu (constantes inutilisees temporairement).");

// ============================================================
// Verifications finales (v3 : compteurs corriges)
// ============================================================
console.log('\n===== Verifications =====');

// Compteurs reels apres patch (j'ai sous-estime en v2) :
// - consultaEmPreparacaoEnabled / consultaNaoCompareceuEnabled : 2 (import + usage)
// - workflowNote : >= 8 (M2: 2, M3: 3, M6: 1, M7: 4 = 10, peut etre +1)
// - em_preparacao branch : 1 occurrence du pattern 'we === "em_preparacao"'
// - cwf.reader.em_preparacao / nao_compareceu / staff.nao_compareceu : 1 chacun
// - whenStart : 4 (declaration + 3 usages dont 1 template-string)
// - whenEnd : 3 (declaration + 2 usages)
const checks = [
  { name: 'consultaEmPreparacaoEnabled (import + usage)', pattern: /consultaEmPreparacaoEnabled/g, min: 2, max: 2 },
  { name: 'consultaNaoCompareceuEnabled (import + usage)', pattern: /consultaNaoCompareceuEnabled/g, min: 2, max: 2 },
  { name: 'workflowNote occurrences (>=8)', pattern: /workflowNote/g, min: 8, max: 20 },
  { name: 'em_preparacao branch', pattern: /we === "em_preparacao"/g, min: 1, max: 1 },
  { name: 'nao_compareceu branch', pattern: /we === "nao_compareceu"/g, min: 1, max: 1 },
  { name: 'cwf.reader.em_preparacao', pattern: /cwf\.reader\.em_preparacao/g, min: 1, max: 1 },
  { name: 'cwf.reader.nao_compareceu', pattern: /cwf\.reader\.nao_compareceu/g, min: 1, max: 1 },
  { name: 'cwf.staff.nao_compareceu', pattern: /cwf\.staff\.nao_compareceu/g, min: 1, max: 1 },
  { name: 'whenStart variable (>=2)', pattern: /whenStart/g, min: 2, max: 10 },
  { name: 'whenEnd variable (>=2)', pattern: /whenEnd/g, min: 2, max: 10 },
];

let allOk = true;
for (const c of checks) {
  const count = (content.match(c.pattern) || []).length;
  const ok = count >= c.min && count <= c.max;
  console.log(`  ${ok ? 'OK' : '!!'}  ${c.name.padEnd(48)} : ${count} (range [${c.min},${c.max}])`);
  if (!ok) allOk = false;
}

if (!allOk) {
  console.error('\n[FATAL] Compteurs incoherents, ne pas ecrire le fichier');
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

console.log(`  consultas.ts : ${originalSize} -> ${newSize} bytes (+${newSize - originalSize}), MD5: ${originalMd5.slice(0,8)} -> ${newMd5.slice(0,8)}`);
console.log(`  EOL preserve : ${eolStyle}`);

console.log('\n===== Patch 141.2.B v3 applique avec succes =====');
console.log('\nProchaines etapes :');
console.log('  1. git diff supabase/functions/_shared/domain/consultas.ts');
console.log('  2. npm run build (warnings TS6133 unused vars attendus,');
console.log('     resolus en 141.2.C lors de l\'ajout cle i18n "note")');
console.log('  3. git add + commit + push');
console.log('  4. Pas de deploy EF (apres 141.2.C qui finit le travail)');

} catch (e) {
  console.error(`\n[FATAL] ${e.message}`);
  process.exit(1);
}
