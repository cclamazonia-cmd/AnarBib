// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 1 (05/10/2026) : l'onglet « Historique » de
// Mon compte sort dans TabHistorico.jsx, ContaTabHeader dans son fichier.
//   * l'onglet monte et rend un emprunt terminé, avec ses actions ;
//   * les séparateurs s'affichent « · » — l'original écrivait · en texte
//     JSX, où l'échappement ne vaut pas : la lectrice lisait « · »
//     (13 occurrences, toutes dans cet onglet) ; garde sur tout src/ ;
//   * le parent monte l'onglet avec ses dix-sept props et ne garde plus le
//     corps de l'onglet ; l'état « montrer le masqué » reste au parent.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import TabHistorico from '@/pages/account/TabHistorico';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

afterEach(cleanup);

const EMPRUNT = {
  emprestimo_id: 41, book_id: 7, titulos: 'L’Entraide', autores: 'Pierre Kropotkine',
  bib_refs: 'BLMF-0007', library_name: 'BLMF', items_count: 1, renewals_used: 1,
  emprestimo_created_at: '2026-09-01T10:00:00Z', returned_at: '2026-09-20T10:00:00Z', is_hidden_by_user: false,
};

function monter(sur = {}) {
  const props = {
    loanHistory: [EMPRUNT], consultationsHistory: [], history: [],
    showHiddenHistory: false, setShowHiddenHistory: vi.fn(),
    renderHistActions: (domain, id) => <span data-testid={`act-${domain}-${id}`} />,
    histLinkBtn: {}, retentionPrefs: { loans: false, reservations: false, consultations: false },
    setRetentionPrefs: vi.fn(), handleSaveRetentionPrefs: vi.fn(), retentionSaving: false, retentionMsg: null,
    setDeleteAllTarget: vi.fn(), setDeleteAllConfirmText: vi.fn(), loadData: vi.fn(),
    availabilityMap: new Map(), countFor: () => 0,
    ...sur,
  };
  render(<IntlProvider locale="fr" messages={fr}><TabHistorico {...props} /></IntlProvider>);
  return props;
}

describe('l’onglet Historique, sorti d’AccountPage', () => {
  it('monte et rend un emprunt terminé, avec ses actions', () => {
    monter();
    expect(screen.getByText(fr['account.history.title'])).toBeTruthy();
    expect(screen.getByText('L’Entraide')).toBeTruthy();
    expect(screen.getByTestId('act-loans-41')).toBeTruthy();
  });

  it('les séparateurs s’affichent « · », jamais « \\u00b7 »', () => {
    monter();
    const texte = document.body.textContent;
    expect(texte).toContain('ref: BLMF-0007 · BLMF');
    expect(texte).not.toContain('\\u00b7');
  });

  it('« montrer le masqué » remonte au parent', () => {
    const p = monter({ loanHistory: [{ ...EMPRUNT, is_hidden_by_user: true }] });
    fireEvent.click(screen.getByText(fr['account.history.showHiddenToggle'].replace('{count}', '1')));
    expect(p.setShowHiddenHistory).toHaveBeenCalled();
  });

  it('le parent monte l’onglet avec ses props et ne garde plus son corps', () => {
    const page = lire('src/pages/account/AccountPage.jsx');
    expect(page).toContain("import TabHistorico from '@/pages/account/TabHistorico';");
    // ContaTabHeader vit dans son fichier ; depuis le lot 5 (07/10) la page ne
    // l'importe plus, ce sont les onglets sortis qui l'emploient.
    for (const onglet of ['TabHistorico', 'TabAvisos', 'TabCurso', 'TabReservar']) {
      expect(lire(`src/pages/account/${onglet}.jsx`), onglet).toContain("import ContaTabHeader from '@/pages/account/ContaTabHeader';");
    }
    expect(page).not.toContain('function ContaTabHeader');
    for (const p of ['loanHistory', 'consultationsHistory', 'history', 'showHiddenHistory', 'setShowHiddenHistory', 'renderHistActions',
      'histLinkBtn', 'retentionPrefs', 'setRetentionPrefs', 'handleSaveRetentionPrefs', 'retentionSaving', 'retentionMsg',
      'setDeleteAllTarget', 'setDeleteAllConfirmText', 'loadData', 'availabilityMap', 'countFor']) {
      expect(page, p).toContain(`${p}={${p}}`);
    }
    expect(page).not.toContain('const hiddenCount');
    expect(page).not.toContain("account.retention.banner.title");
    expect(lire('src/pages/account/TabHistorico.jsx')).not.toMatch(/useState/);
  });
});

// Garde générale : en texte JSX, \uXXXX ne s'interprète pas.
describe('aucune séquence \\uXXXX en texte JSX', () => {
  it('dans tout src/ (hors chaînes de caractères et commentaires)', () => {
    const ESC = /\\u[0-9a-fA-F]{4}/;
    const LIT = /'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|`(?:[^`\\]|\\.)*`/g;
    const fautes = [];
    (function w(d) {
      for (const n of readdirSync(d)) {
        const p = path.join(d, n);
        if (statSync(p).isDirectory()) { if (n !== 'tests') w(p); continue; }
        if (!n.endsWith('.jsx')) continue;
        readFileSync(p, 'utf8').split('\n').forEach((l, i) => {
          if (ESC.test(l) && ESC.test(l.replace(/\/\/.*$/, '').replace(LIT, '""'))) fautes.push(`${path.relative(RACINE, p)}:${i + 1}`);
        });
      }
    })(path.join(RACINE, 'src'));
    expect(fautes).toEqual([]);
  });
});
