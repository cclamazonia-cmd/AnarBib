// ═══════════════════════════════════════════════════════════
// AnarBib — 21/10/2026, les deux familles de 401 sans jeton :
//
//   * notes de lecture : api.reading_notes_published_v1 n'est ouverte qu'aux
//     comptes connectés (20261018211324, conforme au cadrage adopté en AG :
//     « visibles par tout compte authentifié du réseau »). Le front l'appelait
//     quand même sur chaque notice vue sans compte → 401 (96 le 21/10).
//     Sans session : aucun appel, l'invitation à se connecter.
//   * session perdue : ProtectedRoute envoie vers /login?reason=lost, et la
//     page de connexion le dit, au lieu d'un tableau de bord qui empile des
//     « Impossible de charger ».
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { render, screen, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter, Routes, Route, useLocation } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const etat = vi.hoisted(() => ({ auth: { user: null, loading: false }, appels: [] }));

vi.mock('@/contexts/AuthContext', () => ({
  useAuth: () => etat.auth,
  AuthProvider: ({ children }) => children,
}));
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://projet-de-test.supabase.co',
  supabase: {
    schema: () => ({
      rpc: async (nom) => { etat.appels.push(nom); return { data: [], error: null }; },
    }),
    rpc: async () => ({ data: null, error: null }),
    auth: { getSession: async () => ({ data: { session: null } }) },
  },
}));

import ReadingNotesSection from '@/components/reading/ReadingNotesSection';
import { ProtectedRoute } from '@/components/layout/ProtectedRoute';
import { LOCALE_CODES } from '../i18n/locales.js';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

beforeEach(() => {
  etat.auth = { user: null, loading: false };
  etat.appels = [];
  localStorage.clear();
});
afterEach(() => cleanup());

describe('Notes de lecture — pas d’appel sans session', () => {
  const monter = () => render(
    <IntlProvider locale="fr" messages={fr}><ReadingNotesSection workId={42} /></IntlProvider>,
  );

  it('visiteur·se sans compte : aucune requête, l’invitation à se connecter', async () => {
    monter();
    expect(await screen.findByText(fr['readingNotes.anonHint'])).toBeTruthy();
    await new Promise((r) => setTimeout(r, 5));
    expect(etat.appels).toEqual([]);
  });

  it('compte connecté : les notes publiées sont demandées', async () => {
    etat.auth = { user: { id: 'u-1' }, loading: false };
    monter();
    await waitFor(() => expect(etat.appels).toContain('reading_notes_published_v1'));
  });
});

function OuSuisJe() {
  const { pathname, search } = useLocation();
  return <p data-testid="ici">{pathname + search}</p>;
}

describe('ProtectedRoute — une session perdue mène à l’explication', () => {
  const monter = () => render(
    <MemoryRouter initialEntries={['/painel?tab=mensagens']}>
      <Routes>
        <Route path="/painel" element={<ProtectedRoute><p>tableau</p></ProtectedRoute>} />
        <Route path="/login" element={<OuSuisJe />} />
        <Route path="/cadastro" element={<OuSuisJe />} />
      </Routes>
    </MemoryRouter>,
  );

  it('session perdue : /login?reason=lost, la page demandée gardée dans next', () => {
    etat.auth = { user: null, loading: false, lostSession: true };
    monter();
    expect(screen.getByTestId('ici').textContent)
      .toBe(`/login?reason=lost&next=${encodeURIComponent('/painel?tab=mensagens')}`);
  });

  it('jamais connecté·e dans cet onglet : le chemin habituel, sans avis', () => {
    monter();
    expect(screen.getByTestId('ici').textContent).toMatch(/^\/cadastro\?next=/);
  });
});

describe('Page de connexion — l’avis « session perdue »', () => {
  it('reason=lost est lu et affiché par sa propre clé', () => {
    const src = lire('src/pages/public/LoginPage.jsx');
    expect(src).toContain("reason === 'idle' || reason === 'lost' ? reason : readSessionEndNotice()");
    expect(src).toContain("endNotice === 'lost' ? 'login.reason.sessionLost'");
  });

  it('la clé existe, non vide, dans les 11 locales', () => {
    for (const code of LOCALE_CODES) {
      const messages = JSON.parse(lire(`src/i18n/locales/${code}.json`));
      expect(messages['login.reason.sessionLost'], code).toBeTruthy();
    }
  });
});
