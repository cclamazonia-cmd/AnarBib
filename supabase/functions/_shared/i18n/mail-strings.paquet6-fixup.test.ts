// ============================================================================
// mail-strings.paquet6-fixup.test.ts — invariants paquet 6 fix-up bug #2/#2bis
// ============================================================================
// Tests anti-régression spécifiques au dédoublement subject/body des clés v3
// wf.reader.* et wf.staff.*.
//
// À exécuter avec : deno test mail-strings.paquet6-fixup.test.ts
//
// NB: ce fichier est COMPLÉMENTAIRE des tests existants (mail-strings.test.ts
// avec ses 5 invariants : 600 traductions, dictionnaire complet, etc.). Il
// n'écrase rien : à fusionner ou conserver à part selon préférence.
// ============================================================================

import { _allKeys, _isComplete, _supportedLocales, tMail } from "./mail-strings.ts";import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

// Liste source de vérité des 16 clés v3 dédoublées (alignée avec V3_DOUBLED
// dans reservas.ts, handler handleReservaV2WorkflowEvent).
const V3_DOUBLED_KEYS = [
  // Côté lecteur·rice (6)
  "wf.reader.libraryProposed",
  "wf.reader.libraryCounterProposed",
  "wf.reader.youCounterProposed",
  "wf.reader.slotLocked",
  "wf.reader.maxIterations",
  "wf.reader.negotiationTimeout",
  // Côté biblio (10)
  "wf.staff.negotiationOpened",
  "wf.staff.staffCounterProposed",
  "wf.staff.readerCounterProposed",
  "wf.staff.readerAccepted",
  "wf.staff.staffConfirmed",
  "wf.staff.ready",
  "wf.staff.noShow",
  "wf.staff.closed",
  "wf.staff.maxIterations",
  "wf.staff.negotiationTimedOut",
];

// Clés v2 conservées (non dédoublées, fallback texte court / labels état).
// Ces clés DOIVENT toujours exister à plat (sans suffixe .subject/.body).
const V2_PRESERVED_KEYS = [
  "wf.ready",
  "wf.readyShort",
  "wf.noShow",
  "wf.closed",
  "wf.preparing",
  "wf.preparingShort",
  "wf.toCoordinate",
  "wf.toCoordinateShort",
  "wf.pickupRescheduled",
  "wf.checkAccount",
];

// ============================================================================
// Invariant #6 (paquet 6) — Toutes les clés v3 ont .subject ET .body complets
// ============================================================================
Deno.test("paquet6 fix-up — chaque clé v3 a .subject et .body dans les 6 locales", () => {
  const allKeys = new Set(_allKeys());
  const missing: string[] = [];
  for (const base of V3_DOUBLED_KEYS) {
    for (const variant of ["subject", "body"]) {
      const k = `${base}.${variant}`;
      if (!allKeys.has(k)) {
        missing.push(`${k} — clé absente du dictionnaire`);
        continue;
      }
      if (!_isComplete(k)) {
        missing.push(`${k} — locale(s) manquante(s) ou vide(s)`);
      }
    }
  }
  if (missing.length) {
    throw new Error(`Clés v3 incomplètes :\n${missing.map(m => `  - ${m}`).join("\n")}`);
  }
});

// ============================================================================
// Invariant #7 (paquet 6) — Aucun .subject ne contient de balise HTML
// ============================================================================
// Le sujet d'un email étant du texte plat, toute balise HTML y apparaîtrait
// littéralement (cf. bug #2 du paquet 6 fix-up : <b>Resposta esperada</b>
// affiché brut dans le sujet du mail biblio).
Deno.test("paquet6 fix-up — aucun .subject ne contient de balise HTML", () => {
  const violations: string[] = [];
  const htmlTagRe = /<[a-zA-Z!\/]/;
  for (const base of V3_DOUBLED_KEYS) {
    const subjectKey = `${base}.subject`;
    for (const loc of _supportedLocales()) {
      const value = tMail(loc, subjectKey);
      if (htmlTagRe.test(value)) {
        violations.push(`${subjectKey} (${loc}) : « ${value} »`);
      }
    }
  }
  if (violations.length) {
    throw new Error(`HTML détecté dans .subject :\n${violations.map(m => `  - ${m}`).join("\n")}`);
  }
});

// ============================================================================
// Invariant #8 (paquet 6) — Placeholders {iter}/{max} interpolés correctement
// ============================================================================
// Spécifique à wf.reader.youCounterProposed : la chaîne contient {iter}/{max}
// dans .subject ET .body, et ces placeholders DOIVENT être présents dans les
// 6 locales (fallback ne doit pas les masquer).
Deno.test("paquet6 fix-up — youCounterProposed contient {iter}/{max} dans 6 locales × 2 variants", () => {
  for (const variant of ["subject", "body"]) {
    const key = `wf.reader.youCounterProposed.${variant}`;
    for (const loc of _supportedLocales()) {
      const raw = tMail(loc, key); // sans params — on doit voir les placeholders bruts
      assertStringIncludes(raw, "{iter}", `${key} (${loc}) : {iter} manquant`);
      assertStringIncludes(raw, "{max}", `${key} (${loc}) : {max} manquant`);
    }
  }
});

// ============================================================================
// Invariant #9 (paquet 6) — Interpolation effective de {iter}/{max}
// ============================================================================
// Vérifie que tMail(loc, key, {iter, max}) substitue effectivement les valeurs.
Deno.test("paquet6 fix-up — tMail interpole {iter}/{max} dans youCounterProposed", () => {
  for (const variant of ["subject", "body"]) {
    const key = `wf.reader.youCounterProposed.${variant}`;
    for (const loc of _supportedLocales()) {
      const result = tMail(loc, key, { iter: 2, max: 3 });
      assert(!result.includes("{iter}"), `${key} (${loc}) : {iter} non interpolé : « ${result} »`);
      assert(!result.includes("{max}"), `${key} (${loc}) : {max} non interpolé : « ${result} »`);
      // Vérifie que les valeurs apparaissent dans la chaîne finale
      assertStringIncludes(result, "2", `${key} (${loc}) : valeur iter absente : « ${result} »`);
      assertStringIncludes(result, "3", `${key} (${loc}) : valeur max absente : « ${result} »`);
    }
  }
});

// ============================================================================
// Invariant #10 (paquet 6) — Clés v2 conservées intactes (non régression)
// ============================================================================
Deno.test("paquet6 fix-up — clés v2 conservées non dédoublées et complètes", () => {
  const allKeys = new Set(_allKeys());
  const missing: string[] = [];
  for (const k of V2_PRESERVED_KEYS) {
    if (!allKeys.has(k)) {
      missing.push(`${k} — DISPARUE`);
      continue;
    }
    if (!_isComplete(k)) {
      missing.push(`${k} — locale(s) incomplètes`);
    }
    // Sanity: les clés v2 ne doivent PAS avoir été dédoublées par erreur.
    if (allKeys.has(`${k}.subject`) || allKeys.has(`${k}.body`)) {
      missing.push(`${k} — dédoublée par erreur (suffixe .subject/.body trouvé)`);
    }
  }
  if (missing.length) {
    throw new Error(`Régression v2 :\n${missing.map(m => `  - ${m}`).join("\n")}`);
  }
});

// ============================================================================
// Invariant #11 (paquet 6) — Aucune clé v3 "nue" (sans .subject ou .body) ne subsiste
// ============================================================================
// Garde-fou : si quelqu'un ajoute par erreur une clé "wf.reader.foo" sans
// la dédoubler, ce test la détectera.
Deno.test("paquet6 fix-up — aucune clé wf.(reader|staff).* nue (hors actionBox/infoBox)", () => {
  const allowedNonDoubled = new Set([
    "wf.staff.actionBox.title",
    "wf.staff.actionBox.openPanel",
    "wf.staff.infoBox.title",
  ]);
  const violations: string[] = [];
  for (const k of _allKeys()) {
    // On ne s'intéresse qu'aux clés wf.reader.* et wf.staff.*
    if (!/^wf\.(reader|staff)\./.test(k)) continue;
    // Les clés autorisées (action/infoBox) sont OK.
    if (allowedNonDoubled.has(k)) continue;
    // Les clés v3 dédoublées doivent finir par .subject ou .body.
    if (k.endsWith(".subject") || k.endsWith(".body")) continue;
    // Tout le reste est une violation.
    violations.push(k);
  }
  if (violations.length) {
    throw new Error(
      `Clés v3 nues (devraient être .subject/.body) :\n${violations.map(m => `  - ${m}`).join("\n")}`
    );
  }
});

// ============================================================================
// Invariant #12 (paquet 6) — Subjects courts (≤ 80 chars dans toutes les locales)
// ============================================================================
// Garde-fou cosmétique : un sujet trop long est tronqué dans la plupart des
// clients mail. La limite à 80 chars laisse de la marge pour l'ajout du
// subjectTag (« — BLMF ») par applyBrandingText.
Deno.test("paquet6 fix-up — subjects ≤ 80 caractères (toutes locales)", () => {
  const SOFT_LIMIT = 80;
  const overflows: string[] = [];
  for (const base of V3_DOUBLED_KEYS) {
    const subjectKey = `${base}.subject`;
    for (const loc of _supportedLocales()) {
      // Interpole avec valeurs maximales pour évaluer le pire cas
      const v = tMail(loc, subjectKey, { iter: 3, max: 3, days: 14 });
      if (v.length > SOFT_LIMIT) {
        overflows.push(`${subjectKey} (${loc}) [${v.length} chars] : « ${v} »`);
      }
    }
  }
  if (overflows.length) {
    throw new Error(
      `Subjects trop longs (> ${SOFT_LIMIT} chars) :\n${overflows.map(m => `  - ${m}`).join("\n")}`
    );
  }
});

// ============================================================================
// Invariant #13 (paquet 6) — DE utilise tutoiement (du/dein/ihr/euer) dans bodies
// ============================================================================
// Convention militante DE pour AnarBib : tutoiement systématique. Aucune
// occurrence de Sie/Ihnen/Ihr (avec majuscule de politesse) dans les bodies
// des clés v3.
//
// NB: ce test est tolérant aux faux positifs. Le mot "Ihrer" (génitif de "ihr"
// = leur) peut apparaître légitimement. Le filtre vise les pronoms de
// politesse en début de phrase ou isolés.
Deno.test("paquet6 fix-up — DE bodies utilisent tutoiement (du/dein/ihr/euer)", () => {
  // Pattern : "Sie" en début de phrase ou suivi d'espace + verbe conjugué
  // au formel (pas au pluriel naturel "sie kommen" minuscule).
  // On chasse : " Sie ", "Sie haben", "Ihr Buch", "Ihre Reservierung",
  // "Ihnen", mais pas "ihr" (minuscule = vous pluriel tutoyé).
  const formalPatterns = [
    /\bSie\s+(haben|können|werden|möchten|erhalten|sind|wollen|sollen)/,  // Sie + verbe
    /\bIhr(?:e[mnrs]?|en)?\s+\w+\s+(ist|wurde|wird|kann)/,  // Ihr Konto ist
    /\bIhnen\b/,
  ];
  const violations: string[] = [];
  for (const base of V3_DOUBLED_KEYS) {
    const bodyKey = `${base}.body`;
    const v = tMail("de", bodyKey);
    for (const re of formalPatterns) {
      if (re.test(v)) {
        violations.push(`${bodyKey} (de) [pattern ${re}] : « ${v} »`);
      }
    }
  }
  if (violations.length) {
    throw new Error(
      `Vouvoiement détecté dans DE bodies (convention = tutoiement) :\n${violations.map(m => `  - ${m}`).join("\n")}`
    );
  }
});
