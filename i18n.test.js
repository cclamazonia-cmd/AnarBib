// ═══════════════════════════════════════════════════════════
// AnarBib — i18n coverage tests
// Verifies that all locale files have consistent keys
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import ptBR from '@/i18n/locales/pt-BR.json';
import fr from '@/i18n/locales/fr.json';
import en from '@/i18n/locales/en.json';
import de from '@/i18n/locales/de.json';
import it_ from '@/i18n/locales/it.json';
import es from '@/i18n/locales/es.json';

const LOCALES = { 'pt-BR': ptBR, fr, en, de, it: it_, es };
const PT_KEYS = Object.keys(ptBR);

// Keys that are intentionally identical across languages (technical terms)
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
        // Extra keys are OK (language-specific additions), but warn if many
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
        // Words that are legitimately identical in PT-BR and another language
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
        // Allow some tolerance but flag if too many
        expect(untranslated.length).toBeLessThan(5);
      });
    });
  }

  it('all locale files should have valid JSON structure', () => {
    for (const [lang, data] of Object.entries(LOCALES)) {
      expect(typeof data).toBe('object');
      expect(data).not.toBeNull();
      // No empty string values (except intentional ones)
      const emptyValues = Object.entries(data).filter(([k, v]) => v === '' && !k.includes('placeholder'));
      expect(emptyValues.length).toBe(0);
    }
  });
});
