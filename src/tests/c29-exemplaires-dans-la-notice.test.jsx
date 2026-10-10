// ═══════════════════════════════════════════════════════════════════════════
// AnarBib — C29 lots 1 à 3 (10/10/2026) : les exemplaires d'une notice, dans la notice.
//
// CE QUE CE TEST PROTÈGE.
//   1. grouperParBibliotheque : mes bibliothèques d'abord et modifiables, les
//      autres en lecture seule ; un brouillon qui reprend un exemplaire publié
//      se greffe sur sa ligne (pas une seconde ligne) ; tri naturel des tombos.
//   2. ExemplaresPanel rendu : les groupes, « Modifier » dans ma bibliothèque
//      seulement, « Reprendre la mise à jour » quand un brouillon existe déjà
//      (create_exemplar_draft_from_exemplar n'est pas idempotent), et les
//      rappels remontent au parent avec le bon identifiant.
//   3. Lot 2, le formulaire court : une seule bibliothèque → choisie d'avance et
//      le temps « Où ? » ne se montre pas ; le numéro vient de fn_next_tombo ;
//      la circulation est héritée de la fiche ; « Enregistrer et publier » pose
//      le brouillon (cible explicite, cote au format shelfLocation, étiquette
//      déduite) PUIS appelle publish_exemplar_draft ; « Garder en brouillon »
//      s'arrête avant ; une publication refusée garde le brouillon et le dit ;
//      staff de deux bibliothèques → le choix d'abord, le reste après.
//   4. Lot 3, modifier sans voir le brouillon : « Modifier » ouvre les temps 2 à 4
//      pré-remplis, le numéro ne change pas, la bibliothèque renvoie à l'éditeur
//      complet ; « Enregistrer les changements » appelle
//      fn_exemplaire_modifier_et_publier avec les douze champs permis (la cote
//      réécrite garde ce que le format ne reconnaît pas) ; un refus se dit par
//      son HINT traduit.
//   5. Contrat lu dans la SOURCE : montage dans la fiche après les ressources
//      numériques ; la cible d'un nouvel exemplaire porte un nonce ; la migration
//      du lot 3 existe, ferme anon, et sa suite est au manifeste.
//   6. Les clés du panneau existent dans les 10 locales.
// ═══════════════════════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach, beforeEach } from 'vitest';
import { render, cleanup, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

// Jeu de données : la notice 7 (BLMF 0000012), deux fonds, trois exemplaires
// publiés (deux chez moi, L1 ; un à la BTL, L2), un brouillon qui reprend
// l'exemplaire 101 et un brouillon neuf sans exemplaire publié.
const DATA = {
  libraries: [{ id: 'L1', name: 'Biblioteca Lucy Parsons', short_name: 'BLMF' }, { id: 'L2', name: 'Biblioteca Terra Livre', short_name: 'BTL' }],
  books: [{ bib_ref: 'BLMF 0000012', titulo: 'La Commune', autor: 'Louise Michel', cdd: '335', circulation_default: 'consulta', loanable: true }],
  book_holdings: [{ id: 1 }, { id: 2 }],
  catalog_ref_acquisition_modes: [{ code: 'doacao', label: 'Doação' }],
  exemplares: [
    { id: 102, library_id: 'L1', holding_id: 1, bib_ref: 'BLMF 0000012', tombo: 'BLMF-000010', shelf_location: 'Setor/sala: Sala A · Estante: 2 · GR 949.5 PAP', circulation_policy: 'ambos', visibility: 'public', notes: 'ancienne note', acquisition_mode: 'doacao', acquisition_date: '2024-05-01', provenance_note: '', source_library: '', label_title_override: '', label_author_override: '', label_cdd_override: '', label_note: '' },
    { id: 101, library_id: 'L1', holding_id: 1, bib_ref: 'BLMF 0000012', tombo: 'BLMF-000002', shelf_location: '', circulation_policy: 'consulta', visibility: 'staff_only' },
    { id: 201, library_id: 'L2', holding_id: 2, bib_ref: 'BLMF 0000012', tombo: 'BTL-000500', shelf_location: '', circulation_policy: 'emprestavel', visibility: 'public' },
  ],
  exemplar_drafts: [
    { id: 9001, target_library_id: 'L1', tombo: 'BLMF-000002', shelf_location: 'Sala B', status: 'draft', published_exemplar_id: 101, circulation_policy: 'consulta', visibility: 'public' },
    { id: 9002, target_library_id: 'L1', tombo: '', shelf_location: '', status: 'ready', published_exemplar_id: null, circulation_policy: '', visibility: 'public' },
  ],
};

// Supabase simulé : un constructeur chaînable et « thenable », qui journalise
// les écritures (insert) et les appels de RPC.
const journal = { inserts: [], rpc: [] };
const STAFF = { ids: ['L1'] };
let publishResult = { data: 7777, error: null };
let editResult = { data: 102, error: null };
const INSERTED = { id: 9100, tombo: 'BLMF-000011' };

function requete(table) {
  let dernierEq = null;
  const q = {
    select: () => q, eq: (c, v) => { dernierEq = [c, v]; return q; }, in: () => q, order: () => q, not: () => q, limit: () => q,
    insert: (payload) => { journal.inserts.push({ table, payload }); return q; },
    single: () => Promise.resolve({ data: { ...INSERTED }, error: null }),
    maybeSingle: () => {
      if (table === 'exemplar_drafts' && dernierEq && dernierEq[0] === 'id') return Promise.resolve({ data: { tombo: INSERTED.tombo }, error: null });
      return Promise.resolve({ data: (DATA[table] || [])[0] || null, error: null });
    },
    then: (res, rej) => Promise.resolve({ data: DATA[table] || [], error: null }).then(res, rej),
  };
  return q;
}
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: (table) => requete(table),
    rpc: async (name, args) => {
      journal.rpc.push({ name, args });
      if (name === 'fn_next_tombo') return { data: args.p_library_id === 'L1' ? 'BLMF-000011' : 'BTL-000501', error: null };
      if (name === 'publish_exemplar_draft') return publishResult;
      if (name === 'fn_exemplaire_modifier_et_publier') return editResult;
      return { data: null, error: null };
    },
  },
}));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'U1' } }) }));
vi.mock('@/contexts/LibraryContext', () => ({ useLibrary: () => ({ isNetworkAdmin: false }) }));
vi.mock('@/lib/useStaffLibraries', async (orig) => ({
  ...(await orig()),
  useStaffLibraries: () => ({ staffLibraryIds: STAFF.ids, loaded: true }),
}));

const { default: ExemplaresPanel, grouperParBibliotheque, circulationHeritee, etatEtiquette, valeursDepuisExemplaire, changementsPour } = await import('@/pages/catalogacao/ExemplaresPanel');

afterEach(cleanup);
beforeEach(() => { journal.inserts = []; journal.rpc = []; STAFF.ids = ['L1']; publishResult = { data: 7777, error: null }; editResult = { data: 102, error: null }; });

const rendre = (ui) => render(<IntlProvider locale="fr" messages={fr}>{ui}</IntlProvider>);
const lignes = (c) => c.querySelectorAll('[data-testid="copies-row"]');

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

describe('ce qui se déduit de la fiche et de l’exemplaire', () => {
  it('la circulation : circulation_default, sinon loanable', () => {
    expect(circulationHeritee({ circulation_default: 'emprestavel', loanable: false })).toBe('emprestavel');
    expect(circulationHeritee({ circulation_default: null, loanable: true })).toBe('ambos');
    expect(circulationHeritee({ loanable: false })).toBe('consulta');
    expect(circulationHeritee(null)).toBe('consulta');
  });
  it('l’étiquette : prête dès qu’auteur et titre sont connus, de la fiche ou saisis', () => {
    expect(etatEtiquette({ titulo: 'La Commune', autor: 'Louise Michel' }, {})).toBe('ready');
    expect(etatEtiquette({ titulo: 'Anonyme' }, {})).toBe('pending');
    expect(etatEtiquette({ titulo: 'Anonyme' }, { author: 'Collectif' })).toBe('ready');
  });
  it('lot 3 : les valeurs d’un exemplaire se relisent, la cote garde sa part brute, et les douze champs permis repartent', () => {
    const v = valeursDepuisExemplaire(DATA.exemplares[0]);
    expect(v).toMatchObject({ tombo: 'BLMF-000010', sector: 'Sala A', shelfUnit: '2', locRaw: 'GR 949.5 PAP', circulation_policy: 'ambos', visibility: 'public', notes: 'ancienne note', acquisition_mode: 'doacao', acquisition_date: '2024-05-01' });
    const c = changementsPour({ ...v, notes: ' reliure refaite ', visibility: 'staff_only' });
    expect(Object.keys(c).sort()).toEqual(['acquisition_date', 'acquisition_mode', 'circulation_policy', 'label_author_override', 'label_cdd_override', 'label_note', 'label_title_override', 'notes', 'provenance_note', 'shelf_location', 'source_library', 'visibility']);
    expect(c.shelf_location).toBe('Setor/sala: Sala A · Estante: 2 · GR 949.5 PAP');
    expect(c.notes).toBe('reliure refaite');
    expect(c.visibility).toBe('staff_only');
    // Une cote d'avant avec sa partie « Biblioteca » ne la perd pas en réécriture.
    const ancien = valeursDepuisExemplaire({ shelf_location: 'Biblioteca: BTL · Estante: 4' });
    expect(changementsPour(ancien).shelf_location).toBe('Biblioteca: BTL · Estante: 4');
  });
});

describe('ExemplaresPanel — la liste (lot 1)', () => {
  it('liste par bibliothèque, « Modifier » chez moi seulement, « Reprendre la mise à jour » quand un brouillon existe déjà', async () => {
    const onNewCopy = vi.fn(); const onEditPublished = vi.fn(); const onEditDraft = vi.fn();
    const { container, getByText, getAllByText } = rendre(
      <ExemplaresPanel publishedBookId={7} draftId={42} reloadKey={0} onNewCopy={onNewCopy} onEditPublished={onEditPublished} onEditDraft={onEditDraft} />,
    );
    await waitFor(() => expect(lignes(container).length).toBe(4));
    const groupes = [...container.querySelectorAll('[data-testid="copies-group"]')];
    expect(groupes.map((g) => g.getAttribute('data-library'))).toEqual(['L1', 'L2']);
    expect(groupes.map((g) => g.getAttribute('data-editable'))).toEqual(['1', '0']);
    expect(groupes[1].textContent).toContain(fr['catalogacao.copies.otherLibrary']);
    expect(groupes[1].querySelectorAll('button')).toHaveLength(0);
    expect(groupes[0].querySelectorAll('button')).toHaveLength(3);
    expect(getAllByText(fr['common.edit'])).toHaveLength(2);
    fireEvent.click(getByText(fr['catalogacao.copies.resumeUpdate']));
    expect(onEditDraft).toHaveBeenCalledWith(9001);
    expect(container.querySelector('[data-kind="published"][data-retake="1"]').textContent).toContain(fr['catalogacao.copies.updatePending']);
    // L'éditeur complet (onglet) reste atteignable, pré-ciblé sur la fiche.
    fireEvent.click(getByText(fr['catalogacao.copies.form.fullEditor']));
    expect(onNewCopy).toHaveBeenCalledWith(7);
    const ligneBrouillon = container.querySelector('[data-kind="draft"]');
    fireEvent.click(ligneBrouillon.querySelector('button'));
    expect(onEditDraft).toHaveBeenLastCalledWith(9002);
    const lignePubliee = container.querySelector('[data-kind="published"][data-retake="0"]');
    expect(lignePubliee.textContent).toContain(fr['catalogacao.exemplar.circulationPolicy.ambos']);
  });

  it('fiche non publiée : la note, pas de bouton « Nouvel exemplaire »', async () => {
    const { container, queryByText } = rendre(<ExemplaresPanel publishedBookId={null} draftId={null} onNewCopy={vi.fn()} />);
    await waitFor(() => expect(container.querySelector('[data-testid="copies-unpublished"]')).toBeTruthy());
    await new Promise((r) => setTimeout(r, 0)); // la liste des bibliothèques se pose après le rendu
    expect(queryByText(fr['catalogacao.copies.new'])).toBeNull();
  });
});

async function ouvrirPanneau(props = {}) {
  const r = rendre(<ExemplaresPanel publishedBookId={7} draftId={42} reloadKey={0} onNewCopy={vi.fn()} onEditPublished={vi.fn()} onEditDraft={vi.fn()} {...props} />);
  await waitFor(() => expect(lignes(r.container).length).toBe(4));
  return r;
}

describe('ExemplaresPanel — le formulaire court (lot 2)', () => {
  async function ouvrir() {
    const r = await ouvrirPanneau();
    await waitFor(() => expect(r.container.querySelector('[data-testid="copies-new"]:not([disabled])')).toBeTruthy());
    fireEvent.click(r.container.querySelector('[data-testid="copies-new"]'));
    await waitFor(() => expect(r.container.querySelector('[data-testid="copies-form"]')).toBeTruthy());
    return r;
  }

  it('une seule bibliothèque : choisie d’avance, le numéro proposé par sa série, la circulation héritée de la fiche', async () => {
    const { container } = await ouvrir();
    expect(container.querySelector('[data-testid="copies-step-where"]')).toBeNull();
    expect(container.querySelector('[data-testid="copies-where-one"]').textContent).toContain('BLMF');
    await waitFor(() => expect(container.querySelector('[data-testid="copies-tombo"]').value).toBe('BLMF-000011'));
    expect(journal.rpc.find((c) => c.name === 'fn_next_tombo')?.args).toEqual({ p_library_id: 'L1' });
    const coche = container.querySelector('[data-testid="copies-step-circulation"] input[type="radio"]:checked');
    expect(coche.closest('label').textContent).toBe(fr['catalogacao.exemplar.circulationPolicy.consulta']);
    expect(container.querySelector('[data-testid="copies-label-state"]').textContent).toContain('Louise Michel — La Commune');
  });

  it('« Enregistrer et publier » : le brouillon est posé avec sa cible et sa cote, puis publish_exemplar_draft est appelée', async () => {
    const { container } = await ouvrir();
    await waitFor(() => expect(container.querySelector('[data-testid="copies-tombo"]').value).toBe('BLMF-000011'));
    const champs = container.querySelectorAll('[data-testid="copies-step-shelf"] input[type="text"]');
    fireEvent.change(champs[2], { target: { value: 'Est. 4' } }); // Étagère
    fireEvent.click(container.querySelector('[data-testid="copies-submit-publish"]'));
    await waitFor(() => expect(journal.rpc.some((c) => c.name === 'publish_exemplar_draft')).toBe(true));
    expect(journal.inserts).toHaveLength(1);
    const { table, payload } = journal.inserts[0];
    expect(table).toBe('exemplar_drafts');
    expect(payload).toMatchObject({
      action: 'create', status: 'draft', label_status: 'ready',
      target_bib_ref: 'BLMF 0000012', target_library_id: 'L1', tombo: 'BLMF-000011',
      shelf_location: 'Estante: Est. 4', circulation_policy: 'consulta', visibility: 'public',
      created_by: 'U1', updated_by: 'U1',
    });
    expect(journal.rpc.find((c) => c.name === 'publish_exemplar_draft').args).toEqual({ p_draft_id: 9100 });
    await waitFor(() => expect(container.querySelector('[data-testid="copies-message"]')).toBeTruthy());
    const msg = container.querySelector('[data-testid="copies-message"]').textContent;
    expect(msg).toContain('BLMF-000011');
    expect(msg).toContain('BLMF');
    expect(container.querySelector('[data-testid="copies-form"]')).toBeNull();
  });

  it('« Garder en brouillon » : le brouillon est posé, rien n’est publié', async () => {
    const { container } = await ouvrir();
    await waitFor(() => expect(container.querySelector('[data-testid="copies-tombo"]').value).toBe('BLMF-000011'));
    fireEvent.click(container.querySelector('[data-testid="copies-submit-draft"]'));
    await waitFor(() => expect(journal.inserts).toHaveLength(1));
    await waitFor(() => expect(container.querySelector('[data-testid="copies-message"]')?.textContent).toBe(fr['catalogacao.copies.form.draftKept']));
    expect(journal.rpc.some((c) => c.name === 'publish_exemplar_draft')).toBe(false);
  });

  it('publication refusée : le brouillon reste, le refus est dit, le formulaire se ferme', async () => {
    publishResult = { data: null, error: { message: 'Ce rascunho est rattache a une bibliotheque dont vous n\'etes pas membre.', hint: 'error.publish.other_library' } };
    const { container } = await ouvrir();
    await waitFor(() => expect(container.querySelector('[data-testid="copies-tombo"]').value).toBe('BLMF-000011'));
    fireEvent.click(container.querySelector('[data-testid="copies-submit-publish"]'));
    await waitFor(() => expect(container.querySelector('[data-testid="copies-message"]')).toBeTruthy());
    expect(journal.inserts).toHaveLength(1);
    expect(container.querySelector('[data-testid="copies-message"]').textContent).toContain(fr['error.publish.other_library']);
    expect(container.querySelector('[data-testid="copies-form"]')).toBeNull();
  });

  it('staff de deux bibliothèques : le choix d’abord, le rangement après ; la série suit la bibliothèque choisie', async () => {
    STAFF.ids = ['L1', 'L2'];
    const { container } = await ouvrir();
    const ou = container.querySelector('[data-testid="copies-step-where"]');
    expect(ou).toBeTruthy();
    expect(ou.querySelectorAll('input[type="radio"]')).toHaveLength(2);
    expect(container.querySelector('[data-testid="copies-step-shelf"]')).toBeNull();
    expect(container.querySelector('[data-testid="copies-submit-publish"]').disabled).toBe(true);
    fireEvent.click(ou.querySelectorAll('input[type="radio"]')[1]); // BTL
    await waitFor(() => expect(container.querySelector('[data-testid="copies-tombo"]')?.value).toBe('BTL-000501'));
    expect(journal.rpc.find((c) => c.name === 'fn_next_tombo').args).toEqual({ p_library_id: 'L2' });
    expect(container.querySelector('[data-testid="copies-submit-publish"]').disabled).toBe(false);
  });
});

describe('ExemplaresPanel — modifier sans voir le brouillon (lot 3)', () => {
  async function ouvrirModification(props) {
    const r = await ouvrirPanneau(props);
    const ligne = r.container.querySelector('[data-kind="published"][data-retake="0"]'); // 102, BLMF-000010
    fireEvent.click(ligne.querySelector('[data-testid="copies-edit"]'));
    await waitFor(() => expect(r.container.querySelector('[data-testid="copies-edit-form"]')).toBeTruthy());
    return r;
  }

  it('« Modifier » ouvre les temps 2 à 4 pré-remplis ; le numéro ne change pas ; la bibliothèque renvoie à l’éditeur complet', async () => {
    const onEditPublished = vi.fn();
    const { container } = await ouvrirModification({ onEditPublished });
    const form = container.querySelector('[data-testid="copies-edit-form"]');
    expect(form.textContent).toContain('BLMF-000010');
    expect(form.querySelector('[data-testid="copies-tombo-fixed"]').textContent).toContain(fr['catalogacao.copies.edit.tomboFixed']);
    expect(form.querySelector('[data-testid="copies-tombo"]')).toBeNull();
    const champs = form.querySelectorAll('[data-testid="copies-step-shelf"] input[type="text"]');
    expect(champs[0].value).toBe('Sala A');        // secteur
    expect(champs[1].value).toBe('2');             // étagère
    expect(champs[4].value).toBe('GR 949.5 PAP');  // la part brute, gardée
    expect(form.querySelector('[data-testid="copies-step-circulation"] input[type="radio"]:checked').closest('label').textContent).toBe(fr['catalogacao.exemplar.circulationPolicy.ambos']);
    expect(form.querySelector('[data-testid="copies-notes"]').value).toBe('ancienne note');
    // Pendant la modification, « Nouvel exemplaire » se retire.
    expect(container.querySelector('[data-testid="copies-new"]')).toBeNull();
    fireEvent.click(form.querySelector('[data-testid="copies-edit-full"]'));
    expect(onEditPublished).toHaveBeenCalledWith(102);
  });

  it('« Enregistrer les changements » appelle fn_exemplaire_modifier_et_publier avec les douze champs, puis la liste se recharge', async () => {
    const { container } = await ouvrirModification();
    const form = container.querySelector('[data-testid="copies-edit-form"]');
    fireEvent.change(form.querySelector('[data-testid="copies-notes"]'), { target: { value: 'reliure refaite' } });
    fireEvent.click(form.querySelector('[data-testid="copies-step-circulation"] input[type="checkbox"]')); // équipe uniquement
    fireEvent.click(form.querySelector('[data-testid="copies-edit-submit"]'));
    await waitFor(() => expect(journal.rpc.some((c) => c.name === 'fn_exemplaire_modifier_et_publier')).toBe(true));
    const appel = journal.rpc.find((c) => c.name === 'fn_exemplaire_modifier_et_publier').args;
    expect(appel.p_exemplar_id).toBe(102);
    expect(appel.p_changes).toMatchObject({
      shelf_location: 'Setor/sala: Sala A · Estante: 2 · GR 949.5 PAP', circulation_policy: 'ambos', visibility: 'staff_only',
      notes: 'reliure refaite', acquisition_mode: 'doacao', acquisition_date: '2024-05-01',
    });
    expect(Object.keys(appel.p_changes)).toHaveLength(12);
    expect(journal.inserts).toHaveLength(0); // aucun brouillon posé par l'écran : la base enchaîne tout
    await waitFor(() => expect(container.querySelector('[data-testid="copies-message"]')?.textContent).toBe(fr['catalogacao.copies.edit.updated'].replace('{tombo}', 'BLMF-000010')));
    expect(container.querySelector('[data-testid="copies-edit-form"]')).toBeNull();
  });

  it('un refus de la base se dit par son HINT traduit, le formulaire reste ouvert', async () => {
    editResult = { data: null, error: { message: 'Este exemplar já tem um rascunho de atualização (9001).', hint: 'error.copies.update_pending' } };
    const { container } = await ouvrirModification();
    fireEvent.click(container.querySelector('[data-testid="copies-edit-submit"]'));
    await waitFor(() => expect(container.querySelector('[data-testid="copies-message"]')).toBeTruthy());
    expect(container.querySelector('[data-testid="copies-message"]').textContent).toBe(fr['error.copies.update_pending']);
    expect(container.querySelector('[data-testid="copies-edit-form"]')).toBeTruthy();
  });
});

describe('contrat de montage (source)', () => {
  const form = lire('src/pages/catalogacao/BookDraftForm.jsx');
  const page = lire('src/pages/catalogacao/CatalogacaoPage.jsx');
  const editeur = lire('src/pages/catalogacao/ExemplarDraftForm.jsx');
  const panneau = lire('src/pages/catalogacao/ExemplaresPanel.jsx');

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

  it('le formulaire court publie par la RPC existante, sans texte libre « Biblioteca » ; la modification passe par la RPC du lot 3', () => {
    expect(panneau).toContain("supabase.rpc('publish_exemplar_draft', { p_draft_id: Number(brouillon.id) })");
    expect(panneau).toContain("supabase.rpc('fn_next_tombo', { p_library_id: libraryId })");
    expect(panneau).toContain('bibliothequesProposables(libraries, { isNetworkAdmin, staffLibraryIds })');
    expect(panneau).toContain("supabase.rpc('fn_exemplaire_modifier_et_publier', { p_exemplar_id: Number(ef.id), p_changes: changementsPour(ef) })");
    // La bibliothèque n’est plus une partie saisie de la cote : la cote n’a que ses parties, plus ce qu’elle portait déjà.
    expect(panneau).toContain('formatShelfLocation({ library: v.locLibrary, sector: v.sector, shelfUnit: v.shelfUnit, shelfLevel: v.shelfLevel, note: v.locNote, raw: v.locRaw })');
  });

  it('la migration du lot 3 existe, ferme anon, garde authenticated ; sa suite est au manifeste', () => {
    const migs = readdirSync(path.join(RACINE, 'supabase/migrations')).filter((f) => f.endsWith('_c29_lot3_modifier_un_exemplaire_en_un_geste.sql'));
    expect(migs).toHaveLength(1);
    expect(migs[0]).toMatch(/^2026101020\d{4}_/);
    const sql = lire(`supabase/migrations/${migs[0]}`);
    expect(sql).toContain('CREATE OR REPLACE FUNCTION public.fn_exemplaire_modifier_et_publier(p_exemplar_id bigint, p_changes jsonb)');
    expect(sql).toContain('REVOKE ALL ON FUNCTION public.fn_exemplaire_modifier_et_publier(bigint, jsonb) FROM PUBLIC, anon;');
    expect(sql).toContain('GRANT EXECUTE ON FUNCTION public.fn_exemplaire_modifier_et_publier(bigint, jsonb) TO authenticated, service_role;');
    expect(sql).toContain('v_ex := public.publish_exemplar_draft(v_draft);');
    expect(sql).toMatch(/e\.circulation_policy,\s*\n\s*coalesce\(e\.visibility, 'public'\),/); // la reprise copie les deux
    const manifeste = lire('tests/sql/ci-suites.txt');
    expect(manifeste).toContain('tests/sql/c29_exemplaire_modifier_et_publier_tests.sql');
    expect(lire('tests/sql/c29_exemplaire_modifier_et_publier_tests.sql')).toContain('C29-MODIFIER-ET-PUBLIER OK');
  });
});

describe('les clés du panneau existent dans les 10 locales', () => {
  const LOCALES = ['ca', 'de', 'el', 'en', 'eo', 'es', 'fr', 'it', 'nl', 'pt-BR'];
  const CLES = [
    ...['title', 'count', 'new', 'unpublished', 'empty', 'otherLibrary', 'resumeUpdate', 'updatePending', 'loadError', 'libraryUnknown'].map((k) => `catalogacao.copies.${k}`),
    ...['title', 'where', 'whereOne', 'noLibrary', 'shelf', 'tomboHint', 'tomboManual', 'circulation', 'circulationInherited', 'details',
      'labelDeduced', 'submitPublish', 'submitDraft', 'created', 'draftKept', 'publishFailed', 'fullEditor', 'fullEditorHint'].map((k) => `catalogacao.copies.form.${k}`),
    ...['title', 'library', 'tomboFixed', 'reassign', 'submit', 'updated'].map((k) => `catalogacao.copies.edit.${k}`),
    ...['not_found', 'changes_invalid', 'field_not_allowed', 'update_pending'].map((k) => `error.copies.${k}`),
  ];
  for (const loc of LOCALES) {
    it(loc, () => {
      const dico = JSON.parse(lire(`src/i18n/locales/${loc}.json`));
      for (const k of CLES) expect(typeof dico[k], k).toBe('string');
    });
  }
});
