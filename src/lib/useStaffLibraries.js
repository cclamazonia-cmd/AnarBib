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
const cache = new Map();
const DUREE_MS = 5 * 60 * 1000;
const NOUVEL_ESSAI_MS = 5000;

export function chargerStaffLibraries(userId) {
  if (!userId) return Promise.resolve([]);
  const entree = cache.get(userId);
  if (entree && Date.now() - entree.t < DUREE_MS) return entree.p;
  const p = supabase.rpc('fn_caller_staff_library_ids')
    .then(({ data, error }) => {
      if (error || !Array.isArray(data)) throw error || new Error('fn_caller_staff_library_ids');
      return data;
    })
    .catch(() => {
      if (cache.get(userId)?.p === p) cache.delete(userId);
      return null;
    });
  cache.set(userId, { p, t: Date.now() });
  return p;
}

export function useStaffLibraries() {
  const { user } = useAuth();
  const userId = user?.id || null;
  const [etat, setEtat] = useState({ userId: null, ids: null });
  // Relecture : après un échec (5 s), toutes les cinq minutes, au retour sur
  // l'onglet ou du réseau.
  const [tick, setTick] = useState(0);
  useEffect(() => {
    let annule = false;
    let relance = null;
    chargerStaffLibraries(userId).then((d) => {
      if (annule) return;
      if (d === null) { relance = setTimeout(() => setTick((x) => x + 1), NOUVEL_ESSAI_MS); return; }
      setEtat({ userId, ids: d });
    });
    return () => { annule = true; if (relance) clearTimeout(relance); };
  }, [userId, tick]);
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
  return { staffLibraryIds: pret ? etat.ids : [], loaded: pret };
}

// Bibliothèques proposables pour ranger un brouillon : toutes pour l'admin,
// sinon celles où l'on est staff — plus la valeur déjà posée, pour ne jamais
// masquer ce qui est enregistré.
export function bibliothequesProposables(toutes, { isNetworkAdmin, staffLibraryIds, garder = null }) {
  const liste = Array.isArray(toutes) ? toutes : [];
  if (isNetworkAdmin) return liste;
  return liste.filter((l) => staffLibraryIds.includes(l.id) || (garder && l.id === garder));
}
