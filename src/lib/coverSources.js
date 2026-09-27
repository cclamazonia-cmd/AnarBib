// ═══════════════════════════════════════════════════════════
// CHEMIN DÉPÔT : src/lib/coverSources.js
//
// Ce que l'écran de catalogage dit après « Chercher une couverture »
// (27/09/2026).
//
// L'EF cover_lookup rend, à côté des candidates, un bilan par source :
// { id, label, count, ok, skipped?, error? }. Le formulaire l'ignorait : la
// voie ISBN, en 404 chez Open Library depuis une date inconnue, s'affichait
// « aucune couverture trouvée » — une panne passait pour un livre introuvable.
//
// On nomme donc les sources qui ont ÉCHOUÉ (ok === false), jamais celles qui
// n'ont simplement pas été interrogées (skipped). Les noms sont des noms
// propres, non traduits ; le `label` de l'EF est en français et sert au
// diagnostic, pas à l'écran.
//
// Et, pour une candidate trouvée par ISBN, on confronte l'édition que l'ISBN
// désigne à la notice (accordEdition, plus bas).
// ═══════════════════════════════════════════════════════════

const NOMS = {
  openlibrary: 'Open Library',
  openlibrary_search: 'Open Library',
  inventaire: 'Inventaire',
  og_image: 'og:image',
};

/** Les sources en échec, telles qu'on les nomme à l'écran (sans doublon). */
export function sourcesEnPanne(sources) {
  const vus = new Set();
  const out = [];
  for (const s of Array.isArray(sources) ? sources : []) {
    if (!s || s.ok !== false) continue;
    const nom = NOMS[s.id] || String(s.id || '?');
    const texte = s.error ? `${nom} (${s.error})` : nom;
    if (vus.has(texte)) continue;
    vus.add(texte);
    out.push(texte);
  }
  return out;
}

/**
 * Le message à afficher après une recherche, ou null s'il n'y a rien à dire
 * (des candidates, et toutes les sources interrogées ont répondu).
 * @returns {{ id: string, values?: object, kind: 'error'|'info' } | null}
 */
export function messageRechercheCapas(data) {
  const n = Array.isArray(data?.candidates) ? data.candidates.length : 0;
  const enPanne = sourcesEnPanne(data?.sources);
  if (!n) {
    return enPanne.length
      ? { id: 'catalogacao.ui.coverLookupSourcesDown', values: { sources: enPanne.join(', ') }, kind: 'error' }
      : { id: 'catalogacao.ui.coverLookupEmpty', kind: 'info' };
  }
  return enPanne.length
    ? { id: 'catalogacao.ui.coverLookupPartial', values: { sources: enPanne.join(', ') }, kind: 'info' }
    : null;
}

// ─── L'édition que désigne l'ISBN concorde-t-elle avec la notice ? ─────────
//
// Pourquoi (27/09/2026). La notice BTL-TL-002335 décrit l'édition Ramparts
// Press de 1971, mais porte l'ISBN de l'édition AK Press de 2004. La galerie
// tenait l'ISBN pour certain et n'affichait que le titre : elle a proposé la
// couverture de 2004 sans rien signaler. Même ISBN sur deux notices d'éditions
// différentes : trois cas au catalogue ce jour-là.
//
// La règle : écart dès que l'année diffère de plus d'un an, ou que les
// éditeurs n'ont aucun mot en commun (une fois ôtés les mots génériques). Un
// écart n'accuse pas l'ISBN : une réimpression garde souvent le sien (Cultrix,
// « Curso de Linguística Geral » : 2002 chez Open Library, 2007 au fonds).
// L'écran le dit tel quel, et laisse la personne trancher.

/** Première année plausible (1500–2099) d'une date libre : « c1971 », « March 2004 ». */
export function anneeDe(texte) {
  const m = String(texte ?? '').match(/(1[5-9]|20)\d{2}/);
  return m ? Number(m[0]) : null;
}

const MOTS_GENERIQUES = new Set((
  'editora editorial editoriale ediciones edicions edicoes edicao edition editions edizioni editore '
  + 'editori editores editor edit eds press presses books book libros livros livres publicacoes '
  + 'publications publishing publishers publisher verlag casa ltda cia companhia compania grupo '
  + 'libreria livraria distribuidora colecao collection coleccion the of and de do da dos das del '
  + 'la le les el los las lo et und di della'
).split(' '));

/** Les mots qui nomment un éditeur, sans accents ni mots génériques. */
export function motsEditeur(texte) {
  return new Set(String(texte ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .split(/[^a-z0-9]+/).filter((m) => m.length > 1 && !MOTS_GENERIQUES.has(m)));
}

/** « AK Press, 2004 » */
export function designationEdition(editeurs, annee) {
  return [(editeurs || []).filter(Boolean).join(', '), annee].filter(Boolean).join(', ');
}

/**
 * Confronte l'édition désignée par l'ISBN d'une candidate à la notice.
 * @returns {null | { statut: 'concordant'|'ecart'|'inconnu', ecartAnnee: boolean,
 *   ecartEditeur: boolean, trouvee: string, notice: string }}
 *   null pour une candidate qui n'est pas passée par l'ISBN (pas d'`edition`).
 */
export function accordEdition(candidate, notice) {
  const ed = candidate?.edition;
  if (!ed) return null;
  const aTrouvee = anneeDe(ed.annee);
  const aNotice = anneeDe(notice?.ano);
  const mTrouves = new Set();
  for (const e of ed.editeurs || []) for (const m of motsEditeur(e)) mTrouves.add(m);
  const mNotice = motsEditeur(notice?.editora);

  const anneeComparable = aTrouvee !== null && aNotice !== null;
  const editeurComparable = mTrouves.size > 0 && mNotice.size > 0;
  const ecartAnnee = anneeComparable && Math.abs(aTrouvee - aNotice) > 1;
  const ecartEditeur = editeurComparable && ![...mTrouves].some((m) => mNotice.has(m));
  let statut = 'inconnu';
  if (ecartAnnee || ecartEditeur) statut = 'ecart';
  else if (anneeComparable || editeurComparable) statut = 'concordant';

  return {
    statut, ecartAnnee, ecartEditeur,
    trouvee: designationEdition(ed.editeurs, ed.annee),
    notice: designationEdition([String(notice?.editora ?? '').trim()], aNotice ?? String(notice?.ano ?? '').trim()),
  };
}
