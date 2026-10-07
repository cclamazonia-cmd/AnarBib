// ═══════════════════════════════════════════════════════════
// AnarBib — E6, AccountPage lot 7 (07/10/2026) : quatre blocs de l'onglet
// « Données personnelles » sortent dans leur fichier, à leur place.
//   * ContaMotDePasse : la saisie remonte au parent, le formulaire appelle
//     handleChangePassword, le message d'erreur se dit ;
//   * ContaCotisation : rien sans cotisation ouverte ; sinon le statut, le
//     dernier paiement et les règles ;
//   * ContaDepot : rien sans dépôt ; sinon le montant et le statut ;
//   * ContaSuppression : le bouton reste bloqué tant que le mot de
//     confirmation n'est pas saisi ; saisi, il appelle fn_delete_my_account,
//     déconnecte et ramène à l'accueil.
//   L'ordre des blocs dans l'onglet reste gardé par conta-decisions-sous-le-
//   profil.test.js.
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const rpc = vi.fn(async () => ({ data: { ok: true }, error: null }));
const signOut = vi.fn(async () => ({}));
vi.mock('@/lib/supabase', () => ({
  supabase: { rpc: (...a) => rpc(...a), auth: { signOut: () => signOut() } },
  SUPABASE_URL: 'https://exemple.invalid',
}));

import ContaMotDePasse from '@/pages/account/ContaMotDePasse';
import ContaCotisation from '@/pages/account/ContaCotisation';
import ContaDepot from '@/pages/account/ContaDepot';
import ContaSuppression from '@/pages/account/ContaSuppression';

const RACINE = path.resolve(__dirname, '../..');
const fr = JSON.parse(readFileSync(path.join(RACINE, 'src/i18n/locales/fr.json'), 'utf8'));
const avecIntl = (el) => render(<IntlProvider locale="fr" messages={fr}>{el}</IntlProvider>);

afterEach(() => { cleanup(); rpc.mockClear(); signOut.mockClear(); });

describe('le mot de passe, sorti d’AccountPage', () => {
  it('la saisie remonte, le formulaire appelle handleChangePassword, l’erreur se dit', () => {
    const p = { pwdNew: '', setPwdNew: vi.fn(), pwdConfirm: '', setPwdConfirm: vi.fn(), pwdSaving: false,
      pwdMsg: 'Les deux mots de passe diffèrent.', pwdMsgIsError: true, handleChangePassword: vi.fn((e) => e.preventDefault()) };
    avecIntl(<ContaMotDePasse {...p} />);
    const champs = document.querySelectorAll('input[type="password"]');
    expect(champs).toHaveLength(2);
    fireEvent.change(champs[0], { target: { value: 'nouveau-secret' } });
    expect(p.setPwdNew).toHaveBeenCalledWith('nouveau-secret');
    fireEvent.submit(document.querySelector('form'));
    expect(p.handleChangePassword).toHaveBeenCalled();
    expect(screen.getByText('Les deux mots de passe diffèrent.').className).toContain('ab-conta-msg--error');
  });
});

describe('la cotisation, sortie d’AccountPage', () => {
  const base = { availability: { cotisacoes: true }, membership: null, membershipRules: [], membershipPayments: [], libraryName: 'BLMF', regimentoUrl: null };
  it('rien sans cotisation ouverte', () => {
    const { container } = avecIntl(<ContaCotisation {...base} availability={{ cotisacoes: false }} membershipRules={[{ id: 1, name: 'Annuelle' }]} />);
    expect(container.textContent).toBe('');
  });
  it('le statut, le dernier paiement et les règles', () => {
    avecIntl(<ContaCotisation {...base}
      membership={{ dues_status: 'up_to_date', last_valid_until: '2027-01-01', days_until_expiry: 86 }}
      membershipRules={[{ id: 1, name: 'Annuelle solidaire', amount_min: 5, currency: 'BRL' }]}
      membershipPayments={[{ id: 9, amount_paid: 10, currency: 'BRL', payment_method: 'cash', paid_at: '2026-01-01' }]} />);
    expect(screen.getByText(fr['membership.config.title'])).toBeTruthy();
    expect(screen.getByText(fr['membership.status.upToDate'])).toBeTruthy();
    expect(screen.getByText('Annuelle solidaire')).toBeTruthy();
    expect(screen.getByText('10 BRL')).toBeTruthy();
  });
});

describe('le dépôt de garantie, sorti d’AccountPage', () => {
  it('rien sans dépôt ; sinon le montant et le statut', () => {
    const { container } = avecIntl(<ContaDepot deposits={[]} />);
    expect(container.textContent).toBe('');
    cleanup();
    avecIntl(<ContaDepot deposits={[{ deposit_id: 3, amount: 20, currency: 'BRL', status: 'detenu', emprestimo_id: 70 }]} />);
    expect(screen.getByText(fr['deposit.account.title'])).toBeTruthy();
    expect(screen.getByText('20 BRL')).toBeTruthy();
    expect(screen.getByText(fr['deposit.status.detenu'])).toBeTruthy();
  });
});

describe('la suppression du compte, sortie d’AccountPage', () => {
  it('bloquée sans le mot de confirmation ; saisi, supprime, déconnecte et ramène à l’accueil', async () => {
    const mot = fr['account.deleteAccount.confirmText'];
    const base = { setDeleteConfirm: vi.fn(), deleting: false, setDeleting: vi.fn(), navigate: vi.fn() };
    avecIntl(<ContaSuppression {...base} deleteConfirm="" />);
    expect(screen.getByText(fr['account.deleteAccount.button']).closest('button').disabled).toBe(true);
    fireEvent.change(screen.getByPlaceholderText(mot), { target: { value: mot } });
    expect(base.setDeleteConfirm).toHaveBeenCalledWith(mot);
    cleanup();
    const confirmer = vi.spyOn(window, 'confirm').mockReturnValue(true);
    avecIntl(<ContaSuppression {...base} deleteConfirm={mot} />);
    fireEvent.click(screen.getByText(fr['account.deleteAccount.button']));
    await waitFor(() => expect(rpc).toHaveBeenCalledWith('fn_delete_my_account'));
    await waitFor(() => expect(signOut).toHaveBeenCalled());
    await waitFor(() => expect(base.navigate).toHaveBeenCalledWith('/'));
    confirmer.mockRestore();
  });
});
