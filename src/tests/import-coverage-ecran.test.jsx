// ═══════════════════════════════════════════════════════════
// AnarBib — la couverture d'un import à l'écran (H16, 26/09/2026).
//
// On rend les VRAIS composants avec les vrais dictionnaires fr et el :
//   * RunCoveragePanel (Importations) sur un summary tel que l'EF l'écrit
//     (formes figées par process-partner-catalog-import-banc.test.js) :
//     comptes, lignes écartées, éléments non repris triés par fréquence,
//     répétitions non reprises, et le CSV téléchargeable ;
//   * BatchReviewReport sur un rapport tel que fn_batch_review_report le rend
//     (formes figées par tests/sql/import_couverture_tests.sql).
// ═══════════════════════════════════════════════════════════

import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import fr from '@/i18n/locales/fr.json';
import el from '@/i18n/locales/el.json';
import RunCoveragePanel from '@/pages/importacoes/RunCoveragePanel.jsx';
import BatchReviewReport from '@/components/catalog/BatchReviewReport.jsx';
import { coverageToCsv, coverageItemLabel } from '@/lib/importCoverage.js';

const RUN = {
  id: 42, original_filename: 'export-pmb.marc', run_status: 'ready_for_review', created_drafts: 0,
  summary: {
    coverage: { kind: 'marc', records: 50, truncated: false, zones: [
      { dialect: 'unimarc', tag: '001', code: '', status: 'repris', occurrences: 50, records: 50, surplus: 0, example: '1' },
      { dialect: 'unimarc', tag: '101', code: 'a', status: 'repris', occurrences: 48, records: 46, surplus: 2, example: 'fre' },
      { dialect: 'unimarc', tag: '215', code: 'a', status: 'brut', occurrences: 43, records: 43, surplus: 0, example: '166 p.' },
      { dialect: 'unimarc', tag: '995', code: 'f', status: 'brut', occurrences: 33, records: 31, surplus: 0, example: '33700004388761' },
    ] },
    coverage_counts: { repris: 2, indice: 0, brut: 2, total: 4 },
    skipped_rows: 3,
  },
};

const rendre = (ui, messages = fr, locale = 'fr') => render(<IntlProvider locale={locale} messages={messages}>{ui}</IntlProvider>);

describe('RunCoveragePanel — ce que l\'import a repris', () => {
  it('comptes, lignes écartées, non-repris triés par fréquence, répétitions non reprises', () => {
    const { container } = rendre(<RunCoveragePanel run={RUN} />);
    expect(container.querySelector('[data-coverage-counts]').textContent)
      .toBe('2 repris, 0 relus en indice, 2 gardés seulement en brut (sur 4)');
    expect(container.textContent).toContain('3 lignes écartées faute de tout contenu bibliographique.');
    const lignes = [...container.querySelectorAll('[data-coverage-item]')].map((r) => r.getAttribute('data-coverage-item'));
    expect(lignes).toEqual(['215 $a', '995 $f', '101 $a']);
    expect(container.textContent).toContain('2 répétitions non reprises');
    expect(screen.getByRole('button', { name: 'Télécharger le rapport (CSV)' })).toBeTruthy();
  });

  it('en grec aussi, avec les pluriels ICU', () => {
    const { container } = rendre(<RunCoveragePanel run={RUN} />, el, 'el');
    expect(container.textContent).toContain('3 γραμμές απορρίφθηκαν');
    expect(container.textContent).toContain(el['importacoes.coverage.download']);
  });

  it('import antérieur à H16 (summary sans couverture) : une ligne qui le dit ; sans summary : rien', () => {
    const a = rendre(<RunCoveragePanel run={{ id: 1, summary: { parser: 'csv_v1' } }} />);
    expect(a.container.textContent).toBe(fr['importacoes.coverage.none']);
    a.unmount();
    const b = rendre(<RunCoveragePanel run={{ id: 2, summary: null }} />);
    expect(b.container.textContent).toBe('');
  });

  it('le CSV téléchargé porte tout, repris compris, et échappe ce qu\'il faut', () => {
    const csv = coverageToCsv(RUN.summary.coverage, { filename: 'export-pmb.marc', runId: 42 });
    const lignes = csv.trim().split('\r\n');
    expect(lignes[0]).toBe('import,fichier,format,element,statut,champ,occurrences,notices,repetitions_non_reprises,exemple');
    expect(lignes).toHaveLength(5);
    expect(lignes[4]).toBe('42,export-pmb.marc,marc,995 $f,brut,,33,31,0,33700004388761');
    expect(coverageToCsv({ kind: 'csv', columns: [{ header: 'titre', status: 'brut', occurrences: 1, example: 'Ni dieu, ni maître' }] }))
      .toContain('"Ni dieu, ni maître"');
    expect(coverageItemLabel({ tag: '001', code: '' })).toBe('001');
    expect(coverageItemLabel({ header: 'titulo' })).toBe('titulo');
    expect(coverageItemLabel({ tag: 'SP', status: 'brut' })).toBe('SP');
  });
});

describe('BatchReviewReport — la section couverture du rapport de révision', () => {
  const REPORT = {
    batch: { id: 7, drafts_active: 1 }, totals: {}, conventions: [], duplicates: {}, authorities: {},
    coverage: [
      { run_id: 42, original_filename: 'export-pmb.marc', kind: 'marc', counts: { repris: 2, indice: 0, brut: 2, total: 4 },
        skipped_rows: 0, encoding: { used: 'utf-8', fallback: false },
        not_taken: [{ tag: '995', code: 'f', status: 'brut', occurrences: 33, example: '33700004388761' },
          { tag: '215', code: 'a', status: 'brut', occurrences: 43, example: '166 p.' }] },
      { run_id: 43, original_filename: 'ancien.csv', kind: null, counts: null, skipped_rows: null, encoding: null, not_taken: [] },
    ],
  };

  it('un bloc par import d\'origine : ce qui n\'est pas repris, ou « aucun rapport » pour un import ancien', () => {
    const { container } = rendre(<BatchReviewReport report={REPORT} />);
    const sec = container.querySelector('[data-testid="review-coverage"]');
    expect(sec).toBeTruthy();
    expect(sec.textContent).toContain('Ce que les imports ont laissé de côté');
    expect(sec.textContent).toContain('Import nº 42 — export-pmb.marc');
    expect(sec.textContent).toContain('995 $f — gardé en brut · 33 occurrences');
    expect(sec.textContent).toContain(fr['importacoes.coverage.none']);
  });

  it('un lot sans import : pas de section', () => {
    const { container } = rendre(<BatchReviewReport report={{ ...REPORT, coverage: [] }} />);
    expect(container.querySelector('[data-testid="review-coverage"]')).toBeNull();
  });
});
