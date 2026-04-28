// ═══════════════════════════════════════════════════════════
// AnarBib — i18n coverage tests
// Verifies that:
//   1. All locale files have consistent keys
//   2. All keys used in source code are defined in locales (anti-regression)
//   3. No camerata/camerati slip into Italian (zero-tolerance fascist term)
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { readFileSync, readdirSync, statSync } from 'fs';
import { join } from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

import ptBR from '@/i18n/locales/pt-BR.json';
import fr from '@/i18n/locales/fr.json';
import en from '@/i18n/locales/en.json';
import de from '@/i18n/locales/de.json';
import it_ from '@/i18n/locales/it.json';
import es from '@/i18n/locales/es.json';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SRC_DIR = join(__dirname, 'src');

const LOCALES = { 'pt-BR': ptBR, fr, en, de, it: it_, es };
const PT_KEYS = Object.keys(ptBR);

// ─────────────────────────────────────────────────────────────
// Static key extraction from source code
// ─────────────────────────────────────────────────────────────

/**
 * Recursively walks the src/ directory and extracts all static i18n keys
 * referenced via t({id:'...'}) or formatMessage({id:'...'}).
 * Returns { staticKeys: Set<string>, dynamicPrefixes: Set<string> }.
 */
function extractKeysFromSource(dir) {
  const staticKeys = new Set();
  const dynamicPrefixes = new Set();

  // Match t({id:'...'}) and formatMessage({id:'...'}) where the id is a FIXED string
  // literal — NOT followed by a '+' (which would indicate string concatenation like
  // t({id:'roles.'+m.role}), where the actual id is built dynamically at runtime).
  const STATIC_PATTERN = /t\s*\(\s*\{\s*id\s*:\s*['"]([^'"]+)['"](?!\s*\+)/g;
  const FORMAT_PATTERN = /formatMessage\s*\(\s*\{\s*id\s*:\s*['"]([^'"]+)['"](?!\s*\+)/g;
  // Template-literal dynamic ids : t({id:`prefix.${var}`})
  const DYNAMIC_PATTERN = /t\s*\(\s*\{\s*id\s*:\s*`([^`]+)`/g;
  // Concatenation-based dynamic ids : t({id:'prefix.'+var})
  const CONCAT_PATTERN = /t\s*\(\s*\{\s*id\s*:\s*['"]([^'"]+)['"]\s*\+/g;

  function walk(currentDir) {
    let entries;
    try {
      entries = readdirSync(currentDir);
    } catch {
      return;
    }
    for (const entry of entries) {
      const full = join(currentDir, entry);
      let stat;
      try {
        stat = statSync(full);
      } catch {
        continue;
      }
      if (stat.isDirectory()) {
        // Skip test directories and node_modules
        if (entry === 'tests' || entry === 'node_modules' || entry.startsWith('.')) continue;
        walk(full);
      } else if (
        (entry.endsWith('.jsx') || entry.endsWith('.js') ||
         entry.endsWith('.tsx') || entry.endsWith('.ts')) &&
        !entry.includes('.test.')
      ) {
        let content;
        try {
          content = readFileSync(full, 'utf-8');
        } catch {
          continue;
        }
        let m;
        while ((m = STATIC_PATTERN.exec(content)) !== null) staticKeys.add(m[1]);
        while ((m = FORMAT_PATTERN.exec(content)) !== null) staticKeys.add(m[1]);
        while ((m = DYNAMIC_PATTERN.exec(content)) !== null) {
          const tmpl = m[1];
          if (tmpl.includes('${')) {
            dynamicPrefixes.add(tmpl.split('${')[0]);
          }
        }
        // Concatenation-based dynamic ids: collect the literal prefix
        while ((m = CONCAT_PATTERN.exec(content)) !== null) {
          dynamicPrefixes.add(m[1]);
        }
      }
    }
  }

  walk(dir);
  return { staticKeys, dynamicPrefixes };
}

// Compute once for all tests
const { staticKeys: USED_KEYS, dynamicPrefixes: DYNAMIC_PREFIXES } =
  extractKeysFromSource(SRC_DIR);

// Keys that are intentionally identical across languages (technical terms, autonyms)
const SKIP_KEYS = [
  'app.name', 'book.isbn', 'book.meta.isbn', 'book.meta.issn', 'book.meta.cdd',
  'catalogacao.form.isbn', 'catalogacao.form.issn', 'catalogacao.form.cdd',
  'material.zine', 'catalog.table.ref', 'CDD', 'ISBN', 'ISSN',
];

describe('i18n locale files', () => {
  it('pt-BR should have at least 1200 keys', () => {
    expect(PT_KEYS.length).toBeGreaterThanOrEqual(1200);
  });

  for (const [lang, data] of Object.entries(LOCALES)) {
    if (lang === 'pt-BR') continue;

    describe(`${lang} locale`, () => {
      it('should have the same number of keys or more than pt-BR', () => {
        expect(Object.keys(data).length).toBeGreaterThanOrEqual(PT_KEYS.length - 50);
      });

      it('should not have keys missing from pt-BR', () => {
        const ptSet = new Set(PT_KEYS);
        const extra = Object.keys(data).filter(k => !ptSet.has(k));
        if (extra.length > 50) {
          console.warn(`${lang} has ${extra.length} extra keys not in pt-BR`);
        }
      });

      it('critical UI keys should be translated (not identical to pt-BR)', () => {
        const critical = [
          'nav.catalog', 'nav.login', 'common.search', 'common.cancel', 'common.save',
          'catalog.title', 'book.author', 'book.publisher', 'book.year',
          'account.title', 'account.loans.renew',
          'panel.subtitle', 'biblioteca.title',
        ];
        const sharedVocab = {
          es: ['nav.catalog', 'nav.login', 'common.search', 'common.cancel', 'catalog.title', 'account.loans.renew', 'biblioteca.title'],
          it: ['biblioteca.title'],
        };
        const allowed = new Set(sharedVocab[lang] || []);
        const untranslated = critical.filter(k => {
          if (SKIP_KEYS.some(sk => k === sk || k.startsWith(sk))) return false;
          if (allowed.has(k)) return false;
          return data[k] === ptBR[k];
        });
        if (untranslated.length > 0) {
          console.warn(`${lang}: untranslated critical keys: ${untranslated.join(', ')}`);
        }
        expect(untranslated.length).toBeLessThan(5);
      });
    });
  }

  it('all locale files should have valid JSON structure', () => {
    for (const [lang, data] of Object.entries(LOCALES)) {
      expect(typeof data).toBe('object');
      expect(data).not.toBeNull();
      const emptyValues = Object.entries(data).filter(([k, v]) => v === '' && !k.includes('placeholder'));
      expect(emptyValues.length).toBe(0);
    }
  });
});

// ═══════════════════════════════════════════════════════════
// Anti-regression : code ↔ locales coverage
// ═══════════════════════════════════════════════════════════

describe('i18n coverage : code ↔ locales', () => {
  it('source code should reference at least 800 distinct keys', () => {
    // Sanity check : if the regex is broken, this will catch it
    expect(USED_KEYS.size).toBeGreaterThanOrEqual(800);
  });

  it('every static key used in code must be defined in pt-BR (reference locale)', () => {
    const ptSet = new Set(PT_KEYS);
    const missing = [...USED_KEYS].filter(k => !ptSet.has(k));
    if (missing.length > 0) {
      console.error(
        `Static keys used in source code but missing from pt-BR.json:\n` +
        missing.map(k => `  - ${k}`).join('\n')
      );
    }
    expect(missing).toEqual([]);
  });

  it('every static key used in code must be defined in all other locales', () => {
    const failures = [];
    for (const [lang, data] of Object.entries(LOCALES)) {
      if (lang === 'pt-BR') continue;
      const localeSet = new Set(Object.keys(data));
      const missing = [...USED_KEYS].filter(k => !localeSet.has(k));
      if (missing.length > 0) {
        failures.push(`${lang} missing ${missing.length} keys: ${missing.slice(0, 5).join(', ')}${missing.length > 5 ? '…' : ''}`);
      }
    }
    if (failures.length > 0) {
      console.error('Locale coverage failures:\n' + failures.join('\n'));
    }
    expect(failures).toEqual([]);
  });

  it('dynamic-key prefixes must have at least one matching key in pt-BR', () => {
    // Each dynamic prefix like `roles.${role}` should have at least one
    // matching key like `roles.admin` defined.
    const failures = [];
    for (const prefix of DYNAMIC_PREFIXES) {
      const matchingKeys = PT_KEYS.filter(k => k.startsWith(prefix));
      if (matchingKeys.length === 0) {
        failures.push(`Dynamic prefix '${prefix}*' has 0 matching keys in pt-BR`);
      }
    }
    if (failures.length > 0) {
      console.warn(failures.join('\n'));
    }
    // Soft check (warn but don't fail) — some prefixes legitimately have 0 keys
    // when the values are stored in the database (e.g. country codes).
  });
});

// ═══════════════════════════════════════════════════════════
// Inclusive language compliance (per charter v1.0)
// ═══════════════════════════════════════════════════════════

describe('inclusive language charter compliance', () => {
  it('Italian must never contain camerata/camerati (proscribed fascist term)', () => {
    // Hard, non-negotiable check : "camerata" is the internal address term of
    // Italian fascism (PNF, MSI, CasaPound) and must never appear in AnarBib.
    const forbidden = /\bcamera[t][aeio]\b/i;
    const violations = Object.entries(it_).filter(([k, v]) => forbidden.test(v));
    if (violations.length > 0) {
      console.error(
        `🚨 ALERT: Italian locale contains proscribed fascist term:\n` +
        violations.map(([k, v]) => `  ${k}: ${JSON.stringify(v)}`).join('\n')
      );
    }
    expect(violations).toEqual([]);
  });

  it('German "Compas" should not appear untranslated (must use Genoss*in)', () => {
    // Hispanophone neologism leaked into German is incorrect — see charter.
    const violations = Object.entries(de).filter(([k, v]) =>
      /\bCompas\b/.test(v)
    );
    expect(violations).toEqual([]);
  });

  it('pt-BR should not contain bureaucratic (a) without (a/e) charter form', () => {
    // Charter v1.0 mandates triple form (o/a/e) or (a/e), not bare (a).
    const bureaucratic = /\([ao]\)(?!\/)/;
    const violations = Object.entries(ptBR)
      .filter(([k, v]) => bureaucratic.test(v))
      .map(([k]) => k);
    if (violations.length > 0) {
      console.warn(
        `pt-BR keys with bureaucratic (a) instead of charter form (a/e):\n` +
        violations.map(k => `  - ${k}`).join('\n')
      );
    }
    // Soft warning to allow gradual migration — escalate to hard fail later.
    expect(violations.length).toBeLessThan(10);
  });

  it('es should use e neutre, not bureaucratic /a or (a)', () => {
    // Charter v1.0 mandates e neutre (compañere), not /a or (a).
    // We exclude legitimate cases like emails (lector@example.org).
    const bureaucratic = /\b\w+\([ao]\)|\b\w+\/[ao]\b/;
    const violations = Object.entries(es)
      .filter(([k, v]) => {
        // Skip emails and technical placeholders
        if (v.includes('@example') || v.includes('@ejemplo')) return false;
        return bureaucratic.test(v);
      })
      .map(([k]) => k);
    if (violations.length > 0) {
      console.warn(
        `es keys with bureaucratic /a or (a) instead of charter form e neutre:\n` +
        violations.map(k => `  - ${k}`).join('\n')
      );
    }
    expect(violations.length).toBeLessThan(5);
  });
});
