// ═══════════════════════════════════════════════════════════
// AnarBib — le panneau « encodage lu » d'un import (H15, 26/09/2026).
//
// On rend le VRAI RunEncodingPanel avec les vrais dictionnaires fr et el, sur
// les trois résumés que l'EF process-partner-catalog-import écrit réellement
// (formes figées par process-partner-catalog-import-banc.test.js) :
//   * UTF-8 détecté → une ligne neutre, le geste « Retraiter » offert ;
//   * repli windows-1252 SUPPOSÉ sur un fichier qui se dit Unicode → deux
//     lignes d'alerte (supposition + incohérence), « Retraiter » offert ;
//   * import déjà promu → plus de « Retraiter », la raison est dite.
// Et le câblage : la page importe ce panneau et appelle la RPC avec
// p_forced_encoding, puis fn_import_dispatch avec p_force_reparse.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import fr from '@/i18n/locales/fr.json';
import el from '@/i18n/locales/el.json';
import RunEncodingPanel from '@/pages/importacoes/RunEncodingPanel.jsx';

const rendre = (run, { messages = fr, locale = 'fr', onReprocess = () => {} } = {}) => render(
  <IntlProvider locale={locale} messages={messages}>
    <RunEncodingPanel run={run} reprocessEncoding="auto" setReprocessEncoding={() => {}}
      reprocessing={false} onReprocess={onReprocess} />
  </IntlProvider>,
);
const lignes = (c) => [...c.querySelectorAll('[data-encoding-line]')].map((p) => p.getAttribute('data-encoding-line'));

describe('RunEncodingPanel — ce que l\'écran dit de l\'encodage lu', () => {
  it('UTF-8 détecté : une ligne neutre, « Retraiter » offert', () => {
    const { container } = rendre({ id: 1, run_status: 'ready_for_review', created_drafts: 0,
      summary: { encoding: { used: 'utf-8', forced: null, fallback: false, declared_unimarc: ['50'] } } });
    expect(lignes(container)).toEqual(['auto']);
    expect(screen.getByText('Lu en UTF-8 (détecté).')).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Retraiter' })).toBeTruthy();
  });

  it('repli supposé sur un fichier qui se dit Unicode : supposition ET incohérence, en grec aussi', () => {
    const run = { id: 2, run_status: 'ready_for_review', created_drafts: 0,
      summary: { encoding: { used: 'windows-1252', forced: null, fallback: true, declared_unimarc: ['50'] } } };
    const onReprocess = vi.fn();
    const { container, unmount } = rendre(run, { onReprocess });
    expect(lignes(container)).toEqual(['fallback', 'declaredUnicode']);
    expect(container.textContent).toContain('Windows-1252 (latin-1), par supposition');
    fireEvent.click(screen.getByRole('button', { name: 'Retraiter' }));
    expect(onReprocess).toHaveBeenCalledTimes(1);
    unmount();
    const g = rendre(run, { messages: el, locale: 'el' });
    expect(g.container.textContent).toContain(el['importacoes.run.encoding.declaredUnicode']);
    expect(g.container.textContent).toContain(el['importacoes.run.reprocess.button']);
  });

  it('jeu déclaré non pris en charge (ISO 5426) : dit, avec le code', () => {
    const { container } = rendre({ id: 3, run_status: 'ready_for_review', created_drafts: 0,
      summary: { encoding: { used: 'utf-8', forced: null, fallback: false, declared_unimarc: ['03'] } } });
    expect(lignes(container)).toEqual(['auto', 'declaredUnsupported']);
    expect(container.textContent).toContain('(03)');
  });

  it('import déjà promu : plus de « Retraiter », la raison est dite', () => {
    const { container } = rendre({ id: 4, run_status: 'drafts_created', created_drafts: 12,
      summary: { encoding: { used: 'windows-1252', forced: 'windows-1252', fallback: false, declared_unimarc: [] } } });
    expect(lignes(container)).toEqual(['forced']);
    expect(screen.queryByRole('button', { name: 'Retraiter' })).toBeNull();
    expect(container.textContent).toContain(fr['importacoes.run.reprocess.locked']);
  });

  it('import promu d\'avant H15 (sans résumé d\'encodage) : rien', () => {
    const { container } = rendre({ id: 5, run_status: 'drafts_created', created_drafts: 3, summary: { parser: 'csv_v1' } });
    expect(container.textContent).toBe('');
  });

  it('la page câble le panneau et les deux RPC (encodage imposé, retraitement forcé)', () => {
    const src = readFileSync(path.resolve(__dirname, '../pages/importacoes/ImportacoesPage.jsx'), 'utf8');
    expect(src).toContain("import RunEncodingPanel from './RunEncodingPanel.jsx'");
    expect(src).toMatch(/p_forced_encoding:\s*adapterEncoding === 'auto' \? null : adapterEncoding/);
    expect(src).toMatch(/p_forced_encoding:\s*reprocessEncoding === 'auto' \? null : reprocessEncoding/);
    expect(src).toMatch(/fn_import_dispatch', \{\s*p_run_id: Number\(selectedRun\.id\), p_force_reparse: true/);
  });
});
