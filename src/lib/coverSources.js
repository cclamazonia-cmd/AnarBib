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
