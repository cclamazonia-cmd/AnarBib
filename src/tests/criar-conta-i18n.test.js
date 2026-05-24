// ═══════════════════════════════════════════════════════════
// AnarBib — Paquet 8 criar-conta — couverture i18n du chantier
// Vérifie que les clés produites par le chantier criar-conta
// (Paquets 5 et 7) sont complètes et traduites dans les 8 locales.
//
// Note : les clés welcome.*.orphan du Paquet 6 vivent dans
// _shared/i18n/mail-strings.ts (les mails), pas dans les locales
// frontend — elles relèvent de mail-strings.test.ts, pas de ce fichier.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import ptBR from '@/i18n/locales/pt-BR.json';
import fr from '@/i18n/locales/fr.json';
import en from '@/i18n/locales/en.json';
import de from '@/i18n/locales/de.json';
import it_ from '@/i18n/locales/it.json';
import es from '@/i18n/locales/es.json';
import ca from '@/i18n/locales/ca.json';
import eo from '@/i18n/locales/eo.json';

const LOCALES = { 'pt-BR': ptBR, fr, en, de, it: it_, es, ca, eo };
const OTHER_LANGS = Object.keys(LOCALES).filter(l => l !== 'pt-BR');

// Préfixes des clés produites par le chantier criar-conta.
const CHANTIER_PREFIXES = ['auth.create.', 'account.declared.', 'privacy.declared.'];

// Toutes les clés du chantier, déterminées à partir du pt-BR (référence).
const CHANTIER_KEYS = Object.keys(ptBR).filter(
  k => CHANTIER_PREFIXES.some(p => k.startsWith(p))
);

// Échantillon de clés « visibles » (titres, libellés, boutons) qui doivent
// être réellement traduites — donc différentes du pt-BR dans les autres
// langues. On évite les clés à fort risque de coïncidence légitime.
const VISIBLE_KEYS = [
  'auth.create.title',
  'auth.create.submit',
  'auth.create.intent.optionOrphan',
  'auth.create.intent.optionNewLibrary',
  'account.declared.title',
  'account.declared.deleteBtn',
  'privacy.declared.title',
];

describe('criar-conta — couverture i18n du chantier', () => {
  it('le chantier expose un socle de clés dans pt-BR', () => {
    // 62 auth.create.* + 6 account.declared.* + 3 privacy.declared.*
    expect(CHANTIER_KEYS.length).toBeGreaterThanOrEqual(70);
  });

  for (const lang of OTHER_LANGS) {
    describe(`${lang}`, () => {
      it('a toutes les clés du chantier présentes et non vides', () => {
        const data = LOCALES[lang];
        const missing = CHANTIER_KEYS.filter(k => !(k in data));
        const empty = CHANTIER_KEYS.filter(
          k => k in data && (typeof data[k] !== 'string' || data[k].trim() === '')
        );
        expect(missing, `clés manquantes en ${lang}: ${missing.join(', ')}`).toEqual([]);
        expect(empty, `clés vides en ${lang}: ${empty.join(', ')}`).toEqual([]);
      });

      it('a traduit les clés visibles (différentes du pt-BR)', () => {
        const data = LOCALES[lang];
        const untranslated = VISIBLE_KEYS.filter(k => data[k] === ptBR[k]);
        expect(
          untranslated,
          `clés visibles non traduites en ${lang}: ${untranslated.join(', ')}`
        ).toEqual([]);
      });
    });
  }

  it('aucune clé du chantier ne contient de marqueur de traduction manquante', () => {
    const BAD_MARKERS = ['TODO', 'FIXME', '???', 'XXX'];
    for (const [lang, data] of Object.entries(LOCALES)) {
      for (const k of CHANTIER_KEYS) {
        const v = data[k];
        if (typeof v !== 'string') continue;
        for (const marker of BAD_MARKERS) {
          expect(
            v.includes(marker),
            `${lang}: ${k} contient un marqueur "${marker}"`
          ).toBe(false);
        }
      }
    }
  });
});
