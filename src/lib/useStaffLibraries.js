import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

// B29 (REGISTRE CAT-E18, 27/09/2026) — les bibliothèques où la personne a une
// adhésion de staff ACTIVE : celles dont elle peut voir et modifier les
// brouillons (la base applique la même règle, fn_caller_staff_library_ids).
// Sert à ne proposer, dans les menus, que les bibliothèques où un brouillon
// peut être rangé ; l'administration du réseau garde toutes les bibliothèques.
// Mis en cache PAR PERSONNE (un changement de compte dans l'onglet ne sert pas
// les bibliothèques de la précédente), cinq minutes (une adhésion accordée ou
// retirée se voit sans recharger la page) ; un échec n'est PAS mis en cache et
// se distingue d'une liste vide (null) — sinon une coupure réseau d'une
// seconde vidait les menus pour la session.
//
// B30 (27/09/2026) — même mécanique pour les bibliothèques que la personne
// COORDONNE (fn_caller_coordinator_library_ids : rôles coordenador et
// administrador, adhésions actives) : supprimer un lot, en demander la
// révision. Une clé de cache par fonction ET par personne.
const cache = new Map();
const DUREE_MS = 5 * 60 * 1000;
const NOUVEL_ESSAI_MS = 5000;

function chargerListe(rpc, userId) {
  if (!userId) return Promise.resolve([]);
  const cle = `${rpc}:${userId}`;
  const entree = cache.get(cle);
  if (entree && Date.now() - entree.t < DUREE_MS) return entree.p;
  const p = supabase.rpc(rpc)
    .then(({ data, error }) => {
      if (error || !Array.isArray(data)) throw error || new Error(rpc);
      return data;
    })
    .catch(() => {
      if (cache.get(cle)?.p === p) cache.delete(cle);
      return null;
    });
  cache.set(cle, { p, t: Date.now() });
  return p;
}

export function chargerStaffLibraries(userId) {
  return chargerListe('fn_caller_staff_library_ids', userId);
}

export function chargerCoordLibraries(userId) {
  return chargerListe('fn_caller_coordinator_library_ids', userId);
}

function useListeDeBibliotheques(charger) {
  const { user } = useAuth();
  const userId = user?.id || null;
  const [etat, setEtat] = useState({ userId: null, ids: null });
  // Relecture : après un échec (5 s), toutes les cinq minutes, au retour sur
  // l'onglet ou du réseau.
  const [tick, setTick] = useState(0);
  useEffect(() => {
    let annule = false;
    let relance = null;
    charger(userId).then((d) => {
      if (annule) return;
      if (d === null) { relance = setTimeout(() => setTick((x) => x + 1), NOUVEL_ESSAI_MS); return; }
      setEtat({ userId, ids: d });
    });
    return () => { annule = true; if (relance) clearTimeout(relance); };
  }, [userId, tick, charger]);
  useEffect(() => {
    const relire = () => setTick((x) => x + 1);
    const minuteur = setInterval(relire, DUREE_MS);
    window.addEventListener('focus', relire);
    window.addEventListener('online', relire);
    return () => {
      clearInterval(minuteur);
      window.removeEventListener('focus', relire);
      window.removeEventListener('online', relire);
    };
  }, []);
  const pret = etat.userId === userId && etat.ids !== null;
  return { ids: pret ? etat.ids : [], loaded: pret };
}

export function useStaffLibraries() {
  const { ids, loaded } = useListeDeBibliotheques(chargerStaffLibraries);
  return { staffLibraryIds: ids, loaded };
}

export function useCoordLibraries() {
  const { ids, loaded } = useListeDeBibliotheques(chargerCoordLibraries);
  return { coordLibraryIds: ids, loaded };
}

// Bibliothèques proposables pour ranger un brouillon : toutes pour l'admin,
// sinon celles où l'on est staff — plus la valeur déjà posée, pour ne jamais
// masquer ce qui est enregistré.
export function bibliothequesProposables(toutes, { isNetworkAdmin, staffLibraryIds, garder = null }) {
  const liste = Array.isArray(toutes) ? toutes : [];
  if (isNetworkAdmin) return liste;
  return liste.filter((l) => staffLibraryIds.includes(l.id) || (garder && l.id === garder));
}

// B30 (27/09/2026) — le lot a SA bibliothèque (catalog_batches.library_id ;
// nulle = lot de l'administration du réseau). Un brouillon ne se range que
// dans un lot de SA bibliothèque ; la base tranche, l'écran ne propose que ce
// qu'elle acceptera.
//
// Lots OUVERTS où ranger un brouillon de la bibliothèque `libraryId` :
//   * administration du réseau : tous les lots ouverts ;
//   * liste de staff inconnue (staffLibraryIds null : pas encore chargée, ou
//     en échec) : tous les lots ouverts — on ne filtre pas à l'aveugle ;
//   * bibliothèque du brouillon connue : les lots ouverts de cette bibliothèque ;
//   * inconnue (brouillon neuf d'une personne staff de plusieurs
//     bibliothèques) : les lots ouverts de ses bibliothèques de staff.
// Le lot `garder` (celui qui est enregistré) reste TOUJOURS proposé, même
// clos, d'une autre bibliothèque ou invisible : sinon le select afficherait
// « Sans lot » alors que le formulaire renvoie batch_id intact. Invisible, il
// revient sous la forme { id, _inconnu: true }.
export function lotsProposables(batches, { isNetworkAdmin = false, staffLibraryIds = null, libraryId = null, garder = null } = {}) {
  const liste = Array.isArray(batches) ? batches : [];
  const ouverts = liste.filter((b) => b.status === 'open');
  // Colonne absente (écran publié avant la migration) : bibliothèque du lot
  // inconnue, on ne l'écarte pas.
  const inconnue = (b) => b.library_id === undefined;
  let retenus;
  if (isNetworkAdmin || !Array.isArray(staffLibraryIds)) retenus = ouverts;
  else if (libraryId) retenus = ouverts.filter((b) => inconnue(b) || b.library_id === libraryId);
  else retenus = ouverts.filter((b) => inconnue(b) || (b.library_id != null && staffLibraryIds.includes(b.library_id)));
  const g = garder === null || garder === undefined || garder === '' ? null : String(garder);
  if (g && !retenus.some((b) => String(b.id) === g)) {
    const enregistre = liste.find((b) => String(b.id) === g);
    retenus = [...retenus, enregistre || { id: g, _inconnu: true }];
  }
  return retenus;
}

// Le lot est-il rangeable pour ce brouillon ? (vide la sélection quand la
// bibliothèque du brouillon change.) Admin, ou bibliothèque inconnue : oui.
export function lotDeLaBibliotheque(batch, libraryId) {
  if (!batch || !libraryId) return true;
  if (batch.library_id === undefined) return true;   // colonne absente (écran publié avant la migration)
  return batch.library_id === libraryId;
}

// Partage d'une sélection avant de la ranger dans `lot` (menu « Affecter au
// lot » de la file). `info` : Map `${type}:${id}` → { lib, importe }, où lib
// est owner_library_id d'une notice, target_library_id d'un exemplaire saisi.
//   * une autorité (sans bibliothèque) part si l'on peut ranger dans ce lot ;
//   * un exemplaire importé suit sa notice : il ne part pas (il est compté
//     dans « certains éléments n'ont pas changé ») ;
//   * une bibliothèque INCONNUE part aussi : élément non relu (relecture en
//     échec, brouillon hors de portée) ou colonne NULLE (brouillon d'avant
//     B29, que ni B29 ni B30 n'a rempli). La base le juge sur sa bibliothèque
//     RÉSOLUE (celle de son créateur) et, si elle refuse, le laisse dans son
//     ancien lot sans erreur ;
//   * seule une bibliothèque CONNUE et différente de celle du lot est écartée
//     d'avance, et comptée dans `autres`.
export function partagerPourLeLot(sel, lot, info, { autoritesRangeables = true } = {}) {
  const aEnvoyer = [];
  let autres = 0;
  const duLot = lot?.library_id ?? null;
  for (const s of Array.isArray(sel) ? sel : []) {
    if (s.type === 'author') {
      if (autoritesRangeables) aEnvoyer.push(s); else autres++;
      continue;
    }
    const i = info?.get(`${s.type}:${s.id}`);
    if (s.type === 'exemplar' && i?.importe) continue;
    if (i?.lib != null && i.lib !== duLot) autres++;
    else aEnvoyer.push(s);
  }
  return { aEnvoyer, autres };
}

// Brouillons en cours d'un lot qui sont d'une AUTRE bibliothèque que la sienne
// (lignes de fn_batch_owner_libraries : { library_id, drafts }). La fonction
// rend owner_library_id BRUT : une ligne NULLE (notice d'avant B29, jamais
// remplie) n'est pas « d'une autre bibliothèque » — sa bibliothèque réelle est
// celle de son créateur, que l'écran ne connaît pas, et c'est souvent elle qui
// a donné au lot la sienne à la reprise. On ne compte que les bibliothèques
// CONNUES et différentes ; pour un lot de l'administration (library_id nulle),
// toute bibliothèque connue compte. Colonne absente (écran publié avant la
// migration) : rien.
export function brouillonsDAutresBibliotheques(batch, lignes) {
  if (!batch || batch.library_id === undefined) return 0;
  const duLot = batch.library_id ?? null;
  return (Array.isArray(lignes) ? lignes : [])
    .filter((r) => r.library_id != null && r.library_id !== duLot)
    .reduce((s, r) => s + Number(r.drafts || 0), 0);
}

// B30 : rouvrir la révision d'un lot importé, approuvé et encore ouvert —
// l'administration seule (un nouveau tour : la publication est de nouveau
// bloquée ; c'est la sortie qu'annonce le refus de réattribution sous
// approbation).
export function peutRouvrirRevision(review, batch, isNetworkAdmin) {
  return !!isNetworkAdmin && !!review?.imported && review.status === 'approved' && batch?.status === 'open';
}

// Nom de la bibliothèque DU LOT : nom court, sinon nom ; un lot sans
// bibliothèque est celui de l'administration du réseau (clé i18n). Colonne
// absente (écran publié avant la migration) : rien.
export function bibliothequeDuLot(batch, t) {
  if (!batch || batch.library_id === undefined || batch._inconnu) return '';
  if (batch.library_id === null) return t({ id: 'catalogacao.batch.library.network' });
  return batch.library?.short_name || batch.library?.name || '';
}

// Libellé d'un lot dans un menu : « nom — bibliothèque ». Un lot invisible
// (enregistré mais hors de portée) garde son numéro : « lot 57 ».
export function libelleLot(batch, t) {
  if (!batch) return '';
  if (batch._inconnu) return t({ id: 'catalogacao.queue.batchPrefix' }, { id: batch.id });
  const bib = bibliothequeDuLot(batch, t);
  return bib ? `${batch.name} — ${bib}` : batch.name;
}
