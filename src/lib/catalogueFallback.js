// ===========================================================================
// catalogueFallback.js — mode dégradé du catalogue
// ---------------------------------------------------------------------------
// Quand l'API ne répond plus, le catalogue reste consultable grâce à un
// instantané statique embarqué dans le build (`public/catalogue-snapshot.json`,
// produit par scripts/build-catalogue-snapshot.mjs). Le front étant servi par
// Codeberg Pages, il reste debout même si Supabase est indisponible.
//
// Portée VOLONTAIREMENT limitée : consulter et chercher. Pas de réservation,
// pas de compte, pas de disponibilité en temps réel — l'instantané date du
// dernier déploiement. C'est un filet, pas un remplacement.
//
// Les notices ont la même forme que les lignes de `api.catalog_list_anon_v1`,
// la vue qu'interroge déjà CatalogPage pour les visiteurs anonymes : elles se
// substituent donc sans conversion.
// ===========================================================================

const CHEMIN = `${import.meta.env.BASE_URL || '/'}catalogue-snapshot.json`.replace(/\/{2,}/g, '/');

let cache = null;      // { genere_le, livres }
let enCours = null;    // promesse partagée, pour ne pas télécharger deux fois

/** Charge (une seule fois) l'instantané. Renvoie null s'il est absent. */
export async function chargerInstantane() {
  if (cache) return cache;
  if (enCours) return enCours;
  enCours = (async () => {
    try {
      const r = await fetch(CHEMIN, { cache: 'no-cache' });
      if (!r.ok) return null;
      const j = await r.json();
      if (!j || !Array.isArray(j.livres)) return null;
      cache = j;
      return cache;
    } catch {
      return null;
    } finally {
      enCours = null;
    }
  })();
  return enCours;
}

function normaliser(v) {
  return String(v ?? '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, ''); // insensible aux accents, comme la recherche serveur
}

/**
 * Recherche multi-mots dans l'instantané. Chaque mot doit apparaître quelque
 * part dans la notice (titre, auteur, éditeur, ISBN, collection, sujets) —
 * même esprit que la recherche serveur, en beaucoup plus rudimentaire.
 */
export function rechercherDansInstantane(livres, texte) {
  const mots = normaliser(texte).split(/\s+/).filter(Boolean);
  if (!mots.length) return livres;
  return livres.filter((l) => {
    const foin = normaliser(
      [l.titulo, l.subtitulo, l.autor, l.author_display, l.editora, l.publisher_display,
       l.isbn, l.issn, l.colecao, l.assuntos, l.bib_ref, l.ano].join(' '),
    );
    return mots.every((m) => foin.includes(m));
  });
}

/**
 * Point d'entrée utilisé par CatalogPage quand l'appel API a échoué.
 * Renvoie { livres, genereLe } ou null si aucun instantané n'est disponible.
 */
export async function catalogueDeSecours(texteRecherche) {
  const inst = await chargerInstantane();
  if (!inst) return null;
  const livres = rechercherDansInstantane(inst.livres, texteRecherche || '');
  return { livres, genereLe: inst.genere_le, total: livres.length };
}

/** Une notice précise, pour la fiche livre en mode dégradé. */
export async function ficheDeSecours(bookId) {
  const inst = await chargerInstantane();
  if (!inst) return null;
  const id = Number(bookId);
  return inst.livres.find((l) => Number(l.book_id) === id) || null;
}
