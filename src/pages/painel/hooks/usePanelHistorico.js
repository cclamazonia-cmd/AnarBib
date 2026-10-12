// AnarBib — Panneau, onglet Historique (E6, lot A, 12/10/2026).
// Déplacé tel quel depuis PanelPage.jsx : l'état, le chargement paginé par
// type (vues api.painel_*_history_v1) et le rafraîchissement par onglet.
// Le crochet ne lit du panneau que l'onglet courant et les trois listes
// (pour choisir le type dominant) ; il ne touche à rien d'autre.
import { useState, useEffect, useCallback, useMemo } from 'react';
import { supabase } from '@/lib/supabase';

export function usePanelHistorico({ tab, reservations, consultations, loans }) {
  // === Onglet Historique (#143.2) =============================
  // Pills cochables multi-selection pour filtrer par type d'item.
  // Initialise au type le plus utilise (dynamique selon les comptes).
  const [historyTypes, setHistoryTypes] = useState(null);

  const dominantHistoryType = useMemo(() => {
    const counts = {
      reservas: (reservations || []).filter(r => ['cancelada_leitor','cancelada_biblioteca','convertida_em_emprestimo','expirada','liberada_para_circulacao'].includes(r.item_status)).length,
      consultas: (consultations || []).filter(c => ['cancelada_biblioteca','cancelada_leitor','consultada','expirada'].includes(c.item_status)).length,
      emprestimos: (loans || []).filter(l => l.status_global === 'encerrado').length,
    };
    if (counts.consultas >= counts.reservas && counts.consultas >= counts.emprestimos) return 'consultas';
    if (counts.reservas >= counts.emprestimos) return 'reservas';
    return 'emprestimos';
  }, [reservations, consultations, loans]);

  useEffect(() => {
    if (historyTypes === null && dominantHistoryType) {
      setHistoryTypes(new Set([dominantHistoryType]));
    }
  }, [dominantHistoryType, historyTypes]);

  const toggleHistoryType = (type) => {
    setHistoryTypes(prev => {
      const next = new Set(prev || []);
      if (next.has(type)) next.delete(type);
      else next.add(type);
      return next;
    });
  };

  // Donnees historiques (chargees a la demande, paginees par 50)
  const [historyData, setHistoryData] = useState({ reservas: [], consultas: [], emprestimos: [] });
  const [historyOffsets, setHistoryOffsets] = useState({ reservas: 0, consultas: 0, emprestimos: 0 });
  const [historyHasMore, setHistoryHasMore] = useState({ reservas: true, consultas: true, emprestimos: true });
  const [historyLoading, setHistoryLoading] = useState({ reservas: false, consultas: false, emprestimos: false });

  // EA-11 (29/05/2026) : taille de page configurable par l'utilisateur·rice
  // (selecteur 25/50/100 cote TabHistorico). State au niveau PanelPage parce
  // que loadHistorySection en a besoin et que le handler de changement doit
  // pouvoir reset historyData/Offsets/HasMore pour relancer le chargement.
  const [historyPageSize, setHistoryPageSize] = useState(50);
  const HISTORY_VIEW_NAMES = {
    reservas: 'painel_reservations_history_v1',
    consultas: 'painel_consultas_history_v1',
    emprestimos: 'painel_loans_history_v1'
  };

  const changeHistoryPageSize = useCallback((newSize) => {
    setHistoryPageSize(newSize);
    // Reset complet : on relance le chargement de la 1ere page a la nouvelle
    // taille. Le useEffect d'auto-load detecte historyData[type].length === 0
    // et appelle loadHistorySection si type est dans historyTypes.
    setHistoryData({ reservas: [], consultas: [], emprestimos: [] });
    setHistoryOffsets({ reservas: 0, consultas: 0, emprestimos: 0 });
    setHistoryHasMore({ reservas: true, consultas: true, emprestimos: true });
  }, []);

  const loadHistorySection = useCallback(async (type, append = false) => {
    if (historyLoading[type]) return;
    setHistoryLoading(prev => ({ ...prev, [type]: true }));
    
    const offset = append ? historyOffsets[type] : 0;
    const viewName = HISTORY_VIEW_NAMES[type];
    
    try {
      const { data, error } = await supabase
        .schema('api').from(viewName)
        .select('*')
        .range(offset, offset + historyPageSize - 1);
      
      if (error) {
        console.error(`load ${type} history error:`, error);
        setHistoryLoading(prev => ({ ...prev, [type]: false }));
        return;
      }
      
      const items = data || [];
      const hasMore = items.length === historyPageSize;
      
      setHistoryData(prev => ({
        ...prev,
        [type]: append ? [...prev[type], ...items] : items
      }));
      setHistoryOffsets(prev => ({ ...prev, [type]: offset + items.length }));
      setHistoryHasMore(prev => ({ ...prev, [type]: hasMore }));
    } catch (err) {
      console.error(`load ${type} history exception:`, err);
    } finally {
      setHistoryLoading(prev => ({ ...prev, [type]: false }));
    }
  }, [historyLoading, historyOffsets, historyPageSize]);

  // Auto-load des sections cochees a l'ouverture de l'onglet
  useEffect(() => {
    if (tab !== 'historico' || !historyTypes) return;
    for (const type of ['reservas', 'consultas', 'emprestimos']) {
      if (historyTypes.has(type) && historyData[type].length === 0 && historyHasMore[type] && !historyLoading[type]) {
        loadHistorySection(type, false);
      }
    }
  }, [tab, historyTypes, historyData, historyHasMore, historyLoading, loadHistorySection]);
  // === Fin onglet Historique ==================================
  // E.2 (OT-1, 28/05/2026) : refresh par onglet — Histórico ne dépend pas de
  // loadData global, il a sa propre logique loadHistorySection par type.
  // On rappelle loadHistorySection(type, false) pour chaque type actif.
  const refreshHistorico = useCallback(() => {
    const types = historyTypes || new Set();
    types.forEach(type => loadHistorySection(type, false));
  }, [historyTypes, loadHistorySection]);

  return { historyTypes, historyData, historyHasMore, historyLoading, toggleHistoryType,
    loadHistorySection, refreshHistorico, historyPageSize, changeHistoryPageSize };
}
