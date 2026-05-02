// ============================================================================
// mail-strings.test.ts — test anti-régression i18n notifications mail
// ============================================================================
//
// Vérifie 3 invariants critiques :
//   1. Toutes les clés appelées via tMail() ou label() dans les handlers
//      domain (emprestimos.ts, reservas.ts, profiles.ts, legacy.ts)
//      existent dans le dictionnaire S de mail-strings.ts.
//   2. Toutes les clés du dictionnaire ont une traduction non vide
//      pour les 6 locales (pt-BR, fr, es, en, it, de).
//   3. Aucune trace de mots proscrits par la charte de langage inclusif
//      (camerata en italien, "Compas" non traduit en allemand, etc.).
//
// Lancer avec :
//   cd supabase/functions
//   deno test --allow-read _shared/i18n/mail-strings.test.ts
//
// Si un test échoue, le mail risque d'envoyer une clé brute (ex: wf.ready)
// au lieu de sa traduction. Bug du même type que celui corrigé le 02/05/2026.
// ============================================================================

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { _allKeys, _supportedLocales, _isComplete } from "./mail-strings.ts";

// Chemins relatifs depuis supabase/functions/_shared/i18n/
const DOMAIN_FILES = [
  "../domain/emprestimos.ts",
  "../domain/reservas.ts",
  "../domain/profiles.ts",
  "../domain/legacy.ts"
];

/**
 * Extrait toutes les clés utilisées via tMail() et label() dans un fichier.
 *
 * Patterns détectés :
 *   tMail(locale, "key.name", ...)  → "key.name"
 *   tMail(locale, 'key.name', ...)  → "key.name"
 *   label(locale, "name")           → "l.name"  (préfixe ajouté car label() concatène)
 *   taskStatusLabel(locale, "open") → "ts.open"
 *   taskPriorityLabel(locale, "hi") → "tp.hi"
 */
function extractKeysFromFile(content: string): Set<string> {
  const keys = new Set<string>();

  // tMail(arg, "key", ...) — capture le premier argument string-literal
  const tMailRe = /\btMail\s*\(\s*[^,()]+?\s*,\s*["']([^"']+?)["']/gs;
  for (const m of content.matchAll(tMailRe)) {
    keys.add(m[1]);
  }

  // label(arg, "name") → "l.name"
  const labelRe = /\blabel\s*\(\s*[^,()]+?\s*,\s*["']([^"']+?)["']/gs;
  for (const m of content.matchAll(labelRe)) {
    keys.add(`l.${m[1]}`);
  }

  // taskStatusLabel(arg, "name") → "ts.name"
  const tsRe = /\btaskStatusLabel\s*\(\s*[^,()]+?\s*,\s*["']([^"']+?)["']/gs;
  for (const m of content.matchAll(tsRe)) {
    keys.add(`ts.${m[1]}`);
  }

  // taskPriorityLabel(arg, "name") → "tp.name"
  const tpRe = /\btaskPriorityLabel\s*\(\s*[^,()]+?\s*,\s*["']([^"']+?)["']/gs;
  for (const m of content.matchAll(tpRe)) {
    keys.add(`tp.${m[1]}`);
  }

  return keys;
}

// ============================================================================
// TEST 1 — Toutes les clés utilisées existent dans le dictionnaire
// ============================================================================

Deno.test("Toutes les clés utilisées dans les handlers existent dans S", async () => {
  const definedKeys = new Set(_allKeys());
  const usedKeys = new Set<string>();
  const usedKeysWithFiles = new Map<string, string[]>();

  for (const filePath of DOMAIN_FILES) {
    let content: string;
    try {
      content = await Deno.readTextFile(new URL(filePath, import.meta.url));
    } catch {
      // Si un fichier n'existe pas, on log et on continue (pas un échec dur)
      console.warn(`[test] Skipping missing file: ${filePath}`);
      continue;
    }
    const fileKeys = extractKeysFromFile(content);
    for (const k of fileKeys) {
      usedKeys.add(k);
      const list = usedKeysWithFiles.get(k) || [];
      list.push(filePath);
      usedKeysWithFiles.set(k, list);
    }
  }

  const missing: string[] = [];
  for (const k of usedKeys) {
    if (!definedKeys.has(k)) {
      const files = usedKeysWithFiles.get(k)?.join(", ") || "?";
      missing.push(`  - "${k}" (utilisée dans: ${files})`);
    }
  }

  if (missing.length > 0) {
    throw new Error(
      `🔴 ${missing.length} clé(s) i18n manquante(s) dans mail-strings.ts :\n` +
      missing.join("\n") +
      `\n\nAjoute-les au dictionnaire S avec une traduction dans les 6 locales.`
    );
  }
});

// ============================================================================
// TEST 2 — Toutes les clés ont une traduction dans toutes les locales
// ============================================================================

Deno.test("Toutes les clés ont une traduction dans les 6 locales", () => {
  const incomplete: string[] = [];
  for (const k of _allKeys()) {
    if (!_isComplete(k)) {
      incomplete.push(`  - "${k}"`);
    }
  }

  if (incomplete.length > 0) {
    throw new Error(
      `🔴 ${incomplete.length} clé(s) avec une traduction manquante ou vide :\n` +
      incomplete.join("\n") +
      `\n\nLocales requises : ${_supportedLocales().join(", ")}`
    );
  }
});

// ============================================================================
// TEST 3 — Conformité à la charte de langage inclusif militant
// ============================================================================

Deno.test("Aucune occurrence de termes proscrits par la charte", async () => {
  const proscribedPatterns: { pattern: RegExp; locale: string; rule: string }[] = [
    // Italien : "camerata" / "camerati" sont des termes de tradition fasciste
    // (CasaPound, Forza Nuova, MSI). Toujours utiliser compagno/a/e ou variantes.
    { pattern: /\bcamerat[ia]\b/i, locale: "it", rule: "Italien : utiliser compagno/a/e, jamais camerata/camerati" },

    // Allemand : "Compas" est un néologisme hispanophone qui n'a aucun sens en allemand.
    // Toujours traduire par Genoss*in / Genoss*innen.
    { pattern: /\bCompas\b/, locale: "de", rule: "Allemand : utiliser Genoss*in / Genoss*innen, jamais 'Compas'" },
  ];

  // Lecture du fichier mail-strings.ts pour scanner les valeurs
  const selfPath = new URL("./mail-strings.ts", import.meta.url);
  const content = await Deno.readTextFile(selfPath);

  const violations: string[] = [];
  for (const { pattern, locale, rule } of proscribedPatterns) {
    // Cherche les violations dans les valeurs associées à la locale
    // On scanne ligne par ligne pour repérer les "value" précédées de la locale
    const lines = content.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      // Match: it: "..." ou de: "..."
      const m = line.match(new RegExp(`^\\s*${locale}:\\s*["']([^"']+)["']`));
      if (m && pattern.test(m[1])) {
        violations.push(`  - ligne ${i + 1} (${locale}): "${m[1]}"\n    règle: ${rule}`);
      }
    }
  }

  if (violations.length > 0) {
    throw new Error(
      `🔴 ${violations.length} violation(s) de la charte militante :\n` +
      violations.join("\n\n")
    );
  }
});

// ============================================================================
// TEST 4 — Bonus : interpolation de paramètres
// ============================================================================

import { tMail } from "./mail-strings.ts";

Deno.test("Interpolation des paramètres {date} et {days}", () => {
  // loan.dueIn contient {date}
  const a = tMail("pt-BR", "loan.dueIn", { date: "05/05/2026" });
  if (!a.includes("05/05/2026")) throw new Error(`tMail n'a pas interpolé {date}: ${a}`);
  if (a.includes("{date}")) throw new Error(`tMail a laissé {date} non remplacé: ${a}`);

  // ov.30d contient {days}
  const b = tMail("fr", "ov.30d", { days: "45" });
  if (!b.includes("45")) throw new Error(`tMail n'a pas interpolé {days}: ${b}`);
  if (b.includes("{days}")) throw new Error(`tMail a laissé {days} non remplacé: ${b}`);
});

Deno.test("Fallback locale invalide → pt-BR", () => {
  const a = tMail("xx-XX", "wf.ready");
  const b = tMail(null, "wf.ready");
  const c = tMail("pt-BR", "wf.ready");
  assertEquals(a, c, "Une locale invalide doit fallback sur pt-BR");
  assertEquals(b, c, "Une locale null doit fallback sur pt-BR");
});

Deno.test("Clé inexistante retourne la clé brute (debug)", () => {
  const a = tMail("fr", "this.key.does.not.exist");
  assertEquals(a, "this.key.does.not.exist");
});
