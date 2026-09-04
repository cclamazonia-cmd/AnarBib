// Tests de src/lib/catalogWorks.js — l'OPAC par œuvre (lot 2, 04/09/2026).
import { describe, it, expect } from 'vitest';
import { buildWorksFilters, worksSortParam, groupBooksIntoWorks, yearsLabel } from '@/lib/catalogWorks';

const base = {
  search: '', authorFilter: '', authorIdFilter: '', alphaFilter: '', publisherFilter: '', yearFilter: '',
  libraryShortNames: [], availabilityFilter: '__all__', isAuth: false, isbnFilter: '', languageFilter: '',
  cddFilter: '', subjectsFilter: '', materialFilter: '__all__', collectionFilter: '', placeFilter: '', subjectFilter: '',
};

describe('buildWorksFilters', () => {
  it('ne pose que ce qui est rempli', () => {
    expect(buildWorksFilters(base)).toEqual({});
    expect(buildWorksFilters({ ...base, search: '  desobediencia ', publisherFilter: 'Antígona' }))
      .toEqual({ q: 'desobediencia', publisher: 'Antígona' });
  });

  it('applique la priorité A–Z > autorité > texte, comme la liste plate', () => {
    expect(buildWorksFilters({ ...base, alphaFilter: 'T', authorIdFilter: '12', authorFilter: 'thoreau' })).toEqual({ alpha: 'T' });
    expect(buildWorksFilters({ ...base, authorIdFilter: '12', authorFilter: 'thoreau' })).toEqual({ author_id: '12' });
    expect(buildWorksFilters({ ...base, authorFilter: 'thoreau' })).toEqual({ author: 'thoreau' });
  });

  it('distingue année exacte et intervalle, et nettoie l’ISBN', () => {
    expect(buildWorksFilters({ ...base, yearFilter: '1987' })).toEqual({ year: '1987' });
    expect(buildWorksFilters({ ...base, yearFilter: '1980 – 1990' })).toEqual({ year_from: '1980', year_to: '1990' });
    expect(buildWorksFilters({ ...base, isbnFilter: '978-85 123' })).toEqual({ isbn: '97885123' });
  });

  it('passe les bibliothèques par nom court et le sujet par slug', () => {
    expect(buildWorksFilters({ ...base, libraryShortNames: ['BTL', undefined, 'MLEG'], subjectFilter: 'anarquismo' }))
      .toEqual({ libraries: ['BTL', 'MLEG'], subject: 'anarquismo' });
  });

  it('ignore la disponibilité pour l’anon (doctrine A1/A2/A3)', () => {
    expect(buildWorksFilters({ ...base, availabilityFilter: 'available' })).toEqual({});
    expect(buildWorksFilters({ ...base, availabilityFilter: 'available', isAuth: true })).toEqual({ availability: 'available' });
  });
});

describe('worksSortParam', () => {
  it('traduit le tri de la liste plate', () => {
    expect(worksSortParam('__relevance__')).toBe('relevance');
    expect(worksSortParam('status')).toBe('status');
    expect(worksSortParam('ano.desc')).toBe('ano.desc');
    expect(worksSortParam('autor.asc')).toBe('autor.asc');
    expect(worksSortParam('autor.desc')).toBe('autor.asc');
    expect(worksSortParam('ano.asc')).toBe('ano.desc');
    expect(worksSortParam('n_importe_quoi')).toBe('titulo.asc');
  });
});

describe('groupBooksIntoWorks (mode dégradé)', () => {
  const rows = [
    { book_id: 1, work_id: 97, titulo: 'Desobediencia Civil', ano: '2010', holding_library_names_json: ['BTL'], global_available_count: 1 },
    { book_id: 2, work_id: 97, titulo: 'A desobediência civil', ano: '1987', holding_library_names_json: '["BTL","MLEG"]', global_available_count: 0 },
    { book_id: 3, work_id: null, titulo: 'Walden', ano: 's.d.', holding_library_names_json: null, global_available_count: 0 },
    { book_id: 4, work_id: 97, titulo: 'Desobediência Civil', ano: null, holding_library_names_json: ['MLEG'], global_available_count: 0 },
  ];

  it('une œuvre par work_id, une notice sans œuvre reste seule, ordre d’arrivée', () => {
    const w = groupBooksIntoWorks(rows);
    expect(w.map(x => x.key)).toEqual(['97', '-3']);
    expect(w[0].edition_count).toBe(3);
    expect(w[0].display_title).toBe('Desobediencia Civil');
    expect(w[0].year_min).toBe(1987);
    expect(w[0].year_max).toBe(2010);
    expect(w[0].any_available).toBe(true);
    expect(w[0].library_names).toEqual(['BTL', 'MLEG']);
    expect(w[0].editions.map(e => e.book_id)).toEqual([1, 2, 4]); // année décroissante, sans année en dernier
    expect(w[1]).toMatchObject({ work_id: null, edition_count: 1, year_min: null, year_max: null, library_names: [] });
  });

  it('accepte une liste vide', () => {
    expect(groupBooksIntoWorks([])).toEqual([]);
    expect(groupBooksIntoWorks(undefined)).toEqual([]);
  });
});

describe('yearsLabel', () => {
  it('rend une borne, un intervalle ou un tiret', () => {
    expect(yearsLabel(null, null)).toBe('—');
    expect(yearsLabel(1987, 1987)).toBe('1987');
    expect(yearsLabel(1987, 2011)).toBe('1987–2011');
    expect(yearsLabel(null, 2011)).toBe('2011');
  });
});
