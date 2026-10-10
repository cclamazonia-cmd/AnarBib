// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — C29 lot 1 (10/10/2026) : les exemplaires d'une notice, dans la notice.
//
// CE QUE CE TEST PROTÈGE.
//   1. grouperParBibliotheque : mes bibliothèques d'abord et modifiables, les
//      autres en lecture seule ; un brouillon qui reprend un exemplaire publié
//      se greffe sur sa ligne (pas une seconde ligne) ; tri naturel des tombos.
//   2. ExemplaresPanel rendu : les groupes, « Modifier » dans ma bibliothèque
//      seulement, « Reprendre la mise à jour » quand un brouillon existe déjà
//      (create_exemplar_draft_from_exemplar n'est pas idempotent), et les trois
//      rappels remontent au parent avec le bon identifiant.
//   3. Contrat de montage lu dans la SOURCE : le panneau est monté dans la
//      fiche après les ressources numériques, avec les rappels de la page ;
//      la cible d'un nouvel exemplaire porte un nonce (une chaîne égale ne
//      relançait pas l'effet quand on redemandait un exemplaire de la même fiche).
//   4. Les clés du panneau existent dans les 10 locales (la garde racine le
//      vérifie aussi ; ici on nomme le lot).
// ═══════════════════════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, cleanup, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

// Jeu de données : la notice 7 (BLMF 0000012), deux fonds, trois exemplaires
// publiés (deux chez moi, L1 ; un à la BTL, L2), un brouillon qui reprend
// l'exemplaire 101 et un brouillon neuf sans exemplaire publié.
const DATA = {
  libraries: [{ id: 'L1', name: 'Biblioteca Lucy Parsons', short_name: 'BLMF' }, { id: 'L2', name: 'Biblioteca Terra Livre', short_name: 'BTL' }],
  books: [{ bib_ref: 'BLMF 0000012' }],
  book_holdings: [{ id: 1 }, { id: 2 }],
  exemplares: [
    { id: 102, library_id: 'L1', holding_id: 1, bib_ref: 'BLMF 0000012', tombo: 'BLMF-000010', shelf_location: 'Sala A · Est. 2', circulation_policy: 'ambos', visibility: 'public' },
    { id: 101, library_id: 'L1', holding_id: 1, bib_ref: 'BLMF 0000012', tombo: 'BLMF-000002', shelf_location: '', circulation_policy: 'consulta', visibility: 'staff_only' },
    { id: 201, library_id: 'L2', holding_id: 2, bib_ref: 'BLMF 0000012', tombo: 'BTL-000500', shelf_location: '', circulation_policy: 'emprestavel', visibility: 'public' },
  ],
  exemplar_drafts: [
    { id: 9001, target_library_id: 'L1', tombo: 'BLMF-000002', shelf_location: 'Sala B', status: 'draft', published_exemplar_id: 101, circulation_policy: 'consulta', visibility: 'public' },
    { id: 9002, target_library_id: 'L1', tombo: '', shelf_location: '', status: 'ready', published_exemplar_id: null, circulation_policy: '', visibility: 'public' },
  ],
};

function requete(table) {
  const q = {
    select: () => q, eq: () => q, in: () => q, order: () => q, not: () => q, limit: () => q,
    maybeSingle: () => Promise.resolve({ data: (DATA[table] || [])[0] || null, error: null }),
    then: (res, rej) => Promise.resolve({ data: DATA[table] || [], error: null }).then(res, rej),
  };
  return q;
}
vi.mock('@/lib/supabase', () => ({ supabase: { from: (table) => requete(table) } }));
vi.mock('@/contexts/LibraryContext', () => ({ useLibrary: () => ({ isNetworkAdmin: false }) }));
vi.mock('@/lib/useStaffLibraries', () => ({ useStaffLibraries: () => ({ staffLibraryIds: ['L1'], loaded: true }) }));

const { default: ExemplaresPanel, grouperParBibliotheque } = await import('@/pages/catalogacao/ExemplaresPanel');

afterEach(cleanup);

const rendre = (ui) => render(<IntlProvider locale="fr" messages={fr}>{ui}</IntlProvider>);

describe('grouperParBibliotheque', () => {
  const ctx = { staffLibraryIds: ['L1'], isNetworkAdmin: false, libraries: DATA.libraries };

  it('mes bibliothèques d’abord, modifiables ; les autres en lecture seule ; tombos en ordre naturel', () => {
    const g = grouperParBibliotheque(DATA.exemplares, [], ctx);
    expect(g.map((x) => [x.nom, x.editable])).toEqual([['BLMF', true], ['BTL', false]]);
    expect(g[0].lignes.map((l) => l.tombo)).toEqual(['BLMF-000002', 'BLMF-000010']);
  });

  it('un brouillon qui reprend un exemplaire publié se greffe sur sa ligne ; un brouillon neuf fait la sienne', () => {
    const g = grouperParBibliotheque(DATA.exemplares, DATA.exemplar_drafts, ctx);
    const blmf = g[0];
    expect(blmf.lignes).toHaveLength(3);
    const reprise = blmf.lignes.find((l) => l.id === 101);
    expect(reprise.kind).toBe('published');
    expect(reprise.retake?.id).toBe(9001);
    const neuf = blmf.lignes.find((l) => l.kind === 'draft');
    expect(neuf.id).toBe(9002);
    expect(neuf.status).toBe('ready');
  });

  it('l’administration du réseau peut tout modifier ; une bibliothèque inconnue garde un groupe sans nom', () => {
    const g = grouperParBibliotheque(DATA.exemplares, [{ id: 1, target_library_id: 'L9', status: 'draft' }], { ...ctx, isNetworkAdmin: true });
    expect(g.every((x) => x.editable)).toBe(true);
    expect(g.find((x) => x.library_id === 'L9').nom).toBeNull();
  });
});

describe('ExemplaresPanel — rendu', () => {
  it('liste par bibliothèque, « Modifier » chez moi seulement, « Reprendre la mise à jour » quand un brouillon existe déjà', async () => {
    const onNewCopy = vi.fn(); const onEditPublished = vi.fn(); const onEditDraft = vi.fn();
    const { container, getByText, getAllByText } = rendre(
      <ExemplaresPanel publishedBookId={7} draftId={42} reloadKey={0} onNewCopy={onNewCopy} onEditPublished={onEditPublished} onEditDraft={onEditDraft} />,
    );
    await waitFor(() => expect(container.querySelectorAll('[data-testid="copies-row"]').length).toBe(4));
    const groupes = [...container.querySelectorAll('[data-testid="copies-group"]')];
    expect(groupes.map((g) => g.getAttribute('data-library'))).toEqual(['L1', 'L2']);
    expect(groupes.map((g) => g.getAttribute('data-editable'))).toEqual(['1', '0']);
    expect(groupes[1].textContent).toContain(fr['catalogacao.copies.otherLibrary']);
    expect(groupes[1].querySelectorAll('button')).toHaveLength(0);
    // Chez moi : 3 lignes, 3 boutons — un « Reprendre », deux « Modifier ».
    expect(groupes[0].querySelectorAll('button')).toHaveLength(3);
    expect(getAllByText(fr['common.edit'])).toHaveLength(2);
    fireEvent.click(getByText(fr['catalogacao.copies.resumeUpdate']));
    expect(onEditDraft).toHaveBeenCalledWith(9001);
    expect(container.querySelector('[data-kind="published"][data-retake="1"]').textContent).toContain(fr['catalogacao.copies.updatePending']);
    fireEvent.click(getByText(fr['catalogacao.copies.new']));
    expect(onNewCopy).toHaveBeenCalledWith(7);
    // Le brouillon neuf s'ouvre par son identifiant de brouillon ; l'exemplaire
    // publié sans brouillon passe par la reprise du parent.
    const ligneBrouillon = container.querySelector('[data-kind="draft"]');
    fireEvent.click(ligneBrouillon.querySelector('button'));
    expect(onEditDraft).toHaveBeenLastCalledWith(9002);
    const lignePubliee = container.querySelector('[data-kind="published"][data-retake="0"]');
    fireEvent.click(lignePubliee.querySelector('button'));
    expect(onEditPublished).toHaveBeenCalledWith(102);
    expect(lignePubliee.textContent).toContain(fr['catalogacao.exemplar.circulationPolicy.ambos']);
  });

  it('fiche non publiée : la note, pas de bouton « Nouvel exemplaire »', async () => {
    const { container, queryByText } = rendre(<ExemplaresPanel publishedBookId={null} draftId={null} onNewCopy={vi.fn()} />);
    await waitFor(() => expect(container.querySelector('[data-testid="copies-unpublished"]')).toBeTruthy());
    await new Promise((r) => setTimeout(r, 0)); // la liste des bibliothèques se pose après le rendu
    expect(queryByText(fr['catalogacao.copies.new'])).toBeNull();
  });
});

describe('contrat de montage (source)', () => {
  const form = lire('src/pages/catalogacao/BookDraftForm.jsx');
  const page = lire('src/pages/catalogacao/CatalogacaoPage.jsx');
  const editeur = lire('src/pages/catalogacao/ExemplarDraftForm.jsx');

  it('le panneau est monté dans la fiche, après les ressources numériques, avec les trois rappels', () => {
    expect(form).toContain("import ExemplaresPanel from './ExemplaresPanel';");
    const digital = form.indexOf('<DigitalResourcesPanel');
    const copies = form.indexOf('<ExemplaresPanel');
    expect(digital).toBeGreaterThan(-1);
    expect(copies).toBeGreaterThan(digital);
    const props = form.slice(copies, form.indexOf('/>', copies));
    expect(props).toMatch(/publishedBookId=\{form\.published_book_id\} draftId=\{f\('id'\)\} reloadKey=\{importedCheck\}/);
    expect(props).toMatch(/onNewCopy=\{onAttachToBook\} onEditPublished=\{onEditExemplar\} onEditDraft=\{onEditExemplarDraft\}/);
    expect(form).toMatch(/onEditExemplar, onEditExemplarDraft, prefillRecord/);
  });

  it('la page ouvre un brouillon d’exemplaire et cible un nouvel exemplaire avec un nonce', () => {
    expect(page).toContain("onEditExemplarDraft={(id) => openForEdit('exemplar', id)}");
    expect(page).toContain('setAttachTarget({ bibRef: String(data.bib_ref), nonce: Date.now() })');
    expect(page).toContain('prefill={attachTarget}');
    expect(page).not.toContain('prefillBibRef');
    expect(editeur).toMatch(/\}, \[prefill\?\.bibRef, prefill\?\.nonce\]\);/);
    expect(editeur).not.toContain('prefillBibRef');
  });
});

describe('les clés du panneau existent dans les 10 locales', () => {
  const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
  const CLES = ['title', 'count', 'new', 'unpublished', 'empty', 'otherLibrary', 'resumeUpdate', 'updatePending', 'loadError', 'libraryUnknown']
    .map((k) => `catalogacao.copies.${k}`);
  for (const loc of LOCALES) {
    it(loc, () => {
      const dico = JSON.parse(lire(`src/i18n/locales/${loc}.json`));
      for (const k of CLES) expect(typeof dico[k], k).toBe('string');
    });
  }
});
