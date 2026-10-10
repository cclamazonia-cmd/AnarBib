// CHEMIN DÉPÔT : src/tests/catalog-lots-3-4.test.jsx
//
// E6, Catalogue public, lots 3 et 4 (10/10/2026) : la barre de filtres
// (CatalogFiltersBar) et la table des résultats avec ses rendus de lignes
// (CatalogResultsTable, AuthorLinks) sont sorties de CatalogPage.jsx telles
// quelles, lignes déplacées par ancres. La page garde tout l'état et le passe
// en un sac de props. Ces tests montent les deux composants hors de la page,
// avec un état minimal, et un test de source tient la page à ses imports.
//
// L'IntlProvider est monté sans messages : formatMessage rend l'identifiant,
// ce qui suffit à vérifier QUELLE clé est affichée. Le fichier d'amorçage
// (src/tests/setup.js) remplace Link par ses enfants : les liens se lisent
// par leur texte, pas par leur href.

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/lib/supabase', () => ({ supabase: {}, apiRpc: vi.fn(), apiQuery: vi.fn(), SUPABASE_URL: 'http://localhost' }));

import CatalogFiltersBar from '@/components/catalog/CatalogFiltersBar';
import CatalogResultsTable from '@/components/catalog/CatalogResultsTable';
import AuthorLinks from '@/components/catalog/AuthorLinks';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const monter = (ui) => render(
  <IntlProvider locale="fr" messages={{}} onError={() => {}}>
    <MemoryRouter>{ui}</MemoryRouter>
  </IntlProvider>,
);

afterEach(() => { cleanup(); vi.restoreAllMocks(); });

// ── la barre de filtres : un sac de props complet, écrasable ──────────────
function propsBarre(sur = {}) {
  const fn = () => vi.fn();
  return {
    LANGUAGE_OPTIONS: [{ value: 'pt', label: 'Português' }],
    SORT_OPTIONS: [{ value: 'titulo.asc', label: 'Titre' }],
    advancedOpen: false, alphaFilter: '', authorFilter: '', availabilityFilter: '__all__',
    availabilityOptions: [{ value: '__all__', label: 'Tout' }, { value: 'available', label: 'Dispo' }],
    catalogNetworks: [], cddFilter: '', clearFilters: fn(), collapseEditions: false, collectionFilter: '', compact: false,
    copySearchLink: fn(), dAuthor: '', dCdd: '', dCollection: '', dIsbn: '', dLanguage: '', dPlace: '', dPublisher: '', dSearch: '', dSubjects: '', dYear: '',
    emailSearchLink: fn(), filtersActiveCount: 0, filtersOpen: true, hasActiveFilters: false, horsReseau: [], isbnFilter: '', languageFilter: '',
    libMenuOpen: false, libMenuRef: { current: null }, libraryFilter: [],
    libraryOptions: [{ value: '__all__', label: 'Toutes' }, { value: 'btl', label: 'BTL', short_name: 'BTL' }],
    libsDesReseaux: new Set(), materialFilter: '__all__', netMenuOpen: false, netMenuRef: { current: null }, pickSubject: fn(), placeFilter: '', publisherFilter: '',
    relatedSubjects: [], reseauxActifs: [], search: '',
    setAdvancedOpen: fn(), setAlphaFilter: fn(), setAuthorFilter: fn(), setAuthorIdFilter: fn(), setAvailabilityFilter: fn(), setCddFilter: fn(), setCollapseEditions: fn(),
    setCollectionFilter: fn(), setCompact: fn(), setFiltersOpen: fn(), setIsbnFilter: fn(), setLanguageFilter: fn(), setLibMenuOpen: fn(), setLibraryFilter: fn(),
    setMaterialFilter: fn(), setNetMenuOpen: fn(), setNetworkFilter: fn(), setPlaceFilter: fn(), setPublisherFilter: fn(), setSearch: fn(), setSortValue: fn(),
    setSubjectFilter: fn(), setSubjectsFilter: fn(), setYearFilter: fn(),
    sortValue: 'titulo.asc', subjectFilter: '', subjectLabel: '', subjectsFilter: '', yearFilter: '',
    ...sur,
  };
}

describe('CatalogFiltersBar — la barre de filtres hors de la page (lot 3)', () => {
  it('ouverte : l’en-tête dit « Filtres », le corps est là, et le clic replie par le geste de la page', () => {
    const p = propsBarre();
    const { container } = monter(<CatalogFiltersBar {...p} />);
    const entete = screen.getByRole('button', { name: /catalog\.section\.filters/ });
    expect(entete.getAttribute('aria-expanded')).toBe('true');
    expect(container.querySelector('section.ab-toolbar').className).not.toContain('ab-toolbar--replie');
    expect(container.querySelectorAll('select').length).toBeGreaterThan(0);
    fireEvent.click(entete);
    expect(p.setFiltersOpen).toHaveBeenCalledTimes(1);
    expect(p.setFiltersOpen.mock.calls[0][0](true)).toBe(false); // bascule fonctionnelle
  });

  it('repliée : la classe de repli, le compte des filtres cachés et son texte pour lecteurs d’écran, rien d’autre', () => {
    const { container } = monter(<CatalogFiltersBar {...propsBarre({ filtersOpen: false, filtersActiveCount: 2 })} />);
    expect(container.querySelector('section.ab-toolbar').className).toContain('ab-toolbar--replie');
    expect(screen.getByRole('button', { name: /catalog\.section\.filters/ }).getAttribute('aria-expanded')).toBe('false');
    expect(container.querySelector('.ab-collapse-badge [aria-hidden="true"]').textContent).toBe('2');
    expect(container.querySelector('.ab-collapse-badge .ab-sr-only').textContent).toBe('catalog.section.exploreActive');
    // le corps (sélecteurs, champs) n'est pas rendu ; la rangée d'actions reste, le CSS la cache sous 640 px (E17)
    expect(container.querySelectorAll('select')).toHaveLength(0);
    expect(container.querySelector('.ab-toolbar-meta')).toBeTruthy();
    expect(screen.queryByText(/catalog\.chip\./)).toBeNull();
  });

  it('les puces des filtres actifs : recherche, bibliothèque et réseau, puis « effacer »', () => {
    const p = propsBarre({
      dSearch: 'anarquia', search: 'anarquia', libraryFilter: ['btl'], reseauxActifs: ['rebal'],
      catalogNetworks: [{ slug: 'rebal', label: 'REBAL' }], hasActiveFilters: true, filtersActiveCount: 3,
    });
    monter(<CatalogFiltersBar {...p} />);
    expect(screen.getByText(/catalog\.chip\.search/).textContent).toContain('anarquia');
    expect(screen.getByText(/catalog\.chip\.library/).textContent).toContain('BTL');
    expect(screen.getByText(/catalog\.chip\.network/).textContent).toContain('REBAL');
    fireEvent.click(screen.getByRole('button', { name: /catalog\.filters\.clearButton/ }));
    expect(p.clearFilters).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByText('catalog.actions.copyLink'));
    expect(p.copySearchLink).toHaveBeenCalledTimes(1);
  });

  it('le tri et l’affichage compact appellent les gestes de la page', () => {
    const p = propsBarre();
    const { container } = monter(<CatalogFiltersBar {...p} />);
    const tri = Array.from(container.querySelectorAll('select')).find((s) => s.value === 'titulo.asc');
    expect(tri).toBeTruthy();
    fireEvent.change(tri, { target: { value: 'titulo.asc' } });
    expect(p.setSortValue).toHaveBeenCalled();
    fireEvent.click(screen.getByText('catalog.collapseEditions'));
    expect(p.setCollapseEditions).toHaveBeenCalledTimes(1);
  });
});

// ── la table des résultats ─────────────────────────────────────────────────
const LIVRE = {
  book_id: 1, bib_ref: 'R1', titulo: 'Titre un', autor: 'Auteur Un', ano: 2020, editora: 'Ed.', tipo_material: 'livro',
  holding_library_names_json: ['BTL'], author_chips: [{ author_id: 7, label: 'Auteur Un' }],
};
const LIVRE2 = { ...LIVRE, book_id: 2, bib_ref: 'R2', ano: 2021 };
function propsTable(sur = {}) {
  const fn = () => vi.fn();
  return {
    STATUS_RANK: { ok: 0, warn: 1, muted: 2, bad: 3 }, accesNumerique: new Map(), books: [LIVRE], cityByLib: {}, compact: false,
    consultaState: {}, consultedBibRefs: new Set(), copiesByBook: {}, expandedCopies: new Set(), expandedWorks: new Set(),
    fetchBooks: fn(), handleHeaderSort: fn(), handleQuickConsulta: fn(), handleQuickReserve: fn(), handleWishlist: fn(),
    hasMore: false, isAuth: false, libPriority: [], loading: false, loadingMore: false,
    quickConsultaAvailable: false, quickReserveAvailable: false, reserveState: {}, reservedBibRefs: new Set(),
    scrollTable: fn(), si: () => '', tableRef: { current: null }, tableRows: [{ type: 'edition', book: LIVRE, depth: 1 }],
    toggleCopies: fn(), toggleWork: fn(), totalCount: 1, totalFetched: 1, wishlistBusy: null, wishlistedIds: new Set(),
    ...sur,
  };
}

describe('CatalogResultsTable — la table hors de la page (lot 4)', () => {
  it('en chargement : un statut annoncé, pas de table ; sans résultat : l’état vide', () => {
    const { rerender } = monter(<CatalogResultsTable {...propsTable({ loading: true })} />);
    expect(screen.getByRole('status').textContent).toContain('catalog.loading.message');
    expect(document.querySelector('table')).toBeNull();
    rerender(
      <IntlProvider locale="fr" messages={{}} onError={() => {}}><MemoryRouter>
        <CatalogResultsTable {...propsTable({ books: [], tableRows: [] })} />
      </MemoryRouter></IntlProvider>,
    );
    expect(screen.getByText('catalog.results.empty')).toBeTruthy();
  });

  it('une notice : sa cote, son auteur et son titre sont là, l’en-tête trie, le « + » déplie les exemplaires', () => {
    const p = propsTable();
    const { container } = monter(<CatalogResultsTable {...p} />);
    expect(container.querySelector('.ab-cat-ref-stack').textContent).toContain('R1');
    expect(screen.getByText('Auteur Un')).toBeTruthy();
    expect(screen.getByText('Titre un')).toBeTruthy();
    expect(container.querySelector('tr[data-depth="1"]')).toBeTruthy();
    fireEvent.click(screen.getByText('catalog.table.author'));
    expect(p.handleHeaderSort).toHaveBeenCalledWith('autor');
    fireEvent.click(screen.getByRole('button', { name: 'catalog.works.showCopies' }));
    expect(p.toggleCopies).toHaveBeenCalledWith(1);
    // visiteur : pas de colonne d'actions, disponibilité « à vérifier »
    expect(screen.queryByText('catalog.table.actions')).toBeNull();
    expect(screen.getByText('catalog.avail.check')).toBeTruthy();
  });

  it('les exemplaires dépliés : chaque bibliothèque, son compte, et « à vérifier » pour un visiteur', () => {
    const p = propsTable({
      expandedCopies: new Set([1]),
      tableRows: [{ type: 'edition', book: LIVRE, depth: 1 }, { type: 'copies', book: LIVRE, depth: 2 }],
      copiesByBook: { 1: { loading: false, libraries: [{ library_slug: 'btl', library_name: 'BTL', city: 'Belém', exemplares_total: 2, available_count: 1 }] } },
    });
    monter(<CatalogResultsTable {...p} />);
    const region = screen.getByRole('region', { name: 'catalog.works.showCopies' });
    expect(region.textContent).toContain('BTL (Belém)');
    expect(region.textContent).toContain('catalog.works.copiesCount');
    expect(region.querySelector('.ab-status-dot--muted').textContent).toBe('catalog.avail.check');
    expect(screen.getByRole('button', { name: 'catalog.works.hideCopies' })).toBeTruthy();
  });

  it('une œuvre à deux éditions : une seule ligne, le bouton déplie par le geste de la page, les années en fourchette', () => {
    const w = { key: 'k1', work_id: 5, rep_book_id: 1, editions: [LIVRE, LIVRE2], library_names: ['BTL'], year_min: 2020, year_max: 2021 };
    const p = propsTable({ books: [LIVRE, LIVRE2], tableRows: [{ type: 'work', w }] });
    monter(<CatalogResultsTable {...p} />);
    expect(document.querySelectorAll('tbody tr')).toHaveLength(1);
    expect(document.querySelector('tr.ab-row--work')).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'catalog.works.expand' }));
    expect(p.toggleWork).toHaveBeenCalledWith('k1');
    expect(document.querySelector('tr.ab-row--work .ab-cat-title__text').textContent).toContain('Titre un');
    expect(document.querySelector('tr.ab-row--work').textContent).toMatch(/2020.*2021/);
  });

  it('« charger la suite » n’apparaît que s’il reste des notices, et appelle fetchBooks depuis le compte chargé', () => {
    const p = propsTable({ hasMore: true, totalFetched: 50, totalCount: 120 });
    monter(<CatalogResultsTable {...p} />);
    fireEvent.click(screen.getByText('catalog.actions.loadMore'));
    expect(p.fetchBooks).toHaveBeenCalledWith(50, true);
    cleanup();
    monter(<CatalogResultsTable {...propsTable({ hasMore: false })} />);
    expect(screen.queryByText('catalog.actions.loadMore')).toBeNull();
  });

  it('AuthorLinks seul : les puces séparées par « ; », aussi quand elles arrivent en JSON texte', () => {
    const { container, rerender } = monter(<AuthorLinks book={{ author_chips: [{ author_id: 7, label: 'Une' }, { author_id: null, label: 'Deux' }] }} />);
    expect(container.textContent).toBe('Une ; Deux');
    rerender(
      <IntlProvider locale="fr" messages={{}} onError={() => {}}><MemoryRouter>
        <AuthorLinks book={{ author_chips: JSON.stringify([{ author_id: 1, label: 'Trois' }]) }} />
      </MemoryRouter></IntlProvider>,
    );
    expect(container.textContent).toBe('Trois');
  });
});

describe('la page ne porte plus que son état (source)', () => {
  it('CatalogPage importe la barre et la table, ne définit plus leurs rendus, et tient sous 65 Ko', () => {
    const page = lire('src/pages/public/CatalogPage.jsx');
    expect(page).toContain("import CatalogFiltersBar from '@/components/catalog/CatalogFiltersBar'");
    expect(page).toContain("import CatalogResultsTable from '@/components/catalog/CatalogResultsTable'");
    expect(page).toContain('<CatalogFiltersBar {...{');
    expect(page).toContain('<CatalogResultsTable {...{');
    for (const def of ['function badgeNumerique(', 'function renderWorkRow(', 'function renderCopiesRow(', 'function copyStatus(', 'function copiesExpander(',
      'function AuthorLinks(', 'ab-toolbar--replie', '{/* ══ TABLE', 'ab-sheet__head', 'ab-collapse-header" onClick={() => setFiltersOpen']) {
      expect(page, def).not.toContain(def);
    }
    // l'état et les gestes restent dans la page : c'est elle qui sait
    for (const garde of ['const [filtersOpen, setFiltersOpen]', 'const filtersActiveCount = [', 'const tableRows = [];', 'useDigitalAccess(idsAffiches', 'function si(col)']) {
      expect(page, garde).toContain(garde);
    }
    expect(Buffer.byteLength(page, 'utf8')).toBeLessThan(65 * 1024);
    const barre = lire('src/components/catalog/CatalogFiltersBar.jsx');
    const table = lire('src/components/catalog/CatalogResultsTable.jsx');
    // les composants ne portent aucun état de filtre ni d'appel réseau : ils reçoivent et rendent
    for (const src of [barre, table]) {
      expect(src).not.toMatch(/useState\(|useEffect\(|supabase|apiRpc|apiQuery/);
      expect(src).toContain('} = p;');
    }
    expect(barre).toContain("className={`ab-toolbar${filtersOpen ? '' : ' ab-toolbar--replie'}`}");
    expect(table).toContain('function renderWorkRow(');
    expect(table).toContain("import AuthorLinks from '@/components/catalog/AuthorLinks'");
  });
});
