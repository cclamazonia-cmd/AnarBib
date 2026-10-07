// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 6 (07/10/2026) : la grille des trois
// décisions de « Données personnelles » sort dans ContaDecisions.jsx.
//   * les trois cartes se rendent (export, notifications, lettre) ;
//   * cocher une préférence remonte au parent ; « Enregistrer » appelle
//     fn_set_my_notification_preferences avec les quatre drapeaux ;
//   * cocher la lettre demande l'abonnement (double opt-in) et note
//     l'attente ; décocher désabonne ;
//   * l'ordre des blocs et l'unicité des gestes restent gardés par
//     conta-decisions-sous-le-profil.test.js.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const rpc = vi.fn(async () => ({ error: null }));
const apiRpc = vi.fn(async () => ({ data: 'confirmation_sent', error: null }));
vi.mock('@/lib/supabase', () => ({
  supabase: { rpc: (...a) => rpc(...a) },
  apiRpc: (...a) => apiRpc(...a),
  SUPABASE_URL: 'https://exemple.invalid',
}));
vi.mock('@/components/account/DataExportButton', () => ({ default: () => <button type="button">export</button> }));

import ContaDecisions from '@/pages/account/ContaDecisions';

const RACINE = path.resolve(__dirname, '../..');
const fr = JSON.parse(readFileSync(path.join(RACINE, 'src/i18n/locales/fr.json'), 'utf8'));

afterEach(() => { cleanup(); rpc.mockClear(); apiRpc.mockClear(); });

const PREFS = { disable_reserva_pronta: false, disable_consulta_pronta: true, disable_rede_news: false, disable_library_events: false };

function monter(sur = {}) {
  const props = {
    notifPrefs: PREFS, setNotifPrefs: vi.fn(), notifPrefsSaving: false, setNotifPrefsSaving: vi.fn(),
    notifPrefsMsg: '', setNotifPrefsMsg: vi.fn(),
    lettreConsent: { consent_lettre: false, pending: false }, setLettreConsent: vi.fn(),
    lettreSaving: false, setLettreSaving: vi.fn(), lettreMsg: '', setLettreMsg: vi.fn(), ...sur,
  };
  render(<IntlProvider locale="fr" messages={fr}><ContaDecisions {...props} /></IntlProvider>);
  return props;
}

describe('les trois décisions de Données personnelles, sorties d’AccountPage', () => {
  it('rend les trois cartes', () => {
    monter();
    for (const cle of ['account.export.title', 'account.notifPrefs.title', 'account.lettre.title']) {
      expect(screen.getByText(fr[cle]), cle).toBeTruthy();
    }
    expect(document.querySelectorAll('.ab-conta-decision')).toHaveLength(3);
  });

  it('cocher une préférence remonte au parent ; Enregistrer envoie les quatre drapeaux', async () => {
    const p = monter();
    fireEvent.click(screen.getByLabelText(fr['account.notifPrefs.disableReservaPronta']));
    expect(p.setNotifPrefs).toHaveBeenCalled();
    fireEvent.click(screen.getByText(fr['common.save']));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_set_my_notification_preferences', {
      p_disable_reserva_pronta: false, p_disable_consulta_pronta: true, p_disable_rede_news: false, p_disable_library_events: false,
    }));
    await waitFor(() => expect(p.setNotifPrefsMsg).toHaveBeenCalledWith(fr['account.notifPrefs.saved']));
  });

  it('cocher la lettre demande l’abonnement et note l’attente ; décocher désabonne', async () => {
    const p = monter();
    fireEvent.click(screen.getByLabelText(fr['account.lettre.toggle']));
    await waitFor(() => expect(apiRpc).toHaveBeenCalledWith('fn_lettre_request_optin'));
    await waitFor(() => expect(p.setLettreMsg).toHaveBeenCalledWith(fr['account.lettre.confirmationSent']));
    cleanup();
    const q = monter({ lettreConsent: { consent_lettre: true, pending: false } });
    expect(screen.getByText(fr['account.lettre.subscribed'])).toBeTruthy();
    fireEvent.click(screen.getByLabelText(fr['account.lettre.toggle']));
    await waitFor(() => expect(apiRpc).toHaveBeenCalledWith('fn_lettre_cancel'));
    await waitFor(() => expect(q.setLettreConsent).toHaveBeenCalledWith({ consent_lettre: false, pending: false }));
  });
});
