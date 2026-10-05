// ═══════════════════════════════════════════════════════════
// AnarBib — un compte sans bibliothèque, et le lien d'un courriel ouvert sans
// session (05/10/2026).
//
// Le camarade coopté admin réseau n'est rattaché à aucune bibliothèque : il
// aide pour le code. Son rôle local reste null — et cinq pages (Réseau,
// Bibliothèque, Fédération, Painel, Importations) attendaient « rôle connu »
// pour s'afficher : la page Réseau, la sienne, chargeait sans fin. Elles
// attendent désormais que la résolution du contexte soit FINIE
// (`libraryResolved`), rôle ou pas — puis montrent la page ou « accès réservé ».
//
// Et un lien de courriel (/rede#tab=admins) ouvert sans session passait par la
// connexion pour finir sur /conta : ProtectedRoute ne transmettait pas la page
// demandée, et /cadastro jetait le `?next=`.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { createElement as h } from 'react';
import { render, waitFor, cleanup } from '@testing-library/react';
import { MemoryRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const etat = vi.hoisted(() => ({ auth: null, adhesions: [], admin: null }));

// setup.js remplace le contexte par un faux : ici on éprouve le VRAI.
vi.unmock('@/contexts/LibraryContext');
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => etat.auth }));
vi.mock('@/lib/theme', () => ({ useTheme: (slug) => ({ settledSlug: slug }) }));
vi.mock('@/lib/supabase', () => {
  // Les deux lectures du contexte : adhésions (…eq().eq() → await) et
  // statut d'admin réseau (…eq().eq().maybeSingle()).
  const requete = (table) => {
    const q = {
      select: () => q,
      eq: () => q,
      maybeSingle: async () => ({ data: table === 'network_administrators' ? etat.admin : null, error: null }),
      then: (ok, ko) => Promise.resolve({ data: table === 'user_library_memberships' ? etat.adhesions : [], error: null }).then(ok, ko),
    };
    return q;
  };
  return { supabase: { from: requete } };
});

import { LibraryProvider, useLibrary } from '@/contexts/LibraryContext';
import { ProtectedRoute } from '@/components/layout/ProtectedRoute';
import { CadastroVersLogin } from '@/components/layout/CadastroVersLogin';

afterEach(() => { cleanup(); sessionStorage.clear(); localStorage.clear(); });

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

describe('un admin réseau sans bibliothèque', () => {
  it('le contexte se dit résolu, sans rôle local, et admin réseau', async () => {
    etat.auth = { user: { id: 'u-camarade' }, loading: false };
    etat.adhesions = [];
    etat.admin = { user_id: 'u-camarade' };
    let vu = null;
    const Sonde = () => { vu = useLibrary(); return null; };
    render(h(LibraryProvider, null, h(Sonde)));
    await waitFor(() => expect(vu.libraryResolved).toBe(true));
    expect(vu.role).toBeNull();
    expect(vu.isNetworkAdmin).toBe(true);
  });

  it('avant la fin de la résolution, le contexte ne se dit pas résolu', () => {
    etat.auth = { user: { id: 'u-camarade' }, loading: true };
    let vu = null;
    const Sonde = () => { vu = useLibrary(); return null; };
    render(h(LibraryProvider, null, h(Sonde)));
    expect(vu.libraryResolved).toBe(false);
  });

  it('les cinq pages qui attendaient un rôle attendent aussi la fin de la résolution', () => {
    for (const p of ['src/pages/rede/RedePage.jsx', 'src/pages/biblioteca/BibliotecaPage.jsx',
      'src/pages/federacao/FederacaoPage.jsx', 'src/pages/importacoes/ImportacoesPage.jsx', 'src/pages/painel/PanelPage.jsx']) {
      const s = lire(p);
      expect(s, p).toContain('const roleLoaded = (role !== null && role !== undefined) || libraryResolved;');
      expect(s, p).toMatch(/libraryResolved \} = useLibrary\(\)/);
    }
  });
});

// Capture du camarade, 05/10 : barre du haut sans « Mon compte » — le lien
// exigeait un rôle local. Sans lui, impossible de demander son inscription.
describe('« Mon compte » pour un compte sans bibliothèque', () => {
  it('le lien est dû à toute personne connectée, rôle local ou pas', async () => {
    const { canSeeAccount } = await import('@/lib/roles');
    expect(canSeeAccount(null)).toBe(true);
    expect(canSeeAccount(undefined)).toBe(true);
    expect(lire('src/components/layout/index.jsx')).toContain('{user && canSeeAccount(role) && (');
  });
});

// Capture du camarade, 05/10 au soir : contributeur·rice du réseau sans
// bibliothèque, il arrive sur « Mon espace contributeur·rice » (ContaRouter),
// qui n'avait pas « Mes bibliothèques » — ni demande d'inscription, ni
// invitation d'équipe à accepter.
describe('l’espace contributeur·rice permet de rejoindre une bibliothèque', () => {
  it('la page monte la rubrique « Mes bibliothèques » (TabBiblios)', () => {
    const page = lire('src/pages/account/ContributorAccountPage.jsx');
    expect(page).toContain("const TabBiblios = lazy(() => import('@/pages/account/TabBiblios'));");
    expect(page).toMatch(/<TabBiblios \/>\s*<\/Suspense>/);
    // et TabBiblios porte bien la demande d'inscription et les invitations
    const tab = lire('src/pages/account/TabBiblios.jsx');
    expect(tab).toContain("rpc('request_membership'");
    expect(tab).toContain("rpc('fn_team_my_invitations')");
  });
});

describe('le lien d’un courriel ouvert sans session', () => {
  it('passe par la connexion avec la page ET l’onglet demandés', () => {
    etat.auth = { user: null, profile: null, loading: false, recovery: false };
    let vu = null;
    const Ici = () => { const l = useLocation(); vu = l.pathname + l.search; return null; };
    // Le parcours réel, ancien lien compris : ancien chemin → /rede#tab=admins →
    // ProtectedRoute → /cadastro?next=… → /login?next=…, avec les VRAIS éléments.
    render(h(MemoryRouter, { initialEntries: ['/painel/admin-rede/cooptation/8f1c'] },
      h(Routes, null,
        h(Route, { path: '/painel/admin-rede/cooptation/:id', element: h(Navigate, { to: '/rede#tab=admins', replace: true }) }),
        h(Route, { path: '/rede', element: h(ProtectedRoute, null, h('p', null, 'rede')) }),
        h(Route, { path: '/cadastro', element: h(CadastroVersLogin) }),
        h(Route, { path: '/login', element: h(Ici) }))));
    expect(vu).toBe('/login?next=%2Frede%23tab%3Dadmins');
    expect(new URLSearchParams(vu.split('?')[1]).get('next')).toBe('/rede#tab=admins');
  });

  it('/cadastro garde le hash des liens de récupération', () => {
    let vu = null;
    const Ici = () => { const l = useLocation(); vu = l.pathname + l.search + l.hash; return null; };
    render(h(MemoryRouter, { initialEntries: ['/cadastro#access_token=x&type=recovery'] },
      h(Routes, null,
        h(Route, { path: '/cadastro', element: h(CadastroVersLogin) }),
        h(Route, { path: '/login', element: h(Ici) }))));
    expect(vu).toBe('/login#access_token=x&type=recovery');
  });

  // Constaté en ligne le 05/10 : un élément de <Route> est construit quand App
  // se monte ; s'il lit window.location, il voit l'URL du PREMIER chargement.
  it('App.jsx déclare /cadastro par le composant, sans lire window.location', () => {
    const app = lire('src/App.jsx');
    expect(app).toContain('<Route path="/cadastro" element={<CadastroVersLogin />} />');
    expect(app).not.toMatch(/<Route[^>]*element=\{[^}]*window\.location/);
  });
});
