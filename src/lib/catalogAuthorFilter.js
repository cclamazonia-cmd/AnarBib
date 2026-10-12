// Filtre auteur·rice de la « Liste plate » du catalogue.
//
// Le catalogue par œuvre (api.catalog_works_v1) applique ce filtre côté
// serveur ; la liste plate, elle, bâtit un filtre PostgREST (buildServerFilters)
// et doit d'abord résoudre le nom saisi. Sorti de CatalogPage.jsx le 12/10/2026
// (la page est plafonnée à 65 Ko par catalog-lots-3-4.test.jsx).
//
// Deux chemins, dans cet ordre :
//   1. api.catalog_author_book_ids_v1 (12/10/2026, suite d'E38) rend les
//      NOTICES retenues par la règle exacte de catalog_works_v1 : chaque mot
//      dans le texte de la notice OU une autorité liée qui porte ce nom
//      (variantes, alias) ; si rien dans tout le catalogue, la même recherche à
//      une ou deux lettres près, sur le texte de TOUTES les notices — celles
//      sans autorité liée comprises. Jusqu'à 500 notices, la page se contraint
//      par leurs book_id.
//   2. Au-delà de 500 (un filtre d'une lettre) ou si la porte ne répond pas :
//      E38 (60ffe977) — api.catalog_author_ids_v1 résout le nom en autorités,
//      exact puis approché, et buildServerFilters les ajoute en OU de l'ILIKE
//      mot à mot, paginé. Jamais de liste tronquée, jamais pire que l'ILIKE seul.
import { apiRpc } from '@/lib/supabase';

export const PLAFOND_NOTICES_AUTEUR = 500;

export async function resoudreFiltreAuteur({ author, authorIdFilter, alphaFilter }) {
  const nom = String(author || '').trim();
  const res = { authorBookIds: null, authorIds: null, approx: false };
  // jamais quand un identifiant est déjà choisi, ni pendant le parcours A–Z
  if (!nom || String(authorIdFilter || '').trim() || String(alphaFilter || '').trim()) return res;

  try {
    const { data: ab, error: abErr } = await apiRpc('catalog_author_book_ids_v1', { p_name: nom });
    if (!abErr && Array.isArray(ab) && ab.length <= PLAFOND_NOTICES_AUTEUR) {
      res.authorBookIds = ab.map(r => r.book_id);
      res.approx = ab.length > 0 && Boolean(ab[0].approx);
      return res;
    }
  } catch { /* repli E38 ci-dessous */ }

  try {
    const { data: exact } = await apiRpc('catalog_author_ids_v1', { p_name: nom });
    res.authorIds = Array.isArray(exact) ? exact : [];
    if (res.authorIds.length === 0) {
      const { data: proches } = await apiRpc('catalog_author_ids_v1', { p_name: nom, p_approche: true });
      if (Array.isArray(proches) && proches.length > 0) { res.authorIds = proches; res.approx = true; }
    }
  } catch { res.authorIds = null; /* repli : l'ILIKE seul, jamais pire que l'existant */ }
  return res;
}

// Contrainte book_id = intersection des listes actives (null = inactive). La
// première liste active donne l'ordre — la recherche libre vient en tête pour
// garder son rang. null si aucune liste n'est active.
export function intersecterContraintes(listes) {
  const actives = listes.filter(l => l !== null && l !== undefined);
  if (actives.length === 0) return null;
  const [tete, ...autres] = actives;
  const ensembles = autres.map(l => new Set(l));
  return tete.filter(id => ensembles.every(s => s.has(id)));
}
