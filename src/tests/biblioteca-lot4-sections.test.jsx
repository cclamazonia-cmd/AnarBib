// AnarBib — E6, BibliotecaPage lot 4 (12/10/2026) : quatre sections sortent de
// la page — horaires, fiche publique, identité des lecteur·rices, rapports.
// Même contrat que les lots 1-3 : la SOURCE (montées au bon endroit, ce qui
// est parti n'y est plus, l'état chargé par loadCore reste au parent) et les
// sections MONTÉES avec un supabase factice et les messages réels en français.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

const journal = { rpc: [], pub: [] };
let apiReponse = () => ({ data: null, error: null });
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: () => ({ select: () => ({ eq: () => ({ maybeSingle: async () => ({ data: null }) }) }) }),
    schema: () => ({ rpc: async (name, args) => { journal.rpc.push({ name, args }); return { data: 'BLMF-0042', error: null }; } }),
    rpc: async (name, args) => { journal.pub.push({ name, args }); return { data: null, error: null }; },
  },
  apiRpc: async (name, args) => { journal.rpc.push({ name, args }); return apiReponse(name, args); },
  SUPABASE_URL: 'https://exemple.invalid',
}));
vi.mock('@/components/library/PebHistorySection', () => ({ default: () => <div data-testid="peb-history" /> }));
vi.mock('@/components/biblioteca/FinanceReportsSection', () => ({ default: () => <div data-testid="finance" /> }));

const { default: OpeningHoursSection } = await import('@/pages/biblioteca/OpeningHoursSection.jsx');
const { default: PublicFicheSection } = await import('@/pages/biblioteca/PublicFicheSection.jsx');
const { default: ReaderIdentitySection } = await import('@/pages/biblioteca/ReaderIdentitySection.jsx');
const { default: ReportsSection } = await import('@/pages/biblioteca/ReportsSection.jsx');
const monter = (ui) => render(<IntlProvider locale="fr" messages={fr}>{ui}</IntlProvider>);

describe('E6 Biblioteca lot 4 — la source', () => {
  const page = lire('src/pages/biblioteca/BibliotecaPage.jsx');
  it('les quatre sections sont montées à leur place, l’état chargé par loadCore reste au parent', () => {
    expect(page).toContain('<OpeningHoursSection libraryId={libraryId} openingHours={openingHours} setOpeningHours={setOpeningHours} />');
    expect(page).toContain('<PublicFicheSection libraryId={libraryId} fichePublic={fichePublic} setFichePublic={setFichePublic} />');
    expect(page).toContain('<ReaderIdentitySection libraryId={libraryId} isCoord={isCoord} lib={lib} setL={setL} />');
    expect(page).toMatch(/\{tab==='reports' && \(\n\s+<ReportsSection libraryId=\{libraryId\} libraryName=\{libraryName\}/);
    expect(page).toContain('taskStatus={TASK_STATUS} taskPrio={TASK_PRIO} setMsg={setMsg} onChanged={loadAll} />');
    // ordre dans l'onglet Identité : numérotation, horaires, fiche publique, identité lecteur·rice, visuels, bouton
    const o = ['<LibraryNumberingSection', '<OpeningHoursSection', '<PublicFicheSection', '<ReaderIdentitySection', '<LibraryVisualAssetsSection', 'onClick={saveIdentity}'].map(s => page.indexOf(s));
    expect(o.every((v, i) => v > -1 && (i === 0 || v > o[i - 1]))).toBe(true);
    expect(page).toContain("setOpeningHours({ slots: Array.isArray(ohR.data?.slots) ? ohR.data.slots : [], public_note: ohR.data?.public_note || '' });");
    expect(page).toContain('setFichePublic({ contact_is_public: !!pcR.data?.is_public, hours_is_public: !!ohR.data?.is_public });');
    for (const gone of ['function generateReportText', 'async function sendReport', 'async function saveHours', 'function toggleFiche', 'const dayName',
      'setLastAssignedIdentity', 'const [ohMsg', 'const [fpSaving', 'fn_upsert_library_opening_hours', 'biblioteca.reports.topBooks90d', "import PebHistorySection from"]) {
      expect(page.includes(gone), `${gone} encore dans BibliotecaPage`).toBe(false);
    }
    expect(Buffer.byteLength(page, 'utf8')).toBeLessThan(65 * 1024);
  });

  it('les sections prennent leurs styles au module commun et ne rechargent jamais la page elles-mêmes', () => {
    for (const f of ['OpeningHoursSection', 'PublicFicheSection', 'ReaderIdentitySection', 'ReportsSection']) {
      const s = lire(`src/pages/biblioteca/${f}.jsx`);
      expect(s, f).toMatch(/from '\.\/styles';/);
      expect(s, f).not.toContain('loadAll');
      expect(s, f).toMatch(/^export default function /m);
    }
    expect(lire('src/pages/biblioteca/ReportsSection.jsx')).toContain('onChange={onChanged}');
    expect(lire('src/pages/biblioteca/ReportsSection.jsx')).toContain('taskStatus[tk.status]');
  });
});

describe('E6 Biblioteca lot 4 — les sections montées', () => {
  beforeEach(() => { journal.rpc.length = 0; journal.pub.length = 0; apiReponse = () => ({ data: null, error: null }); });

  it('horaires : un créneau ajouté, nettoyé, enregistré par la RPC ; le message vient de la réponse', async () => {
    let etat = { slots: [], public_note: '' };
    const setOpeningHours = vi.fn((f) => { etat = typeof f === 'function' ? f(etat) : f; });
    const { rerender } = monter(<OpeningHoursSection libraryId="L1" openingHours={etat} setOpeningHours={setOpeningHours} />);
    expect(screen.getByText(fr['biblioteca.openingHours.empty'])).toBeTruthy();
    fireEvent.click(screen.getByText(fr['biblioteca.openingHours.addSlot']));
    expect(etat.slots).toEqual([{ day: 1, start: '18:00', end: '20:00', label: '' }]);
    rerender(<IntlProvider locale="fr" messages={fr}><OpeningHoursSection libraryId="L1" openingHours={{ ...etat, slots: [...etat.slots, { day: 3, start: '', end: '' }] }} setOpeningHours={setOpeningHours} /></IntlProvider>);
    fireEvent.click(screen.getByText(fr['common.save']));
    await waitFor(() => expect(journal.rpc).toHaveLength(1));
    expect(journal.rpc[0]).toEqual({ name: 'fn_upsert_library_opening_hours', args: { p_library_id: 'L1', p_slots: [{ day: 1, start: '18:00', end: '20:00', label: undefined }], p_public_note: null } });
    await waitFor(() => expect(screen.getByText(fr['biblioteca.msg.saved'])).toBeTruthy());
  });

  it('fiche publique : la bascule appelle la RPC du bon volet et ne change l’état que si elle réussit', async () => {
    const setFichePublic = vi.fn();
    monter(<PublicFicheSection libraryId="L1" fichePublic={{ contact_is_public: false, hours_is_public: false }} setFichePublic={setFichePublic} />);
    const cases = screen.getAllByRole('checkbox');
    fireEvent.click(cases[1]);
    await waitFor(() => expect(journal.rpc).toHaveLength(1));
    expect(journal.rpc[0]).toEqual({ name: 'fn_set_library_hours_public', args: { p_library_id: 'L1', p_is_public: true } });
    await waitFor(() => expect(setFichePublic).toHaveBeenCalledTimes(1));
    apiReponse = () => ({ data: null, error: new Error('refus') });
    fireEvent.click(cases[0]);
    await waitFor(() => expect(journal.rpc).toHaveLength(2));
    expect(journal.rpc[1].name).toBe('fn_set_library_contact_public');
    expect(setFichePublic).toHaveBeenCalledTimes(1); // le refus ne bascule pas
  });

  it('identité lecteur·rice : le dernier identifiant attribué est lu au montage et affiché ; les champs écrivent par setL', async () => {
    const setL = vi.fn();
    monter(<ReaderIdentitySection libraryId="L1" isCoord lib={{ reader_identity_model: 'sequenced_number', reader_validation_mode: 'presential', accepts_public_signup: false }} setL={setL} />);
    await waitFor(() => expect(screen.getByText(fr['biblioteca.readerIdentity.lastAssigned'].replace('{value}', 'BLMF-0042'))).toBeTruthy());
    expect(journal.rpc[0]).toEqual({ name: 'get_last_assigned_reader_identity', args: { p_library_id: 'L1' } });
    fireEvent.click(screen.getByRole('checkbox'));
    expect(setL).toHaveBeenCalledWith('accepts_public_signup', true);
  });

  it('rapports : le compte-rendu se génère avec les compteurs, l’équipe et les PEB ; l’envoi exige l’adresse hebdomadaire', async () => {
    const setMsg = vi.fn();
    const props = {
      libraryId: 'L1', libraryName: 'BLMF', lib: { name: 'Biblioteca Livre' }, members: [{ role: 'librarian', profiles: { first_name: 'Ana' } }],
      tasks: [{ status: 'aberta', title: 'Ranger', priority: 'media' }], exchanges: [], allLibraries: [{ id: 'L2', short_name: 'BTL' }],
      illLoans: [{ id: 7, status_global: 'emprestado', lender_library_id: 'L1', borrower_library_id: 'L2' }], illItemsByLoan: { 7: [{ titulo_cache: 'Germinal' }] },
      stats: { books: 12, authors: 3, exemplars: 20, readers: 5, loansOpen: 2, loansOverdue: 1, loansCreated7d: 0, loansReturned7d: 0, loansCreated30d: 0, reservationsActive: 0, reservations30d: 0, consultationsActive: 0, trocasActive: 0, librariansActive: 1, topBooks: [{ titulo: 'Germinal', autor: 'Zola', cnt: 3 }] },
      mailChannel: {}, taskStatus: { aberta: 'Ouverte' }, taskPrio: { media: 'moyenne' }, setMsg, onChanged: vi.fn(),
    };
    monter(<ReportsSection {...props} />);
    const texte = screen.getByRole('textbox').value;
    expect(texte).toContain(fr['biblioteca.report.docsInCatalog'].replace('{count}', '12'));
    expect(texte).toContain('Ana');
    expect(texte).toContain('[Ouverte] Ranger (moyenne)');
    expect(texte).toContain('#7');
    expect(texte).toContain('Germinal');
    expect(screen.getByTestId('peb-history')).toBeTruthy();
    expect(screen.getByTestId('finance')).toBeTruthy();
    fireEvent.click(screen.getByText(fr['biblioteca.reports.sendEmail']));
    await waitFor(() => expect(setMsg).toHaveBeenCalledWith({ text: fr['biblioteca.report.noWeeklyEmail'], kind: 'error' }));
    expect(journal.pub).toHaveLength(0);
  });
});
