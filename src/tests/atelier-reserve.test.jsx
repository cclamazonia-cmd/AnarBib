// CHEMIN DÉPÔT : src/tests/atelier-reserve.test.jsx
//
// E36 (10/10/2026) : un compte sans rôle d'équipe, sur /atelier-autoridades,
// lit UNE phrase qui dit à qui l'Atelier est réservé — pas deux « erreur
// technique (42501) » (la liste et la file de vérification). La page monte
// avec un faux supabase dont la liste refuse (42501, HINT
// error.atelier.reserved) : la phrase s'affiche une fois, ni bouton
// « Faire une proposition », ni file de vérification, ni appel à son RPC.
// Et les HINT des RPC de l'Atelier existent dans les dix locales.

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const rpc = vi.fn(async (nom) => (nom === 'fn_authority_list'
  ? { data: null, error: { code: '42501', hint: 'error.atelier.reserved', message: 'Atelier reservado a quem participa da rede (contribuinte, equipe ou administracao).' } }
  : { data: [], error: null }));
vi.mock('@/lib/supabase', () => ({
  supabase: {
    schema: () => ({ rpc: (...a) => rpc(...a) }),
    rpc: (...a) => rpc(...a),
    from: () => ({ select: () => ({ eq: () => ({ eq: () => ({ in: async () => ({ data: [], error: null }) }) }) }) }),
  },
  SUPABASE_URL: 'https://exemple.invalid',
}));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'u-lecteur' }, loading: false }), AuthProvider: ({ children }) => children }));
vi.mock('@/lib/useDocumentTitle', () => ({ useDocumentTitle: () => {} }));
vi.mock('@/components/layout', () => ({ PageShell: ({ children }) => <div>{children}</div>, Topbar: () => null, Footer: () => null }));
vi.mock('@/components/atelier/ConvRevuePanel', () => ({ default: () => <div data-testid="file-de-verification" /> }));
vi.mock('@/components/atelier/WorksWorkshopPanel', () => ({ default: () => <div data-testid="atelier-oeuvres" /> }));

const RACINE = path.resolve(__dirname, '../..');
const fr = JSON.parse(readFileSync(path.join(RACINE, 'src/i18n/locales/fr.json'), 'utf8'));
const { default: AtelierAutoridadesPage } = await import('@/pages/atelier/AtelierAutoridadesPage');

afterEach(() => { cleanup(); rpc.mockClear(); });

describe('Atelier des autorités — réservé aux équipes (E36)', () => {
  it('un compte sans rôle lit la phrase une seule fois ; ni formulaire, ni file de vérification, ni appel à son RPC', async () => {
    render(<MemoryRouter><IntlProvider locale="fr" messages={fr}><AtelierAutoridadesPage /></IntlProvider></MemoryRouter>);
    const phrase = fr['error.atelier.reserved'];
    await waitFor(() => expect(screen.getAllByText(phrase)).toHaveLength(1));
    expect(screen.queryByText(fr['atelier.action.newProposal'] || 'Fazer uma proposta')).toBeNull();
    expect(screen.queryByTestId('file-de-verification')).toBeNull();
    expect(screen.queryByText(/42501/)).toBeNull();
    expect(rpc.mock.calls.map((c) => c[0])).not.toContain('conv_revue_resume');
  });

  it('les HINT des RPC de l’Atelier existent dans les dix locales', () => {
    const dir = path.join(RACINE, 'src/i18n/locales');
    const fichiers = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(fichiers).toHaveLength(10);
    const cles = ['reserved', 'reservedStaff', 'notContributor', 'notStaff', 'notCoordenador', 'notUsingAuthority', 'notResolvedConsent', 'applyKindDeferred',
      'scissionAuthorOnly', 'scissionParts', 'scissionPartIncomplete', 'scissionBadType', 'scissionPartExists', 'scissionDuplicateParts',
      'splitTargetChanged', 'workNotFound', 'workKind', 'workLang', 'workTitle', 'workMergeTarget', 'workNotSame', 'workBook', 'workBookSame', 'workTomes', 'workPartBooks'].map((k) => `error.atelier.${k}`);
    for (const f of fichiers) {
      const j = JSON.parse(readFileSync(path.join(dir, f), 'utf8'));
      for (const k of cles) expect(typeof j[k], `${f} ${k}`).toBe('string');
    }
  });
});
