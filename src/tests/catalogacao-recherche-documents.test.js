// @vitest-environment node
//
// Catalogage, onglet « Catalogue(s) publié(s) › Documents » (13/10/2026) : la
// barre cherche comme l'OPAC, par api.catalogacao_book_ids_v1 (public.books en
// direct, variantes de l'autorité, ISBN avec ou sans tirets, une ou deux
// lettres près si rien d'exact), et retombe sur l'ILIKE d'avant si la porte ne
// répond pas.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const appels = [];
let reponse = null;
vi.mock('@/lib/supabase', () => ({
  apiRpc: vi.fn(async (fn, args) => {
    appels.push([fn, args]);
    if (reponse instanceof Error) throw reponse;
    return reponse ?? { data: null, error: { status: 404 } };
  }),
}));

const { chercherDocumentsPublies, ordonnerSelonIds } = await import('@/lib/catalogacaoBookSearch');
const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

beforeEach(() => { appels.length = 0; reponse = null; });

describe('chercherDocumentsPublies', () => {
  it('rien à chercher sans saisie : aucun appel', async () => {
    expect(await chercherDocumentsPublies('   ')).toBeNull();
    expect(appels).toHaveLength(0);
  });

  it('les notices dans l\'ordre du rang, exactes', async () => {
    reponse = { data: [{ book_id: 9, rank: 1 }, { book_id: 4, rank: 0.3 }], error: null };
    expect(await chercherDocumentsPublies(' 978-956 ')).toEqual({ ids: [9, 4], approx: false });
    expect(appels).toEqual([['catalogacao_book_ids_v1', { p_q: '978-956' }]]);
  });

  it('tous les rangs négatifs : approché', async () => {
    reponse = { data: [{ book_id: 7, rank: -0.42 }, { book_id: 3, rank: -0.6 }], error: null };
    expect(await chercherDocumentsPublies('malatesa')).toEqual({ ids: [7, 3], approx: true });
  });

  it('aucune notice : liste vide, pas approché', async () => {
    reponse = { data: [], error: null };
    expect(await chercherDocumentsPublies('zzzz')).toEqual({ ids: [], approx: false });
  });

  it('porte en erreur ou qui lève : null (l\'écran garde l\'ILIKE)', async () => {
    reponse = { data: null, error: { status: 500 } };
    expect(await chercherDocumentsPublies('x')).toBeNull();
    reponse = new Error('réseau');
    expect(await chercherDocumentsPublies('x')).toBeNull();
  });
});

describe('ordonnerSelonIds', () => {
  it('remet la page dans l\'ordre du rang, inconnus en dernier', () => {
    const lignes = [{ id: 4 }, { id: 99 }, { id: 9 }, { id: 2 }];
    expect(ordonnerSelonIds(lignes, [9, 2, 4]).map(l => l.id)).toEqual([9, 2, 4, 99]);
    expect(ordonnerSelonIds(null, [1])).toEqual([]);
  });
});

describe('CatalogPanel et la migration', () => {
  const panneau = lire('src/pages/catalogacao/CatalogPanel.jsx');
  const mig = lire('supabase/migrations/20261013062921_le_catalogage_cherche_ses_documents_comme_l_opac.sql');

  it('la vue Documents passe par la porte, découpe la page dans ses identifiants et garde l\'ILIKE en repli', () => {
    expect(panneau).toContain('await chercherDocumentsPublies(dSearch)');
    expect(panneau).toContain('recherche.ids.slice(from, to + 1)');
    expect(panneau).toContain(".in('id', pageIds)");
    expect(panneau).toContain('ordonnerSelonIds(data, pageIds)');
    expect(panneau).toMatch(/titulo\.ilike\.%\$\{dSearch\.trim\(\)\}%/);
  });

  it('l\'écran dit quand les résultats sont approchés', () => {
    expect(panneau).toContain("view === 'book' && approx");
    expect(panneau).toContain("t({ id: 'catalog.results.approx' })");
  });

  it('la porte lit public.books (pas la vue matérialisée), INVOKER, fermée à anon', () => {
    expect(mig).toContain('from public.books b');
    expect(mig).not.toMatch(/catalog_list_(anon|session)_v1\s+c/);
    expect(mig).not.toMatch(/SECURITY DEFINER/);
    expect(mig).toContain('REVOKE ALL ON FUNCTION api.catalogacao_book_ids_v1(text) FROM PUBLIC, anon;');
    expect(mig).toContain('GRANT EXECUTE ON FUNCTION api.catalogacao_book_ids_v1(text) TO authenticated, service_role;');
    expect(lire('tests/sql/ci-suites.txt')).toContain('tests/sql/catalogacao_recherche_documents_tests.sql');
  });
});
