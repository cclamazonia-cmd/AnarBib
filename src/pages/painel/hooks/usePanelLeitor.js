// AnarBib — Panneau, « Gérer un·e lecteur·rice » et la cotisation (E6, lot C, 12/10/2026).
// Déplacé tel quel depuis PanelPage.jsx : la recherche (fn_painel_search_reader,
// restriction, paiements), le formulaire d'adresse synchronisé au profil, les
// règles et l'aperçu de cotisation (onglet Contribuições), la modale de
// paiement (fn_record_membership_payment). Le crochet lit l'onglet et les rôles.
import { useState, useEffect, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { parseAddressText } from '@/lib/addressFormat';
import { normalizePublicId } from '@/lib/publicId';

export function usePanelLeitor({ t, libraryId, isLibrarian, isCoordOrAdmin, membershipEnabled, tab }) {
  // Gerir leitor
  const [readerLookup, setReaderLookup] = useState('');
  const [readerProfile, setReaderProfile] = useState(null);
  const [readerMsg, setReaderMsg] = useState('');
  // CARD-LOCAL-1 : méta de correspondance (identité locale, biblio d'origine si repli)
  const [readerMatchInfo, setReaderMatchInfo] = useState(null);
  // State local du formulaire d'édition d'adresse, séparé de readerProfile.address
  // pour éviter la boucle parse→format→parse à chaque frappe (qui mangeait les
  // espaces de fin via .trim() dans parseAddressText). Initialisé/réinitialisé
  // depuis readerProfile.address quand celui-ci change (cf. useEffect ci-dessous).
  const [editAddrState, setEditAddrState] = useState({
    line1: '', line2: '', unit: '', postal_code: '',
    district: '', city: '', state_region: '', country: ''
  });
  // Feedback du clic « Enregistrer le profil », affiché DANS le formulaire
  // d'édition (à côté du bouton) et non plus dans la zone globale qui
  // se trouve hors viewport quand le formulaire est déplié.
  const [editProfileMsg, setEditProfileMsg] = useState('');
  const [restrictReason, setRestrictReason] = useState('');
  // EA-10 (chantier D) : etat de restriction (local membership + global profile)
  const [restrictionState, setRestrictionState] = useState(null);
  const [restrictBusy, setRestrictBusy] = useState(false);
  const [freezeReason, setFreezeReason] = useState('');

  const [membershipRules, setMembershipRules] = useState([]);
  const [membershipOverview, setMembershipOverview] = useState([]);
  const [membershipFilter, setMembershipFilter] = useState('all'); // all, up_to_date, expired, never_paid
  const [readerPayments, setReaderPayments] = useState([]);
  const [paymentModal, setPaymentModal] = useState(null); // null ou { user_id, display_name, ... }
  const [paymentDraft, setPaymentDraft] = useState(null);
  // PATCH 07/05/2026 audit i18n : flag séparé pour la coloration erreur/succès
  // (l'ancienne détection paymentMsg.startsWith('Erro') ne marchait qu'en pt-BR/fr)
  const [paymentMsg, setPaymentMsg] = useState('');
  const [paymentMsgIsError, setPaymentMsgIsError] = useState(false);
  const [paymentSaving, setPaymentSaving] = useState(false);

  // ── Synchronisation editAddrState ↔ readerProfile.address ──
  // Quand on charge un·e nouveau·lle lecteur·rice, on (ré)initialise le state
  // local d'édition d'adresse en parsant readerProfile.address. Et on remet
  // à zéro le message de feedback local.
  useEffect(() => {
    if (readerProfile?.address !== undefined) {
      setEditAddrState(parseAddressText(readerProfile.address));
    } else {
      setEditAddrState({
        line1: '', line2: '', unit: '', postal_code: '',
        district: '', city: '', state_region: '', country: ''
      });
    }
    setEditProfileMsg('');
  }, [readerProfile?.id]);

  // ── Gerir leitor ─────────────────────────────────────

  async function searchReader() {
    if (!readerLookup.trim()) { setReaderMsg(t({id:'panel.loan.errorMissing'})); return; }
    setReaderMsg(t({id:'common.searching'}));
    try {
      // CARD-LOCAL-1 : recherche par UUID / e-mail / identité locale, scopée à la
      // biblio courante avec repli « toutes mes biblios » (biblio d'origine signalée).
      const { data, error } = await supabase.rpc('fn_painel_search_reader', { p_lookup: normalizePublicId(readerLookup), p_library_id: libraryId });
      if (error) throw error;
      const res = Array.isArray(data) ? data[0] : data;
      const p = res?.profile || null;
      if (!p) { setReaderMsg(t({id:'panel.reader.notFound'})); setReaderProfile(null); setReaderMatchInfo(null); return; }
      setReaderProfile(p);
      setReaderMatchInfo(res ? {
        matchedVia: res.matched_via || null,
        matchedLibraryId: res.matched_library_id || null,
        matchedLibraryName: res.matched_library_name || null,
        localIdentity: res.local_identity || null,
        membershipStatus: res.membership_status || null, // Suite 7
        isFallback: !!res.is_fallback,
      } : null);
      setReaderMsg('');
      // EA-10 : charger l'etat de restriction (local + global)
      try {
        const { data: rs } = await supabase.schema('api').rpc('get_member_restriction', { p_user_id: p.id, p_library_id: libraryId });
        setRestrictionState(rs?.ok ? rs : null);
      } catch { setRestrictionState(null); }
      // Charger l'historique de cotisation pour ce lecteur (tout staff peut gérer
      // les cotisations au quotidien — décision gouvernance 10/06, sauf gel global).
      if (membershipEnabled && isLibrarian) {
        const { data: payments } = await supabase.rpc('fn_list_membership_payments_for_user', { p_user_id: p.id });
        setReaderPayments(payments || []);
      } else {
        setReaderPayments([]);
      }
    } catch (e) { setReaderMsg(t({id:'common.errorPrefix'}, {message: localizeError(e, t)})); setReaderProfile(null); setReaderMatchInfo(null); }
  }

  // ── Cotisation ───────────────────────────────────────

  // Chargement de la config et des règles de cotisation
  const loadMembershipConfig = useCallback(async () => {
    if (!libraryId || !isLibrarian) return;
    try {
      // E.0 (paquet profils 19/05) : membership_enabled est deja expose par le
      // LibraryContext. Plus de SELECT redondant ici. On charge uniquement les regles.
      const { data: rules } = await supabase
        .from('library_membership_rules')
        .select('*')
        .eq('library_id', libraryId)
        .eq('is_active', true)
        .order('display_order');
      setMembershipRules(rules || []);
    } catch (e) { console.warn('loadMembershipConfig:', e); }
  }, [libraryId, isLibrarian]);

  // Chargement de l'aperçu global (tableau Contribuições)
  const loadMembershipOverview = useCallback(async () => {
    if (!libraryId || !isCoordOrAdmin) return;
    try {
      const { data, error } = await supabase
        .from('v_membership_overview_panel')
        .select('*')
        .eq('library_id', libraryId)
        .order('display_name', { ascending: true });
      if (error) throw error;
      setMembershipOverview(data || []);
    } catch (e) { console.warn('loadMembershipOverview:', e); }
  }, [libraryId, isCoordOrAdmin]);

  useEffect(() => { loadMembershipConfig(); }, [loadMembershipConfig]);
  useEffect(() => { if (tab === 'contribuicoes') loadMembershipOverview(); }, [tab, loadMembershipOverview]);

  // Ouvrir le modal de paiement
  function openPaymentModal(target) {
    if (membershipRules.length === 0) {
      setPaymentMsg(t({ id: 'membership.payment.noRulesAvailable' }));
      setPaymentMsgIsError(true);
      return;
    }
    const firstRule = membershipRules[0];
    setPaymentModal(target);
    setPaymentDraft({
      user_id: target.user_id,
      rule_id: firstRule.id,
      amount_paid: firstRule.amount_suggested ?? firstRule.amount_min ?? 0,
      payment_method: 'cash',
      paid_at: new Date().toISOString().slice(0, 10), // YYYY-MM-DD
      notes: '',
    });
    setPaymentMsg('');
    setPaymentMsgIsError(false);
  }

  function closePaymentModal() {
    setPaymentModal(null);
    setPaymentDraft(null);
    setPaymentMsg('');
    setPaymentMsgIsError(false);
  }

  // Quand on change de règle, pré-remplir le montant
  function onPaymentRuleChange(newRuleId) {
    const rule = membershipRules.find(r => r.id === newRuleId);
    setPaymentDraft(p => ({
      ...p,
      rule_id: newRuleId,
      amount_paid: rule?.amount_suggested ?? rule?.amount_min ?? 0,
    }));
  }

  async function submitPayment() {
    if (!paymentDraft) return;
    setPaymentSaving(true);
    setPaymentMsg('');
    setPaymentMsgIsError(false);
    try {
      const { data, error } = await supabase.rpc('fn_record_membership_payment', {
        p_user_id: paymentDraft.user_id,
        p_rule_id: paymentDraft.rule_id,
        p_amount_paid: Number(paymentDraft.amount_paid) || 0,
        p_payment_method: paymentDraft.payment_method,
        p_paid_at: new Date(paymentDraft.paid_at + 'T12:00:00Z').toISOString(),
        p_notes: paymentDraft.notes?.trim() || null,
      });
      if (error) throw error;
      const result = Array.isArray(data) ? data[0] : data;
      setPaymentMsg(t({ id: 'membership.payment.recorded' }, { from: result.valid_from, until: result.valid_until || '∞' }));
      setPaymentMsgIsError(false);
      // Refresh des données affichées
      await loadMembershipOverview();
      if (readerProfile && readerProfile.id === paymentDraft.user_id) {
        const { data: payments } = await supabase.rpc('fn_list_membership_payments_for_user', { p_user_id: readerProfile.id });
        setReaderPayments(payments || []);
      }
      // Fermer le modal après 1s pour que le user voie le message
      setTimeout(() => closePaymentModal(), 1500);
    } catch (e) {
      setPaymentMsg(t({ id: 'common.errorPrefix' }, { message: localizeError(e, t) }));
      setPaymentMsgIsError(true);
    } finally {
      setPaymentSaving(false);
    }
  }

  function fmtMembershipStatus(status, days) {
    if (status === 'up_to_date') {
      if (days != null && days <= 30) return { label: t({ id: 'membership.status.upToDate' }), variant: 'warn', detail: t({ id: 'membership.daysUntilExpiry.plural' }, { days }) };
      return { label: t({ id: 'membership.status.upToDate' }), variant: 'ok', detail: null };
    }
    if (status === 'expired') return { label: t({ id: 'membership.status.expired' }), variant: 'danger', detail: null };
    if (status === 'never_paid') return { label: t({ id: 'membership.status.neverPaid' }), variant: 'warn', detail: null };
    if (status === 'lifetime') return { label: t({ id: 'membership.status.lifetime' }), variant: 'ok', detail: null };
    return { label: t({ id: 'membership.status.notApplicable' }), variant: 'default', detail: null };
  }

  function getMembershipFilterCount(filter) {
    if (filter === 'all') return membershipOverview.length;
    return membershipOverview.filter(m => m.dues_status === filter).length;
  }

  return { readerLookup, setReaderLookup, readerProfile, setReaderProfile, readerMatchInfo, readerMsg, setReaderMsg, editAddrState, setEditAddrState, editProfileMsg, setEditProfileMsg, restrictReason, setRestrictReason, restrictionState, setRestrictionState, restrictBusy, setRestrictBusy, freezeReason, setFreezeReason, readerPayments, membershipRules, searchReader, openPaymentModal,
    membershipFilter, setMembershipFilter, membershipOverview, getMembershipFilterCount, fmtMembershipStatus, loadMembershipOverview, paymentModal, paymentDraft, setPaymentDraft, onPaymentRuleChange, paymentMsg, paymentMsgIsError, paymentSaving, submitPayment, closePaymentModal };
}
