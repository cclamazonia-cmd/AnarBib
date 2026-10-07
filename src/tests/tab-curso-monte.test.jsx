// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 4 (07/10/2026) : l'onglet « En cours » de
// Mon compte sort dans TabCurso.jsx.
//   * les items ouverts se groupent par emprunt (« n livres »), les items
//     rendus n'y sont pas ; sans item ouvert, le vide est dit ;
//   * « Renouveler tout » n'apparaît qu'à partir de deux livres ;
//   * un item en retard dit « en retard » et n'offre pas « Renouveler » ;
//   * « Renouveler » appelle api.renew_my_loan_item puis recharge ;
//   * les rendus partagés du parent (étiquette, même titre) sont appelés ;
//   * le parent monte l'onglet et ne garde plus son corps.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const rpc = vi.fn(async () => ({ data: { ok: true, new_due_date: '2026-12-01' }, error: null }));
vi.mock('@/lib/supabase', () => ({
  supabase: { schema: () => ({ rpc: (...a) => rpc(...a) }) },
  SUPABASE_URL: 'https://exemple.invalid',
}));

import TabCurso from '@/pages/account/TabCurso';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

afterEach(() => { cleanup(); rpc.mockClear(); });

const jour = (d) => { const x = new Date(); x.setDate(x.getDate() + d); return x.toISOString().slice(0, 10); };
const item = (sur) => ({ emprestimo_id: 41, emprestimo_created_at: '2026-09-20T10:00:00Z', library_id: 'lib-a',
  item_status: 'aberto', due_at: jour(20), extended_until: null, book_id: 7, titulo: 'L’Entraide',
  autor: 'Pierre Kropotkine', bib_ref: 'BLMF-0007', line_no: 1, sub_id: 's1', ...sur });

function monter(sur = {}) {
  const props = {
    loans: [item(), item({ line_no: 2, sub_id: 's2', titulo: 'La Conquête du pain', book_id: 8, bib_ref: 'BLMF-0008' }),
            item({ emprestimo_id: 40, line_no: 1, sub_id: 's9', item_status: 'devolvido', titulo: 'Rendu' })],
    renewStatus: { s1: { can_renew: true, renewals_used: 0 }, s2: { can_renew: true, renewals_used: 0 } },
    loadData: vi.fn(), renderLibTag: vi.fn(() => null), renderSameTitleSignal: vi.fn(() => null), ...sur,
  };
  render(<IntlProvider locale="fr" messages={fr}><MemoryRouter><TabCurso {...props} /></MemoryRouter></IntlProvider>);
  return props;
}

describe('l’onglet En cours, sorti d’AccountPage', () => {
  it('groupe les items ouverts par emprunt, sans les items rendus', () => {
    const p = monter();
    expect(screen.getByText(fr['account.loans.title'])).toBeTruthy();
    expect(screen.getByText('L’Entraide')).toBeTruthy();
    expect(screen.getByText('La Conquête du pain')).toBeTruthy();
    expect(screen.queryByText('Rendu')).toBeNull();
    expect(screen.getByText(fr['account.loans.renewAll'])).toBeTruthy();
    expect(p.renderLibTag).toHaveBeenCalledWith('lib-a');
    expect(p.renderSameTitleSignal).toHaveBeenCalledWith('L’Entraide');
  });

  it('un seul livre : pas de « Renouveler tout » ; aucun item ouvert : le vide est dit', () => {
    monter({ loans: [item()] });
    expect(screen.queryByText(fr['account.loans.renewAll'])).toBeNull();
    cleanup();
    monter({ loans: [] });
    expect(screen.getByText(fr['account.loans.empty'])).toBeTruthy();
  });

  it('un item en retard dit « en retard » et n’offre pas « Renouveler »', () => {
    monter({ loans: [item({ due_at: jour(-5) })], renewStatus: {} });
    expect(screen.getByText(fr['account.loans.overdue'])).toBeTruthy();
    expect(screen.queryByText(fr['account.loans.renew'])).toBeNull();
  });

  it('« Renouveler » appelle api.renew_my_loan_item puis recharge', async () => {
    const alerte = vi.spyOn(window, 'alert').mockImplementation(() => {});
    const p = monter({ loans: [item()] });
    fireEvent.click(screen.getByText(fr['account.loans.renew']));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('renew_my_loan_item', { p_emprestimo_id: 41, p_line_no: 1 }));
    await waitFor(() => expect(p.loadData).toHaveBeenCalled());
    alerte.mockRestore();
  });

  it('le parent monte TabCurso et ne garde plus le corps de l’onglet', () => {
    const page = lire('src/pages/account/AccountPage.jsx');
    expect(page).toMatch(/<TabCurso\b/);
    expect(page).not.toMatch(/renew_my_loan_item|renew_my_loan'/);
  });
});
