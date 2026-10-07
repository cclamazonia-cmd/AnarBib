// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 8 (07/10/2026) : les gestes de réservation
// et de consultation de Mon compte, et leurs états propres, sortent dans le
// hook useReservationActions (src/hooks).
//   * réserver par référence garde ses validations, dans l'ordre : service
//     fermé, profil restreint, aucune référence, plus de cinq, déjà réservé,
//     déjà emprunté ; puis résolution, refus d'un emprunt sur un document en
//     consultation seule, création (réservation ou consultation), message,
//     référence vidée, rechargement ;
//   * annuler, contre-proposer un créneau, refuser un créneau (note exigée),
//     confirmer un créneau : chaque geste appelle sa RPC puis recharge ;
//   * la page appelle le hook et ne définit plus ces gestes.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const rpcPublic = vi.fn();
const rpcApi = vi.fn();
vi.mock('@/lib/supabase', () => ({
  supabase: { rpc: (...a) => rpcPublic(...a), schema: (s) => ({ rpc: (...a) => rpcApi(s, ...a) }) },
  SUPABASE_URL: 'https://exemple.invalid',
}));

import { useReservationActions } from '@/hooks/useReservationActions';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));
const wrapper = ({ children }) => <IntlProvider locale="fr" messages={fr}>{children}</IntlProvider>;

const RESOLU = [{ matched: true, session_holding_id: 55, session_loanable: true, bib_ref: 'BLMF-0007' }];
let alerte;
beforeEach(() => {
  rpcPublic.mockImplementation(async (nom) => nom === 'fn_v2_resolve_catalog_refs_for_current_user'
    ? { data: RESOLU, error: null } : { data: null, error: null });
  rpcApi.mockResolvedValue({ data: { ok: true }, error: null });
  alerte = vi.spyOn(window, 'alert').mockImplementation(() => {});
});
afterEach(() => { rpcPublic.mockReset(); rpcApi.mockReset(); alerte.mockRestore(); });

function monter(sur = {}) {
  const entrees = { user: { id: 'u-1' }, profile: { is_restricted: false }, serviceState: { service_mode: 'funcionamento_normal', allows_new_reservations: true },
    reservations: [], loans: [], loadData: vi.fn(), ...sur };
  const h = renderHook(() => useReservationActions(entrees), { wrapper });
  return { ...h, entrees };
}
const saisir = async (h, ref) => { await act(async () => { h.result.current.setReserveRef(ref); }); };
const reserver = async (h, mode = 'reserve') => { await act(async () => { await h.result.current.handleReserve(mode); }); };

describe('réserver par référence, depuis le hook', () => {
  it('refuse quand le service est en pause, puis quand le profil est restreint, sans appeler la base', async () => {
    const h = monter({ serviceState: { service_mode: 'pausada' } });
    await saisir(h, 'BLMF-0007'); await reserver(h);
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.loansClosed']);
    const r = monter({ profile: { is_restricted: true } });
    await saisir(r, 'BLMF-0007'); await reserver(r);
    expect(r.result.current.reserveMsg).toBe(fr['account.reserve.restricted']);
    expect(rpcPublic).not.toHaveBeenCalled();
  });

  it('refuse sans référence, au-delà de cinq, déjà réservé, déjà emprunté', async () => {
    const h = monter({ reservations: [{ bib_ref: 'BLMF-0007' }], loans: [{ item_status: 'aberto', bib_ref: 'BLMF-0008' }] });
    await reserver(h);
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.pasteHintLoan']);
    await saisir(h, 'a, b, c, d, e, f'); await reserver(h);
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.maxLoan']);
    await saisir(h, 'blmf-0007'); await reserver(h);
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.alreadyReserved'].replace('{refs}', 'blmf-0007'));
    await saisir(h, 'BLMF-0008'); await reserver(h);
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.alreadyLoaned'].replace('{refs}', 'BLMF-0008'));
    expect(rpcPublic).not.toHaveBeenCalled();
  });

  it('résout la référence, crée la réservation pour la personne connectée, vide la saisie et recharge', async () => {
    const h = monter();
    await saisir(h, 'BLMF-0007'); await reserver(h);
    expect(rpcPublic).toHaveBeenCalledWith('fn_v2_resolve_catalog_refs_for_current_user', { p_refs: ['BLMF-0007'] });
    expect(rpcPublic).toHaveBeenCalledWith('fn_v2_create_reserva_by_holdings',
      { p_user_id: 'u-1', p_holding_ids: [55], p_notes: '@@note:account.reserve.noteLoan' });
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.loanRegistered'].replace('{count}', '1'));
    expect(h.result.current.reserveRef).toBe('');
    expect(h.entrees.loadData).toHaveBeenCalled();
  });

  it('un document en consultation seule ne s’emprunte pas, mais se consulte (RPC api)', async () => {
    rpcPublic.mockImplementation(async (nom) => nom === 'fn_v2_resolve_catalog_refs_for_current_user'
      ? { data: [{ matched: true, session_holding_id: 56, session_loanable: false, bib_ref: 'REV-1' }], error: null } : { data: null, error: null });
    const h = monter();
    await saisir(h, 'REV-1'); await reserver(h, 'reserve');
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.consultationOnlyHint'].replace('{refs}', 'REV-1'));
    expect(rpcPublic).not.toHaveBeenCalledWith('fn_v2_create_reserva_by_holdings', expect.anything());
    await reserver(h, 'consult');
    expect(rpcApi).toHaveBeenCalledWith('api', 'create_consulta_local',
      { p_user_id: 'u-1', p_holding_ids: [56], p_notes: '@@note:account.reserve.noteConsult' });
    expect(h.result.current.reserveMsg).toBe(fr['account.reserve.consultationRegistered'].replace('{count}', '1'));
  });
});

describe('les autres gestes, depuis le hook', () => {
  it('annuler une réservation appelle api.cancel_my_reservation puis recharge', async () => {
    const h = monter();
    await act(async () => { await h.result.current.cancelReservation(41); });
    expect(rpcApi).toHaveBeenCalledWith('api', 'cancel_my_reservation', { p_reserva_id: 41 });
    expect(h.entrees.loadData).toHaveBeenCalled();
  });

  it('la contre-proposition : le formulaire s’ouvre pré-rempli, l’envoi appelle la RPC et le referme', async () => {
    const h = monter();
    act(() => h.result.current.openCounterProposalForm(41, 1, '2026-10-15T14:00:00'));
    expect(h.result.current.negotiationForm).toMatchObject({ reservaId: 41, lineNo: 1, note: '' });
    expect(h.result.current.negotiationForm.datetime).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/);
    await act(async () => { await h.result.current.handleSubmitCounterProposal(); });
    expect(rpcApi).toHaveBeenCalledWith('api', 'fn_propose_pickup_slot_as_reader',
      expect.objectContaining({ p_reserva_id: 41, p_line_no: 1, p_note: null }));
    expect(h.result.current.negotiationForm).toBeNull();
  });

  it('refuser un créneau exige une note ; avec la note, la RPC est appelée et la modale se ferme', async () => {
    const h = monter();
    const c = { consulta_id: 7, line_no: 1 };
    act(() => h.result.current.openRefuseModal(c));
    expect(h.result.current.refuseTarget).toBe(c);
    await act(async () => { await h.result.current.handleRefuseSchedule(); });
    expect(h.result.current.refuseError).toBe(fr['account.consultations.refuseModal.errorNoteRequired']);
    expect(rpcApi).not.toHaveBeenCalled();
    act(() => h.result.current.setRefuseNote('indisponible ce jour-là'));
    await act(async () => { await h.result.current.handleRefuseSchedule(); });
    expect(rpcApi).toHaveBeenCalledWith('api', 'reply_consulta_schedule',
      { p_consulta_id: 7, p_line_nos: [1], p_reply: 'recusado_leitor', p_note: 'indisponible ce jour-là' });
    expect(h.result.current.refuseTarget).toBeNull();
    await act(async () => { await h.result.current.handleConfirmSchedule(c); });
    expect(rpcApi).toHaveBeenCalledWith('api', 'reply_consulta_schedule',
      { p_consulta_id: 7, p_line_nos: [1], p_reply: 'confirmado_leitor', p_note: null });
  });
});

describe('la page appelle le hook et ne définit plus ces gestes', () => {
  it('AccountPage délègue, le hook porte les onze gestes', () => {
    const page = lire('src/pages/account/AccountPage.jsx');
    const hook = lire('src/hooks/useReservationActions.js');
    expect(page).toContain('} = useReservationActions({ user, profile, serviceState, reservations, loans, loadData });');
    for (const g of ['async function handleReserve', 'async function cancelReservation', 'const handleRefuseSchedule', "const [reserveRef, setReserveRef] = useState('')"]) {
      expect(page, g).not.toContain(g);
      expect(hook, g).toContain(g);
    }
    expect(page).not.toContain('fn_v2_resolve_catalog_refs_for_current_user');
  });
});
