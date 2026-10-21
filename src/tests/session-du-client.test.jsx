// ═══════════════════════════════════════════════════════════
// AnarBib — 21/10/2026 : la session affichée est celle que le client enverra.
//
// Constat (edge_logs du 21/10, 20:12 UTC) : un tableau de bord /painel
// envoyait ses requêtes SANS jeton pendant que l'onglet voisin, lui, portait
// le JWT du même compte. supabase-js relaie aux abonné·es les événements
// d'auth des AUTRES onglets (BroadcastChannel), avec la session de l'onglet
// émetteur ; or la session d'équipe vit en sessionStorage, propre à chaque
// onglet. AuthContext prenait cette session pour la sienne : l'interface se
// croyait connectée, le client n'avait rien à envoyer.
//
// Ici le vrai AuthProvider, devant un faux client dont on tient le stockage
// et à qui l'on fait « recevoir » des événements d'un autre onglet.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { render, screen, cleanup, act, waitFor, fireEvent } from '@testing-library/react';

const client = vi.hoisted(() => ({ stocke: null, abonnes: [] }));

vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://projet-de-test.supabase.co',
  supabase: {
    auth: {
      // getSession lit le stockage de CET onglet, comme supabase-js.
      getSession: vi.fn(async () => ({ data: { session: client.stocke } })),
      onAuthStateChange: vi.fn((cb) => {
        client.abonnes.push(cb);
        return { data: { subscription: { unsubscribe: () => {} } } };
      }),
      signOut: vi.fn(async () => {
        client.stocke = null;
        client.abonnes.forEach((cb) => cb('SIGNED_OUT', null));
      }),
    },
    from: () => ({ select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: null, error: null }) }) }) }),
  },
  apiRpc: vi.fn(async () => ({ data: null, error: null })),
}));
vi.mock('@/i18n', () => ({ syncLocaleFromProfile: vi.fn() }));
vi.mock('@/lib/clearAuthHash', () => ({ clearAuthHash: vi.fn() }));

const { AuthProvider, useAuth } = await vi.importActual('@/contexts/AuthContext');

const session = (id) => ({ access_token: `jeton-${id}`, user: { id } });

function Sonde() {
  const { user, loading, lostSession, recovery, signOut } = useAuth();
  if (loading) return <p>chargement</p>;
  return (
    <div>
      <p data-testid="compte">{user?.id ?? 'anon'}</p>
      <p data-testid="perdue">{lostSession ? 'perdue' : 'non'}</p>
      <p data-testid="recup">{recovery ? 'recup' : 'non'}</p>
      <button type="button" onClick={signOut}>sortir</button>
    </div>
  );
}

async function monter() {
  render(<AuthProvider><Sonde /></AuthProvider>);
  await screen.findByTestId('compte');
}

// Un événement d'auth, tel que l'onglet le reçoit (émis ici ou relayé).
async function evenement(nom, s) {
  await act(async () => {
    client.abonnes.forEach((cb) => cb(nom, s));
    await new Promise((r) => setTimeout(r, 5));
  });
}

beforeEach(() => {
  client.stocke = null;
  client.abonnes = [];
  localStorage.clear();
});
afterEach(() => cleanup());

describe('AuthContext — un événement d’un autre onglet ne change pas de compte', () => {
  it('SIGNED_IN / code de double authentification relayés, stockage vide : l’onglet reste anonyme', async () => {
    await monter();
    await evenement('SIGNED_IN', session('coordination'));
    await evenement('MFA_CHALLENGE_VERIFIED', session('coordination'));
    expect(screen.getByTestId('compte').textContent).toBe('anon');
    expect(screen.getByTestId('perdue').textContent).toBe('non');
  });

  it('la session propre à l’onglet survit au SIGNED_OUT d’un autre onglet', async () => {
    client.stocke = session('coordination');
    await monter();
    expect(screen.getByTestId('compte').textContent).toBe('coordination');
    await evenement('SIGNED_OUT', null); // client.stocke inchangé : c'est l'autre onglet qui sort
    expect(screen.getByTestId('compte').textContent).toBe('coordination');
  });

  it('un compte de test connecté ailleurs ne remplace pas la session de l’onglet', async () => {
    client.stocke = session('coordination');
    await monter();
    await evenement('SIGNED_IN', session('compte-de-test'));
    expect(screen.getByTestId('compte').textContent).toBe('coordination');
  });

  it('un événement de CET onglet est suivi', async () => {
    await monter();
    client.stocke = session('lectrice');
    await evenement('SIGNED_IN', session('lectrice'));
    expect(screen.getByTestId('compte').textContent).toBe('lectrice');
  });
});

describe('AuthContext — session perdue, déconnexion voulue', () => {
  it('stockage vidé depuis un autre onglet : l’onglet le sait et la dit perdue', async () => {
    client.stocke = session('coordination');
    await monter();
    client.stocke = null;
    await act(async () => {
      window.dispatchEvent(new StorageEvent('storage', { key: 'sb-projet-auth-token' }));
      await new Promise((r) => setTimeout(r, 5));
    });
    expect(screen.getByTestId('compte').textContent).toBe('anon');
    expect(screen.getByTestId('perdue').textContent).toBe('perdue');
  });

  it('une clé qui n’est pas une session ne déclenche rien', async () => {
    client.stocke = session('coordination');
    await monter();
    client.stocke = null;
    await act(async () => {
      window.dispatchEvent(new StorageEvent('storage', { key: 'anarbib:locale' }));
      await new Promise((r) => setTimeout(r, 5));
    });
    expect(screen.getByTestId('compte').textContent).toBe('coordination');
  });

  it('déconnexion demandée ici : anonyme, mais pas « perdue »', async () => {
    client.stocke = session('coordination');
    await monter();
    await act(async () => {
      fireEvent.click(screen.getByText('sortir'));
      await new Promise((r) => setTimeout(r, 5));
    });
    expect(screen.getByTestId('compte').textContent).toBe('anon');
    expect(screen.getByTestId('perdue').textContent).toBe('non');
  });

  it('SIGNED_OUT de CET onglet (jeton révoqué) : anonyme, pas d’avis de plus', async () => {
    client.stocke = session('coordination');
    await monter();
    client.stocke = null;
    await evenement('SIGNED_OUT', null);
    expect(screen.getByTestId('compte').textContent).toBe('anon');
    expect(screen.getByTestId('perdue').textContent).toBe('non');
  });

  it('une reconnexion efface l’état « perdue »', async () => {
    client.stocke = session('coordination');
    await monter();
    client.stocke = null;
    await act(async () => {
      window.dispatchEvent(new StorageEvent('storage', { key: 'sb-projet-auth-token' }));
      await new Promise((r) => setTimeout(r, 5));
    });
    client.stocke = session('coordination');
    await evenement('SIGNED_IN', session('coordination'));
    await waitFor(() => expect(screen.getByTestId('perdue').textContent).toBe('non'));
    expect(screen.getByTestId('compte').textContent).toBe('coordination');
  });
});

describe('AuthContext — lien de récupération du mot de passe', () => {
  it('session de récup de CET onglet : mode récup posé avec la session', async () => {
    await monter();
    client.stocke = session('compte-de-test');
    await evenement('PASSWORD_RECOVERY', session('compte-de-test'));
    expect(screen.getByTestId('recup').textContent).toBe('recup');
    expect(screen.getByTestId('compte').textContent).toBe('compte-de-test');
  });

  it('récup relayée d’un autre onglet : ni compte ni mode récup ici', async () => {
    client.stocke = session('coordination');
    await monter();
    await evenement('PASSWORD_RECOVERY', session('compte-de-test'));
    expect(screen.getByTestId('recup').textContent).toBe('non');
    expect(screen.getByTestId('compte').textContent).toBe('coordination');
  });
});
