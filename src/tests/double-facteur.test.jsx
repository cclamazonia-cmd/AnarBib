// ═══════════════════════════════════════════════════════════
// AnarBib — B42, lot 1 (13/10/2026) : la double authentification (TOTP).
//   * src/lib/doubleFacteur.js : quand un code est dû (facteur vérifié ET
//     jeton aal1), la forme du code, le secret par groupes, la traduction des
//     refus de Supabase Auth ;
//   * ContaDoubleFacteur (Mon compte) : inscription = enroll puis premier
//     code ; une inscription abandonnée est retirée avant d'en commencer une
//     autre ; retrait d'un appareil ;
//   * DoubleFacteurDefi (connexion) : code mal formé refusé sans appel, refus
//     de GoTrue traduit ;
//   * LoginPage demande le code AVANT toute autre bascule ; ProtectedRoute
//     renvoie une session aal1 vers /login.
//   * REGISTRE 2FA-2 (14/10/2026) : volet « J'utilise… » fermé par défaut et
//     choix d'application, lien otpauth:// quand l'inscription le rend, refus
//     de code propre à l'inscription, retour visible de « Copier la clé ».
// ═══════════════════════════════════════════════════════════

import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react';
import { IntlProvider } from 'react-intl';
import { IntlMessageFormat } from 'intl-messageformat';
import { readFileSync } from 'node:fs';
import path from 'node:path';

const mfa = {
  listFactors: vi.fn(),
  enroll: vi.fn(),
  challengeAndVerify: vi.fn(),
  unenroll: vi.fn(async () => ({ data: {}, error: null })),
};
const apiRpc = vi.fn();
vi.mock('@/lib/supabase', () => ({
  supabase: { auth: { mfa: new Proxy({}, { get: (_, k) => (...a) => mfa[k](...a) }) } },
  apiRpc: (...a) => apiRpc(...a),
  SUPABASE_URL: 'https://exemple.invalid',
}));

import {
  niveauDuJeton, facteursVerifies, codeDeuxiemeFacteurRequis, etapeDoubleFacteur, nettoyerCode, codeBienForme,
  secretParGroupes, cleErreurDoubleFacteur, cleErreurInscription, lienOtpauth, APPLIS_TOTP,
} from '@/lib/doubleFacteur';
import DoubleFacteurPanel from '@/components/rede/DoubleFacteurPanel';
import ContaDoubleFacteur from '@/pages/account/ContaDoubleFacteur';
import DoubleFacteurDefi from '@/components/auth/DoubleFacteurDefi';
import { LOCALE_CODES } from '../i18n/locales.js';

const RACINE = path.resolve(__dirname, '../..');
const lire = (p) => readFileSync(path.join(RACINE, p), 'utf8');
const fr = JSON.parse(lire('src/i18n/locales/fr.json'));
const avecIntl = (el) => render(<IntlProvider locale="fr" messages={fr}>{el}</IntlProvider>);

const jeton = (charge) => `e30.${Buffer.from(JSON.stringify(charge)).toString('base64url')}.signature`;
const VERIFIE = { id: 'f-1', factor_type: 'totp', status: 'verified', friendly_name: 'Téléphone', created_at: '2026-10-13T10:00:00Z' };
const INACHEVE = { id: 'f-0', factor_type: 'totp', status: 'unverified', friendly_name: 'Appareil 1', created_at: '2026-10-13T09:00:00Z' };
const session = (aal, factors) => ({ access_token: jeton({ sub: 'u', aal, user_metadata: { nom: 'Élise' } }), user: { id: 'u', factors } });

afterEach(() => { cleanup(); apiRpc.mockReset(); Object.values(mfa).forEach((f) => f.mockReset()); mfa.unenroll.mockImplementation(async () => ({ data: {}, error: null })); });

describe('doubleFacteur.js — quand un code est dû', () => {
  it('lit le niveau du jeton, accents compris ; un jeton illisible ne vaut rien', () => {
    expect(niveauDuJeton(jeton({ aal: 'aal2', nom: 'Ñandú' }))).toBe('aal2');
    expect(niveauDuJeton('pas-un-jeton')).toBeNull();
    expect(niveauDuJeton(undefined)).toBeNull();
  });

  it('seuls les facteurs vérifiés comptent', () => {
    expect(facteursVerifies({ factors: [VERIFIE, INACHEVE] })).toEqual([VERIFIE]);
    expect(facteursVerifies(null)).toEqual([]);
  });

  it('code dû = facteur vérifié ET jeton aal1', () => {
    expect(codeDeuxiemeFacteurRequis(null)).toBe(false);
    expect(codeDeuxiemeFacteurRequis(session('aal1', []))).toBe(false);
    expect(codeDeuxiemeFacteurRequis(session('aal1', [INACHEVE]))).toBe(false);
    expect(codeDeuxiemeFacteurRequis(session('aal1', [VERIFIE]))).toBe(true);
    expect(codeDeuxiemeFacteurRequis(session('aal2', [VERIFIE]))).toBe(false);
  });

  it('la forme du code et du secret', () => {
    expect(nettoyerCode(' 123 456 ')).toBe('123456');
    expect(codeBienForme('123-456')).toBe(true);
    expect(codeBienForme('12345')).toBe(false);
    expect(codeBienForme('12345a')).toBe(false);
    expect(secretParGroupes('ABCDEFGHIJ')).toBe('ABCD EFGH IJ');
  });

  it('chaque refus a sa clé, et toutes les clés existent dans les dix locales', () => {
    const codes = ['mfa_verification_failed', 'mfa_challenge_expired', 'mfa_factor_name_conflict', 'too_many_enrolled_mfa_factors',
      'insufficient_aal', 'mfa_totp_enroll_not_enabled', 'over_request_rate_limit', 'inconnu'];
    const cles = new Set([...codes.map((code) => cleErreurDoubleFacteur({ code })), cleErreurDoubleFacteur(null)]);
    expect(cles.size).toBe(8);
    for (const loc of LOCALE_CODES) {
      const msgs = JSON.parse(lire(`src/i18n/locales/${loc}.json`));
      for (const c of cles) expect(msgs[c], `${loc} ${c}`).toBeTruthy();
    }
  });
});

describe('etapeDoubleFacteur — lot 2 : code ou inscription', () => {
  const coord = { mode: 'equipes', exige: true, a_facteur: false, equipe: true };
  it('facteur vérifié en aal1 : le code, quel que soit l’état serveur', () => {
    expect(etapeDoubleFacteur(session('aal1', [VERIFIE]), undefined)).toBe('code');
    expect(etapeDoubleFacteur(session('aal1', [VERIFIE]), null)).toBe('code');
  });
  it('compte d’équipe sans appareil, exigé par le serveur : l’inscription', () => {
    expect(etapeDoubleFacteur(session('aal1', []), coord)).toBe('inscription');
  });
  it('facteur connu du serveur mais pas encore de la session : le code', () => {
    expect(etapeDoubleFacteur(session('aal1', []), { ...coord, a_facteur: true })).toBe('code');
  });
  it('rien à faire : aal2, état inconnu ou illisible, rien d’exigé, pas de session', () => {
    expect(etapeDoubleFacteur(session('aal2', [VERIFIE]), coord)).toBeNull();
    expect(etapeDoubleFacteur(session('aal1', []), undefined)).toBeNull();
    expect(etapeDoubleFacteur(session('aal1', []), null)).toBeNull();
    expect(etapeDoubleFacteur(session('aal1', []), { ...coord, exige: false })).toBeNull();
    expect(etapeDoubleFacteur(null, coord)).toBeNull();
  });
});

describe('ContaDoubleFacteur — Mon compte', () => {
  it('inactive : on inscrit (inscription abandonnée retirée d’abord), on scanne, le premier code vérifie', async () => {
    mfa.listFactors.mockResolvedValue({ data: { all: [INACHEVE] }, error: null });
    mfa.enroll.mockResolvedValue({ data: { id: 'f-2', totp: { qr_code: 'data:image/svg+xml;utf-8,<svg/>', secret: 'JBSWY3DPEHPK3PXP' } }, error: null });
    mfa.challengeAndVerify.mockResolvedValue({ data: {}, error: null });
    avecIntl(<ContaDoubleFacteur />);

    await screen.findByText(fr['twoFactor.status.off']);
    fireEvent.click(screen.getByText(fr['twoFactor.enroll.start']));
    await screen.findByAltText(fr['twoFactor.enroll.qrAlt']);
    expect(mfa.unenroll).toHaveBeenCalledWith({ factorId: 'f-0' });
    expect(mfa.enroll).toHaveBeenCalledWith({ factorType: 'totp', friendlyName: 'Appareil 1', issuer: 'AnarBib' });
    expect(screen.getByText('JBSW Y3DP EHPK 3PXP')).toBeTruthy();

    const champ = document.querySelector('input[autocomplete="one-time-code"]');
    fireEvent.change(champ, { target: { value: '123 456' } });
    mfa.listFactors.mockResolvedValue({ data: { all: [{ ...VERIFIE, id: 'f-2' }] }, error: null });
    fireEvent.submit(champ.closest('form'));
    await screen.findByText(fr['twoFactor.enroll.done']);
    expect(mfa.challengeAndVerify).toHaveBeenCalledWith({ factorId: 'f-2', code: '123456' });
  });

  it('active : un appareil listé, un second conseillé, le retrait se confirme', async () => {
    mfa.listFactors.mockResolvedValue({ data: { all: [VERIFIE] }, error: null });
    avecIntl(<ContaDoubleFacteur />);
    await screen.findByText('Téléphone');
    expect(screen.getByText(fr['twoFactor.backupAdvice'])).toBeTruthy();
    expect(screen.getByText(fr['twoFactor.enroll.addAnother'])).toBeTruthy();
    fireEvent.click(screen.getByText(fr['twoFactor.remove.button']));
    expect(mfa.unenroll).not.toHaveBeenCalled();
    mfa.listFactors.mockResolvedValue({ data: { all: [] }, error: null });
    fireEvent.click(screen.getByText(fr['twoFactor.remove.yes']));
    await screen.findByText(fr['twoFactor.remove.done']);
    expect(mfa.unenroll).toHaveBeenCalledWith({ factorId: 'f-1' });
  });

  it('retrait refusé en aal1 : le refus se dit', async () => {
    mfa.listFactors.mockResolvedValue({ data: { all: [VERIFIE] }, error: null });
    mfa.unenroll.mockResolvedValue({ data: null, error: { code: 'insufficient_aal' } });
    avecIntl(<ContaDoubleFacteur />);
    fireEvent.click(await screen.findByText(fr['twoFactor.remove.button']));
    fireEvent.click(screen.getByText(fr['twoFactor.remove.yes']));
    await screen.findByText(fr['twoFactor.error.needCode']);
  });
});

// ── REGISTRE 2FA-2 (14/10/2026) : l'inscription conduit jusque dans l'application ──
describe('2FA-2 — inscription guidée', () => {
  const URI = 'otpauth://totp/AnarBib:elise%40exemple.invalid?secret=JBSWY3DPEHPK3PXP&issuer=AnarBib';
  const presse = (writeText) => Object.defineProperty(navigator, 'clipboard', { value: writeText ? { writeText } : undefined, configurable: true });
  async function inscrire(totp) {
    mfa.listFactors.mockResolvedValue({ data: { all: [] }, error: null });
    mfa.enroll.mockResolvedValue({ data: { id: 'f-2', totp: { qr_code: 'data:image/svg+xml;utf-8,<svg/>', secret: 'JBSWY3DPEHPK3PXP', ...totp } }, error: null });
    avecIntl(<ContaDoubleFacteur />);
    fireEvent.click(await screen.findByText(fr['twoFactor.enroll.start']));
    await screen.findByAltText(fr['twoFactor.enroll.qrAlt']);
  }

  it('aides : refus propre à l’inscription, lien otpauth bien formé seulement', () => {
    expect(cleErreurInscription({ code: 'mfa_verification_failed' })).toBe('twoFactor.error.badCodeEnroll');
    expect(cleErreurInscription({ code: 'mfa_verification_rejected' })).toBe('twoFactor.error.badCodeEnroll');
    expect(cleErreurInscription({ code: 'mfa_challenge_expired' })).toBe('twoFactor.error.expired');
    expect(cleErreurInscription(null)).toBe('twoFactor.error.generic');
    expect(cleErreurDoubleFacteur({ code: 'mfa_verification_failed' })).toBe('twoFactor.error.badCode');
    expect(lienOtpauth(URI)).toBe(URI);
    for (const x of [undefined, null, '', 'https://exemple.invalid', 'javascript:alert(1)', 'otpauth://hotp/x?secret=A', 'otpauth://totp/a b']) {
      expect(lienOtpauth(x), String(x)).toBeNull();
    }
  });

  it('les étapes de chaque application existent dans les dix locales et se formatent (le lien cité par son nom)', () => {
    const cles = ['twoFactor.enroll.openLink', 'twoFactor.enroll.openLinkHint', 'twoFactor.enroll.copied', 'twoFactor.enroll.copyFailed',
      'twoFactor.error.badCodeEnroll', 'twoFactor.guide.summary', 'twoFactor.guide.legend', 'twoFactor.guide.otherApp', 'twoFactor.guide.pick'];
    for (const a of APPLIS_TOTP) for (let i = 1; i <= a.etapes; i++) cles.push(`twoFactor.guide.${a.id}.${i}`);
    expect(APPLIS_TOTP.map((a) => a.id)).toEqual(['aegis', 'freeotp', 'keepassxc', 'other']);
    for (const loc of LOCALE_CODES) {
      const msgs = JSON.parse(lire(`src/i18n/locales/${loc}.json`));
      expect(msgs[`twoFactor.guide.${APPLIS_TOTP.at(-1).id}.${APPLIS_TOTP.at(-1).etapes + 1}`], `${loc} étape de trop`).toBeUndefined();
      for (const c of cles) {
        expect(msgs[c], `${loc} ${c}`).toBeTruthy();
        const texte = new IntlMessageFormat(msgs[c], loc).format({ lien: '§LIEN§' });
        if (msgs[c].includes('{lien}')) expect(texte, `${loc} ${c}`).toContain('§LIEN§');
        expect(texte, `${loc} ${c}`).not.toMatch(/[{}]/);
      }
    }
  });

  it('le volet « J’utilise… » est fermé par défaut ; choisir KeePassXC montre ses étapes, avec les vrais menus', async () => {
    await inscrire({ uri: URI });
    const volet = document.querySelector('details.ab-conta-guide');
    expect(volet).toBeTruthy();
    expect(volet.open).toBe(false);
    expect(volet.querySelector('summary').textContent).toBe(fr['twoFactor.guide.summary']);
    expect(screen.getByText(fr['twoFactor.guide.pick'])).toBeTruthy();
    const radios = screen.getAllByRole('radio');
    expect(radios.map((r) => r.closest('label').textContent)).toEqual(['Aegis', 'FreeOTP+', 'KeePassXC', fr['twoFactor.guide.otherApp']]);
    expect(radios.every((r) => !r.checked)).toBe(true);

    fireEvent.click(screen.getByLabelText('KeePassXC'));
    const etapes = volet.querySelectorAll('ol li');
    expect(etapes).toHaveLength(4);
    expect(etapes[1].textContent).toBe(fr['twoFactor.guide.keepassxc.2']);
    expect(etapes[1].textContent).toContain('« Configurer le TOTP… »');
    expect(screen.queryByText(fr['twoFactor.guide.pick'])).toBeNull();

    fireEvent.click(screen.getByLabelText('Aegis'));
    const aegis = volet.querySelectorAll('ol li');
    expect(aegis).toHaveLength(4);
    expect(aegis[1].textContent).toContain(`« ${fr['twoFactor.enroll.openLink']} »`);
  });

  it('le lien otpauth est à côté du QR quand l’inscription le rend, et seulement alors', async () => {
    await inscrire({ uri: URI });
    const lien = screen.getByRole('link', { name: fr['twoFactor.enroll.openLink'] });
    expect(lien.getAttribute('href')).toBe(URI);
    expect(window.location.href).not.toContain('JBSWY3DPEHPK3PXP');
    cleanup();
    await inscrire({});
    expect(screen.queryByRole('link', { name: fr['twoFactor.enroll.openLink'] })).toBeNull();
  });

  it('un code refusé à l’inscription nomme les trois causes ; à la connexion, le message reste le sien', async () => {
    await inscrire({ uri: URI });
    mfa.challengeAndVerify.mockResolvedValue({ data: null, error: { code: 'mfa_verification_failed' } });
    const champ = document.querySelector('input[autocomplete="one-time-code"]');
    fireEvent.change(champ, { target: { value: '123456' } });
    fireEvent.submit(champ.closest('form'));
    await screen.findByText(fr['twoFactor.error.badCodeEnroll']);
    expect(screen.queryByText(fr['twoFactor.error.badCode'])).toBeNull();
    expect(fr['twoFactor.error.badCodeEnroll']).not.toBe(fr['twoFactor.error.badCode']);
  });

  it('« Copier la clé » dit que c’est copié ; sans presse-papiers, la clé brute est sélectionnée et on le dit', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    presse(writeText);
    await inscrire({ uri: URI });
    fireEvent.click(screen.getByText(fr['twoFactor.enroll.copy']));
    await screen.findByText(fr['twoFactor.enroll.copied']);
    expect(writeText).toHaveBeenCalledWith('JBSWY3DPEHPK3PXP');
    cleanup();

    presse(vi.fn().mockRejectedValue(new Error('NotAllowedError')));
    await inscrire({ uri: URI });
    fireEvent.click(screen.getByText(fr['twoFactor.enroll.copy']));
    await screen.findByText(fr['twoFactor.enroll.copyFailed']);
    const cle = screen.getByLabelText(fr['twoFactor.enroll.copy']);
    expect(cle.value).toBe('JBSWY3DPEHPK3PXP');
    await waitFor(() => expect(document.activeElement).toBe(cle));
    expect(screen.queryByText(fr['twoFactor.enroll.copied'])).toBeNull();
    cleanup();

    presse(null);
    await inscrire({});
    fireEvent.click(screen.getByText(fr['twoFactor.enroll.copy']));
    await screen.findByText(fr['twoFactor.enroll.copyFailed']);
  });
});

describe('DoubleFacteurDefi — le code à la connexion', () => {
  it('code mal formé : refusé sans appel ; mauvais code : refus traduit', async () => {
    avecIntl(<DoubleFacteurDefi session={session('aal1', [VERIFIE])} />);
    const champ = document.querySelector('input[autocomplete="one-time-code"]');
    fireEvent.change(champ, { target: { value: '12' } });
    fireEvent.submit(champ.closest('form'));
    await screen.findByText(fr['twoFactor.error.malformed']);
    expect(mfa.challengeAndVerify).not.toHaveBeenCalled();

    mfa.challengeAndVerify.mockResolvedValue({ data: null, error: { code: 'mfa_verification_failed' } });
    fireEvent.change(champ, { target: { value: '654321' } });
    fireEvent.submit(champ.closest('form'));
    await screen.findByText(fr['twoFactor.error.badCode']);
    expect(mfa.challengeAndVerify).toHaveBeenCalledWith({ factorId: 'f-1', code: '654321' });
  });

  it('plusieurs appareils : on choisit lequel', async () => {
    const autre = { ...VERIFIE, id: 'f-3', friendly_name: 'KeePassXC' };
    mfa.challengeAndVerify.mockResolvedValue({ data: {}, error: null });
    avecIntl(<DoubleFacteurDefi session={session('aal1', [VERIFIE, autre])} />);
    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'f-3' } });
    const champ = document.querySelector('input[autocomplete="one-time-code"]');
    fireEvent.change(champ, { target: { value: '111111' } });
    fireEvent.submit(champ.closest('form'));
    await waitFor(() => expect(mfa.challengeAndVerify).toHaveBeenCalledWith({ factorId: 'f-3', code: '111111' }));
  });
});

describe('DoubleFacteurPanel — page Réseau', () => {
  const COORD = { user_id: 'u-1', nom: 'Camille', email: 'c@x.org', administration: false, equipes: 'BLMF (coordenador)', facteurs: 0, dernier_facteur: null };
  const LECT = { user_id: 'u-2', nom: 'Lou', email: 'l@x.org', administration: false, equipes: null, facteurs: 1, dernier_facteur: '2026-10-13T10:00:00Z' };
  it('le mode, les comptes sans appareil, le retrait exige un motif puis se fait', async () => {
    apiRpc.mockImplementation(async (fn) => {
      if (fn === 'fn_admin_double_facteur_comptes') return { data: [COORD, LECT], error: null };
      if (fn === 'fn_mon_etat_double_facteur') return { data: { mode: 'off' }, error: null };
      if (fn === 'fn_admin_retirer_double_facteur') return { data: { facteurs_retires: 1, sessions_fermees: 2 }, error: null };
      return { data: null, error: { message: '{}' } };
    });
    avecIntl(<DoubleFacteurPanel />);
    await screen.findByText('Camille');
    expect(screen.getByText(fr['twoFactor.admin.mode'].replace('{mode}', fr['twoFactor.admin.mode.off']))).toBeTruthy();
    expect(screen.getByText(fr['twoFactor.admin.none'])).toBeTruthy();
    // un seul bouton de retrait : le compte sans appareil n'en a pas
    const boutons = screen.getAllByText(fr['twoFactor.admin.remove']);
    expect(boutons).toHaveLength(1);
    fireEvent.click(boutons[0]);
    const motif = document.querySelector('form input[type="text"]');
    fireEvent.change(motif, { target: { value: 'court' } });
    fireEvent.submit(motif.closest('form'));
    await screen.findByText(fr['twoFactor.admin.motifRequired']);
    expect(apiRpc).not.toHaveBeenCalledWith('fn_admin_retirer_double_facteur', expect.anything());
    fireEvent.change(motif, { target: { value: 'Identité vérifiée de vive voix en assemblée' } });
    fireEvent.submit(motif.closest('form'));
    await waitFor(() => expect(apiRpc).toHaveBeenCalledWith('fn_admin_retirer_double_facteur', { p_user: 'u-2', p_motif: 'Identité vérifiée de vive voix en assemblée' }));
  });
  it('administration en aal1 : le refus aal2_required se traduit', async () => {
    apiRpc.mockImplementation(async (fn) => {
      if (fn === 'fn_admin_double_facteur_comptes') return { data: [LECT], error: null };
      if (fn === 'fn_mon_etat_double_facteur') return { data: { mode: 'equipes' }, error: null };
      return { data: null, error: { status: 403, message: JSON.stringify({ code: '42501', message: 'aal2_required' }) } };
    });
    avecIntl(<DoubleFacteurPanel />);
    fireEvent.click(await screen.findByText(fr['twoFactor.admin.remove']));
    const motif = document.querySelector('form input[type="text"]');
    fireEvent.change(motif, { target: { value: 'Identité vérifiée sur Matrix' } });
    fireEvent.submit(motif.closest('form'));
    await screen.findByText(fr['twoFactor.error.needCode']);
  });
});

describe('le code passe avant tout', () => {
  it('LoginPage : vue mfa demandée avant le changement de mot de passe forcé et la redirection', () => {
    const src = lire('src/pages/public/LoginPage.jsx');
    const effet = src.slice(src.indexOf('if (view !== \'login\') return;'));
    expect(effet.indexOf('etapeDoubleFacteur(session, doubleFacteur)')).toBeGreaterThan(-1);
    expect(effet.indexOf('etapeDoubleFacteur(session, doubleFacteur)')).toBeLessThan(effet.indexOf('must_change_password === true'));
    expect(src).toMatch(/view === 'mfa' && \(\s*<DoubleFacteurDefi/);
  });

  it('ProtectedRoute : session aal1 qui doit un code ou une inscription renvoyée vers /login avec next', () => {
    const src = lire('src/components/layout/ProtectedRoute.jsx');
    expect(src).toMatch(/if \(etapeDoubleFacteur\(session, doubleFacteur\)\) \{\s*return <Navigate to=\{`\/login\$\{next\}`\} replace \/>;/);
  });

  it('LoginPage : vue d’inscription obligatoire, et attente de l’état serveur en aal1', () => {
    const src = lire('src/pages/public/LoginPage.jsx');
    expect(src).toMatch(/setView\(etape === 'code' \? 'mfa' : 'mfa-inscription'\)/);
    expect(src).toMatch(/view === 'mfa-inscription' && \(\s*<div>\s*<ContaDoubleFacteur obligatoire \/>/);
    expect(src).toContain("if (doubleFacteur === undefined && niveauDuJeton(session?.access_token) !== 'aal2') return;");
  });

  it('AuthContext : l’état serveur relu à chaque nouveau jeton, exposé', () => {
    const src = lire('src/contexts/AuthContext.jsx');
    expect(src).toContain("apiRpc('fn_mon_etat_double_facteur')");
    expect(src).toMatch(/\}, \[jeton\]\);/);
    expect(src).toMatch(/exitRecovery,\s*doubleFacteur,/);
  });
});
