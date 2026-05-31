import { useEffect, useMemo, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { useAuth } from '@/contexts/AuthContext';

/**
 * Hook useBookAvailability (chantier #CL.1 + #CL.9, 31/05/2026)
 *
 * Retourne une Map<book_id, availabilityRow> indexant la disponibilité
 * courante et prospective de chaque livre demandé, dans la biblio par
 * défaut de la lectrice (api.my_access.default_library_id).
 *
 * **Note de nommage importante** : ce hook ne remplace PAS le hook
 * `useAccountAvailability` qui existe par ailleurs et qui sert à la matrice
 * de masquage des onglets/chips selon le profil de biblio. Les deux
 * cohabitent et traitent deux dimensions distinctes :
 *  - `useAccountAvailability` → quels onglets afficher (matrice profil biblio)
 *  - `useBookAvailability`    → état de stock de N livres (matrice livre)
 *
 * **Doctrine** : la dispo affichée est celle de la biblio par défaut
 * (Lecture α, décision validation par-appartenance du 30/05/2026). Pour les
 * comptes multi-biblios, c'est intentionnel — chaque biblio est souveraine,
 * et l'historique d'un livre emprunté ailleurs affiche la dispo *dans la
 * biblio courante*, pas dans la biblio d'origine.
 *
 * **Source backend** : RPC `public.fn_v2_book_session_availability_for_current_user(p_book_ids bigint[])`
 * existante depuis le paquet L5 (12/05/2026, livraison silencieuse), permissions
 * `authenticated` confirmées. Pattern d'appel inspiré de BookPage.jsx:191.
 *
 * **Pattern d'utilisation** :
 *   const { availabilityMap, loading } = useBookAvailability([42, 1337, 7]);
 *   const dispo = availabilityMap.get(book.id); // → availabilityRow | undefined
 *
 * **Forme d'une `availabilityRow`** (cf. définition RPC) :
 *   {
 *     book_id, bib_ref,
 *     session_library_id, session_library_slug, session_library_name,
 *     session_holding_id, session_local_bib_ref,
 *     session_loanable,         // boolean — prêt autorisé ou consultation seule
 *     session_status_hint,      // 'sem_biblioteca_de_sessao' | 'indisponivel_para_voce' |
 *                               // 'consultavel_no_local' | 'no_acervo_da_sua_biblioteca' |
 *                               // 'indisponivel_no_momento'
 *     session_exemplares_total,
 *     session_available_count,
 *     session_next_available_on,    // date — prochaine dispo prospective si épuisé
 *     session_due_at,
 *     session_pickup_scheduled_for,
 *     session_has_holding,
 *   }
 *
 * **Comportement de bord** :
 *  - Si `bookIds` est vide, le hook ne fait pas d'appel réseau et retourne
 *    un Map vide.
 *  - Si l'utilisateur·rice n'est pas connecté·e, idem (la RPC SECURITY DEFINER
 *    s'appuie sur api.my_access qui exige une session).
 *  - Si l'appel échoue, le Map reste vide et `error` est exposé. Le composant
 *    consommateur dégrade gracieusement.
 *  - La mémoïsation se fait sur la chaîne triée des bookIds, donc si la
 *    liste change d'ordre sans changer de contenu, pas de rechargement.
 */
export function useBookAvailability(bookIds) {
  const { user } = useAuth();
  const [availabilityMap, setAvailabilityMap] = useState(new Map());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Clé de mémoïsation : tableau trié des IDs distincts, sérialisé.
  // Évite les rechargements quand la même liste arrive dans un ordre différent.
  const stableKey = useMemo(() => {
    if (!Array.isArray(bookIds) || bookIds.length === 0) return '';
    const distinct = Array.from(new Set(bookIds.filter(id => id != null)));
    distinct.sort((a, b) => Number(a) - Number(b));
    return distinct.join(',');
  }, [bookIds]);

  useEffect(() => {
    if (!user || !stableKey) {
      setAvailabilityMap(new Map());
      setError(null);
      return;
    }

    const ids = stableKey.split(',').map(s => Number(s)).filter(n => Number.isFinite(n));
    if (ids.length === 0) {
      setAvailabilityMap(new Map());
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    (async () => {
      try {
        const { data, error: rpcError } = await supabase.rpc(
          'fn_v2_book_session_availability_for_current_user',
          { p_book_ids: ids }
        );
        if (cancelled) return;
        if (rpcError) {
          setError(rpcError);
          setAvailabilityMap(new Map());
          return;
        }
        const next = new Map();
        for (const row of (data || [])) {
          if (row?.book_id != null) {
            next.set(Number(row.book_id), row);
          }
        }
        setAvailabilityMap(next);
      } catch (err) {
        if (!cancelled) {
          setError(err);
          setAvailabilityMap(new Map());
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, [stableKey, user?.id]);

  return { availabilityMap, loading, error };
}
