// src/lib/catalogWorks.js
// L'OPAC par œuvre (lot 2, 04/09/2026) : fonctions pures, sans React, testables.
//
//  - buildWorksFilters : l'état des filtres de CatalogPage → le p_filters de
//    api.catalog_works_v1 (même vocabulaire que catalog_facets_v1, plus ce que
//    la liste plate envoyait à PostgREST : auteur texte, ISBN, sujets texte,
//    disponibilité de session, bibliothèques par nom court).
//  - worksSortParam : le tri de la liste plate → le p_sort du RPC.
//  - groupBooksIntoWorks : le repli côté client, gardé pour le mode dégradé
//    (instantané statique quand l'API ne répond pas) — même forme de sortie que
//    le RPC, pour que le rendu ne connaisse qu'une seule forme.
//  - yearsLabel : « 1987 », « 1987–2011 » ou « — ».

export const WORKS_PAGE_SIZE = 50;

function trim(v) { return String(v ?? '').trim(); }

export function buildWorksFilters({
  search, authorFilter, authorIdFilter, alphaFilter, publisherFilter, yearFilter,
  libraryShortNames, availabilityFilter, isAuth, isbnFilter, languageFilter, cddFilter,
  subjectsFilter, materialFilter, collectionFilter, placeFilter, subjectFilter,
}) {
  const f = {};
  if (trim(search)) f.q = trim(search);
  if (trim(alphaFilter)) f.alpha = trim(alphaFilter);
  else if (trim(authorIdFilter)) f.author_id = trim(authorIdFilter);
  else if (trim(authorFilter)) f.author = trim(authorFilter);
  if (trim(publisherFilter)) f.publisher = trim(publisherFilter);

  const yr = trim(yearFilter);
  if (yr) {
    const m = yr.match(/^(\d{4})\s*[-–]\s*(\d{4})$/);
    if (m) { f.year_from = m[1]; f.year_to = m[2]; }
    else f.year = yr;
  }
  if (Array.isArray(libraryShortNames) && libraryShortNames.length) f.libraries = libraryShortNames.filter(Boolean);
  if (trim(isbnFilter)) f.isbn = trim(isbnFilter).replace(/[-\s]/g, '');
  if (trim(languageFilter)) f.language = trim(languageFilter);
  if (trim(cddFilter)) f.cdd = trim(cddFilter);
  if (trim(subjectsFilter)) f.subjects = trim(subjectsFilter);
  if (materialFilter && materialFilter !== '__all__') f.material = materialFilter;
  if (trim(collectionFilter)) f.collection = trim(collectionFilter);
  if (trim(placeFilter)) f.place = trim(placeFilter);
  if (trim(subjectFilter)) f.subject = trim(subjectFilter);
  // Doctrine A1/A2/A3 : aucun critère de disponibilité pour l'anon.
  if (isAuth && availabilityFilter && availabilityFilter !== '__all__') f.availability = availabilityFilter;
  return f;
}

// Le RPC connaît : relevance, status, ano.desc, created_at.desc, autor.asc,
// editora.asc, bib_ref.asc, titulo.asc (défaut). Un tri inconnu retombe sur le
// titre, comme resolveOrder() le fait pour la liste plate.
export function worksSortParam(sortValue) {
  if (!sortValue || sortValue === '__relevance__') return 'relevance';
  if (['status', 'ano.desc', 'created_at.desc', 'autor.asc', 'editora.asc', 'bib_ref.asc', 'titulo.asc'].includes(sortValue)) return sortValue;
  // Un tri descendant sur une colonne texte : on garde l'ascendant du RPC (une
  // seule direction par colonne côté serveur), le titre sert d'ordre secondaire.
  const [col] = String(sortValue).split('.');
  if (['autor', 'editora', 'bib_ref', 'titulo'].includes(col)) return `${col}.asc`;
  if (col === 'ano') return 'ano.desc';
  if (col === 'created_at') return 'created_at.desc';
  return 'titulo.asc';
}

function yearOf(b) {
  const m = String(b?.ano ?? '').match(/\d{4}/);
  return m ? Number(m[0]) : null;
}

export function yearsLabel(min, max) {
  if (min == null && max == null) return '—';
  if (min == null) return String(max);
  if (max == null || min === max) return String(min);
  return `${min}–${max}`;
}

function libraryNamesOf(book) {
  const n = book?.holding_library_names_json;
  try {
    if (!n) return [];
    const p = typeof n === 'string' ? JSON.parse(n) : n;
    if (Array.isArray(p)) return p.filter(Boolean).map(String);
    if (p && typeof p === 'object') return Object.values(p).filter(Boolean).map(String);
  } catch { /* forme inattendue : pas de biblio */ }
  return [];
}

// Regroupe des lignes d'édition (forme des vues catalog_list_*_v1) en œuvres, à
// la forme exacte de api.catalog_works_v1. Ordre : celui des lignes reçues
// (pertinence ou tri serveur), une œuvre prenant la place de sa première ligne.
export function groupBooksIntoWorks(books) {
  const byKey = new Map();
  const order = [];
  for (const b of books || []) {
    const key = b.work_id != null ? String(b.work_id) : String(-Number(b.book_id));
    let g = byKey.get(key);
    if (!g) {
      g = { key, work_id: b.work_id ?? null, editions: [], libs: new Set() };
      byKey.set(key, g); order.push(g);
    }
    g.editions.push(b);
    for (const nm of libraryNamesOf(b)) g.libs.add(nm);
  }
  return order.map(g => {
    const years = g.editions.map(yearOf).filter(y => y != null);
    const rep = g.editions[0];
    const sorted = [...g.editions].sort((a, b) => (yearOf(b) ?? -1) - (yearOf(a) ?? -1) || a.book_id - b.book_id);
    return {
      key: g.key,
      work_id: g.work_id,
      display_title: rep.titulo,
      edition_count: g.editions.length,
      year_min: years.length ? Math.min(...years) : null,
      year_max: years.length ? Math.max(...years) : null,
      rep_book_id: rep.book_id,
      any_available: g.editions.some(e => Number(e.global_available_count) > 0),
      session_available: g.editions.some(e => e.session_status_hint === 'no_acervo_da_sua_biblioteca' && Number(e.session_available_count) > 0),
      library_names: [...g.libs].sort(),
      editions: sorted,
    };
  });
}
