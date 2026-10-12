// AnarBib — Panneau, onglet Actions : sortie et retour au comptoir (E6, lot B, 12/10/2026).
// Déplacé tel quel depuis PanelPage.jsx : l'état des deux formulaires et les
// gestes en deux phases (aperçu puis confirmation) — api.create_loan_at_counter,
// return_loan_total, return_loan_partial. Le crochet lit loans (déjà chargés)
// pour l'aperçu des retours et rappelle loadLoans après chaque écriture.
import { useState } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { normalizePublicId } from '@/lib/publicId';
import { fmtD } from '../_shared';

export function usePanelAcoes({ t, libraryId, loans, loadLoans }) {
  // Ações
  const [borrowerLookup, setBorrowerLookup] = useState('');
  const [loanRefs, setLoanRefs] = useState('');
  // Paquet 16 v2 (10/05/2026) : preview echeance + guard double-clic
  const [loanPreview, setLoanPreview] = useState(null);
  const [loanBusy, setLoanBusy] = useState(false);
  const [loanMsg, setLoanMsg] = useState('');
  const [returnId, setReturnId] = useState('');
  const [returnSubIds, setReturnSubIds] = useState('');
  const [returnMsg, setReturnMsg] = useState('');
  // EA-03 (29/05/2026) : prévisualisation symétrique de la sortie d'emprunt
  // pour les retours total et partiel. 2 phases (preview puis confirmation)
  // avec clé de cohérence : la preview est invalidée dès que l'input change.
  // Calcul de preview entièrement côté front à partir de `loans` (déjà chargé) :
  // pas de RPC supplémentaire.
  const [returnTotalPreview, setReturnTotalPreview] = useState(null);
  const [returnPartialPreview, setReturnPartialPreview] = useState(null);

  // ── Ações: saída e devolução ──────────────────────────

  async function registrarSaida() {
    // Paquet 16 v2 (10/05/2026) : 2 phases (preview puis confirmation) + guard double-clic
    // Paquet 19 (10/05/2026) : utilise api.create_loan_at_counter au lieu de fn_v2_create_emprestimo_by_holdings
    if (loanBusy) return;
    const refs = loanRefs.split(/[,;\s]+/).map(r => r.trim()).filter(Boolean);
    if (!borrowerLookup.trim() || !refs.length) { setLoanMsg(t({ id: 'panel.loan.errorMissing' })); return; }

    // ════════════════════════════════════════════════════
    // PHASE 2 : confirmation - on a deja une preview valide
    // ════════════════════════════════════════════════════
    if (loanPreview && loanPreview.refsKey === refs.join('|') && loanPreview.borrowerKey === borrowerLookup.trim()) {
      setLoanBusy(true);
      setLoanMsg(t({id:'panel.loan.registering'}));
      try {
        const { error } = await supabase.schema('api').rpc('create_loan_at_counter', {
          p_user_id: loanPreview.borrowerId, p_holding_ids: loanPreview.holdingIds,
        });
        if (error) throw error;
        setLoanMsg(t({ id: 'panel.loan.exitRegistered' }, { count: refs.length, name: loanPreview.borrowerName }));
        // Paquet 9 (10/05/2026) : notifyEvent manuel supprimé. Le trigger DB
        // trg_notify_emprestimo_criado (header AFTER INSERT) s'en charge.
        setBorrowerLookup(''); setLoanRefs('');
        setLoanPreview(null);
        loadLoans();
      } catch (e) { setLoanMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.loan.errorMissing')})); }
      finally { setLoanBusy(false); }
      return;
    }

    // ════════════════════════════════════════════════════
    // PHASE 1 : preview - resoudre borrower + holdings + projection
    // ════════════════════════════════════════════════════
    setLoanBusy(true);
    setLoanMsg(t({id:'panel.loan.resolving'}));
    try {
      // Resolve borrower — CARD-LOCAL : même résolution que « gerir leitor·a »
      // (fn_painel_search_reader), qui accepte aussi l'identité locale (n°
      // lecteur·rice) en plus de l'UUID / ID public / e-mail, scopée à la biblio
      // courante avec repli « toutes mes biblios ». Renvoie { profile, … }.
      const lookupRes = await supabase.rpc('fn_painel_search_reader', { p_lookup: normalizePublicId(borrowerLookup), p_library_id: libraryId });
      if (lookupRes.error) throw lookupRes.error;
      const lookupData = Array.isArray(lookupRes.data) ? lookupRes.data[0] : lookupRes.data;
      const borrower = lookupData?.profile || null;
      if (!borrower?.id) { setLoanMsg(t({ id: 'panel.loan.readerNotFound' })); return; }

      // Resolve holdings
      const resolveRes = await supabase.rpc('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: refs });
      if (resolveRes.error) throw resolveRes.error;
      const holdingIds = (resolveRes.data || []).filter(r => r.matched && Number(r.session_holding_id) > 0).map(r => Number(r.session_holding_id));
      if (!holdingIds.length) { setLoanMsg(t({ id: 'panel.loan.noValidRefs' })); return; }

      // Get loan projection (paquet 16)
      const bookIds = (resolveRes.data || []).filter(r => r.matched && Number(r.book_id) > 0).map(r => Number(r.book_id));
      const projectionRes = await supabase.schema('api').rpc('get_batch_loan_projection', {
        p_library_id: libraryId,
        p_user_id: borrower.id,
        p_book_ids: bookIds,
        p_holding_ids: holdingIds,
        p_quantity: holdingIds.length,
        p_as_of_date: new Date().toISOString().slice(0, 10),
      });
      if (projectionRes.error) throw projectionRes.error;
      const proj = Array.isArray(projectionRes.data) ? projectionRes.data[0] : projectionRes.data;

      // Stocker la preview
      setLoanPreview({
        borrowerId: borrower.id,
        borrowerName: borrower.first_name || borrower.email,
        borrowerKey: borrowerLookup.trim(),
        holdingIds,
        refsKey: refs.join('|'),
        dueDate: proj?.due_date,
        ruleLabel: proj?.rule_label,
        loanAllowed: proj?.loan_allowed !== false,
      });

      if (proj?.loan_allowed === false) {
        setLoanMsg(t({id:'panel.loan.preview.notAllowed'}, { rule: proj.rule_label || '' }));
      } else {
        setLoanMsg(t({id:'panel.loan.preview.confirm'}, {
          name: borrower.first_name || borrower.email,
          count: holdingIds.length,
          dueDate: fmtD(proj?.due_date) || '—',
          rule: proj?.rule_label || '—',
        }));
      }
    } catch (e) { setLoanMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.loan.errorMissing')})); }
    finally { setLoanBusy(false); }
  }

  // Paquet 16 v2 : annuler la preview pour reprendre la saisie
  function cancelLoanPreview() {
    setLoanPreview(null);
    setLoanMsg('');
  }

  async function registrarDevolucaoTotal() {
    const id = parseInt(returnId);
    if (!id) { setReturnMsg(t({id:'panel.loan.enterLoanId'})); return; }

    // ════════════════════════════════════════════════════
    // PHASE 2 : confirmation - preview valide et cohérente
    // ════════════════════════════════════════════════════
    if (returnTotalPreview && returnTotalPreview.id === id) {
      setReturnMsg(t({id:'panel.loan.returning'}));
      try {
        // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
        const { error } = await supabase.schema('api').rpc('return_loan_total', { p_emprestimo_id: id });
        if (error) throw error;
        setReturnMsg(t({id:'panel.return.totalRegistered'},{id}));
        // Paquet 9 (10/05/2026) : notifyEvent manuel supprimé. Le trigger DB
        // (via fn_v2_refresh_emprestimo_status_global) dispatch déjà l'event
        // approprié selon la transition (devolvido OU devolvido_apos_parcial).
        setReturnId('');
        setReturnTotalPreview(null);
        loadLoans();
      } catch (e) { setReturnMsg(t({id:'common.errorPrefix'},{message: localizeError(e, t, 'panel.error.loanReturn')})); }
      return;
    }

    // ════════════════════════════════════════════════════
    // PHASE 1 : preview - vérifier emprunt + lister items à clore
    // ════════════════════════════════════════════════════
    // EA-03 (29/05/2026) : on cherche l'emprunt dans `loans` (et non
    // `activeLoans`) pour pouvoir distinguer "inconnu" (jamais existé / archivé)
    // de "déjà totalement clôturé" (tous items à 'devolvido' mais encore dans
    // le scope chargé). Si aucun item ouvert à clore, on rejette.
    const matchingItems = loans.filter(l => l.emprestimo_id === id);
    if (!matchingItems.length) {
      setReturnMsg(t({id:'panel.return.total.notFound'},{id}));
      return;
    }
    const openItems = matchingItems.filter(l => l.item_status === 'aberto');
    if (!openItems.length) {
      setReturnMsg(t({id:'panel.return.total.alreadyClosed'},{id}));
      return;
    }
    const borrowerName = matchingItems[0].user_name
      || matchingItems[0].user_email
      || matchingItems[0].user_public_id
      || '?';
    setReturnTotalPreview({
      id,
      borrowerName,
      itemCount: openItems.length,
    });
    setReturnMsg(t({id:'panel.return.total.preview.confirm'}, {
      id,
      borrower: borrowerName,
      count: openItems.length,
    }));
  }

  async function registrarDevolucaoParcial() {
    const subIds = returnSubIds.split(/[,;\s]+/).map(s => s.trim()).filter(Boolean);
    if (!subIds.length) { setReturnMsg(t({id:'panel.loan.enterSubIds'})); return; }

    // Clé de cohérence : chaîne canonique des sub_ids (triée pour être
    // insensible à l'ordre de saisie).
    const subIdsKey = subIds.slice().sort().join('|');

    // ════════════════════════════════════════════════════
    // PHASE 2 : confirmation - preview valide et cohérente
    // ════════════════════════════════════════════════════
    if (returnPartialPreview && returnPartialPreview.subIdsKey === subIdsKey) {
      setReturnMsg(t({id:'panel.loan.returning'}));
      // BUG-retour-partiel-faux-succès (28/05/2026) : on conserve la
      // défense en profondeur (filets backend + check data === 0) même
      // si la preview a déjà filtré les cas mal formés / inapplicables.
      // Cas couvert : un item passe en 'devolvido' entre la preview et
      // la confirmation (course condition rare mais possible).
      const rejected = [];
      const ok = [];
      for (const item of returnPartialPreview.okCandidates) {
        try {
          const { data, error } = await supabase.schema('api').rpc('return_loan_partial', {
            p_emprestimo_id: item.empId, p_line_nos: [item.lineNo],
          });
          if (error) throw error;
          if (data === 0 || data === null) {
            rejected.push(item.sub_id);
          } else {
            ok.push(item.sub_id);
          }
        } catch (e) {
          rejected.push(item.sub_id);
        }
      }
      // Message consolidé reprenant les 3 catégories (pre-preview + post-RPC).
      const parts = [];
      if (ok.length) {
        parts.push(t({id:'panel.return.partialRegistered'},{ids: ok.join(', ')}));
      }
      if (returnPartialPreview.malformed.length) {
        parts.push(t({id:'panel.return.malformedSubIds'},{ids: returnPartialPreview.malformed.join(', ')}));
      }
      const allRejected = [
        ...returnPartialPreview.preRejected.map(r => r.sub_id),
        ...rejected,
      ];
      if (allRejected.length) {
        parts.push(t({id:'panel.return.rejectedSubIds'},{ids: allRejected.join(', ')}));
      }
      setReturnMsg(parts.join(' · '));
      if (ok.length) {
        setReturnSubIds('');
        setReturnPartialPreview(null);
        loadLoans();
      }
      return;
    }

    // ════════════════════════════════════════════════════
    // PHASE 1 : preview - catégoriser les sub_ids
    // ════════════════════════════════════════════════════
    // EA-03 (29/05/2026) : tri front en 3 catégories AVANT exécution :
    //   - malformed : parsing échoué (book_id au lieu de sub_id, etc.)
    //   - preRejected : sub_id valide mais item inconnu ou déjà rendu
    //   - okCandidates : sub_id valide ET item ouvert → à rendre
    // Le même tri était fait après-coup côté front depuis le fix d'hier
    // soir ; maintenant on l'expose en preview pour que l'utilisateur·rice
    // puisse vérifier avant de confirmer.
    const malformed = [];
    const preRejected = [];
    const okCandidates = [];
    for (const subId of subIds) {
      const [empId, lineNo] = subId.split('.').map(Number);
      if (!empId || !lineNo) { malformed.push(subId); continue; }
      const item = loans.find(l => l.emprestimo_id === empId && l.line_no === lineNo);
      if (!item) {
        preRejected.push({ sub_id: subId, reason: 'unknown' });
      } else if (item.item_status !== 'aberto') {
        preRejected.push({ sub_id: subId, reason: 'alreadyReturned' });
      } else {
        okCandidates.push({
          sub_id: subId,
          empId,
          lineNo,
          titulo: item.titulo || item.bib_ref || '—',
        });
      }
    }

    // Si rien à rendre : message d'erreur immédiat sans pré-loader de preview.
    if (!okCandidates.length) {
      const parts = [];
      if (malformed.length) {
        parts.push(t({id:'panel.return.malformedSubIds'},{ids: malformed.join(', ')}));
      }
      if (preRejected.length) {
        parts.push(t({id:'panel.return.rejectedSubIds'},{ids: preRejected.map(r => r.sub_id).join(', ')}));
      }
      setReturnMsg(parts.join(' · '));
      return;
    }

    // Au moins un ok candidate : on stocke la preview et on demande confirmation.
    setReturnPartialPreview({
      subIdsKey,
      okCandidates,
      malformed,
      preRejected,
    });
    const parts = [
      t({id:'panel.return.partial.preview.confirm'}, {
        count: okCandidates.length,
        ids: okCandidates.map(c => c.sub_id).join(', '),
      }),
    ];
    if (malformed.length) {
      parts.push(t({id:'panel.return.partial.preview.malformed'}, { count: malformed.length }));
    }
    if (preRejected.length) {
      parts.push(t({id:'panel.return.partial.preview.rejected'}, { count: preRejected.length }));
    }
    setReturnMsg(parts.join(' · '));
  }

  // EA-03 (29/05/2026) : annulation symétrique de cancelLoanPreview, pour
  // les deux flux de retour. Reset le state preview + efface le message.
  function cancelReturnTotalPreview() {
    setReturnTotalPreview(null);
    setReturnMsg('');
  }
  function cancelReturnPartialPreview() {
    setReturnPartialPreview(null);
    setReturnMsg('');
  }

  return { borrowerLookup, setBorrowerLookup, loanRefs, setLoanRefs, loanPreview, setLoanPreview, loanBusy, loanMsg,
    returnId, setReturnId, returnSubIds, setReturnSubIds, returnMsg, registrarSaida, cancelLoanPreview,
    registrarDevolucaoTotal, registrarDevolucaoParcial, returnTotalPreview, setReturnTotalPreview,
    returnPartialPreview, setReturnPartialPreview, cancelReturnTotalPreview, cancelReturnPartialPreview };
}
