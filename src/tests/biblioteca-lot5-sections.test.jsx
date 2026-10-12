// AnarBib — E6, BibliotecaPage lot 5 (12/10/2026) : les onglets Communications
// et Règlement sortent de la page (CommsSection, RegulationSection). Source et
// sections montées en français avec un supabase factice.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

const journal = { from: [], rpc: [] };
function requete(table) {
  const q = { update: (data) => { journal.from.push({ table, data }); return q; }, eq: () => q, then: (res) => res({ data: null, error: null }) };
  return q;
}
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: (table) => requete(table),
    rpc: async (name, args) => { journal.rpc.push({ name, args }); return { data: null, error: null }; },
    storage: { from: () => ({ upload: async () => ({ error: null }), remove: async () => ({}) }) },
  },
  SUPABASE_URL: 'https://exemple.invalid',
}));
vi.mock('@/components/library/LibraryContactProfileSection', () => ({ default: () => <div data-testid="contact-profile" /> }));
vi.mock('@/components/library/LibraryPublicContactSection', () => ({ default: () => <div data-testid="public-contact" /> }));
vi.mock('@/components/library/RegimeStateBox', () => ({ default: () => <div data-testid="regime" /> }));
vi.mock('@/components/library/PolicySetManager', () => ({ default: () => <div data-testid="policy-sets" /> }));
vi.mock('@/pages/biblioteca/MembershipSection', () => ({ default: () => <div data-testid="membership" /> }));
vi.mock('@/pages/biblioteca/DepositSection', () => ({ default: () => <div data-testid="deposit" /> }));

const { default: CommsSection } = await import('@/pages/biblioteca/CommsSection.jsx');
const { default: RegulationSection } = await import('@/pages/biblioteca/RegulationSection.jsx');
const monter = (ui) => render(<IntlProvider locale="fr" messages={fr}>{ui}</IntlProvider>);

describe('E6 Biblioteca lot 5 — la source', () => {
  const page = lire('src/pages/biblioteca/BibliotecaPage.jsx');
  it('les deux onglets sont montés à leur place et la page ne porte plus leur logique', () => {
    expect(page).toContain("import CommsSection from './CommsSection';");
    expect(page).toContain("import RegulationSection from './RegulationSection';");
    expect(page).toMatch(/\{tab==='comms' && \(\n\s+<CommsSection libraryId=\{libraryId\} isCoord=\{isCoord\} user=\{user\} commons=\{commons\} setC=\{setC\}/);
    expect(page).toMatch(/\{tab==='regulation' && \(\n\s+<RegulationSection libraryId=\{libraryId\} isCoord=\{isCoord\} user=\{user\} lib=\{lib\} setLib=\{setLib\} regDocs=\{regDocs\}/);
    expect(page).toContain('setMsg={setMsg} onChanged={loadAll} />');
    for (const gone of ['async function saveComms', 'async function uploadRegimento', 'async function removeRegimento', 'function seedT', 'NOTIFICATION_FLAG_KEYS',
      'regFileRef', 'function setMC', 'function setNP', 'biblioteca.comms.adminRecipients', 'biblioteca.regulation.choosePdf', '<PolicySetManager', "import MembershipSection from"]) {
      expect(page.includes(gone), `${gone} encore dans BibliotecaPage`).toBe(false);
    }
    // les états chargés par loadCore restent au parent ; setC sert encore à l'onglet Identité
    for (const kept of ['const [mailChannel, setMailChannel]', 'const [notifPolicy, setNotifPolicy]', 'const [regDocs, setRegDocs]', 'function setC(k,v)', 'setMailChannel(mcR.data || {});']) {
      expect(page).toContain(kept);
    }
    expect(Buffer.byteLength(page, 'utf8')).toBeLessThan(50 * 1024);
  });
  it('les sections prennent leurs styles au module commun et préviennent par onChanged', () => {
    const comms = lire('src/pages/biblioteca/CommsSection.jsx');
    const reg = lire('src/pages/biblioteca/RegulationSection.jsx');
    for (const [nom, s] of [['CommsSection', comms], ['RegulationSection', reg]]) {
      expect(s, nom).toMatch(/from '\.\/styles';/);
      expect(s, nom).not.toContain('loadAll');
      expect(s, nom).toMatch(/^export default function /m);
    }
    expect(comms).toContain("supabase.rpc('upsert_library_mail_channel', {");
    expect(comms).toMatch(/^const NOTIFICATION_FLAG_KEYS = \[/m);
    expect((reg.match(/await onChanged\?\.\(\);/g) || []).length).toBe(2);
    expect(reg).toContain("supabase.rpc('remove_library_regulation_document', { p_document_id: doc.id })");
    expect(reg).toContain('function seedT(');
  });
});

describe('E6 Biblioteca lot 5 — les sections montées', () => {
  beforeEach(() => { journal.from.length = 0; journal.rpc.length = 0; });

  it('communications : une case de notification écrit par setNotifPolicy ; un délai hors 7..60 est refusé avant toute écriture', async () => {
    const setMsg = vi.fn(); const setNotifPolicy = vi.fn(); const setMailChannel = vi.fn();
    const notifPolicy = { loan_overdue_enabled: false, reservation_negotiation_timeout_days: 3 };
    monter(<CommsSection libraryId="L1" isCoord user={{ id: 'u1' }} commons={{ display_name: 'BLMF' }} setC={vi.fn()}
      mailChannel={{ delivery_mode: 'platform_shared', active: true }} setMailChannel={setMailChannel} notifPolicy={notifPolicy} setNotifPolicy={setNotifPolicy} setMsg={setMsg} />);
    expect(screen.getByTestId('contact-profile')).toBeTruthy();
    expect(screen.getByTestId('public-contact')).toBeTruthy();
    fireEvent.click(screen.getByLabelText(fr['notif.type.loan_overdue']));
    expect(setNotifPolicy).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByText(fr['biblioteca.comms.save']));
    await waitFor(() => expect(setMsg).toHaveBeenLastCalledWith(expect.objectContaining({ kind: 'error' })));
    expect(setMsg.mock.calls.at(-1)[0].text).toContain(fr['biblioteca.reservation.timeoutDays.outOfRange']);
    // l'identité et le canal sont écrits avant la vérification du délai (ordre historique) ; la politique, non
    expect(journal.rpc.map(r => r.name)).toEqual(['upsert_library_mail_channel']);
    expect(journal.from.filter(f => f.table === 'library_notification_policies')).toHaveLength(0);
  });

  it('communications : un délai valide enregistre l’identité, le canal entier et la politique', async () => {
    const setMsg = vi.fn();
    monter(<CommsSection libraryId="L1" isCoord user={{ id: 'u1' }} commons={{ display_name: 'BLMF', contact_email: 'c@x.org' }} setC={vi.fn()}
      mailChannel={{ delivery_mode: 'platform_shared', active: true, transport_state: 'ok' }} setMailChannel={vi.fn()}
      notifPolicy={{ reservation_negotiation_timeout_days: 21, loan_overdue_enabled: true }} setNotifPolicy={vi.fn()} setMsg={setMsg} />);
    fireEvent.click(screen.getByText(fr['biblioteca.comms.save']));
    await waitFor(() => expect(setMsg).toHaveBeenLastCalledWith({ text: fr['biblioteca.comms.savedOk'], kind: 'ok' }));
    expect(journal.from.map(f => f.table)).toEqual(['library_commons', 'library_notification_policies']);
    expect(journal.rpc[0].name).toBe('upsert_library_mail_channel');
    expect(journal.rpc[0].args.p_channel).toMatchObject({ delivery_mode: 'platform_shared', transport_state: 'ok', active: true });
    expect(journal.from[1].data).toMatchObject({ loan_overdue_enabled: true, reservation_negotiation_timeout_days: 21, updated_by: 'u1' });
  });

  it('règlement : la liste montre les versions, le retrait seulement aux inactives pour la coordination ; téléverser sans fichier refuse', async () => {
    const setMsg = vi.fn();
    const regDocs = [
      { id: 1, version_label: 'v1 (2025)', doc_kind: 'regimento', publication_status: 'published', is_active: false },
      { id: 2, version_label: 'v2 (2026)', doc_kind: 'regimento', publication_status: 'published', is_active: true },
      { id: 3, version_label: 'archivé', archived_at: '2026-01-01' },
    ];
    monter(<RegulationSection libraryId="L1" isCoord user={{ id: 'u1' }} lib={{ slug: 'blmf' }} setLib={vi.fn()} regDocs={regDocs}
      membershipRules={[]} setMembershipRules={vi.fn()} depositRules={[]} setDepositRules={vi.fn()} setMsg={setMsg} onChanged={vi.fn()} />);
    expect(screen.getByText('v1 (2025)')).toBeTruthy();
    expect(screen.getByText('v2 (2026)')).toBeTruthy();
    expect(screen.queryByText('archivé')).toBeNull();
    expect(screen.getAllByText(fr['biblioteca.regulation.remove'])).toHaveLength(1);
    for (const id of ['regime', 'policy-sets', 'membership', 'deposit']) expect(screen.getByTestId(id)).toBeTruthy();
    fireEvent.click(screen.getByText(fr['biblioteca.regulation.uploadNew']));
    await waitFor(() => expect(setMsg).toHaveBeenCalledWith({ text: 'Selecione um arquivo PDF.', kind: 'error' }));
  });
});
