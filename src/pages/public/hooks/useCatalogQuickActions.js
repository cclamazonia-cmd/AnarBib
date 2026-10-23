// Réservation rapide, consultation sur place et favoris depuis la liste du
// catalogue public — sortis de CatalogPage.jsx tels quels (E6, lot 5,
// 23/10/2026), sans changer de comportement : la page passe la personne
// connectée et `t`, et reçoit l'état par ligne et les actions qu'elle donne à
// CatalogResultsTable. Garde : src/tests/catalog-actions-rapides.test.js.
import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { assertRpcOk } from '@/lib/rpcStatus.js';

export function useCatalogQuickActions({ user, isAuth, t }) {
  // ── Réservation rapide depuis le catalogue (Paquet 27 quickReserve) ──
  // serviceState : connaître si la biblio est `pausada` / `somente_consulta`
  //   → on cache le bouton dans ces cas.
  // isRestricted : profil suspendu (sanction militante) → on cache aussi.
  // reserveState : statut par livre, clef = book_id (ou bib_ref en fallback).
  //   Valeurs : 'idle' | 'reserving' | 'done' | 'error:<message>'
  // reservedBibRefs : set des bib_ref déjà réservés avec succès dans la
  //   session courante du catalogue, pour ne pas montrer un bouton "actif"
  //   sur une ligne déjà traitée (UX : évite le double clic surpris).
  const [serviceState, setServiceState] = useState(null);
  const [isRestricted, setIsRestricted] = useState(false);
  const [reserveState, setReserveState] = useState({});
  const [reservedBibRefs, setReservedBibRefs] = useState(new Set());
  // Paquet B.2 (chantier consulta button) : miroir de reservedBibRefs / reserveState
  // pour la chaine consultation. Doctrine §8 : la consulta a son propre cycle.
  const [consultedBibRefs, setConsultedBibRefs] = useState(new Set());
  const [consultaState, setConsultaState] = useState({});
  // #OPAC9 : favoris (wishlist) ajoutés depuis la liste
  const [wishlistedIds, setWishlistedIds] = useState(new Set());
  const [wishlistBusy, setWishlistBusy] = useState(null);

  // ── Garde-fous pour la réservation rapide ──────────────────
  // Charge 2 contextes globaux stables : mode service de la biblio et statut
  // restreint du profil. Suffisant pour décider si le bouton apparaît.
  // Les doublons (réservation/emprunt actif sur même livre) sont laissés au
  // backend : trop coûteux à charger ici, et le RPC les rejette proprement.
  useEffect(() => {
    if (!isAuth) return;
    (async () => {
      // Mode service de la biblio de l'utilisateur connecte.
      // La vue api.my_library_context filtre deja par auth.uid()
      // via my_session_context : pas besoin de library_id ici.
      // Coherent avec la doctrine 'page = scope, no cross-calculation'.
      const svcRes = await supabase.schema('api').from('my_library_context')
        .select('service_mode, allows_new_reservations').maybeSingle();
      if (svcRes.data) setServiceState(svcRes.data);

      // profil : flag is_restricted seul (pas besoin du reste ici)
      const profRes = await supabase.from('profiles')
        .select('is_restricted').eq('id', user.id).maybeSingle();
      if (profRes.data) setIsRestricted(!!profRes.data.is_restricted);
    })();
  }, [isAuth, user?.id]);

  // ── Action de réservation rapide ───────────────────────────
  // Appelée par le bouton "Reservar" en bout de ligne. Pour 1 seul livre :
  //   1. fn_v2_resolve_catalog_refs_for_current_user → résout bib_ref vers
  //      holding_id de la session du lecteur (sa bibliothèque).
  //   2. fn_v2_create_reserva_by_holdings → crée la réservation. Le trigger
  //      DB trg_notify_reserva_workflow_change émet automatiquement
  //      'reserva_v2_criada' (cf. spec workflow réservation phase 4).
  // Pas de notifyEvent manuel à faire ici.
  const handleQuickReserve = useCallback(async (book) => {
    const key = String(book.book_id || book.bib_ref || '');
    const ref = String(book.bib_ref || '').trim();
    if (!ref) return;

    // Cache local : déjà réservé dans cette session ?
    if (reservedBibRefs.has(ref.toLowerCase())) return;

    setReserveState(s => ({ ...s, [key]: 'reserving' }));

    try {
      // 1. Résolution bib_ref → holding_id (côté session du lecteur)
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: [ref] });
      if (resolveRes.error) throw resolveRes.error;

      const rows = Array.isArray(resolveRes.data) ? resolveRes.data : [];
      const row = rows[0];
      if (!row || !row.matched || !(Number(row.session_holding_id) > 0)) {
        // Cas "trouvé mais non disponible dans MA biblio" : message du backend si présent.
        throw new Error(row?.message || t({ id: 'catalog.quickReserve.notInMyLibrary' }));
      }

      // 2. Refus si l'exemplaire est consultation-only (ne devrait pas arriver
      //    car le bouton n'apparaît que sur status 'ok', mais on garde la
      //    ceinture-bretelles : un livre peut bouger entre l'affichage et le clic).
      if (row.session_loanable === false) {
        throw new Error(t({ id: 'catalog.quickReserve.consultationOnly' }));
      }

      // 3. Création de la réservation
      const createRes = await supabase.rpc('fn_v2_create_reserva_by_holdings', {
        p_user_id: user.id,
        p_holding_ids: [Number(row.session_holding_id)],
        p_notes: '@@note:catalog.quickReserve.note', // Route B : code système (décodé à l'affichage)
      });
      if (createRes.error) throw createRes.error;
      assertRpcOk(createRes.data);

      // Succès : on marque le livre comme réservé pour éviter le double clic
      setReserveState(s => ({ ...s, [key]: 'done' }));
      setReservedBibRefs(prev => {
        const next = new Set(prev);
        next.add(ref.toLowerCase());
        return next;
      });
    } catch (err) {
      setReserveState(s => ({ ...s, [key]: `error:${localizeError(err, t) || 'erro'}` }));
    }
  }, [user?.id, t, reservedBibRefs]);

  // Paquet B.2 (chantier consulta button) : miroir de handleQuickReserve pour la
  // chaine consultation sur place. Appelle api.create_consulta_local (wrapper
  // SECURITY INVOKER, paquet 27.A.1) au lieu de fn_v2_create_reserva_by_holdings.
  const handleQuickConsulta = useCallback(async (book) => {
    const key = String(book.book_id || book.bib_ref || '');
    const ref = String(book.bib_ref || '').trim();
    if (!ref) return;
    if (consultedBibRefs.has(ref.toLowerCase())) return;

    setConsultaState(s => ({ ...s, [key]: 'reserving' }));

    try {
      // 1. Resolution bib_ref -> holding_id (cote session du lecteur)
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: [ref] });
      if (resolveRes.error) throw resolveRes.error;

      const rows = Array.isArray(resolveRes.data) ? resolveRes.data : [];
      const row = rows[0];
      if (!row || !row.matched || !(Number(row.session_holding_id) > 0)) {
        throw new Error(row?.message || t({ id: 'catalog.quickReserve.notInMyLibrary' }));
      }

      // 2. Creation de la demande de consultation
      const createRes = await supabase.schema('api').rpc('create_consulta_local', {
        p_user_id: user.id,
        p_holding_ids: [Number(row.session_holding_id)],
        p_notes: '@@note:catalog.quickConsulta.note', // Route B : code système (décodé à l'affichage)
      });
      if (createRes.error) throw createRes.error;
      assertRpcOk(createRes.data);

      // Succes
      setConsultaState(s => ({ ...s, [key]: 'done' }));
      setConsultedBibRefs(prev => {
        const next = new Set(prev);
        next.add(ref.toLowerCase());
        return next;
      });
    } catch (err) {
      setConsultaState(s => ({ ...s, [key]: 'error:' + (localizeError(err, t) || 'erro') }));
    }
  }, [user?.id, t, consultedBibRefs]);

  // #OPAC9 — ajout aux favoris depuis la liste (table user_wishlist, RLS owner-only).
  const handleWishlist = useCallback(async (book) => {
    if (!user) return;
    const bid = book.book_id || book.id;
    if (!bid || wishlistedIds.has(bid)) return;
    setWishlistBusy(bid);
    try {
      const { error } = await supabase.from('user_wishlist')
        .upsert({ user_id: user.id, book_id: bid }, { onConflict: 'user_id,book_id' });
      if (error && error.code !== '23505') throw error; // 23505 = déjà présent → succès
      setWishlistedIds(prev => new Set(prev).add(bid));
    } catch (err) { console.error('wishlist error', err); }
    finally { setWishlistBusy(null); }
  }, [user?.id, wishlistedIds]);

  // Calcul dérivé : le bouton de réservation rapide est-il globalement actif ?
  // Cache pour le rendu de chaque ligne (évalué une fois par render).
  const quickReserveAvailable = useMemo(() => {
    if (!isAuth) return false;
    if (isRestricted) return false;
    const svcMode = serviceState?.service_mode || 'funcionamento_normal';
    const allowsRes = serviceState?.allows_new_reservations !== false;
    if (!allowsRes) return false;
    if (svcMode === 'pausada' || svcMode === 'somente_consulta') return false;
    return true;
  }, [isAuth, isRestricted, serviceState]);

  // Paquet B.2 : disponibilite du bouton "Agendar consulta". Doctrine §8 :
  // pausada -> non ; somente_consulta -> oui ; funcionamento_normal -> oui.
  // Donc plus permissif que quickReserveAvailable.
  const quickConsultaAvailable = useMemo(() => {
    if (!isAuth) return false;
    if (isRestricted) return false;
    const svcMode = serviceState?.service_mode || 'funcionamento_normal';
    if (svcMode === 'pausada') return false;
    return true;
  }, [isAuth, isRestricted, serviceState]);

  return {
    reserveState, reservedBibRefs, consultedBibRefs, consultaState, wishlistedIds, wishlistBusy,
    handleQuickReserve, handleQuickConsulta, handleWishlist, quickReserveAvailable, quickConsultaAvailable,
  };
}
