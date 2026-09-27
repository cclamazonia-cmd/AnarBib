// ═══════════════════════════════════════════════════════════
// AnarBib — les exemplaires d'un catalogue importé à l'écran (H19, 26/09/2026,
// REGISTRE IMP-21).
//
//   * BatchReviewReport sur un rapport tel que fn_batch_review_report le rend
//     (formes figées par tests/sql/import_exemplaires_tests.sql) : section
//     « Exemplaires importés », compte, et chaque exemplaire qui empêcherait
//     la publication avec sa raison ;
//   * les clés construites à l'exécution (raisons, champs du profil) et les
//     HINT de la migration H19 existent dans les 10 locales — la garde i18n ne
//     voit ni les gabarits `${...}` ni les HINT SQL.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import el from '@/i18n/locales/el.json';
import BatchReviewReport from '@/components/catalog/BatchReviewReport.jsx';
import { DEFAULT_ITEM_MAPPINGS } from '../../supabase/functions/process-partner-catalog-import/marc.ts';

const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
const dico = (loc) => JSON.parse(readFileSync(path.resolve(__dirname, `../i18n/locales/${loc}.json`), 'utf8'));

const REPORT = {
  batch: { drafts_active: 3, drafts_published: 0, drafts_cancelled: 0 },
  totals: { convention_issues: 0, duplicates: 0, unlinked_authorities: 0 },
  items: {
    count: 5, with_code: 4, without_library: 1, library_without_numbering: 0, code_taken: 1, code_twice: 0,
    problems: [
      { item_draft_id: 11, draft_id: 7, titulo: 'La Commune', source_item_code: 'CDF0000000001', reason: 'code_taken' },
      { item_draft_id: 12, draft_id: 8, titulo: 'L’Anarchie', source_item_code: null, reason: 'without_library' },
    ],
  },
};

const rendre = (ui, messages = fr, locale = 'fr') => render(<IntlProvider locale={locale} messages={messages}>{ui}</IntlProvider>);

describe('BatchReviewReport — exemplaires importés', () => {
  it('compte, puis chaque exemplaire bloquant avec son code d\'origine et sa raison', () => {
    const { container } = rendre(<BatchReviewReport report={REPORT} />);
    const sec = container.querySelector('[data-testid="review-items"]');
    expect(sec).toBeTruthy();
    expect(sec.textContent).toContain('Exemplaires importés');
    expect(sec.textContent).toContain('5 exemplaires, dont 4 avec un code d’origine');
    const raisons = [...sec.querySelectorAll('[data-item-problem]')].map((li) => li.getAttribute('data-item-problem'));
    expect(raisons).toEqual(['code_taken', 'without_library']);
    expect(sec.textContent).toContain('CDF0000000001');
    expect(sec.textContent).toContain(fr['review.report.items.reason.code_taken']);
    expect(sec.textContent).toContain(fr['review.report.items.reason.without_library']);
  });

  it('aucun problème : le compte et « rien à signaler » ; en grec, le pluriel ICU', () => {
    const propre = { ...REPORT, items: { count: 1, with_code: 1, problems: [] } };
    const a = rendre(<BatchReviewReport report={propre} />);
    const sec = a.container.querySelector('[data-testid="review-items"]');
    expect(sec.textContent).toContain('1 exemplaire, dont 1 avec un code d’origine');
    expect(sec.textContent).toContain(fr['review.report.noIssues']);
    expect(sec.querySelector('[data-item-problem]')).toBeNull();
    a.unmount();
    const b = rendre(<BatchReviewReport report={REPORT} />, el, 'el');
    expect(b.container.querySelector('[data-testid="review-items"]').textContent).toContain('5 αντίτυπα');
  });

  it('exemplaire de rapprochement (sans brouillon de notice) : le titre ; au-delà de 40, « et N autres » sur le total', () => {
    const quarante = Array.from({ length: 40 }, (_, i) => ({ item_draft_id: 100 + i, draft_id: 9, titulo: 'Quarante-cinq', source_item_code: 'DUP-X', reason: 'code_twice' }));
    const rapport = { ...REPORT, items: {
      count: 47, with_code: 47, code_twice: 45, code_pending_elsewhere: 1, library_mismatch: 1,
      problems: [{ item_draft_id: 1, draft_id: null, titulo: 'Petite histoire', source_item_code: 'RAP-1', reason: 'code_pending_elsewhere' }, ...quarante.slice(0, 39)],
    } };
    const { container } = rendre(<BatchReviewReport report={rapport} />);
    const sec = container.querySelector('[data-testid="review-items"]');
    const premier = sec.querySelector('[data-item-problem]');
    expect(premier.textContent).toContain('Petite histoire');
    expect(premier.textContent).not.toMatch(/brouillon|null/);
    expect(premier.textContent).toContain(fr['review.report.items.reason.code_pending_elsewhere']);
    expect(sec.querySelectorAll('[data-item-problem]')).toHaveLength(40);
    // 47 problèmes au total (45 + 1 + 1), 40 montrés.
    expect(sec.textContent).toContain('… et 7 de plus');
  });

  it('lot sans exemplaire importé, ou rapport antérieur à H19 : pas de section', () => {
    const a = rendre(<BatchReviewReport report={{ ...REPORT, items: { count: 0, with_code: 0, problems: [] } }} />);
    expect(a.container.querySelector('[data-testid="review-items"]')).toBeNull();
    a.unmount();
    const { items: _omis, ...ancien } = REPORT;
    const b = rendre(<BatchReviewReport report={ancien} />);
    expect(b.container.querySelector('[data-testid="review-items"]')).toBeNull();
  });
});

describe('H19 — clés dynamiques et HINT présents dans les 10 locales', () => {
  const migration = readFileSync(path.resolve(__dirname, '../../supabase/migrations/20260927113000_h19_exemplaires_importes.sql'), 'utf8');
  const hints = [...new Set([...migration.matchAll(/hint\s*=\s*'(error\.[A-Za-z0-9_.]+)'/gi)].map((m) => m[1]))];
  const page = readFileSync(path.resolve(__dirname, '../pages/importacoes/ImportacoesPage.jsx'), 'utf8');
  const champs = JSON.parse(page.match(/const PROFILE_ITEM_KEYS = (\[[^\]]*\])/)[1].replace(/'/g, '"'));
  const RAISONS = ['without_library', 'library_mismatch', 'library_without_numbering', 'code_taken', 'code_twice', 'code_pending_elsewhere'];
  const raisons = [...new Set([...migration.matchAll(/then '([a-z_]+)'\s*$/gm)].map((m) => m[1]))]
    .filter((r) => RAISONS.includes(r));

  // Toutes les HINT de la migration, y compris celles des fonctions qu'elle
  // réécrit : error.catalog.staff_only et holding_library_mismatch, posées en
  // juillet sans libellé, ont été trouvées ainsi.
  it('la migration porte les HINT neuves, la page les 8 champs, le rapport les 6 raisons', () => {
    expect(hints).toEqual(expect.arrayContaining([
      'error.import.items_mapping_invalid',
      'error.publish.item_before_record', 'error.publish.item_without_library',
      'error.publish.items_library_mismatch', 'error.publish.items_on_update',
      'error.publish.items_without_library', 'error.publish.source_item_code_taken',
      'error.catalog.staff_only', 'error.catalog.holding_library_mismatch',
    ]));
    expect(champs).toEqual(['tag', 'code', 'call_number', 'note', 'owner', 'item_type', 'public', 'status']);
    expect(raisons.sort()).toEqual([...RAISONS].sort());
  });

  it('les grisés du profil disent la convention réelle des deux dialectes (marc.ts)', () => {
    const grises = Function(`return ${page.match(/const PROFILE_ITEM_HINTS = (\{[^}]*\})/)[1]}`)();
    for (const k of champs) {
      const [uni, m21] = grises[k].split(' · ');
      expect(uni.replace('—', '')).toBe(DEFAULT_ITEM_MAPPINGS.unimarc[k]);
      expect(m21.replace('—', '')).toBe(DEFAULT_ITEM_MAPPINGS.marc21[k]);
    }
  });

  it.each(LOCALES)('%s', (loc) => {
    const d = dico(loc);
    const cles = [
      ...hints,
      ...champs.map((k) => `importacoes.adapter.profileItems.${k}`),
      ...raisons.map((r) => `review.report.items.reason.${r}`),
    ];
    expect(cles.filter((k) => typeof d[k] !== 'string' || !d[k].trim())).toEqual([]);
  });
});
