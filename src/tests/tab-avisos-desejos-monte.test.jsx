// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 2 (06/10/2026) : les onglets « Avis » et
// « Liste de souhaits » de Mon compte sortent dans TabAvisos.jsx et
// TabDesejos.jsx.
//   * Avis : un avis non lu se rend, son libellé traduit par tNotifText ;
//     « tout marquer lu » n'apparaît qu'avec des non-lus ; marquer lu et
//     archiver appellent la base puis rechargent ;
//   * Souhaits : un souhait se rend ; « Réserver » n'apparaît que si le livre
//     est disponible et prêtable dans la bibliothèque de la session, et
//     réserve pour la personne connectée ;
//   * le parent monte les deux onglets et ne garde plus leur corps.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { MemoryRouter } from 'react-router-dom';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const rpc = vi.fn(async () => ({ error: null }));
const supprimer = vi.fn(async () => ({ error: null }));
vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...a) => rpc(...a),
    from: () => ({ delete: () => ({ eq: (...a) => supprimer(...a) }) }),
  },
  SUPABASE_URL: 'https://exemple.invalid',
}));

import TabAvisos from '@/pages/account/TabAvisos';
import TabDesejos from '@/pages/account/TabDesejos';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));

afterEach(() => { cleanup(); rpc.mockClear(); supprimer.mockClear(); });

const enveloppe = (el) => render(
  <IntlProvider locale="fr" messages={fr}><MemoryRouter>{el}</MemoryRouter></IntlProvider>,
);

const AVIS = { id: 9, title: 'Votre réservation est prête', body: 'À retirer avant vendredi', is_read: false,
  category: 'reserva', created_at: '2026-10-05T10:00:00Z', link_type: 'livro', link_id: 7 };

describe('l’onglet Avis, sorti d’AccountPage', () => {
  function monter(sur = {}) {
    const props = { notifViewMode: 'active', setNotifViewMode: vi.fn(), unreadCount: 1,
      visibleNotifications: [AVIS], tNotifText: (s) => s, loadData: vi.fn(), ...sur };
    enveloppe(<TabAvisos {...props} />);
    return props;
  }

  it('rend un avis non lu et le bouton « tout marquer lu »', () => {
    monter();
    expect(screen.getByText(fr['account.notifications.title'])).toBeTruthy();
    expect(screen.getByText('Votre réservation est prête')).toBeTruthy();
    expect(screen.getByText(fr['account.notifications.markAllRead'])).toBeTruthy();
  });

  it('sans non-lu, pas de « tout marquer lu » ; liste vide dite', () => {
    monter({ unreadCount: 0, visibleNotifications: [] });
    expect(screen.queryByText(fr['account.notifications.markAllRead'])).toBeNull();
    expect(screen.getByText(fr['account.notifications.empty'])).toBeTruthy();
  });

  it('marquer lu et archiver appellent la base, puis rechargent', async () => {
    const p = monter();
    fireEvent.click(screen.getByText('✓'));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_mark_notifications_read', { p_ids: [9] }));
    fireEvent.click(screen.getByTitle(fr['account.notifications.archive']));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_archive_notification', { p_notification_id: 9 }));
    await waitFor(() => expect(p.loadData).toHaveBeenCalledTimes(2));
  });
});

const SOUHAIT = { id: 3, book_id: 7, created_at: '2026-10-01T10:00:00Z', note: null,
  books: { titulo: 'L’Entraide', autor: 'Pierre Kropotkine', editora: 'Hedra', ano: '2009', bib_ref: 'BLMF-0007' } };

describe('l’onglet Liste de souhaits, sorti d’AccountPage', () => {
  function monter(dispo) {
    const props = { wishlist: [SOUHAIT], availabilityMap: new Map(dispo ? [[7, dispo]] : []),
      user: { id: 'u-1' }, loadData: vi.fn() };
    enveloppe(<TabDesejos {...props} />);
    return props;
  }

  it('rend le souhait, sans « Réserver » quand le livre n’est pas disponible ici', () => {
    monter(null);
    expect(screen.getByText('L’Entraide')).toBeTruthy();
    expect(screen.queryByText(fr['account.wishlist.reserveNow'])).toBeNull();
  });

  it('réserve pour la personne connectée quand le livre est disponible et prêtable', async () => {
    const p = monter({ session_status_hint: 'no_acervo_da_sua_biblioteca', session_holding_id: 55, session_loanable: true, session_available_count: 1 });
    fireEvent.click(screen.getByText(fr['account.wishlist.reserveNow']));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_v2_create_reserva_by_holdings', { p_user_id: 'u-1', p_holding_ids: [55] }));
    await waitFor(() => expect(p.loadData).toHaveBeenCalled());
  });

  it('retirer supprime le souhait puis recharge', async () => {
    const p = monter(null);
    fireEvent.click(screen.getByText(fr['common.remove']));
    await waitFor(() => expect(supprimer).toHaveBeenCalledWith('id', 3));
    await waitFor(() => expect(p.loadData).toHaveBeenCalled());
  });
});

describe('AccountPage monte les deux onglets', () => {
  const page = lire('src/pages/account/AccountPage.jsx');
  it('le parent rend TabAvisos et TabDesejos et ne garde plus leur corps', () => {
    expect(page).toMatch(/<TabAvisos\b/);
    expect(page).toMatch(/<TabDesejos\b/);
    expect(page).not.toMatch(/fn_archive_notification|fn_unarchive_notification/);
    expect(page).not.toMatch(/from\('user_wishlist'\)\.delete/);
    expect(page).not.toMatch(/fn_v2_create_reserva_by_holdings', \{\s*p_user_id: user\.id,\s*p_holding_ids: \[wAvail/);
  });
});
