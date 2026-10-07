// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 5 (07/10/2026) : l'onglet « Réserver » de
// Mon compte sort dans TabReservar.jsx.
//   * le formulaire par référence : la saisie remonte au parent, « Emprunter »
//     et « Consulter » appellent handleReserve('reserve' | 'consult'), le
//     message du parent s'affiche ;
//   * les réservations actives passent par ReservationCard (chargé à la
//     demande), sans réservation le vide est dit ;
//   * un créneau de consultation proposé se confirme ou se refuse (gestes du
//     parent), boutons bloqués pendant une réponse ;
//   * une consultation active s'annule (setCancelTarget) ; une consultation
//     annulée par la bibliothèque s'efface (handleDismissConsultaCancelled) ;
//   * le parent monte l'onglet, ne garde plus son corps ni ReservationCard.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';

vi.mock('@/components/account/ReservationCard', () => ({
  default: ({ r }) => <div data-testid={`carte-${r.reserva_id}`}>{r.titulo}</div>,
}));

import TabReservar from '@/pages/account/TabReservar';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

afterEach(cleanup);

const PROPOSEE = { book_id: 7, titulo: 'L’Entraide', bib_ref: 'BLMF-0007', library_id: 'lib-a', status: 'ativa',
  workflow_stage_effective: 'consulta_agendada', schedule_reply_status: null,
  consultation_starts_at: '2026-10-15T14:00:00Z', consultation_ends_at: '2026-10-15T15:30:00Z' };
const ANNULEE = { book_id: 8, titulo: 'La Conquête du pain', bib_ref: 'BLMF-0008', library_id: 'lib-a',
  status: 'cancelada_biblioteca', cancelled_at: '2026-10-01T10:00:00Z' };

function monter(sur = {}) {
  const props = {
    reserveRef: '', setReserveRef: vi.fn(), handleReserve: vi.fn(), reserveMsg: '',
    reservations: [], consultations: [], tzMap: { 'lib-a': 'America/Belem' }, loadData: vi.fn(),
    renderLibTag: vi.fn(() => null), renderSameTitleSignal: vi.fn(() => null),
    cancelReservation: vi.fn(), handleConfirmPickup: vi.fn(), openCounterProposalForm: vi.fn(),
    handleSubmitCounterProposal: vi.fn(), negotiationForm: null, setNegotiationForm: vi.fn(),
    handleConfirmSchedule: vi.fn(), replying: false, openRefuseModal: vi.fn(),
    setCancelTarget: vi.fn(), handleDismissConsultaCancelled: vi.fn(), ...sur,
  };
  render(<IntlProvider locale="fr" messages={fr}><MemoryRouter><TabReservar {...props} /></MemoryRouter></IntlProvider>);
  return props;
}

describe('l’onglet Réserver, sorti d’AccountPage', () => {
  it('le formulaire par référence remonte la saisie et appelle handleReserve', () => {
    const p = monter({ reserveMsg: 'Réservation enregistrée.' });
    fireEvent.change(screen.getByPlaceholderText(fr['account.reserve.placeholder']), { target: { value: 'BLMF-0007' } });
    expect(p.setReserveRef).toHaveBeenCalledWith('BLMF-0007');
    fireEvent.click(screen.getByText(fr['account.reserve.loan'], { selector: 'button' }));
    fireEvent.click(screen.getByText(fr['account.reserve.consult'], { selector: 'button' }));
    expect(p.handleReserve).toHaveBeenNthCalledWith(1, 'reserve');
    expect(p.handleReserve).toHaveBeenNthCalledWith(2, 'consult');
    expect(screen.getByText('Réservation enregistrée.')).toBeTruthy();
  });

  it('sans réservation, le vide est dit ; avec, chaque réservation passe par ReservationCard', async () => {
    monter();
    expect(screen.getByText(fr['account.reservations.empty'])).toBeTruthy();
    cleanup();
    monter({ reservations: [{ reserva_id: 5, titulo: 'Dieu et l’État', library_id: 'lib-a' }] });
    expect(await screen.findByTestId('carte-5')).toBeTruthy();
  });

  it('un créneau proposé se confirme ou se refuse, et se bloque pendant une réponse', () => {
    const p = monter({ consultations: [PROPOSEE] });
    fireEvent.click(screen.getByText(fr['account.consultations.scheduleProposed.confirmButton']));
    expect(p.handleConfirmSchedule).toHaveBeenCalledWith(PROPOSEE);
    fireEvent.click(screen.getByText(fr['account.consultations.scheduleProposed.refuseButton']));
    expect(p.openRefuseModal).toHaveBeenCalledWith(PROPOSEE);
    cleanup();
    monter({ consultations: [PROPOSEE], replying: true });
    expect(screen.getByText(fr['account.consultations.scheduleProposed.confirmButton']).closest('button').disabled).toBe(true);
  });

  it('une consultation active s’annule ; une consultation annulée par la bibliothèque s’efface', () => {
    const p = monter({ consultations: [PROPOSEE, ANNULEE] });
    fireEvent.click(screen.getByText(fr['account.consultations.cancelButton']));
    expect(p.setCancelTarget).toHaveBeenCalledWith(PROPOSEE);
    fireEvent.click(screen.getByText(fr['account.consultations.dismissButton']));
    expect(p.handleDismissConsultaCancelled).toHaveBeenCalledWith(ANNULEE);
  });

  it('le parent monte TabReservar et ne garde plus son corps ni ReservationCard', () => {
    const page = lire('src/pages/account/AccountPage.jsx');
    expect(page).toMatch(/<TabReservar\b/);
    expect(page).not.toMatch(/<ReservationCard\b/);
    expect(page).not.toMatch(/lazy\(\(\) => import\('@\/components\/account\/ReservationCard'\)\)/);
    expect(page).not.toMatch(/handleDismissConsultaCancelled\(c\)/);
  });
});
