// AnarBib — les aides de la file du catalogage (QueuePanel).
// E6 (19/10/2026) : sorties telles quelles de QueuePanel.jsx ; seules les
// déclarations de premier niveau sont devenues exportées.
import { supabase } from '@/lib/supabase';

// Labels resolved inside component via t()
export const TYPE_KEYS = { book: 'catalogacao.type.book', author: 'catalogacao.type.author', exemplar: 'catalogacao.type.exemplar' };
export const STATUS_KEYS = { draft: 'catalogacao.status.draft', ready: 'catalogacao.status.ready', published: 'catalogacao.status.published', cancelled: 'catalogacao.status.cancelled' };
export const PAGE_SIZE = 100;

// Les gestes de masse passaient UNE requete PAR LIGNE : jeter 300 brouillons,
// c'etait 300 allers-retours, et la vue ne se reconciliait qu'a la toute fin
// (d'ou l'impression tenace qu'il faut recharger la page plusieurs fois).
// PostgREST accepte un filtre `in` sur une liste d'ids : une requete par
// paquet suffit.
export const TABLE_FOR = { book: 'book_drafts', author: 'author_drafts', exemplar: 'exemplar_drafts' };
export const ID_CHUNK = 200;

// Portee d'un geste de corbeille : '' = toute la corbeille (donc tout le
// reseau, la corbeille n'etant cloisonnee ni par lot ni par bibliotheque),
// 'none' = les brouillons sans lot, sinon l'id d'un lot. Meme vocabulaire que
// le filtre de la file au-dessus, pour que les deux se lisent pareil.
//
// Ce qui est repare ici n'est pas un droit mais une PORTEE : « Vider la
// corbeille » atteignait 259 brouillons de 5 bibliotheques la ou on voulait
// nettoyer un seul lot (28/08/2026). Le bouton porte desormais exactement sur
// ce que la liste affiche, et la confirmation nomme cette portee.
export function scopeToBatch(q, batch) {
  if (batch === 'none') return q.is('batch_id', null);
  if (batch) return q.eq('batch_id', Number(batch));
  return q;
}

export function chunkIds(ids, size = ID_CHUNK) {
  const out = [];
  for (let i = 0; i < ids.length; i += size) out.push(ids.slice(i, i + size));
  return out;
}

// Rend le nombre de lignes REELLEMENT traitees : un paquet en echec ne compte
// pas, la ou le `catch {}` par ligne des boucles d'origine incrementait quand
// meme et pouvait annoncer « 300 traites » sans que rien ne bouge.
// Rendre la propriete LISIBLE : depuis B29 les rascunhos sont cloisonnes par
// bibliotheque (une autorite, commun federal, reste lisible de tous), et depuis
// B30 chaque lot porte la sienne (catalog_batches.library_id, nulle pour
// l'administration du reseau) — on dit A QUI appartient le travail qu'on
// s'apprete a toucher.
//
// La destination vient de la vue v_book_draft_destination, qui appelle la MEME
// fonction que la publication : afficher une destination calculee autrement
// serait pire que ne rien afficher — on ferait confiance a une information
// fausse. `enregistree` distingue ce que le rascunho declare de ce qui est
// seulement deduit de l'adhesion de qui a catalogue.
export async function attacherDestinations(items) {
  const ids = items.filter(it => it._type === 'book').map(it => it.id);
  if (!ids.length) return items;
  try {
    const { data } = await supabase.from('v_book_draft_destination')
      .select('draft_id, library_id, enregistree').in('draft_id', ids);
    const par = new Map((data || []).map(r => [r.draft_id, r]));
    for (const it of items) {
      if (it._type !== 'book') continue;
      const d = par.get(it.id);
      if (d) { it._libId = d.library_id; it._libEnregistree = d.enregistree; }
    }
  } catch { /* l information de propriete est un confort, pas un pre-requis */ }
  return items;
}

// `compter` (facultatif) : compte les lignes RENDUES par la requête qui ont
// réellement changé, au lieu des ids demandés. H19 : un exemplaire importé suit
// sa notice ; restauré ou déplacé seul, il peut ne pas bouger (déclencheur
// exemplar_drafts_import_links_locked), et l'écran ne doit pas l'annoncer.
// `erreurs` (facultatif) recueille les refus de la base, pour les DIRE (B29 :
// ranger dans le lot d'une autre bibliothèque) au lieu de « certains
// éléments n'ont pas changé ».
export async function bulkByType(sel, run, compter = null, erreurs = null) {
  const byType = new Map();
  for (const { type, id } of sel) {
    if (!byType.has(type)) byType.set(type, []);
    byType.get(type).push(id);
  }
  let ok = 0;
  for (const [type, ids] of byType) {
    for (const part of chunkIds(ids)) {
      const { data, error } = await run(TABLE_FOR[type], part);
      if (error) erreurs?.push(error);
      else ok += (compter && Array.isArray(data)) ? compter(data) : part.length;
    }
  }
  return ok;
}
// Colonnes physiques présentes dans les 3 tables brouillon → triables côté serveur.
export const SERVER_SORT_COLS = ['updated_at', 'last_opened_at', 'status'];
// Largeurs de colonnes partagées entre l'en-tête cliquable et les lignes (alignement).
export const COLW = { check: 16, type: 66, status: 78, opened: 80, updated: 84, actions: 210 };

// Comparateur de la file fusionnée (multi-couches) selon la colonne de tri choisie.
// Les colonnes physiques sont aussi poussées au serveur (cf. loadQueue) pour cadrer
// la fenêtre ; ce tri client réordonne la fusion des 3 couches de façon cohérente.
export function makeComparator(sortBy, sortDir) {
  const dir = sortDir === 'asc' ? 1 : -1;
  return (a, b) => {
    if (sortBy === 'last_opened_at') {
      const ta = a.last_opened_at ? new Date(a.last_opened_at).getTime() : null;
      const tb = b.last_opened_at ? new Date(b.last_opened_at).getTime() : null;
      if (ta === null && tb === null) return 0;
      if (ta === null) return 1;   // jamais ouvert → toujours en bas
      if (tb === null) return -1;
      return (ta - tb) * dir;
    }
    if (sortBy === 'type' || sortBy === 'label' || sortBy === 'status') {
      const key = sortBy === 'type' ? '_type' : sortBy === 'label' ? '_label' : 'status';
      const va = (a[key] || '').toString().toLowerCase();
      const vb = (b[key] || '').toString().toLowerCase();
      return va < vb ? -dir : va > vb ? dir : 0;
    }
    return (new Date(a.updated_at).getTime() - new Date(b.updated_at).getTime()) * dir;  // updated_at (défaut)
  };
}
