// AnarBib — E6, le Panneau en crochets par domaine, lot B (12/10/2026) :
// usePanelReservas et usePanelAcoes. Source (ce qui est parti n'y est plus,
// les onglets reçoivent les mêmes props) et comportement, crochets montés
// seuls avec un supabase factice.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const lire = (p) => readFileSync(resolve(__dirname, '..', p), 'utf8');

const journal = { api: [], pub: [] };
let apiReponse = () => ({ data: null, error: null });
let pubReponse = () => ({ data: null, error: null });
vi.mock('@/lib/supabase', () => ({
  supabase: {
    schema: () => ({
      rpc: async (name, args) => { journal.api.push({ name, args }); return apiReponse(name, args); },
    }),
    rpc: async (name, args) => { journal.pub.push({ name, args }); return pubReponse(name, args); },
  },
  apiQuery: async () => ({ data: [] }),
}));

const { usePanelReservas } = await import('@/pages/painel/hooks/usePanelReservas');
const { usePanelAcoes } = await import('@/pages/painel/hooks/usePanelAcoes');
const t = ({ id }, v) => (v ? `${id}:${JSON.stringify(v)}` : id);

describe('E6 lot B — la source', () => {
  const page = lire('pages/painel/PanelPage.jsx');
  const res = lire('pages/painel/hooks/usePanelReservas.js');
  const acoes = lire('pages/painel/hooks/usePanelAcoes.js');

  it('la page importe les deux crochets et ne porte plus leur code', () => {
    expect(page).toContain("import { usePanelReservas } from './hooks/usePanelReservas';");
    expect(page).toContain("import { usePanelAcoes } from './hooks/usePanelAcoes';");
    for (const parti of ['async function applyResWorkflow', 'async function registrarSaida', 'function toggleAllRes', 'const [selectedRes',
      'const [negotiationForm', 'const [loanPreview', 'setActionMsg(', 'setReturnMsg(', 'window.prompt', 'create_loan_at_counter']) {
      expect(page.includes(parti), `resté dans la page : ${parti}`).toBe(false);
    }
    expect(page).toMatch(/= usePanelReservas\(\{ t, activeRes, loadReservas, loadLoans \}\);/);
    expect(page).toMatch(/= usePanelAcoes\(\{ t, libraryId, loans, loadLoans \}\);/);
    // le crochet des réservations lit activeRes : il est appelé APRÈS son calcul, avant les retours anticipés
    expect(page.indexOf('const activeRes = reservations.filter')).toBeLessThan(page.indexOf('= usePanelReservas('));
    expect(page.indexOf('= usePanelReservas(')).toBeLessThan(page.indexOf('if (!roleLoaded) {'));
  });

  it('les onglets reçoivent les mêmes props qu’avant', () => {
    for (const prop of ['borrowerLookup', 'setBorrowerLookup', 'loanRefs', 'setLoanRefs', 'loanPreview', 'setLoanPreview', 'loanBusy', 'loanMsg',
      'returnId', 'setReturnId', 'returnSubIds', 'setReturnSubIds', 'returnMsg', 'registrarSaida', 'cancelLoanPreview', 'registrarDevolucaoTotal',
      'registrarDevolucaoParcial', 'returnTotalPreview', 'setReturnTotalPreview', 'returnPartialPreview', 'setReturnPartialPreview',
      'cancelReturnTotalPreview', 'cancelReturnPartialPreview', 'selectedRes', 'resNote', 'setResNote', 'resSchedule', 'setResSchedule',
      'resStage', 'setResStage', 'actionMsg', 'negotiationForm', 'setNegotiationForm', 'confirmSelectedPickup', 'cancelSelectedRes',
      'applyResWorkflow', 'toggleAllRes', 'toggleRes', 'confirmReaderSlot', 'openCounterProposalForm', 'cancelWithReason', 'submitCounterProposal']) {
      expect(page).toContain(`${prop}={${prop}}`);
    }
  });

  it('les crochets ne rendent rien, n’écrivent pas l’onglet, et passent par la façade api', () => {
    for (const [nom, s] of [['usePanelReservas', res], ['usePanelAcoes', acoes]]) {
      expect(s, nom).not.toMatch(/setTab\(|<[A-Z][A-Za-z]+[ />]|from 'react-intl'|useEffect/);
      expect(s, nom).toMatch(/^export function /m);
    }
    expect(res).toContain("supabase.schema('api').rpc('advance_reservation'");
    expect(res).toContain("supabase.schema('api').rpc('confirm_pickup_v1'");
    expect(res).toContain('if (selectedRes.size === activeRes.length) setSelectedRes(new Set());');
    expect(acoes).toContain("supabase.schema('api').rpc('create_loan_at_counter'");
    expect(acoes).toContain("supabase.rpc('fn_painel_search_reader', { p_lookup: normalizePublicId(borrowerLookup), p_library_id: libraryId })");
    expect(acoes).toContain('const matchingItems = loans.filter(l => l.emprestimo_id === id);');
  });

  it('la page a encore maigri', () => {
    expect(Buffer.byteLength(page, 'utf8')).toBeLessThan(80 * 1024);
  });
});

describe('E6 lot B — usePanelReservas, monté seul', () => {
  beforeEach(() => { journal.api.length = 0; apiReponse = () => ({ data: null, error: null }); });

  it('sélectionne, « tout » porte sur les actives, refuse sans étape, puis applique et recharge', async () => {
    const loadReservas = vi.fn(); const loadLoans = vi.fn();
    const activeRes = [{ reserva_id: 1, line_no: 1 }, { reserva_id: 2, line_no: 1 }];
    const { result } = renderHook(() => usePanelReservas({ t, activeRes, loadReservas, loadLoans }));
    act(() => result.current.toggleRes('1-1'));
    expect([...result.current.selectedRes]).toEqual(['1-1']);
    act(() => result.current.toggleAllRes());
    expect([...result.current.selectedRes]).toEqual(['1-1', '2-1']);
    await act(() => result.current.applyResWorkflow());
    expect(result.current.actionMsg).toBe('panel.action.selectStep');
    expect(journal.api).toEqual([]);
    act(() => result.current.setResStage('retirada_no_show'));
    await act(() => result.current.applyResWorkflow());
    expect(journal.api.map(a => a.name)).toEqual(['mark_no_show', 'mark_no_show']);
    expect(journal.api[1].args).toEqual({ p_reserva_id: 2, p_line_no: 1 });
    expect(result.current.selectedRes.size).toBe(0);
    expect(loadReservas).toHaveBeenCalledTimes(1);
    expect(result.current.actionMsg).toBe('panel.action.stepApplied:{"count":2}');
  });

  it('confirmer le retrait convertit en emprunt, recharge les deux listes, et montre les numéros', async () => {
    const loadReservas = vi.fn(); const loadLoans = vi.fn();
    apiReponse = () => ({ data: 41, error: null });
    const { result } = renderHook(() => usePanelReservas({ t, activeRes: [], loadReservas, loadLoans }));
    act(() => result.current.toggleRes('3-2'));
    await act(() => result.current.confirmSelectedPickup());
    expect(journal.api).toEqual([{ name: 'confirm_pickup_v1', args: { p_reserva_id: 3, p_line_no: 2, p_loan_options: {} } }]);
    expect(loadReservas).toHaveBeenCalledTimes(1);
    expect(loadLoans).toHaveBeenCalledTimes(1);
    expect(result.current.actionMsg).toBe('panel.action.pickupConfirmedWithIds:{"count":1,"loanIds":"41"}');
  });

  it('une contre-proposition sans date est refusée ; avec date elle part en ISO et ferme le formulaire', async () => {
    const loadReservas = vi.fn();
    const { result } = renderHook(() => usePanelReservas({ t, activeRes: [], loadReservas, loadLoans: vi.fn() }));
    act(() => result.current.openCounterProposalForm(5, 1, null));
    expect(result.current.negotiationForm).toEqual({ reservaId: 5, lineNo: 1, datetime: '', note: '' });
    await act(() => result.current.submitCounterProposal());
    expect(result.current.actionMsg).toBe('panel.action.counterProposalDatetimeRequired');
    act(() => result.current.setNegotiationForm(f => ({ ...f, datetime: '2026-10-20T14:00', note: ' ok ' })));
    await act(() => result.current.submitCounterProposal());
    expect(journal.api).toHaveLength(1);
    expect(journal.api[0].name).toBe('fn_propose_pickup_slot_as_library');
    expect(journal.api[0].args.p_pickup_at).toBe(new Date('2026-10-20T14:00').toISOString());
    expect(journal.api[0].args.p_note).toBe('ok');
    expect(result.current.negotiationForm).toBeNull();
    expect(loadReservas).toHaveBeenCalledTimes(1);
  });
});

describe('E6 lot B — usePanelAcoes, monté seul', () => {
  beforeEach(() => { journal.api.length = 0; journal.pub.length = 0; apiReponse = () => ({ data: null, error: null }); });

  it('la sortie exige un·e lecteur·rice et des références ; l’aperçu puis la confirmation', async () => {
    const loadLoans = vi.fn();
    pubReponse = (name) => name === 'fn_painel_search_reader'
      ? { data: [{ profile: { id: 'u1', first_name: 'Ana' } }], error: null }
      : { data: [{ matched: true, session_holding_id: 11, book_id: 7 }], error: null };
    apiReponse = (name) => name === 'get_batch_loan_projection' ? { data: [{ due_date: '2026-11-01', rule_label: 'R', loan_allowed: true }], error: null } : { data: null, error: null };
    const { result } = renderHook(() => usePanelAcoes({ t, libraryId: 'L1', loans: [], loadLoans }));
    await act(() => result.current.registrarSaida());
    expect(result.current.loanMsg).toBe('panel.loan.errorMissing');
    act(() => { result.current.setBorrowerLookup('ana'); result.current.setLoanRefs('BLMF-1, BLMF-2'); });
    await act(() => result.current.registrarSaida());
    expect(journal.pub.map(a => a.name)).toEqual(['fn_painel_search_reader', 'fn_v2_resolve_catalog_refs_for_current_user']);
    expect(journal.api.map(a => a.name)).toEqual(['get_batch_loan_projection']);
    expect(result.current.loanPreview).toMatchObject({ borrowerId: 'u1', holdingIds: [11], refsKey: 'BLMF-1|BLMF-2', loanAllowed: true });
    expect(loadLoans).not.toHaveBeenCalled();
    await act(() => result.current.registrarSaida()); // phase 2 : même saisie → confirmation
    expect(journal.api.at(-1)).toEqual({ name: 'create_loan_at_counter', args: { p_user_id: 'u1', p_holding_ids: [11] } });
    expect(result.current.loanPreview).toBeNull();
    expect(result.current.loanRefs).toBe('');
    expect(loadLoans).toHaveBeenCalledTimes(1);
  });

  it('le retour total : inconnu, déjà clos, puis aperçu et confirmation ; l’annulation efface', async () => {
    const loadLoans = vi.fn();
    const loans = [
      { emprestimo_id: 9, line_no: 1, item_status: 'aberto', user_name: 'Bea' },
      { emprestimo_id: 9, line_no: 2, item_status: 'devolvido', user_name: 'Bea' },
      { emprestimo_id: 10, line_no: 1, item_status: 'devolvido', user_name: 'Caio' },
    ];
    const { result } = renderHook(() => usePanelAcoes({ t, libraryId: 'L1', loans, loadLoans }));
    act(() => result.current.setReturnId('77'));
    await act(() => result.current.registrarDevolucaoTotal());
    expect(result.current.returnMsg).toBe('panel.return.total.notFound:{"id":77}');
    act(() => result.current.setReturnId('10'));
    await act(() => result.current.registrarDevolucaoTotal());
    expect(result.current.returnMsg).toBe('panel.return.total.alreadyClosed:{"id":10}');
    act(() => result.current.setReturnId('9'));
    await act(() => result.current.registrarDevolucaoTotal());
    expect(result.current.returnTotalPreview).toEqual({ id: 9, borrowerName: 'Bea', itemCount: 1 });
    expect(journal.api).toEqual([]);
    await act(() => result.current.registrarDevolucaoTotal());
    expect(journal.api).toEqual([{ name: 'return_loan_total', args: { p_emprestimo_id: 9 } }]);
    expect(result.current.returnId).toBe('');
    expect(loadLoans).toHaveBeenCalledTimes(1);
    act(() => result.current.setReturnSubIds('9.1'));
    await act(() => result.current.registrarDevolucaoParcial());
    expect(result.current.returnPartialPreview).toMatchObject({ subIdsKey: '9.1', malformed: [], preRejected: [] });
    act(() => result.current.cancelReturnPartialPreview());
    expect(result.current.returnPartialPreview).toBeNull();
    expect(result.current.returnMsg).toBe('');
  });
});
