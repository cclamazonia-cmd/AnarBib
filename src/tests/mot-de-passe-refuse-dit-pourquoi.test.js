// 22/09/2026 — Un mot de passe refusé dit POURQUOI, et le compte contributeur se supprime.
//
// Trouvé pendant l'essai de bascule authentifié : Supabase Auth refuse un mot de
// passe faible avec « …please choose a different one. » et les formulaires, qui
// testaient le mot « different », affichaient « le nouveau mot de passe doit être
// différent de l'ancien ». Ici : les messages RÉELS de GoTrue (relevés en
// production le 22/09 sur /auth/v1/signup) donnent chacun leur clé.
import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { localizeError } from '../lib/localizeError';

const ROOT = join(__dirname, '..', '..');
const t = ({ id }) => `<${id}>`;

describe('localizeError — refus de mot de passe par Supabase Auth', () => {
  it('même mot de passe qu\'avant (code same_password) → resetSamePassword', () => {
    expect(localizeError({ code: 'same_password', message: 'New password should be different from the old password.' }, t))
      .toBe('<auth.resetSamePassword>');
  });
  it('mot de passe connu des fuites (« choose a different one ») → passwordPwned, PAS resetSamePassword', () => {
    const err = { code: 'weak_password', message: 'Password is known to be weak and easy to guess, please choose a different one.', reasons: ['pwned'] };
    expect(localizeError(err, t)).toBe('<auth.passwordPwned>');
  });
  it('les raisons peuvent aussi arriver sous weak_password.reasons (réponse brute)', () => {
    const err = { code: 'weak_password', message: 'Password should be at least 6 characters. Password is known to be weak and easy to guess, please choose a different one.', weak_password: { reasons: ['length', 'pwned'] } };
    expect(localizeError(err, t)).toBe('<auth.passwordPwned>');
  });
  it('trop court, sans fuite → passwordPolicy', () => {
    expect(localizeError({ code: 'weak_password', message: 'Password should be at least 6 characters.', reasons: ['length'] }, t))
      .toBe('<auth.passwordPolicy>');
  });
});

describe('les formulaires ne lisent plus les mots du message', () => {
  it('LoginPage ne teste plus « different » ni « same »', () => {
    const src = readFileSync(join(ROOT, 'src/pages/public/LoginPage.jsx'), 'utf8');
    expect(src).not.toMatch(/includes\('different'\)|includes\('same'\)/);
  });
  it('les deux clés existent dans les dix locales', () => {
    for (const loc of ['fr', 'pt-BR', 'es', 'it', 'en', 'de', 'ca', 'eo', 'nl', 'el']) {
      const j = JSON.parse(readFileSync(join(ROOT, `src/i18n/locales/${loc}.json`), 'utf8'));
      expect(j['auth.passwordPwned'], loc).toBeTruthy();
      expect(j['auth.passwordPolicy'], loc).toMatch(/6/);
    }
  });
});

describe('le compte contributeur se supprime depuis sa page', () => {
  it('ContributorAccountPage appelle fn_delete_my_account avec le même garde-fou que la page lecteur', () => {
    const src = readFileSync(join(ROOT, 'src/pages/account/ContributorAccountPage.jsx'), 'utf8');
    expect(src).toContain("supabase.rpc('fn_delete_my_account')");
    expect(src).toContain("'account.deleteAccount.confirmText'");
    expect(src).toContain("'account.deleteAccount.confirmDialog'");
    expect(src).toContain('supabase.auth.signOut()');
  });
});
