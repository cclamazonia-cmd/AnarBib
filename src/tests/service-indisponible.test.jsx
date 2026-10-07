// ═══════════════════════════════════════════════════════════
// AnarBib — E33 (07/10/2026) : quand la base ne répond pas, Mon compte dit
// que le service est indisponible au lieu d'une page vide.
//   * ContaRouter : des requêtes qui pendent → rien d'abord (pas de flash),
//     puis, douze secondes plus tard, le message et « Réessayer » ; une
//     requête fondatrice en erreur (522) → le message tout de suite ; des
//     réponses normales → la page, et la minuterie est annulée ;
//   * le composant : titre, texte, « Réessayer » appelle onRetry ;
//   * AccountPage : squelette borné, profil nul → message compact, limite
//     d'erreur autour du panneau des onglets (source) ;
//   * les deux clés existent dans les dix locales.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, act } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

let reponseNc, reponseMemb;
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: () => ({ select: () => ({ eq: () => ({ maybeSingle: () => reponseNc }) }) }),
    schema: () => ({ rpc: () => reponseMemb }),
  },
  SUPABASE_URL: 'https://exemple.invalid',
}));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'u-1' }, loading: false }), AuthProvider: ({ children }) => children }));
vi.mock('@/pages/account/AccountPage', () => ({ default: () => <div>page compte</div> }));
vi.mock('@/pages/account/ContributorAccountPage', () => ({ default: () => <div>page contributeur</div> }));

import ContaRouter from '@/pages/account/ContaRouter';
import ServiceIndisponible from '@/components/ServiceIndisponible';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));
const intl = (ui) => <IntlProvider locale="fr" messages={fr}>{ui}</IntlProvider>;
const jamais = () => new Promise(() => {});

afterEach(() => { cleanup(); vi.useRealTimers(); });

describe('ContaRouter quand la base ne répond pas (E33)', () => {
  it('requêtes pendantes : rien d’abord, puis le message après douze secondes', () => {
    vi.useFakeTimers();
    reponseNc = jamais(); reponseMemb = jamais();
    const { container } = render(intl(<ContaRouter />));
    expect(container.textContent).toBe('');
    act(() => { vi.advanceTimersByTime(11000); });
    expect(container.textContent).toBe('');
    act(() => { vi.advanceTimersByTime(1500); });
    expect(screen.getByRole('alert').textContent).toContain(fr['service.unavailable.title']);
    expect(screen.getByText(fr['common.retry'])).toBeTruthy();
  });

  it('une requête fondatrice en erreur (522) : le message tout de suite, pas la page', async () => {
    reponseNc = Promise.resolve({ data: null, error: { status: 522, message: 'origin unreachable' } });
    reponseMemb = Promise.resolve({ data: null, error: { status: 522, message: 'origin unreachable' } });
    render(intl(<ContaRouter />));
    expect(await screen.findByRole('alert')).toBeTruthy();
    expect(screen.queryByText('page compte')).toBeNull();
  });

  it('des réponses normales : la page se monte, et douze secondes plus tard aucun message', async () => {
    reponseNc = Promise.resolve({ data: null, error: null });
    reponseMemb = Promise.resolve({ data: [{ status: 'active', library_id: 'lib-a' }], error: null });
    render(intl(<ContaRouter />));
    expect(await screen.findByText('page compte')).toBeTruthy();
    vi.useFakeTimers();
    act(() => { vi.advanceTimersByTime(13000); });
    expect(screen.queryByRole('alert')).toBeNull();
    expect(screen.getByText('page compte')).toBeTruthy();
  });
});

describe('le composant ServiceIndisponible', () => {
  it('dit le titre et le texte, et « Réessayer » appelle onRetry', () => {
    const onRetry = vi.fn();
    render(intl(<ServiceIndisponible onRetry={onRetry} />));
    expect(screen.getByRole('heading', { level: 1 }).textContent).toBe(fr['service.unavailable.title']);
    expect(screen.getByText(fr['service.unavailable.body'])).toBeTruthy();
    fireEvent.click(screen.getByText(fr['common.retry']));
    expect(onRetry).toHaveBeenCalledTimes(1);
    cleanup();
    render(intl(<ServiceIndisponible compact onRetry={onRetry} />));
    expect(screen.getByRole('heading', { level: 2 })).toBeTruthy();
  });
});

describe('AccountPage et les locales (source)', () => {
  it('le squelette est borné, un profil nul dit l’indisponibilité, le panneau a sa limite d’erreur', () => {
    const page = lire('src/pages/account/AccountPage.jsx');
    expect(page).toContain('if (loading && attenteLongue) {');
    expect(page).toContain('setTimeout(() => setAttenteLongue(true), 12000)');
    expect(page).toContain('{!profile && <ServiceIndisponible compact onRetry={() => loadData()} />}');
    const panneau = page.slice(page.indexOf('<div className="ab-conta-panel">'));
    expect(panneau.indexOf('<ErrorBoundary>')).toBeGreaterThan(-1);
    expect(panneau.indexOf('<ErrorBoundary>')).toBeLessThan(panneau.indexOf("activeTab === 'perfil'"));
    expect(panneau.indexOf('</ErrorBoundary>')).toBeGreaterThan(panneau.indexOf('<TabEventos />'));
  });

  it('les deux clés existent dans les dix locales, sans texte vide', () => {
    const dir = path.join(RACINE, 'src/i18n/locales');
    const fichiers = readdirSync(dir).filter((f) => f.endsWith('.json'));
    expect(fichiers).toHaveLength(10);
    for (const f of fichiers) {
      const j = JSON.parse(readFileSync(path.join(dir, f), 'utf8'));
      for (const k of ['service.unavailable.title', 'service.unavailable.body', 'common.retry']) {
        expect(typeof j[k], `${f} ${k}`).toBe('string');
        // « Retry » en anglais fait cinq lettres : on refuse seulement le vide ou presque
        expect(j[k].trim().length, `${f} ${k}`).toBeGreaterThan(2);
      }
    }
  });
});
