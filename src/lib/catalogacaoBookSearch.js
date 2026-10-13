// Recherche de l'onglet « Catalogue(s) publié(s) › Documents » du catalogage
// (13/10/2026, demande de Xavier : « comme dans l'OPAC »).
//
// La barre faisait un ILIKE PostgREST de la saisie ENTIÈRE sur titre,
// auteur·rice, ISBN et référence : deux mots, un autre nom de l'autorité
// (« kropotkine »), une lettre de travers ou un ISBN tapé sans ses tirets ne
// trouvaient rien. Elle passe désormais par api.catalogacao_book_ids_v1
// (migration 20261013062921) : les règles de la recherche de l'OPAC
// (catalog_search_ids_v1 — chaque mot quelque part dans la notice, variantes
// et alias de l'autorité liée, une ou deux lettres près si rien d'exact), plus
// l'ISBN avec ou sans tirets et ISBN-10 ↔ ISBN-13 — mais sur public.books en
// direct : une notice qu'on vient de publier n'est pas encore dans la vue
// matérialisée de l'OPAC. Jusqu'à 500 notices classées par pertinence ; un
// rang négatif veut dire « approché ».
//
// Si la porte ne répond pas : null, et l'écran retombe sur l'ILIKE d'avant —
// jamais pire que l'existant.
import { apiRpc } from '@/lib/supabase';

export async function chercherDocumentsPublies(saisie) {
  const q = String(saisie || '').trim();
  if (!q) return null;
  try {
    const { data, error } = await apiRpc('catalogacao_book_ids_v1', { p_q: q });
    if (error || !Array.isArray(data)) return null;
    return {
      ids: data.map(r => r.book_id),
      approx: data.length > 0 && data.every(r => Number(r.rank) < 0),
    };
  } catch {
    return null;
  }
}

// PostgREST rend un filtre `in.(…)` dans son ordre à lui : remettre les
// lignes d'une page dans l'ordre du rang.
export function ordonnerSelonIds(lignes, ids) {
  const pos = new Map(ids.map((id, i) => [Number(id), i]));
  return [...(lignes || [])].sort((a, b) => (pos.get(Number(a.id)) ?? ids.length) - (pos.get(Number(b.id)) ?? ids.length));
}
