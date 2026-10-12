// ═══════════════════════════════════════════════════════════
// AnarBib — H34 lot 2 (12/10/2026, REGISTRE IMP-36) : un lot approuvé se
// publie par pages. Module pur (sans React ni icône).
//
// public.publish_catalog_batch publie au plus une page par appel (borne en
// base : private.fn_h34_page_de_publication, 60 notices et 400 exemplaires ;
// une notice et ses exemplaires ne se séparent jamais) et rend
// {books_published, authors_published, exemplars_published, done, remaining,
// page}. Tant que done vaut false, le lot est « publishing » : le geste
// rappelle la RPC jusqu'au bout. Une page refusée n'écrit rien ; les pages
// d'avant restent publiées ; un nouvel appel reprend la page refusée.
// Une réponse sans « done » (base d'avant le lot 2) vaut une seule page.
// ═══════════════════════════════════════════════════════════
import { cumulerReponses } from './importItemUpdates.js';

// Garde-fou de la boucle : jamais un geste sans fin si la base répondait
// toujours done=false (un lot de 50 000 notices en ferait 500).
export const PAGES_PUBLICATION_MAX = 2000;

// Notices (fiches et autorités) d'une réponse cumulée.
export function noticesPubliees(cumul) {
  return Number(cumul?.books_published || 0) + Number(cumul?.authors_published || 0);
}

// Exemplaires publiés d'une réponse cumulée : ceux qui partent avec leur notice
// ne sont pas comptés à part par la base — la page les compte (page.exemplaires).
export function exemplairesPublies(reponses) {
  let n = 0;
  for (const r of Array.isArray(reponses) ? reponses : []) {
    if (!r || typeof r !== 'object') continue;
    n += r.page && Number.isFinite(Number(r.page.exemplaires)) ? Number(r.page.exemplaires) : Number(r.exemplars_published || 0);
  }
  return n;
}

// Le total de notices du geste, lu sur la première réponse : ce que la page a
// publié plus ce qui reste.
export function noticesAPublier(premiere) {
  if (!premiere || typeof premiere !== 'object') return 0;
  const reste = premiere.remaining || {};
  return noticesPubliees(premiere) + Number(reste.books || 0) + Number(reste.authors || 0);
}

// Enchaîne les pages. appeler() rend la réponse d'une page ou lève (l'erreur
// telle que la RPC l'a rendue). surPage({page, cumul, total, notices,
// exemplaires}) suit l'avancement. Rend {ok, pages, reponses, cumul, total,
// notices, exemplaires, erreur?, pageRefusee?}.
export async function publierLotParPages(appeler, { surPage, maxPages = PAGES_PUBLICATION_MAX } = {}) {
  const reponses = [];
  let total = 0;
  const bilan = (extra) => {
    const cumul = cumulerReponses(reponses);
    return { pages: reponses.length, reponses, cumul, total, notices: noticesPubliees(cumul),
             exemplaires: exemplairesPublies(reponses), ...extra };
  };
  for (let page = 1; page <= maxPages; page += 1) {
    let data;
    try {
      data = await appeler(page);
    } catch (erreur) {
      return bilan({ ok: false, erreur, pageRefusee: page });
    }
    const r = data && typeof data === 'object' ? data : {};
    reponses.push(r);
    if (page === 1) total = noticesAPublier(r);
    const b = bilan({});
    if (typeof surPage === 'function') surPage({ page, cumul: b.cumul, total, notices: b.notices, exemplaires: b.exemplaires });
    if (r.done !== false) return bilan({ ok: true });
  }
  return bilan({ ok: false, erreur: new Error('publication: too many pages'), pageRefusee: maxPages + 1 });
}
