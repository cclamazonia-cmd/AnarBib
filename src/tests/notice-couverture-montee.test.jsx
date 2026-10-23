// =====================================================================
// E6, formulaire de notice (23/10/2026) — BookDraftForm découpé : l'en-tête
// couverture (BookCoverPanel), la pop-up de création, les blocs Œuvre et
// Doublons, et l'enregistrement dans un hook (useNoticePersistance). Leçon du
// formulaire d'autorité (une variable lue avant d'exister, invisible au test de
// source) : ici le formulaire ENTIER est monté, base simulée, et les gestes sont
// joués — dépôt OCR repris dans la fiche, enregistrement (le PDF scanné est
// rattaché), recherche et choix d'une couverture, envoi d'une image, page 1 du
// PDF, retrait. Le panneau couverture ne touche le formulaire que par les
// fonctions que la page lui passe.
// =====================================================================
import { describe, it, expect, vi, afterEach, beforeAll } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor, act } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

// ── Base simulée : chaque appel est noté ; quelques réponses sont choisies ──
const appels = [];
const reponse = (table, ops) => {
  if (table === 'book_drafts' && ops.includes('insert')) return { data: { id: 77, batch_id: null }, error: null };
  if (table === 'book_drafts' && ops.includes('update')) return { data: { id: 77, batch_id: null }, error: null };
  if (table === 'book_draft_digital_resources' && ops.includes('select') && !ops.includes('insert')) {
    return { data: [{ id: 9, mime_type: 'application/pdf', storage_bucket: 'pdf-restrito', storage_path: 'books/77/scan.pdf', is_active: true }], error: null };
  }
  return { data: [], error: null, count: 0 };
};
function chaine(table) {
  const ops = [];
  const p = new Proxy(() => {}, {
    get(_, k) {
      if (k === 'then') return (ok, ko) => Promise.resolve(reponse(table, ops)).then(ok, ko);
      return (...args) => { ops.push(k); appels.push([table, k, args[0]]); return p; };
    },
  });
  return p;
}
const stockage = (bucket) => ({
  upload: async (chemin) => { appels.push(['storage', 'upload', bucket, chemin]); return { data: { path: chemin }, error: null }; },
  remove: async (chemins) => { appels.push(['storage', 'remove', bucket, chemins]); return { data: [], error: null }; },
  download: async (chemin) => { appels.push(['storage', 'download', bucket, chemin]); return { data: new Blob(['%PDF']), error: null }; },
  createSignedUrl: async () => ({ data: { signedUrl: 'x' }, error: null }),
  getPublicUrl: () => ({ data: { publicUrl: 'x' } }),
});
const invoque = vi.fn(async (nom, { body }) => {
  appels.push(['fn', nom, body.action]);
  if (body.action === 'search') {
    return { data: { ok: true, candidates: [{ fullUrl: 'https://ol/1.jpg', thumbnailData: 'data:image/png;base64,AA', source: 'openlibrary', label: 'Anarchie (1950)' }] }, error: null };
  }
  if (body.action === 'store') return { data: { ok: true, storagePath: 'BTL-9/capa-neuve.jpg', source: 'openlibrary' }, error: null };
  return { data: null, error: null };
});
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://base.test',
  SUPABASE_ANON_KEY: 'anon',
  supabase: {
    from: (table) => chaine(table),
    rpc: (nom) => chaine('rpc:' + nom),
    functions: { invoke: (...a) => invoque(...a) },
    storage: { from: stockage },
    auth: { getSession: async () => ({ data: { session: null } }), onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }) },
    channel: () => ({ on() { return this; }, subscribe() { return this; } }),
    removeChannel: () => {},
  },
}));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'u1' }, profile: {} }) }));
vi.mock('@/contexts/LibraryContext', () => ({
  useLibrary: () => ({ isNetworkAdmin: false, libraryId: 5, libraryName: 'BTL', effectiveRole: 'catalogador', config: {} }),
}));
vi.mock('@/contexts/ConfirmContext', () => ({ useConfirm: () => async () => true }));
vi.mock('@/contexts/ToastContext', () => ({ useToast: () => ({ notify: () => {} }) }));
vi.mock('@/lib/useStaffLibraries', async (orig) => ({
  ...(await orig()),
  useStaffLibraries: () => ({ staffLibraryIds: [5], loaded: true }),
}));
vi.mock('@/lib/coverThumbs', async (orig) => ({
  ...(await orig()),
  writeCoverThumb: vi.fn(async () => {}),
  removeCoverThumb: vi.fn(async () => {}),
  nomCapaNeuf: () => 'capa-neuve',
}));
vi.mock('@/lib/capaPdf', () => ({
  rendrePage1: vi.fn(async () => ({ width: 1, height: 1 })),
  canvasEnJpeg: vi.fn(async () => new Blob(['jpg'])),
}));
vi.mock('@/lib/imageMetadata', () => ({ fichierSansMetadonnees: async (f) => f }));

const { default: BookDraftForm } = await import('@/pages/catalogacao/BookDraftForm');
const fr = JSON.parse(readFileSync(path.resolve(__dirname, '..', 'i18n/locales/fr.json'), 'utf8'));
const monter = (props = {}) => render(
  <IntlProvider locale="fr" messages={fr} onError={() => {}}>
    <BookDraftForm panelActive {...props} />
  </IntlProvider>,
);

beforeAll(() => {
  globalThis.URL.createObjectURL = () => 'blob:apercu';
  globalThis.URL.revokeObjectURL = () => {};
});
afterEach(() => { cleanup(); appels.length = 0; invoque.mockClear(); });

describe('le formulaire de notice découpé, monté', () => {
  it('un dépôt OCR remplit la fiche ; « Enregistrer » crée le brouillon et y rattache le PDF scanné', async () => {
    const scan = new File(['%PDF'], 'scan.pdf', { type: 'application/pdf' });
    monter({ prefillRecord: { titulo: 'Anarchie', autor: 'Élisée Reclus' }, prefillFile: scan });
    expect(await screen.findByDisplayValue('Anarchie')).toBeTruthy();
    fireEvent.click(screen.getByText(fr['catalogacao.ui.saveDraft']));
    await screen.findByText(fr['catalogacao.msg.draftSaved']);
    const insertion = appels.find(([t, op]) => t === 'book_drafts' && op === 'insert');
    expect(insertion[2]).toMatchObject({ titulo: 'Anarchie', status: 'draft', action: 'create' });
    expect(appels.some(([t, op, b, chemin]) => t === 'storage' && op === 'upload' && b === 'pdf-restrito' && /^books\/77\//.test(chemin))).toBe(true);
    expect(appels.find(([t, op]) => t === 'book_draft_digital_resources' && op === 'insert')[2])
      .toMatchObject({ book_draft_id: 77, access_scope: 'conta_ativa', is_primary: true });
  });

  it('couverture : sans titre la recherche le dit ; avec, la galerie s\'ouvre et la candidate choisie devient la capa', async () => {
    monter({ prefillRecord: {} });
    fireEvent.click(screen.getByText(fr['catalogacao.ui.coverSearch']));
    expect(await screen.findByText(fr['catalogacao.ui.coverLookupNeed'])).toBeTruthy();
    expect(invoque).not.toHaveBeenCalled();
    cleanup();

    monter({ prefillRecord: { titulo: 'Anarchie', bib_ref: 'BTL-9' } });
    await screen.findByDisplayValue('Anarchie');
    fireEvent.click(screen.getByText(fr['catalogacao.ui.coverSearch']));
    expect(await screen.findByText(fr['catalogacao.ui.coverGalleryTitle'])).toBeTruthy();
    expect(invoque.mock.calls[0][1].body).toMatchObject({ action: 'search', title: 'Anarchie' });
    fireEvent.click(screen.getByTitle('Anarchie (1950) · openlibrary'));
    await screen.findByText(fr['catalogacao.ui.coverSaved']);
    expect(invoque.mock.calls[1][1].body).toMatchObject({ action: 'store', key: 'BTL-9', nom: 'capa-neuve' });
    // la capa retenue s'affiche, la galerie se referme
    expect(document.querySelector('.ab-cover__frame img').getAttribute('src')).toBe('https://base.test/storage/v1/object/public/covers/BTL-9/capa-neuve.jpg');
    expect(screen.queryByText(fr['catalogacao.ui.coverGalleryTitle'])).toBeNull();
    // « Retirer » efface l'objet et les champs
    fireEvent.click(screen.getByText(fr['catalogacao.ui.coverRemove']));
    await waitFor(() => expect(appels).toContainEqual(['storage', 'remove', 'covers', ['BTL-9/capa-neuve.jpg']]));
    await waitFor(() => expect(document.querySelector('.ab-cover__frame img')).toBeNull());
  });

  it('couverture : une image choisie s\'aperçoit, puis « Envoyer » la range sous un nom neuf', async () => {
    monter({ prefillRecord: { titulo: 'Anarchie', bib_ref: 'BTL-9' } });
    await screen.findByDisplayValue('Anarchie');
    const champ = document.querySelector('.ab-cover input[type="file"]');
    const image = new File(['img'], 'capa.png', { type: 'image/png' });
    await act(async () => { fireEvent.change(champ, { target: { files: [image] } }); });
    expect(document.querySelector('.ab-cover__frame img').getAttribute('src')).toBe('blob:apercu');
    expect(screen.getByText('capa.png')).toBeTruthy();
    fireEvent.click(screen.getByText(fr['catalogacao.ui.coverUploadBtn']));
    await waitFor(() => expect(appels.some(([t, op, b, chemin]) => t === 'storage' && op === 'upload' && b === 'covers' && /^books\/BTL-9\/capa-[a-z0-9]+\.png$/.test(chemin))).toBe(true));
    // l'envoi fait la capa : l'aperçu local cède la place au fichier rangé, le bouton s'efface
    await waitFor(() => expect(screen.queryByText(fr['catalogacao.ui.coverUploadBtn'])).toBeNull());
  });

  it('couverture : la page 1 du PDF rattaché devient la capa, sans contacter la source', async () => {
    monter({ prefillRecord: { id: '77', titulo: 'Anarchie', bib_ref: 'BTL-9' } });
    fireEvent.click(await screen.findByText(fr['catalogacao.ui.coverPdfPage1']));
    await screen.findByText(fr['catalogacao.ui.coverSaved']);
    expect(appels).toContainEqual(['storage', 'download', 'pdf-restrito', 'books/77/scan.pdf']);
    expect(appels.some(([t, op, b, chemin]) => t === 'storage' && op === 'upload' && b === 'covers' && /^books\/BTL-9\/capa-[a-z0-9]+\.jpg$/.test(chemin))).toBe(true);
    expect(invoque).not.toHaveBeenCalled();
  });

  it('le panneau couverture n\'écrit le formulaire que par ce que la page lui passe', () => {
    const src = readFileSync(path.resolve(__dirname, '..', 'pages/catalogacao/BookCoverPanel.jsx'), 'utf8');
    expect(src).not.toMatch(/from\('book_drafts'\)/);
    expect(src).not.toMatch(/useState\(\{ \.\.\.EMPTY_FORM/);
    for (const f of ['BookCoverPanel.jsx', 'BookCreationChoice.jsx', 'BookWorkPanel.jsx', 'BookDuplicatesPanel.jsx', 'useNoticePersistance.js']) {
      expect(readFileSync(path.resolve(__dirname, '..', `pages/catalogacao/${f}`), 'utf8'), f).not.toMatch(/const (\w+) = \1;/);
    }
  });
});
