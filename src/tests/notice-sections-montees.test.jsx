// =====================================================================
// E6, formulaire de notice (23/10/2026) — les sections sorties de
// BookDraftForm.jsx : la pop-up de création (BookCreationChoice), les blocs
// Œuvre (BookWorkPanel) et Doublons (BookDuplicatesPanel), l'enregistrement
// (useNoticePersistance). Le formulaire est MONTÉ, base simulée, et les gestes
// joués ; puis le contrat de source : chaque section montée une fois, aucune
// ne redéclare ce qu'elle reçoit, la page sous 60 Kio. La couverture a son
// propre test : notice-couverture-montee.test.jsx.
// =====================================================================
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync, statSync } from 'node:fs';
import path from 'node:path';

const appels = [];
const doublon = { book_id: 31, titulo: 'Anarchie', autor: 'Élisée Reclus', exemplares: 2, match_kind: 'isbn', score: 1 };
const reponse = (cle) => (cle === 'rpc:suggest_book_duplicates' ? { data: [doublon], error: null } : { data: [], error: null, count: 0 });
function chaine(cle) {
  const p = new Proxy(() => {}, {
    get(_, k) {
      if (k === 'then') return (ok, ko) => Promise.resolve(reponse(cle)).then(ok, ko);
      return () => p;
    },
  });
  return p;
}
vi.mock('@/lib/supabase', () => ({
  SUPABASE_URL: 'https://base.test',
  SUPABASE_ANON_KEY: 'anon',
  supabase: {
    from: (table) => { appels.push(['from', table]); return chaine(table); },
    rpc: (nom, args) => { appels.push(['rpc', nom, args]); return chaine('rpc:' + nom); },
    functions: { invoke: async () => ({ data: null, error: null }) },
    storage: { from: () => ({ upload: async () => ({ error: null }), remove: async () => ({ error: null }) }) },
    auth: { getSession: async () => ({ data: { session: null } }), onAuthStateChange: () => ({ data: { subscription: { unsubscribe() {} } } }) },
    channel: () => ({ on() { return this; }, subscribe() { return this; } }),
    removeChannel: () => {},
  },
}));
vi.mock('@/contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'u1' }, profile: {} }) }));
vi.mock('@/contexts/LibraryContext', () => ({
  useLibrary: () => ({ isNetworkAdmin: false, libraryId: 5, libraryName: 'BTL', effectiveRole: 'coordenador', config: {} }),
}));
vi.mock('@/contexts/ConfirmContext', () => ({ useConfirm: () => async () => true }));
vi.mock('@/contexts/ToastContext', () => ({ useToast: () => ({ notify: () => {} }) }));
vi.mock('@/lib/useStaffLibraries', async (orig) => ({
  ...(await orig()),
  useStaffLibraries: () => ({ staffLibraryIds: [5], loaded: true }),
}));

const { default: BookDraftForm } = await import('@/pages/catalogacao/BookDraftForm');
const fr = JSON.parse(readFileSync(path.resolve(__dirname, '..', 'i18n/locales/fr.json'), 'utf8'));
const monter = (props = {}) => render(
  <IntlProvider locale="fr" messages={fr} onError={() => {}}>
    <BookDraftForm panelActive mode="complete" {...props} />
  </IntlProvider>,
);
const publiee = { id: '77', published_book_id: '12', titulo: 'Anarchie', bib_ref: 'BTL-9' };

afterEach(() => { cleanup(); appels.length = 0; });

describe('les sections du formulaire de notice, montées', () => {
  it('pop-up de création : la recherche d\'éditions interroge le catalogue, « œuvre nouvelle » la ferme', async () => {
    monter();
    expect(await screen.findByText(fr['catalogacao.create.title'])).toBeTruthy();
    fireEvent.change(screen.getByPlaceholderText(fr['catalogacao.create.searchEdition']), { target: { value: 'Anar' } });
    expect(await screen.findByText(fr['catalogacao.create.noEditionFound'], {}, { timeout: 2000 })).toBeTruthy();
    expect(appels).toContainEqual(['from', 'books']);
    fireEvent.click(screen.getByText(fr['catalogacao.create.newWork']));
    await waitFor(() => expect(screen.queryByText(fr['catalogacao.create.title'])).toBeNull());
  });

  it('bloc Œuvre : « Suggérer » appelle la base et dit qu\'il n\'y a rien', async () => {
    monter({ prefillRecord: publiee });
    fireEvent.click(await screen.findByText(fr['catalogacao.work.suggest']));
    expect(await screen.findByText(fr['catalogacao.work.noSuggestions'])).toBeTruthy();
    expect(appels).toContainEqual(['rpc', 'suggest_editions_for_book', { p_book_id: 12 }]);
  });

  it('bloc Doublons : « Chercher » liste le doublon ; « pas un doublon » l\'écarte puis relance la recherche', async () => {
    monter({ prefillRecord: publiee });
    fireEvent.click(await screen.findByText(fr['catalogacao.dedup.find']));
    expect(await screen.findByText(fr['catalogacao.dedup.notDuplicate'])).toBeTruthy();
    expect(appels).toContainEqual(['rpc', 'suggest_book_duplicates', { p_book_id: 12 }]);
    fireEvent.click(screen.getByText(fr['catalogacao.dedup.notDuplicate']));
    expect(await screen.findByText(fr['catalogacao.dedup.markedNotDuplicate'])).toBeTruthy();
    expect(appels).toContainEqual(['rpc', 'mark_books_not_duplicate', { p_a: 12, p_b: 31 }]);
    expect(appels.filter(([k, nom]) => k === 'rpc' && nom === 'suggest_book_duplicates')).toHaveLength(2);
  });
});

const racine = path.resolve(__dirname, '..', '..');
const lire = (f) => readFileSync(path.join(racine, 'src/pages/catalogacao', f), 'utf8');
const SECTIONS = ['BookCoverPanel', 'BookCreationChoice', 'BookWorkPanel', 'BookDuplicatesPanel'];

describe('le formulaire de notice, en sections (source)', () => {
  it('chaque section est importée et montée une fois ; le hook est appelé une fois', () => {
    const page = lire('BookDraftForm.jsx');
    for (const s of SECTIONS) {
      expect(page, s).toContain(`import ${s} from './${s}.jsx';`);
      expect(page.match(new RegExp(`<${s} \\{\\.\\.\\.\\{`, 'g')), s).toHaveLength(1);
    }
    expect(page).toContain("import { useNoticePersistance } from './useNoticePersistance.js';");
    expect(page.match(/= useNoticePersistance\(\{/g)).toHaveLength(1);
  });
  it('aucune section ne redéclare ce qu\'elle reçoit, aucune variable ne se lit elle-même', () => {
    for (const f of [...SECTIONS.map((s) => `${s}.jsx`), 'useNoticePersistance.js']) {
      const src = lire(f);
      const bloc = src.match(/const \{\n([\s\S]*?)\n {2}\} = p;/);
      const props = (bloc ? bloc[1] : '').split(',').map((x) => x.trim()).filter(Boolean);
      expect(props.length, f).toBeGreaterThan(0);
      for (const n of props) {
        expect(src, `${f} : ${n}`).not.toMatch(new RegExp(`const \\[${n},|const ${n} =|function ${n}\\(`));
      }
      expect(src, f).not.toMatch(/const (\w+) = \1;/);
    }
  });
  it('la page tient sous 60 Kio (E6)', () => {
    expect(statSync(path.join(racine, 'src/pages/catalogacao/BookDraftForm.jsx')).size).toBeLessThan(60 * 1024);
  });
});
