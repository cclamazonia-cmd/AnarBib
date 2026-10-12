// AnarBib — E6, le Panneau en crochets par domaine, lot A (12/10/2026) :
// usePanelHistorico, usePanelEmprestimos, dailyTasks. Le test garde deux
// choses : la SOURCE (ce qui est parti de la page n'y est plus, les onglets
// reçoivent les mêmes props qu'avant) et le COMPORTEMENT des crochets,
// montés seuls avec un supabase factice.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const lire = (p) => readFileSync(resolve(__dirname, '..', p), 'utf8');

const journal = { range: [], rpc: [] };
let rangeData = [];
let rpcData = { ok: true };
vi.mock('@/lib/supabase', () => ({
  supabase: {
    schema: () => ({
      from: (view) => ({
        select: () => ({
          range: async (a, b) => { journal.range.push({ view, a, b }); return { data: rangeData, error: null }; },
        }),
      }),
      rpc: async (name, args) => { journal.rpc.push({ name, args }); return { data: rpcData, error: null }; },
    }),
  },
  apiQuery: async () => ({ data: [] }),
}));

const { usePanelHistorico } = await import('@/pages/painel/hooks/usePanelHistorico');
const { usePanelEmprestimos } = await import('@/pages/painel/hooks/usePanelEmprestimos');
const { construireTachesDuJour } = await import('@/pages/painel/dailyTasks');

describe('E6 lot A — la source', () => {
  const page = lire('pages/painel/PanelPage.jsx');
  const hist = lire('pages/painel/hooks/usePanelHistorico.js');
  const emp = lire('pages/painel/hooks/usePanelEmprestimos.js');
  const taches = lire('pages/painel/dailyTasks.js');

  it('la page importe les trois modules et ne porte plus leur code', () => {
    expect(page).toContain("import { usePanelHistorico } from './hooks/usePanelHistorico';");
    expect(page).toContain("import { usePanelEmprestimos } from './hooks/usePanelEmprestimos';");
    expect(page).toContain("import { construireTachesDuJour } from './dailyTasks';");
    for (const parti of ['loadHistorySection = useCallback', 'HISTORY_VIEW_NAMES', 'async function extendLoan', 'setExpandedLoans',
      'tasks.push(', 'function buildDailyTasks() {', 'const [historyData', 'const [loteStatusFilter', 'const statusLabel = taskStatusLabel']) {
      expect(page.includes(parti), `resté dans la page : ${parti}`).toBe(false);
    }
    expect(page).toMatch(/= usePanelHistorico\(\{ tab, reservations, consultations, loans \}\);/);
    expect(page).toMatch(/= usePanelEmprestimos\(\{ t, loadLoans, notifyError \}\);/);
    expect(page).toContain('const buildDailyTasks = () => construireTachesDuJour({ t, displayTz, activeRes, overdueLoans, activeLoans, consultations, internalTasks });');
  });

  it('les onglets reçoivent les mêmes props qu’avant', () => {
    for (const prop of ['historyTypes', 'historyData', 'historyHasMore', 'historyLoading', 'toggleHistoryType', 'loadHistorySection',
      'refreshHistorico', 'historyPageSize', 'changeHistoryPageSize', 'loteStatusFilter', 'setLoteStatusFilter', 'loteSortKey', 'setLoteSortKey',
      'expandedLoans', 'toggleExpandedLoan', 'extendLoan', 'returnLoanItem', 'extendLoanItem', 'buildDailyTasks']) {
      expect(page).toContain(`${prop}={${prop}}`);
    }
  });

  it('les crochets ne rendent rien et n’écrivent pas l’onglet ; les tâches sont une fonction pure', () => {
    for (const [nom, s] of [['usePanelHistorico', hist], ['usePanelEmprestimos', emp]]) {
      expect(s, nom).not.toMatch(/setTab\(|<[A-Z][A-Za-z]+[ />]|from 'react-intl'/);
      expect(s, nom).toMatch(/^export function /m);
    }
    expect(hist).toContain("from(viewName)");
    expect(hist).toMatch(/return \{ historyTypes, historyData, historyHasMore, historyLoading, toggleHistoryType,\n\s+loadHistorySection, refreshHistorico, historyPageSize, changeHistoryPageSize \};/);
    expect(emp).toContain("assertRpcOk(data);");
    expect(emp).toMatch(/return \{ loteStatusFilter, setLoteStatusFilter, loteSortKey, setLoteSortKey, expandedLoans,\n\s+toggleExpandedLoan, extendLoan, returnLoanItem, extendLoanItem \};/);
    expect(taches).not.toMatch(/useState|useEffect|useMemo|supabase/);
    expect(taches).toContain('const statusLabel = taskStatusLabel(t, tk.status);');
    expect(taches).toContain("return tasks.sort((a, b) => (a.priority === 'alta' ? 0 : 1) - (b.priority === 'alta' ? 0 : 1));");
  });

  it('la page a maigri', () => {
    expect(Buffer.byteLength(page, 'utf8')).toBeLessThan(105 * 1024);
  });
});

describe('E6 lot A — usePanelHistorico, monté seul', () => {
  beforeEach(() => { journal.range.length = 0; rangeData = [{ id: 1 }, { id: 2 }]; });

  it('choisit le type dominant, charge la première page à l’ouverture de l’onglet, pagine et se remet à zéro', async () => {
    const consultations = [{ item_status: 'consultada' }, { item_status: 'ativa' }];
    const { result, rerender } = renderHook(
      (p) => usePanelHistorico(p),
      { initialProps: { tab: 'reservas', reservations: [], consultations, loans: [] } },
    );
    await waitFor(() => expect([...result.current.historyTypes]).toEqual(['consultas']));
    expect(journal.range).toEqual([]); // pas d'onglet Historique ouvert : rien ne charge
    rerender({ tab: 'historico', reservations: [], consultations, loans: [] });
    await waitFor(() => expect(result.current.historyData.consultas).toHaveLength(2));
    expect(journal.range).toEqual([{ view: 'painel_consultas_history_v1', a: 0, b: 49 }]);
    expect(result.current.historyHasMore.consultas).toBe(false); // 2 < 50
    act(() => result.current.toggleHistoryType('reservas'));
    await waitFor(() => expect(result.current.historyData.reservas).toHaveLength(2));
    expect(journal.range.at(-1)).toEqual({ view: 'painel_reservations_history_v1', a: 0, b: 49 });
    act(() => result.current.changeHistoryPageSize(25));
    expect(result.current.historyPageSize).toBe(25);
    await waitFor(() => expect(journal.range.filter(r => r.b === 24)).toHaveLength(2)); // les deux types rechargés à 25
  });
});

describe('E6 lot A — usePanelEmprestimos, monté seul', () => {
  beforeEach(() => { journal.rpc.length = 0; rpcData = { ok: true }; });

  it('déplie et replie une ligne ; prolonge par la façade api et recharge ; un refus ok:false remonte au toast', async () => {
    const loadLoans = vi.fn();
    const notifyError = vi.fn();
    const t = ({ id }) => id;
    const { result } = renderHook(() => usePanelEmprestimos({ t, loadLoans, notifyError }));
    expect(result.current.loteStatusFilter).toBe('all');
    expect(result.current.loteSortKey).toBe('due_at_asc');
    act(() => result.current.toggleExpandedLoan(5));
    expect(result.current.expandedLoans.has(5)).toBe(true);
    act(() => result.current.toggleExpandedLoan(5));
    expect(result.current.expandedLoans.has(5)).toBe(false);
    await act(() => result.current.extendLoan(7));
    expect(journal.rpc).toEqual([{ name: 'extend_loan_as_library', args: { p_emprestimo_id: 7 } }]);
    expect(loadLoans).toHaveBeenCalledTimes(1);
    expect(notifyError).not.toHaveBeenCalled();
    rpcData = { ok: false, reason: 'overdue' };
    await act(() => result.current.extendLoanItem(7, 2));
    expect(journal.rpc.at(-1)).toEqual({ name: 'extend_loan_item_as_library', args: { p_emprestimo_id: 7, p_line_no: 2 } });
    expect(notifyError).toHaveBeenCalledTimes(1);
    expect(loadLoans).toHaveBeenCalledTimes(1); // pas de rechargement sur refus
  });
});

describe('E6 lot A — construireTachesDuJour', () => {
  it('classe les tâches : retard en haut, retrait du jour dans « hoje », tâche interne échue en « atencao »', () => {
    const t = ({ id }) => id;
    const today = new Date().toISOString().slice(0, 10);
    const tasks = construireTachesDuJour({
      t, displayTz: 'America/Belem',
      activeRes: [{ workflow_stage_effective: 'retirada_agendada', pickup_scheduled_for: `${today}T12:00:00Z`, user_name: 'A', titulo: 'T1', reserva_id: 1 }],
      overdueLoans: [{ due_at: '2026-01-01', user_name: 'B', titulo: 'T2', sub_id: '9.1', emprestimo_id: 9 }],
      activeLoans: [], consultations: [],
      internalTasks: [{ id: 3, title: 'Ranger', priority: 'media', status: 'aberta', due_date: '2026-01-02' }],
    });
    expect(tasks.map(x => [x.priority, x.bucket, x.actionType])).toEqual([
      ['alta', 'hoje', 'reserva'], ['alta', 'atencao', 'emprestimo'], ['alta', 'atencao', 'tarefa'],
    ]);
  });
});
