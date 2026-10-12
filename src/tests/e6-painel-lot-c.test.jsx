// AnarBib — E6, le Panneau en crochets par domaine, lot C (12/10/2026) :
// usePanelConsultas + ConsultaModals, usePanelLeitor + PaymentModal. Source,
// comportement des crochets montés seuls, et les deux modales montées.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act, render, screen } from '@testing-library/react';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const lire = (p) => readFileSync(resolve(__dirname, '..', p), 'utf8');

const journal = { api: [], pub: [], from: [] };
let apiReponse = () => ({ data: { ok: true }, error: null });
let pubReponse = () => ({ data: null, error: null });
let tables = {};
function requete(table) {
  journal.from.push(table);
  const q = {
    select: () => q, eq: () => q, order: () => q, in: () => q, limit: () => q, maybeSingle: () => q,
    then: (res) => res({ data: tables[table] ?? [], error: null }),
  };
  return q;
}
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: (table) => requete(table),
    schema: () => ({
      rpc: async (name, args) => { journal.api.push({ name, args }); return apiReponse(name, args); },
      from: (table) => requete(table),
    }),
    rpc: async (name, args) => { journal.pub.push({ name, args }); return pubReponse(name, args); },
  },
  apiQuery: async () => ({ data: [] }),
}));

const { usePanelConsultas } = await import('@/pages/painel/hooks/usePanelConsultas');
const { usePanelLeitor } = await import('@/pages/painel/hooks/usePanelLeitor');
const { default: PaymentModal } = await import('@/pages/painel/PaymentModal.jsx');
const { default: ConsultaModals } = await import('@/pages/painel/ConsultaModals.jsx');
const t = ({ id }, v) => (v ? `${id}:${JSON.stringify(v)}` : id);

describe('E6 lot C — la source', () => {
  const page = lire('pages/painel/PanelPage.jsx');
  const cons = lire('pages/painel/hooks/usePanelConsultas.js');
  const leitor = lire('pages/painel/hooks/usePanelLeitor.js');
  const modales = lire('pages/painel/ConsultaModals.jsx');
  const paiement = lire('pages/painel/PaymentModal.jsx');

  it('la page importe les crochets et les modales, et ne porte plus leur code', () => {
    for (const imp of ["import { usePanelConsultas } from './hooks/usePanelConsultas';", "import { usePanelLeitor } from './hooks/usePanelLeitor';",
      "import ConsultaModals from './ConsultaModals';", "import PaymentModal from './PaymentModal';"]) expect(page).toContain(imp);
    for (const parti of ['async function searchReader', 'async function submitPayment', 'function openScheduleModal', 'const [readerProfile',
      'const [paymentDraft', 'const [scheduleTarget', 'const [cancelTarget', 'setMembershipEnabled', 'membership.payment.modalTitle',
      'panel.consultation.schedule.title', '<Modal', 'parseAddressText', 'fn_record_membership_payment']) {
      expect(page.includes(parti), `resté dans la page : ${parti}`).toBe(false);
    }
    expect(page).toContain('const consultas = usePanelConsultas({ t, loadConsultas, notifyError });');
    expect(page).toContain('const leitor = usePanelLeitor({ t, libraryId, isLibrarian, isCoordOrAdmin, membershipEnabled, tab });');
    expect(page).toContain('<PaymentModal t={t} {...leitor} />');
    expect(page).toContain('<ConsultaModals t={t} consultationTz={consultationTz} {...consultas} />');
    // l'alias membershipEnabled (contexte) précède le crochet qui le lit
    expect(page.indexOf('const membershipEnabled = membership_enabled;')).toBeLessThan(page.indexOf('const leitor = usePanelLeitor('));
    // le crochet des consultations vient après loadConsultas, qu'il rappelle
    expect(page.indexOf('const loadConsultas = useCallback')).toBeLessThan(page.indexOf('const consultas = usePanelConsultas('));
  });

  it('les onglets reçoivent les mêmes props qu’avant', () => {
    for (const prop of ['readerLookup', 'setReaderLookup', 'readerProfile', 'setReaderProfile', 'readerMatchInfo', 'readerMsg', 'setReaderMsg',
      'editAddrState', 'setEditAddrState', 'editProfileMsg', 'setEditProfileMsg', 'restrictReason', 'setRestrictReason', 'restrictionState',
      'setRestrictionState', 'restrictBusy', 'setRestrictBusy', 'freezeReason', 'setFreezeReason', 'readerPayments', 'membershipRules',
      'searchReader', 'openPaymentModal', 'membershipFilter', 'setMembershipFilter', 'membershipOverview', 'getMembershipFilterCount',
      'fmtMembershipStatus', 'loadMembershipOverview', 'setConsultaWorkflow', 'openScheduleModal', 'openCancelModal', 'membershipEnabled']) {
      expect(page).toContain(`${prop}={${prop}}`);
    }
  });

  it('les crochets ne rendent rien ; les modales ne portent ni état ni appel réseau', () => {
    for (const [nom, s] of [['usePanelConsultas', cons], ['usePanelLeitor', leitor]]) {
      expect(s, nom).not.toMatch(/setTab\(|<[A-Z][A-Za-z]+[ />]|from 'react-intl'/);
      expect(s, nom).toMatch(/^export function /m);
    }
    for (const [nom, s] of [['ConsultaModals', modales], ['PaymentModal', paiement]]) {
      expect(s, nom).not.toMatch(/useState|useEffect|supabase|\.rpc\(/);
      expect(s, nom).toMatch(/^export default function /m);
    }
    expect(cons).toContain("supabase.schema('api').rpc('advance_consulta', params)");
    expect(cons).toContain('if (opts.rethrow) throw e;');
    expect(leitor).toContain("supabase.rpc('fn_painel_search_reader', { p_lookup: normalizePublicId(readerLookup), p_library_id: libraryId })");
    expect(leitor).toContain("supabase.rpc('fn_record_membership_payment', {");
    expect(leitor).toContain('}, [readerProfile?.id]);');
    expect(paiement).toContain('if (!paymentModal || !paymentDraft) return null;');
    expect(modales).toContain("isOpen={!!scheduleTarget}");
    expect(modales).toContain("isOpen={!!cancelTarget}");
  });

  it('la page a fini de maigrir : moins de 50 Ko', () => {
    expect(Buffer.byteLength(page, 'utf8')).toBeLessThan(50 * 1024);
  });
});

describe('E6 lot C — usePanelConsultas, monté seul', () => {
  beforeEach(() => { journal.api.length = 0; apiReponse = () => ({ data: { ok: true }, error: null }); });

  it('planifier : demain par défaut, refus fin avant début, puis advance_consulta en ISO ; un refus du serveur reste dans la modale', async () => {
    const loadConsultas = vi.fn(); const notifyError = vi.fn();
    const { result } = renderHook(() => usePanelConsultas({ t, loadConsultas, notifyError }));
    const consulta = { consulta_id: 4, line_no: 1, user_name: 'Dia', titulo: 'T' };
    act(() => result.current.openScheduleModal(consulta));
    expect(result.current.scheduleTarget).toBe(consulta);
    expect(result.current.scheduleForm).toMatchObject({ startsAt: '14:00', endsAt: '15:00', note: '' });
    expect(result.current.scheduleForm.date > new Date().toISOString().slice(0, 10)).toBe(true);
    act(() => result.current.setScheduleForm(f => ({ ...f, endsAt: '13:00' })));
    await act(() => result.current.handleScheduleSubmit());
    expect(result.current.scheduleError).toBe('panel.consultation.schedule.errorEndBeforeStart');
    expect(journal.api).toEqual([]);
    act(() => result.current.setScheduleForm(f => ({ ...f, endsAt: '16:00', note: 'salle 2' })));
    await act(() => result.current.handleScheduleSubmit());
    expect(journal.api).toHaveLength(1);
    expect(journal.api[0].name).toBe('advance_consulta');
    expect(journal.api[0].args).toMatchObject({ p_consulta_id: 4, p_line_nos: [1], p_target_stage: 'consulta_agendada', p_workflow_note: 'salle 2' });
    expect(journal.api[0].args.p_consultation_starts_at).toMatch(/Z$/);
    expect(result.current.scheduleTarget).toBeNull();
    expect(loadConsultas).toHaveBeenCalledTimes(1);
    expect(notifyError).not.toHaveBeenCalled();
    // refus du serveur : relevé vers la modale, pas vers le toast
    apiReponse = () => ({ data: { ok: false, reason: 'consulta_outside_window' }, error: null });
    act(() => result.current.openScheduleModal(consulta));
    await act(() => result.current.handleScheduleSubmit());
    expect(result.current.scheduleTarget).toBe(consulta);
    expect(result.current.scheduleError).not.toBe('');
    expect(notifyError).not.toHaveBeenCalled();
  });

  it('annuler : note trop courte refusée, puis cancelada_biblioteca envoyée et la modale fermée', async () => {
    const loadConsultas = vi.fn();
    const { result } = renderHook(() => usePanelConsultas({ t, loadConsultas, notifyError: vi.fn() }));
    const consulta = { consulta_id: 5, line_no: 2 };
    act(() => result.current.openCancelModal(consulta));
    act(() => result.current.setCancelForm({ note: 'nn' }));
    await act(() => result.current.handleCancelSubmit());
    expect(result.current.cancelError).toBe('panel.consultation.cancel.errorNoteTooShort');
    act(() => result.current.setCancelForm({ note: 'Livre indisponible' }));
    await act(() => result.current.handleCancelSubmit());
    expect(journal.api.at(-1).args).toMatchObject({ p_consulta_id: 5, p_line_nos: [2], p_target_stage: 'cancelada_biblioteca', p_workflow_note: 'Livre indisponible' });
    expect(result.current.cancelTarget).toBeNull();
    expect(loadConsultas).toHaveBeenCalledTimes(1);
  });
});

describe('E6 lot C — usePanelLeitor, monté seul', () => {
  beforeEach(() => {
    journal.api.length = 0; journal.pub.length = 0; journal.from.length = 0;
    tables = { library_membership_rules: [{ id: 'r1', name: 'Annuelle', amount_suggested: 20, amount_min: 10, currency: 'EUR' }], v_membership_overview_panel: [{ dues_status: 'expired' }, { dues_status: 'up_to_date' }] };
    apiReponse = () => ({ data: { ok: true, local: 'x' }, error: null });
    pubReponse = (name) => name === 'fn_painel_search_reader'
      ? { data: [{ profile: { id: 'u9', address: { line1: '12 rue A', city: 'Paris' } }, matched_via: 'email', is_fallback: false }], error: null }
      : name === 'fn_list_membership_payments_for_user' ? { data: [{ id: 'p1' }], error: null }
      : { data: [{ valid_from: '2026-10-12', valid_until: '2027-10-12' }], error: null };
  });

  it('cherche un·e lecteur·rice : vide refusé ; trouvé·e → profil, restriction, paiements, adresse parsée', async () => {
    const { result } = renderHook(() => usePanelLeitor({ t, libraryId: 'L1', isLibrarian: true, isCoordOrAdmin: false, membershipEnabled: true, tab: 'leitor' }));
    await act(() => result.current.searchReader());
    expect(result.current.readerMsg).toBe('panel.loan.errorMissing');
    act(() => result.current.setReaderLookup(' ana@x.org '));
    await act(() => result.current.searchReader());
    expect(journal.pub.map(a => a.name)).toEqual(['fn_painel_search_reader', 'fn_list_membership_payments_for_user']);
    expect(journal.api.map(a => a.name)).toEqual(['get_member_restriction']);
    expect(result.current.readerProfile.id).toBe('u9');
    expect(result.current.readerMatchInfo).toMatchObject({ matchedVia: 'email', isFallback: false });
    expect(result.current.readerPayments).toEqual([{ id: 'p1' }]);
    expect(result.current.restrictionState).toMatchObject({ ok: true });
    expect(result.current.editAddrState.city).toBe('Paris');
    expect(result.current.readerMsg).toBe('');
  });

  it('cotisation : les règles se chargent, l’aperçu sur l’onglet, la modale prend la première règle, le paiement part et rafraîchit', async () => {
    const { result, rerender } = renderHook((p) => usePanelLeitor(p),
      { initialProps: { t, libraryId: 'L1', isLibrarian: true, isCoordOrAdmin: true, membershipEnabled: true, tab: 'leitor' } });
    await act(async () => {});
    expect(result.current.membershipRules).toHaveLength(1);
    expect(result.current.membershipOverview).toEqual([]);
    rerender({ t, libraryId: 'L1', isLibrarian: true, isCoordOrAdmin: true, membershipEnabled: true, tab: 'contribuicoes' });
    await act(async () => {});
    expect(result.current.membershipOverview).toHaveLength(2);
    expect(result.current.getMembershipFilterCount('expired')).toBe(1);
    expect(result.current.getMembershipFilterCount('all')).toBe(2);
    expect(result.current.fmtMembershipStatus('up_to_date', 10)).toMatchObject({ variant: 'warn' });
    expect(result.current.fmtMembershipStatus('expired')).toMatchObject({ variant: 'danger' });
    act(() => result.current.openPaymentModal({ user_id: 'u9', display_name: 'Ana' }));
    expect(result.current.paymentDraft).toMatchObject({ user_id: 'u9', rule_id: 'r1', amount_paid: 20, payment_method: 'cash' });
    act(() => result.current.setPaymentDraft(p => ({ ...p, amount_paid: '25' })));
    await act(() => result.current.submitPayment());
    const envoi = journal.pub.find(a => a.name === 'fn_record_membership_payment');
    expect(envoi.args).toMatchObject({ p_user_id: 'u9', p_rule_id: 'r1', p_amount_paid: 25, p_payment_method: 'cash', p_notes: null });
    expect(result.current.paymentMsg).toBe('membership.payment.recorded:{"from":"2026-10-12","until":"2027-10-12"}');
    expect(result.current.paymentMsgIsError).toBe(false);
  });

  it('sans règle, la modale ne s’ouvre pas et le dit', () => {
    tables = { library_membership_rules: [] };
    const { result } = renderHook(() => usePanelLeitor({ t, libraryId: 'L1', isLibrarian: true, isCoordOrAdmin: true, membershipEnabled: true, tab: 'leitor' }));
    act(() => result.current.openPaymentModal({ user_id: 'u9', display_name: 'Ana' }));
    expect(result.current.paymentModal).toBeNull();
    expect(result.current.paymentMsg).toBe('membership.payment.noRulesAvailable');
    expect(result.current.paymentMsgIsError).toBe(true);
  });
});

describe('E6 lot C — les modales montées', () => {
  it('PaymentModal rend null sans saisie, puis le formulaire avec la règle et le montant', () => {
    const base = { t, membershipRules: [{ id: 'r1', name: 'Annuelle', amount_min: 10, currency: 'EUR' }], onPaymentRuleChange: vi.fn(),
      setPaymentDraft: vi.fn(), paymentMsg: '', paymentMsgIsError: false, paymentSaving: false, submitPayment: vi.fn(), closePaymentModal: vi.fn() };
    const { container, rerender } = render(<PaymentModal {...base} paymentModal={null} paymentDraft={null} />);
    expect(container.innerHTML).toBe('');
    rerender(<PaymentModal {...base} paymentModal={{ display_name: 'Ana' }} paymentDraft={{ rule_id: 'r1', amount_paid: 20, payment_method: 'cash', paid_at: '2026-10-12', notes: '' }} />);
    expect(screen.getByText('membership.payment.modalTitle')).toBeTruthy();
    expect(screen.getByText('membership.payment.forReader:{"name":"Ana"}')).toBeTruthy();
    expect(screen.getByDisplayValue('20')).toBeTruthy();
    expect(screen.getByText('membership.payment.submit')).toBeTruthy();
  });

  it('ConsultaModals montre la planification quand une consultation est visée, avec le fuseau de la bibliothèque', () => {
    const props = { t, consultationTz: 'Europe/Lisbon', scheduleTarget: { user_name: 'Dia', titulo: 'T' }, scheduleForm: { date: '2026-10-20', startsAt: '14:00', endsAt: '15:00', note: '' },
      setScheduleForm: vi.fn(), scheduling: false, scheduleError: 'erreur X', closeScheduleModal: vi.fn(), handleScheduleSubmit: vi.fn(),
      cancelTarget: null, cancelForm: { note: '' }, setCancelForm: vi.fn(), cancelling: false, cancelError: '', closeCancelModal: vi.fn(), handleCancelSubmit: vi.fn() };
    render(<ConsultaModals {...props} />);
    expect(screen.getByText('panel.consultation.schedule.title')).toBeTruthy();
    expect(screen.getByText('panel.consultation.schedule.timezoneHint:{"tz":"Europe/Lisbon"}')).toBeTruthy();
    expect(screen.getByText('erreur X')).toBeTruthy();
    expect(screen.queryByText('panel.consultation.cancel.title')).toBeNull();
  });
});
