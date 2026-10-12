// @vitest-environment node
//
// Liste plate, suite d'E38 (12/10/2026) : le filtre auteur·rice passe d'abord
// par api.catalog_author_book_ids_v1 (notices retenues par la règle de
// catalog_works_v1, l'approché couvrant aussi les notices sans autorité liée),
// et garde le chemin E38 (autorités + ILIKE paginé) au-delà de 500 notices ou
// si la porte ne répond pas.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const appels = [];
let reponses = {};
vi.mock('@/lib/supabase', () => ({
  apiRpc: vi.fn(async (fn, args) => {
    appels.push([fn, args]);
    const r = reponses[fn];
    return typeof r === 'function' ? r(args) : (r ?? { data: null, error: { status: 404 } });
  }),
}));

const { resoudreFiltreAuteur, intersecterContraintes } = await import('@/lib/catalogAuthorFilter');
const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');

beforeEach(() => { appels.length = 0; reponses = {}; });

describe('resoudreFiltreAuteur', () => {
  it('rien à résoudre sans nom, avec un identifiant choisi ou pendant le parcours A–Z', async () => {
    for (const p of [{ author: '  ' }, { author: 'x', authorIdFilter: '5' }, { author: 'x', alphaFilter: 'K' }]) {
      expect(await resoudreFiltreAuteur(p)).toEqual({ authorBookIds: null, authorIds: null, approx: false });
    }
    expect(appels).toHaveLength(0);
  });

  it('les notices de la porte, et le drapeau « approché » qu\'elle porte', async () => {
    reponses.catalog_author_book_ids_v1 = { data: [{ book_id: 7, approx: true }, { book_id: 9, approx: true }], error: null };
    expect(await resoudreFiltreAuteur({ author: ' malatesa ' })).toEqual({ authorBookIds: [7, 9], authorIds: null, approx: true });
    expect(appels).toEqual([['catalog_author_book_ids_v1', { p_name: 'malatesa' }]]);
  });

  it('au-delà de 500 notices, le chemin E38 : autorités exactes, puis approchées', async () => {
    reponses.catalog_author_book_ids_v1 = { data: Array.from({ length: 501 }, (_, i) => ({ book_id: i, approx: false })), error: null };
    reponses.catalog_author_ids_v1 = (args) => ({ data: args.p_approche ? [5] : [], error: null });
    expect(await resoudreFiltreAuteur({ author: 'a' })).toEqual({ authorBookIds: null, authorIds: [5], approx: true });
    expect(appels.map(([fn, a]) => `${fn}:${a.p_approche ? 'approche' : 'exact'}`)).toEqual([
      'catalog_author_book_ids_v1:exact', 'catalog_author_ids_v1:exact', 'catalog_author_ids_v1:approche']);
  });

  it('porte en erreur : le chemin E38, et l\'ILIKE seul si lui aussi échoue', async () => {
    reponses.catalog_author_ids_v1 = { data: [5], error: null };
    expect(await resoudreFiltreAuteur({ author: 'kropotkine' })).toEqual({ authorBookIds: null, authorIds: [5], approx: false });
    reponses.catalog_author_ids_v1 = () => { throw new Error('réseau'); };
    expect(await resoudreFiltreAuteur({ author: 'kropotkine' })).toEqual({ authorBookIds: null, authorIds: null, approx: false });
  });
});

describe('intersecterContraintes', () => {
  it('null si rien d\'actif ; sinon l\'intersection, dans l\'ordre de la première liste', () => {
    expect(intersecterContraintes([null, null, null])).toBeNull();
    expect(intersecterContraintes([null, [3, 1], null])).toEqual([3, 1]);
    expect(intersecterContraintes([[9, 4, 2, 7], [2, 9, 8], [7, 9, 2]])).toEqual([9, 2]);
    expect(intersecterContraintes([[1, 2], []])).toEqual([]);
  });
});

describe('la page et la migration', () => {
  it('la page délègue la résolution et contraint par les notices rendues', () => {
    const page = lire('src/pages/public/CatalogPage.jsx');
    expect(page).toContain('await resoudreFiltreAuteur({ author: dAuthor, authorIdFilter, alphaFilter })');
    expect(page).toContain("authorFilter: authorBookIds !== null ? '' : dAuthor");
    expect(page).toContain('intersecterContraintes([rankedIds, authorBookIds, subjectIds])');
  });

  it('la porte : règle de catalog_works_v1, plafond 501, approché en seconde passe, ouverte à anon', () => {
    const mig = lire('supabase/migrations/20261012121812_la_liste_plate_s_approche_des_notices_sans_lien.sql');
    expect(mig).toContain('limit 501');
    expect(mig).toContain('return query execute v_sql using btrim(p_name), private.fn_auteurs_par_nom(p_name, false), false;\n  if not found then');
    expect(mig).toContain('GRANT EXECUTE ON FUNCTION api.catalog_author_book_ids_v1(text) TO anon, authenticated, service_role;');
    expect(mig).not.toMatch(/SECURITY DEFINER/);
    expect(lire('tests/sql/grants_herites_tests.sql')).toContain("('api.catalog_author_book_ids_v1'),");
  });
});
