// AnarBib — Panneau, onglet Emprunts (E6, lot A, 12/10/2026).
// Déplacé tel quel depuis PanelPage.jsx : filtre et tri de l'onglet, lignes
// dépliées, et les trois gestes du personnel (prolonger, rendre un item,
// prolonger un item). Le crochet rappelle loadLoans et signale par le toast.
import { useState, useCallback } from 'react';
import { supabase } from '@/lib/supabase';
import { localizeError } from '@/lib/localizeError';
import { assertRpcOk } from '@/lib/rpcStatus.js';

export function usePanelEmprestimos({ t, loadLoans, notifyError }) {
  // EA-08 (chantier B, 27/05/2026) : tri et filtre sur l'onglet Empréstimos
  // (initialement emprestimos-lote, désormais fusionné en emprestimos via E.3/EA-07).
  // Aligne l'experience avec les trois autres onglets-objet. Valeurs canoniques
  // de emprestimo_status derivees de fn_v2_refresh_emprestimo_status_global
  // (dump du 27/05) : aberto, parcialmente_devolvido, encerrado. L'onglet
  // n'affichant que les actifs, 'encerrado' n'apparait jamais.
  const [loteStatusFilter, setLoteStatusFilter] = useState('all');
  const [loteSortKey, setLoteSortKey] = useState('due_at_asc');
  // E.3 / EA-07 (29/05/2026) : onglet Empréstimos fusionné. Les lignes
  // d'emprunt sont dépliables, le set contient les emprestimo_id ouverts.
  const [expandedLoans, setExpandedLoans] = useState(() => new Set());
  const toggleExpandedLoan = useCallback((empId) => {
    setExpandedLoans(prev => {
      const next = new Set(prev);
      if (next.has(empId)) next.delete(empId);
      else next.add(empId);
      return next;
    });
  }, []);

  // ── Empréstimo actions ─────────────────────────────────

  async function extendLoan(empId) {
    try {
      // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
      // DOC-RPC-4. Ce site et son jumeau `extendLoanItem` sont le pendant STAFF
      // de `renew_my_loan`, le cas qui a fondé DOC-SILENCE-1 — et ils étaient
      // restés en l'état parce que la requête du relevé ne voit pas les façades
      // à deux sauts : `api.extend_loan_as_library` →
      // `public.fn_v2_extend_emprestimo_once` → `public.fn_v2_extend_core`,
      // qui est la seule à poser `ok`.
      // Vérifié en base le 31/08/2026 : `fn_v2_extend_core` ne lève JAMAIS. Elle
      // rend `ok:false` sur huit refus d'entrée (`not_authenticated`, `not_found`,
      // `circulation_disabled`, `dues_blocked`, `no_active_membership`,
      // `restricted`) et, ligne à ligne, sur `overdue`, `reserved_by_other`,
      // `not_renewable`, `quota_exceeded`, `already_extended` — son `ok` final
      // vaut `v_any_renewed`, donc « faux » dès qu'aucune ligne n'a bougé.
      // Avec `const { error }`, la charge utile était jetée à la destructuration :
      // le `ok` n'était pas ignoré, il était INATTEIGNABLE. La bibliothécaire
      // cliquait « prolonger », rien ne levait, `loadLoans()` rafraîchissait, et
      // l'échéance n'avait pas bougé — sans un mot.
      const { data, error } = await supabase.schema('api').rpc('extend_loan_as_library', { p_emprestimo_id: empId });
      if (error) throw error;
      assertRpcOk(data);
      loadLoans();
    } catch (e) {
      notifyError(localizeError(e, t, 'panel.loan.extendError'), e);
    }
  }

  async function returnLoanItem(empId, lineNos) {
    try {
      // Paquet 19 : utiliser le wrapper api.* au lieu de la fn DEFINER
      const { error } = await supabase.schema('api').rpc('return_loan_partial', {
        p_emprestimo_id: empId, p_line_nos: lineNos,
      });
      if (error) throw error;
      loadLoans();
    } catch (e) { notifyError(localizeError(e, t, 'panel.error.loanReturn'), e); }
  }

  async function extendLoanItem(empId, lineNo) {
    try {
      // Granularité Phase 4 : extension PAR ITEM via wrapper api.* (non-DEFINER).
      // Même défaut et même correctif qu'`extendLoan` ci-dessus, où le pourquoi
      // est écrit en entier — même chaîne à deux sauts jusqu'à `fn_v2_extend_core`.
      const { data, error } = await supabase.schema('api').rpc('extend_loan_item_as_library', {
        p_emprestimo_id: empId, p_line_no: lineNo,
      });
      if (error) throw error;
      assertRpcOk(data);
      loadLoans();
    } catch (e) {
      notifyError(localizeError(e, t, 'panel.loan.extendError'), e);
    }
  }

  return { loteStatusFilter, setLoteStatusFilter, loteSortKey, setLoteSortKey, expandedLoans,
    toggleExpandedLoan, extendLoan, returnLoanItem, extendLoanItem };
}
