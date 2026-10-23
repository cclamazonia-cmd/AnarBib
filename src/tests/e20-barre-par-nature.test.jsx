// =====================================================================
// E20 (demande de Xavier du 08/09/2026, livrée le 23/10) — la barre se
// regroupe par NATURE : le catalogue en lien direct, puis trois menus, Public,
// Moi, Travail, ouverts au clic ou au clavier, fermés à Échap (le focus revient
// au bouton), au clic ailleurs et à la navigation. Chaque entrée garde son
// `canSee*` : un groupe vide n'apparaît pas. Aucun chemin ne change.
// =====================================================================
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, cleanup, screen, fireEvent } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { LOCALE_CODES } from '../i18n/locales.js';

// setup.js remplace `Link` par son seul texte : ici, ce sont les chemins (href)
// qu'on vérifie, il faut le vrai routeur.
vi.mock('react-router-dom', async () => vi.importActual('react-router-dom'));

const etat = { user: null, role: null, isNetworkAdmin: false };
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: etat.user, signOut: () => {} }) }));
vi.mock('@/contexts/LibraryContext', () => ({ useLibrary: () => ({ libraryName: '', libraryId: null, role: etat.role, isNetworkAdmin: etat.isNetworkAdmin }) }));
vi.mock('@/components/notifications/NotificationBell', () => ({ default: () => null }));
vi.mock('@/components/LocaleSwitcher', () => ({ LocaleSwitcher: () => null }));
vi.mock('@/components/ui', () => ({ Button: ({ children }) => <button type="button">{children}</button> }));
vi.mock('@/lib/theme', () => ({ resolveLibraryLogo: () => null, DEFAULT_BRAND_LOGO: '/img/logo.png' }));
vi.mock('@/lib/supabase', () => ({ supabase: { from: () => ({ select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: null }) }) }) }) } }));

const { Topbar } = await import('@/components/layout');
const racine = path.resolve(__dirname, '..');
const fr = JSON.parse(readFileSync(path.join(racine, 'i18n/locales/fr.json'), 'utf8'));

afterEach(() => { cleanup(); Object.assign(etat, { user: null, role: null, isNetworkAdmin: false }); });

const monter = (chemin = '/catalogo') => render(
  <IntlProvider locale="fr" messages={fr} onError={() => {}}>
    <MemoryRouter initialEntries={[chemin]}><Topbar /></MemoryRouter>
  </IntlProvider>,
);
const groupe = (cle) => screen.queryByRole('button', { name: new RegExp(`^${fr[cle]}`) });
const liensDuMenu = (cle) => {
  const b = groupe(cle);
  return b ? [...document.getElementById(b.getAttribute('aria-controls')).querySelectorAll('a')].map((a) => a.getAttribute('href')) : null;
};

describe('qui voit quels groupes', () => {
  it('une inconnue : le catalogue et Public, ni Moi ni Travail', () => {
    monter();
    expect(screen.getByRole('link', { name: fr['nav.catalog'] }).getAttribute('href')).toBe('/');
    expect(liensDuMenu('nav.group.public')).toEqual(['/bibliotecas', '/cartografia', '/thesaurus-ficedl']);
    expect(groupe('nav.group.me')).toBeNull();
    expect(groupe('nav.group.work')).toBeNull();
  });
  it('une personne connectée sans bibliothèque : Moi (compte, Je veux…), pas Travail', () => {
    etat.user = { id: 'u' };
    monter();
    expect(liensDuMenu('nav.group.me')).toEqual(['/conta', '/inicio']);
    expect(groupe('nav.group.work')).toBeNull();
  });
  it('une lectrice rattachée : Travail ne porte que la Fédération (FED-2)', () => {
    Object.assign(etat, { user: { id: 'u' }, role: 'reader' });
    monter();
    expect(liensDuMenu('nav.group.work')).toEqual(['/federacao']);
  });
  it('une bibliothécaire : Panneau et Catalogage', () => {
    Object.assign(etat, { user: { id: 'u' }, role: 'librarian' });
    monter();
    expect(liensDuMenu('nav.group.work')).toEqual(['/painel', '/catalogacao', '/federacao']);
  });
  it('une coordination admin réseau : tout, Réseau compris', () => {
    Object.assign(etat, { user: { id: 'u' }, role: 'coordenador', isNetworkAdmin: true });
    monter();
    expect(liensDuMenu('nav.group.work')).toEqual(['/painel', '/catalogacao', '/importacoes', '/biblioteca', '/federacao', '/rede']);
  });
});

describe('ouvrir et fermer', () => {
  it('fermé au départ, ouvert au clic, fermé à Échap avec le focus rendu au bouton', () => {
    Object.assign(etat, { user: { id: 'u' }, role: 'coordenador' });
    monter();
    const b = groupe('nav.group.work');
    const menu = document.getElementById(b.getAttribute('aria-controls'));
    expect(b.getAttribute('aria-haspopup')).toBe('true');
    expect(b.getAttribute('aria-expanded')).toBe('false');
    expect(menu.hidden).toBe(true);
    fireEvent.click(b);
    expect(b.getAttribute('aria-expanded')).toBe('true');
    expect(menu.hidden).toBe(false);
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(menu.hidden).toBe(true);
    expect(document.activeElement).toBe(b);
  });
  it('un seul menu ouvert à la fois ; un clic ailleurs le ferme', () => {
    Object.assign(etat, { user: { id: 'u' }, role: 'coordenador' });
    monter();
    fireEvent.click(groupe('nav.group.public'));
    fireEvent.click(groupe('nav.group.work'));
    expect(groupe('nav.group.public').getAttribute('aria-expanded')).toBe('false');
    expect(groupe('nav.group.work').getAttribute('aria-expanded')).toBe('true');
    fireEvent.mouseDown(document.body);
    expect(groupe('nav.group.work').getAttribute('aria-expanded')).toBe('false');
  });
  it('le groupe de la page courante se dit actif ; « /biblioteca » ne s\'allume pas sur « /bibliotecas »', () => {
    Object.assign(etat, { user: { id: 'u' }, role: 'coordenador' });
    monter('/bibliotecas');
    expect(groupe('nav.group.public').className).toContain('active');
    expect(groupe('nav.group.work').className).not.toContain('active');
    cleanup();
    monter('/biblioteca');
    expect(groupe('nav.group.work').className).toContain('active');
  });
});

describe('les libellés', () => {
  it('les trois groupes existent dans toutes les langues', () => {
    for (const loc of LOCALE_CODES) {
      const l = JSON.parse(readFileSync(path.join(racine, `i18n/locales/${loc}.json`), 'utf8'));
      for (const k of ['nav.group.public', 'nav.group.me', 'nav.group.work']) expect(String(l[k] || '').trim(), `${loc} ${k}`).not.toBe('');
    }
  });
});
